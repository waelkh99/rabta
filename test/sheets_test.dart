// Reading a price list the seller already had, in whatever shape it is in.
//
// Asked for on 22 September 2026: "some owners will have pre-made excel
// sheets". A pre-made sheet was not made from our template. Its columns are
// named in the seller's words, it often starts with a title, and it holds
// things we have no field for — so each case here is one a real sheet has.

import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rabta/data.dart';
import 'package:rabta/files.dart';

Uint8List workbook(List<List<Object?>> rows) {
  final book = Excel.createExcel();
  final sheet = book[book.getDefaultSheet()!];

  for (final row in rows) {
    sheet.appendRow([
      for (final cell in row)
        switch (cell) {
          null => null,
          final int number => IntCellValue(number),
          final double number => DoubleCellValue(number),
          _ => TextCellValue(cell.toString()),
        },
    ]);
  }

  return Uint8List.fromList(book.encode()!);
}

String utf(Uint8List bytes) => utf8.decode(bytes);

void main() {
  group('a sheet in the seller\'s own words', () {
    test('Arabic headers are understood', () {
      final products = parseCatalogRows([
        ['اسم المنتج', 'السعر', 'الوصف', 'القسم'],
        ['فستان أحمر', '25.500', 'قطن', 'فساتين'],
      ]);

      expect(products.single.name, 'فستان أحمر');
      expect(products.single.price, 25.5);
      expect(products.single.description, 'قطن');
      expect(products.single.category, 'فساتين');
    });

    test('English headers are understood, whatever their case', () {
      final products = parseCatalogRows([
        ['Product Name', 'Price (JD)', 'Category'],
        ['Red dress', '25', 'Dresses'],
      ]);

      expect(products.single.name, 'Red dress');
      expect(products.single.price, 25);
      expect(products.single.category, 'Dresses');
    });

    test('a category name column is a category, not the product name', () {
      // "اسم القسم" contains the word for name. Read as the name, every
      // product would be called "فساتين".
      final products = parseCatalogRows([
        ['اسم القسم', 'اسم المنتج', 'السعر'],
        ['فساتين', 'فستان أحمر', '25'],
      ]);

      expect(products.single.name, 'فستان أحمر');
      expect(products.single.category, 'فساتين');
    });

    test('a title above the header is skipped', () {
      final products = parseCatalogRows([
        ['قائمة أسعار متجر ليلى'],
        [''],
        ['المنتج', 'السعر'],
        ['شنطة', '18'],
      ]);

      expect(products.single.name, 'شنطة');
      expect(products.single.price, 18);
    });

    test('what the shop paid is never read', () {
      // The one mistake here that would reach a customer: "سعر التكلفة"
      // contains the word for price, and read as the price the assistant
      // would quote the seller's cost.
      final products = parseCatalogRows([
        ['المنتج', 'سعر التكلفة', 'سعر البيع', 'Wholesale'],
        ['شنطة', '9', '18', '12'],
      ]);

      expect(products.single.price, 18);
      expect(products.single.description, isNull);
    });

    test('columns we have no field for go into the details, under their own name', () {
      final products = parseCatalogRows([
        ['المنتج', 'السعر', 'اللون', 'المقاسات', 'الخامة'],
        ['فستان', '25', 'أسود، بيج', 'S M L', 'قطن'],
      ]);

      expect(products.single.description, 'اللون: أسود، بيج\nالمقاسات: S M L\nالخامة: قطن');
    });

    test('the details column comes first, and empty extras are left out', () {
      final products = parseCatalogRows([
        ['Name', 'Colour', 'Notes', 'Size'],
        ['Dress', 'Red', 'Runs small', ''],
      ]);

      expect(products.single.description, 'Runs small\nColour: Red');
    });

    test('a second price column is kept as a detail rather than replacing the first', () {
      final products = parseCatalogRows([
        ['المنتج', 'السعر', 'السعر قبل'],
        ['فستان', '20', '25'],
      ]);

      expect(products.single.price, 20);
      expect(products.single.description, 'السعر قبل: 25');
    });

    test('a quantity of zero is out of stock, and any other is in stock', () {
      final products = parseCatalogRows([
        ['المنتج', 'الكمية'],
        ['فستان', '0'],
        ['شنطة', '7'],
      ]);

      expect(products.map((p) => p.inStock), [false, true]);
      // The count itself is not kept anywhere: this is not stock control.
      expect(products.first.description, isNull);
    });

    test('a row number column is ignored', () {
      final products = parseCatalogRows([
        ['#', 'المنتج', 'السعر'],
        ['1', 'فستان', '20'],
      ]);

      expect(products.single.name, 'فستان');
      expect(products.single.description, isNull);
    });
  });

  group('an Excel file', () {
    test('is read from its first sheet', () {
      final bytes = workbook([
        ['اسم المنتج', 'السعر', 'اللون'],
        ['فستان أحمر', 25.5, 'أحمر'],
        ['شنطة', 18, null],
      ]);

      final products = parseCatalogXlsx(bytes);

      expect(products.map((p) => p.name), ['فستان أحمر', 'شنطة']);
      expect(products.map((p) => p.price), [25.5, 18]);
      expect(products.first.description, 'اللون: أحمر');
    });

    test('a whole number stored as a decimal reads back as the seller typed it', () {
      final products = parseCatalogXlsx(workbook([
        ['Name', 'Size'],
        ['Shoe', 38.0],
      ]));

      expect(products.single.description, 'Size: 38');
    });

    test('is told apart from a text file by its name', () {
      final bytes = workbook([
        ['Name', 'Price'],
        ['Dress', 20],
      ]);

      expect(readCatalogFile('Prices.XLSX', bytes, utf).products.single.name, 'Dress');
      expect(
        readCatalogFile('prices.csv', Uint8List.fromList(utf8.encode('name,price\nDress,20\n')), utf)
            .products
            .single
            .price,
        20,
      );
    });

    test('an old .xls file is named as such, so the seller can fix it', () {
      expect(
        () => readCatalogFile('old.xls', Uint8List(10), utf),
        throwsA(isA<SheetException>().having((e) => e.problem, 'problem', SheetProblem.oldExcel)),
      );
    });

    test('a damaged file is unreadable rather than a crash', () {
      expect(
        () => readCatalogFile('broken.xlsx', Uint8List.fromList([1, 2, 3, 4]), utf),
        throwsA(isA<SheetException>().having((e) => e.problem, 'problem', SheetProblem.unreadable)),
      );
    });
  });
}
