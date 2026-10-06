// The browser's file picker and canvas. No decisions are made here —
// `files.dart` decides, this does.
//
// No package for it. `package:web` is already a dependency, and a file input
// plus a canvas is the whole job.

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../data.dart';
import 'files.dart';

Future<Picked> pickPhotos() async {
  final files = await _choose();

  final photos = <PickedPhoto>[];
  var failed = 0;

  for (final file in files) {
    try {
      // createImageBitmap applies the photo's EXIF rotation, so a portrait
      // shot from a phone is not stored lying on its side.
      final bitmap = await web.window.createImageBitmap(file).toDart;
      photos.add(PickedPhoto(
        full: await _jpeg(bitmap, photoEdge),
        thumbnail: await _jpeg(bitmap, thumbnailEdge),
      ));
      bitmap.close();
    } catch (_) {
      failed++;
    }
  }

  return (photos: photos, failed: failed);
}

Future<({String name, Uint8List bytes})?> pickFile(String accept) async {
  final files = await _choose(accept: accept, multiple: false);
  if (files.isEmpty) return null;

  final file = files.first;
  final buffer = await file.arrayBuffer().toDart;
  return (name: file.name, bytes: buffer.toDart.asUint8List());
}

/// UTF-8 if the bytes are valid UTF-8, otherwise Windows-1256.
///
/// "CSV" saved from an Arabic copy of Excel is written in the Windows Arabic
/// codepage, and read as UTF-8 every Arabic product name is mojibake. UTF-8 is
/// strict about what it accepts, so failing to read as UTF-8 is a reliable
/// sign the file is in the other one.
String decodeText(Uint8List bytes) {
  try {
    return web.TextDecoder('utf-8', web.TextDecoderOptions(fatal: true)).decode(bytes.toJS);
  } catch (_) {
    return web.TextDecoder('windows-1256').decode(bytes.toJS);
  }
}

/// Resolves with nothing when the seller closes the picker without choosing.
/// The `cancel` event is what says so; without it the future would wait
/// forever and the editor would sit there believing a pick was in progress.
Future<List<web.File>> _choose({String accept = 'image/*', bool multiple = true}) {
  final completer = Completer<List<web.File>>();

  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..multiple = multiple
    ..style.display = 'none';

  void finish(List<web.File> files) {
    if (!completer.isCompleted) completer.complete(files);
    input.remove();
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      final list = input.files;
      finish([
        for (var i = 0; i < (list?.length ?? 0); i++) list!.item(i)!,
      ]);
    }).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish(const [])).toJS);

  // In the document rather than floating: Safari has ignored click() on a
  // detached input.
  web.document.body!.append(input);
  input.click();

  return completer.future;
}

Future<Uint8List> _jpeg(web.ImageBitmap bitmap, int edge) async {
  final size = fitWithin(bitmap.width, bitmap.height, edge);

  final canvas = web.HTMLCanvasElement()
    ..width = size.width
    ..height = size.height;

  final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;

  // JPEG has no transparency, and a transparent PNG drawn straight onto it
  // turns black. White is what the seller saw behind it.
  context.fillStyle = 'white'.toJS;
  context.fillRect(0, 0, size.width, size.height);
  context.imageSmoothingQuality = 'high';
  context.drawImage(bitmap, 0, 0, size.width, size.height);

  final completer = Completer<web.Blob?>();
  canvas.toBlob(
    ((web.Blob? blob) => completer.complete(blob)).toJS,
    'image/jpeg',
    0.85.toJS,
  );

  final blob = await completer.future;
  if (blob == null) throw StateError('the browser could not encode this photo');

  return (await blob.arrayBuffer().toDart).toDart.asUint8List();
}

/// Hands the seller a file, the way any download does: a link to a blob,
/// clicked once and thrown away.
void saveFile(String name, Uint8List bytes, String type) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: type));
  final url = web.URL.createObjectURL(blob);

  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..style.display = 'none';

  web.document.body!.append(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
}
