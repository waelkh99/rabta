// Importing a sheet the seller has already imported once.
//
// Asked for on 22 September 2026: a seller who fixes prices or moves products
// between categories in their own sheet, and imports it again, expects the
// catalog to follow — not to hold every product twice. Matched by the
// product's code, never its name: a shop writes one product in Arabic in one
// place and English in another. What an update may and may not change is the
// whole of the risk here, so each rule has a case.

import 'package:flutter_test/flutter_test.dart';
import 'package:rabta/data.dart';

const saved = [
  Product(
    id: 'p1',
    code: 'FS-101',
    name: 'فستان أحمر',
    price: 25,
    description: 'قطن',
    inStock: false,
    categoryId: 'c1',
    category: 'فساتين',
    photos: ['ws/dress.jpg'],
  ),
  Product(id: 'p2', code: 'P-007', name: 'Leather bag', price: 18),
];

CatalogSheet sheet(List<List<String>> rows) => readCatalogRows(rows);

void main() {
  group('reading a code column', () {
    test('a sheet reports the columns it had', () {
      final read = sheet([
        ['رمز المنتج', 'اسم المنتج', 'السعر', 'اللون'],
        ['FS-101', 'فستان', '20', 'أحمر'],
      ]);

      // The colour column goes into the details, so the details count as given.
      expect(read.columns, {'code', 'name', 'price', 'description'});
      expect(read.products.single.code, 'FS-101');
      expect(read.products.single.name, 'فستان');
    });

    test('the headers sellers use for a code are all read as one', () {
      for (final header in ['ID', 'Product ID', 'Code', 'SKU', 'الكود', 'الرمز', 'رقم المنتج']) {
        final read = sheet([
          [header, 'name'],
          ['X-1', 'dress'],
        ]);
        expect(read.products.single.code, 'X-1', reason: header);
      }
    });

    test('a barcode is not a code', () {
      final read = sheet([
        ['name', 'Barcode'],
        ['dress', '6251234567890'],
      ]);
      expect(read.products.single.code, isNull);
      expect(read.products.single.description, isNull);
    });

    test('a sheet with no header is read as the template, every column included', () {
      expect(sheet([['فستان', '20']]).columns, containsAll(catalogColumns));
    });
  });

  group('matching by code', () {
    test('a row with a known code updates that product, and can rename it', () {
      final plan = planImport(
        sheet([
          ['code', 'name', 'price'],
          ['FS-101', 'Red dress', '22'],
        ]),
        saved,
      );

      expect(plan.added, isEmpty);
      expect(plan.updated.single.id, 'p1');
      expect(plan.updated.single.name, 'Red dress');
      expect(plan.updated.single.price, 22);
    });

    test('the code is matched ignoring case and spacing', () {
      final plan = planImport(
        sheet([
          ['code', 'name'],
          ['  p-007 ', 'bag'],
        ]),
        saved,
      );

      expect(plan.updated.single.id, 'p2');
      expect(plan.updated.single.code, 'P-007');
    });

    test('the same name without a code is a new product, never a match', () {
      // The whole reason for codes: a name is not an identity.
      final plan = planImport(
        sheet([
          ['name', 'price'],
          ['فستان أحمر', '22'],
        ]),
        saved,
      );

      expect(plan.updated, isEmpty);
      expect(plan.added.single.name, 'فستان أحمر');
    });

    test('a code the catalog does not have is a new product that keeps it', () {
      final plan = planImport(
        sheet([
          ['code', 'name'],
          ['NEW-1', 'شنطة'],
        ]),
        saved,
      );

      expect(plan.added.single.code, 'NEW-1');
    });

    test('a code with no name that matches nothing is dropped, not added nameless', () {
      final plan = planImport(sheet([['code', 'price'], ['NOPE-1', '9']]), saved);

      expect(plan.added, isEmpty);
      expect(plan.updated, isEmpty);
    });

    test('a code with no name updates the product and keeps its name', () {
      final plan = planImport(sheet([['code', 'price'], ['FS-101', '9']]), saved);

      expect(plan.updated.single.name, 'فستان أحمر');
      expect(plan.updated.single.price, 9);
    });

    test('rows without a code are given the next free codes', () {
      final plan = planImport(
        sheet([
          ['name', 'price'],
          ['شنطة', '15'],
          ['حذاء', '30'],
        ]),
        saved,
      );

      // P-007 is taken, so numbering carries on after it.
      expect(plan.added.map((p) => p.code), ['P-008', 'P-009']);
    });

    test('a code twice in the sheet is imported once, and the lower row wins', () {
      final plan = planImport(
        sheet([
          ['code', 'name', 'price'],
          ['X-1', 'شنطة', '15'],
          ['x-1', 'شنطة', '16'],
        ]),
        saved,
      );

      expect(plan.added.single.price, 16);
    });
  });

  group('what an update changes', () {
    Product updateWith(List<List<String>> rows) => planImport(sheet(rows), saved).updated.single;

    test('a sheet with no stock column leaves stock alone', () {
      // Product.inStock defaults to true. Without this, every product the
      // seller had marked out of stock would be put back on sale by an import
      // that said nothing about stock at all.
      expect(updateWith([['code', 'price'], ['FS-101', '22']]).inStock, isFalse);
    });

    test('a sheet with a stock column does change it', () {
      expect(updateWith([['code', 'in_stock'], ['FS-101', 'yes']]).inStock, isTrue);
    });

    test('an empty cell leaves the saved value alone', () {
      final dress = updateWith([
        ['code', 'name', 'price', 'description', 'category'],
        ['FS-101', 'فستان أحمر', '', '', ''],
      ]);

      expect(dress.price, 25);
      expect(dress.description, 'قطن');
      expect(dress.categoryId, 'c1');
    });

    test('a new category is carried by name, to be found or made when saved', () {
      final dress = updateWith([['code', 'name', 'category'], ['FS-101', 'x', 'فساتين سهرة']]);

      expect(dress.category, 'فساتين سهرة');
      // The old id must not survive, or the save would keep the old category.
      expect(dress.categoryId, isNull);
    });

    test('photos are never touched by a sheet', () {
      expect(updateWith([['code', 'name'], ['FS-101', 'x']]).photos, ['ws/dress.jpg']);
    });

    test('nothing missing from the sheet is removed', () {
      final plan = planImport(sheet([['code', 'name'], ['FS-101', 'x']]), saved);

      // importProducts only inserts and updates; p2 is simply not in the plan.
      expect(plan.updated.map((p) => p.id), ['p1']);
    });
  });

  group('generated codes', () {
    test('carry on after the highest P- code, not into its gaps', () {
      // A deleted P-002 is not reused: a sheet the seller still has would
      // otherwise update a different product than the one it was written for.
      expect(nextCodes(['P-001', 'P-003', null, 'FS-101'], 2), ['P-004', 'P-005']);
    });

    test('start at P-001 in an empty shop', () {
      expect(nextCodes([], 1), ['P-001']);
    });

    test('keep counting past three digits', () {
      expect(nextCodes(['P-999'], 1), ['P-1000']);
    });
  });

  test('a downloaded list imports straight back, updating what it lists', () {
    // The round trip generated codes exist for: download, edit, import.
    for (final (headers, yes, no) in [
      (['رمز المنتج', 'الاسم', 'السعر', 'التفاصيل', 'متوفر', 'القسم'], 'نعم', 'لا'),
      (['Product code', 'Name', 'Price', 'Details', 'In stock', 'Category'], 'yes', 'no'),
    ]) {
      final bytes = catalogWorkbook(saved, headers: headers, yes: yes, no: no);
      final read = readCatalogXlsx(bytes);

      expect(read.columns, containsAll(['code', 'name', 'price', 'description', 'in_stock', 'category']),
          reason: headers.first);

      final plan = planImport(read, saved);
      expect(plan.added, isEmpty, reason: headers.first);
      expect(plan.updated.map((p) => p.id), ['p1', 'p2']);

      final dress = plan.updated.first;
      expect(dress.price, 25);
      expect(dress.description, 'قطن');
      expect(dress.inStock, isFalse, reason: 'out of stock survives the round trip');
      expect(dress.category, 'فساتين');
    }
  });
}
