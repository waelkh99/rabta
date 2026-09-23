// The files a seller picks: product photos, and a price list they already
// keep in Excel.
//
// Photos. A phone photo arrives at about 6 MB (measured on a real delivery, 15
// September). Kept as it is, that is slow for the seller to upload on a phone
// connection, slow for Meta to fetch when the assistant sends it, and storage
// nobody needs. So every photo is re-encoded in the browser before it leaves:
// a 1600px JPEG to show and send, and a 320px one the assistant can compare a
// customer's screenshot against without paying for a full-size image.
//
// Spreadsheets. Asked for by the product owner on 22 September 2026: "some
// owners will have pre-made excel sheets". The paste box stays — it is still
// the fastest way from a sheet that is already open — and a file can now be
// chosen as well.
//
// What is decided is decided here, in plain Dart, so it can be tested.
// `files_web.dart` does the talking to the browser.

import 'dart:typed_data';

import 'data.dart';
import 'files_stub.dart' if (dart.library.js_interop) 'files_web.dart' as browser;

/// The long edge of the photo that is shown and sent. Enough for a phone
/// screen at full width; a customer on Instagram never sees more.
const photoEdge = 1600;

/// The long edge of the thumbnail. At this size the model reads a photo for
/// about 137 tokens.
const thumbnailEdge = 320;

/// The size to draw an image at so its long edge is at most [edge], keeping
/// its shape. Never scaled up — a small photo stays as sharp as it was.
({int width, int height}) fitWithin(int width, int height, int edge) {
  final long = width > height ? width : height;
  if (long <= edge || long == 0) return (width: width, height: height);

  final scale = edge / long;
  return (
    width: (width * scale).round().clamp(1, edge),
    height: (height * scale).round().clamp(1, edge),
  );
}

/// What came back from the picker: the photos that could be read, and how many
/// could not. A photo the browser cannot decode — an iPhone's HEIC in Chrome,
/// most often — is counted rather than thrown, so the seller hears about it
/// and the rest still arrive.
typedef Picked = ({List<PickedPhoto> photos, int failed});

/// Opens the browser's file picker. Empty if the seller cancels.
Future<Picked> pickPhotos() => browser.pickPhotos();

/// A spreadsheet that could not be read, and why, in terms the interface can
/// turn into words for the seller.
enum SheetProblem {
  /// The old binary `.xls` format. Excel still opens it and nothing small
  /// reads it; "save as .xlsx" is a thing a seller can do.
  oldExcel,

  /// Not a spreadsheet at all, or a damaged one.
  unreadable,
}

class SheetException implements Exception {
  const SheetException(this.problem);

  final SheetProblem problem;
}

/// Products out of a file the seller chose.
///
/// [decode] turns a text file's bytes into text. It is passed in because the
/// right answer depends on the browser: a CSV saved from an Arabic copy of
/// Excel is in Windows-1256, not UTF-8, and only the browser's decoder knows
/// that encoding.
CatalogSheet readCatalogFile(String name, Uint8List bytes, String Function(Uint8List) decode) {
  final lower = name.toLowerCase();

  if (lower.endsWith('.xls')) throw const SheetException(SheetProblem.oldExcel);

  try {
    if (lower.endsWith('.xlsx')) return readCatalogXlsx(bytes);
    return readCatalogCsv(decode(bytes));
  } on SheetException {
    rethrow;
  } catch (_) {
    throw const SheetException(SheetProblem.unreadable);
  }
}

/// Opens the file picker for a price list. Null if the seller cancels.
Future<CatalogSheet?> pickCatalogFile() async {
  final file = await browser.pickFile('.xlsx,.xls,.csv,.tsv,.txt');
  if (file == null) return null;

  return readCatalogFile(file.name, file.bytes, browser.decodeText);
}

/// Saves the catalog as an Excel file on the seller's computer or phone.
void downloadCatalog(
  List<Product> products, {
  required List<String> headers,
  required String yes,
  required String no,
}) {
  browser.saveFile(
    'products.xlsx',
    catalogWorkbook(products, headers: headers, yes: yes, no: no),
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
}
