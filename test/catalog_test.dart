// Reading a seller's spreadsheet.
//
// A seller filling in a price list is not doing data entry — they are doing
// the least interesting part of their day, once, and if it silently mangles
// their catalog the assistant then quotes the mangled version to their
// customers. Every case here is one a real file will hit.

import 'package:flutter_test/flutter_test.dart';
import 'package:rabta/data.dart';

void main() {
  group('the template', () {
    test('starts with a byte order mark, so Excel reads Arabic correctly', () {
      // Without it Excel falls back to the system codepage and every Arabic
      // name arrives as mojibake. The seller concludes the app is broken.
      expect(catalogTemplateCsv().startsWith(catalogBom), isTrue);
    });

    test('names its columns, and they are the ones the importer reads', () {
      final header = catalogTemplateCsv()
          .replaceFirst(catalogBom, '')
          .split('\n')
          .first
          .split(',');

      expect(header, catalogColumns);
    });

    test('reads back into exactly what it shows', () {
      // The example row is the only instruction most sellers will read, so it
      // has to survive a round trip unchanged.
      final products = parseCatalogCsv(catalogTemplateCsv());

      expect(products, hasLength(1));
      expect(products.single.name, 'فستان أحمر');
      expect(products.single.price, 25.500);
      expect(products.single.inStock, isTrue);
    });
  });

  group('reading a filled-in file', () {
    test('a description containing a comma does not shift the columns', () {
      // Sellers write "قطن، مقاسات S M L" constantly. Splitting on every comma
      // would quietly put a size into the price.
      final products = parseCatalogCsv(
        'name,price,description,in_stock\n'
        'فستان,25.500,"قطن, مقاسات S M L",yes\n',
      );

      expect(products.single.description, 'قطن, مقاسات S M L');
      expect(products.single.price, 25.500);
    });

    test('a doubled quote inside a quoted field is one quote', () {
      final products = parseCatalogCsv(
        'name,price\n'
        '"the ""red"" one",100\n',
      );

      expect(products.single.name, 'the "red" one');
    });

    test('a price written with a separator or a currency still reads', () {
      // "25.500 د.ا" is how a seller writes a price. Refusing it would mean
      // the assistant thinks the product has no price at all.
      final products = parseCatalogCsv(
        'name,price\n'
        'a,"1,250"\n'
        'b,30.750 د.ا\n'
        'c,١٥.٥٠٠\n',
      );

      expect(products.map((p) => p.price), [1250, 30.750, 15.500]);
    });

    test('a missing price is null rather than zero', () {
      // Zero would read as free, and the assistant would say so.
      final products = parseCatalogCsv('name,price\nفستان,\n');

      expect(products.single.price, isNull);
    });

    test('anything that plainly means no is out of stock', () {
      final products = parseCatalogCsv(
        'name,in_stock\n'
        'a,no\n'
        'b,false\n'
        'c,0\n'
        'd,لا\n'
        'e,نفد\n',
      );

      expect(products.every((p) => !p.inStock), isTrue);
    });

    test('an empty stock column means the seller has it', () {
      // A product they bothered to list is for sale until they say otherwise,
      // and defaulting the other way would silence the assistant on everything.
      final products = parseCatalogCsv('name,price,in_stock\nفستان,25.500,\n');

      expect(products.single.inStock, isTrue);
    });

    test('a row with no name is skipped', () {
      // A price with nothing attached is not a product, and a stray trailing
      // row is the most common thing a spreadsheet exports.
      final products = parseCatalogCsv(
        'name,price\n'
        'فستان,25.500\n'
        ',999\n',
      );

      expect(products, hasLength(1));
    });

    test('a file with no header row is read in the template order', () {
      // Sellers delete the header. It should not cost them their first row.
      final products = parseCatalogCsv('فستان,25.500,قطن,yes\n');

      expect(products.single.name, 'فستان');
      expect(products.single.price, 25.500);
    });

    test('columns in a different order are followed, not assumed', () {
      final products = parseCatalogCsv(
        'price,name\n'
        '25.500,فستان\n',
      );

      expect(products.single.name, 'فستان');
      expect(products.single.price, 25.500);
    });

    test('Windows line endings do not end up inside the last column', () {
      // Excel on Windows writes \r\n, and a stray \r would become part of the
      // stock value and make everything read as in stock.
      final products = parseCatalogCsv(
        'name,in_stock\r\n'
        'فستان,no\r\n',
      );

      expect(products.single.inStock, isFalse);
      expect(products.single.name, 'فستان');
    });

    test('cells pasted straight out of a spreadsheet are tab separated', () {
      // Copying from Excel or Google Sheets puts tabs on the clipboard, not
      // commas. Reading only commas would turn each pasted row into one long
      // product name with the price buried inside it.
      final products = parseCatalogCsv(
        'name\tprice\tdescription\tin_stock\n'
        'فستان أحمر\t25.500\tقطن\tyes\n'
        'حذاء\t40000\tجلد\tno\n',
      );

      expect(products, hasLength(2));
      expect(products.first.name, 'فستان أحمر');
      expect(products.first.price, 25.500);
      expect(products.first.description, 'قطن');
      expect(products.last.inStock, isFalse);
    });

    test('a comma inside a pasted cell is not a column break', () {
      // The delimiter is decided per paste. A description written with commas
      // must survive when the columns are tabs.
      final products = parseCatalogCsv(
        'name\tprice\tdescription\n'
        'فستان\t25.500\tقطن، مقاسات S, M, L\n',
      );

      expect(products, hasLength(1));
      expect(products.single.description, 'قطن، مقاسات S, M, L');
      expect(products.single.price, 25.500);
    });

    test('a tab inside a quoted comma-separated field is just a tab', () {
      final products = parseCatalogCsv(
        'name,description\n'
        'فستان,"a\tb"\n',
      );

      expect(products.single.description, 'a\tb');
    });

    test('an empty file is empty rather than an error', () {
      expect(parseCatalogCsv(''), isEmpty);
      expect(parseCatalogCsv('\n\n'), isEmpty);
      expect(parseCatalogCsv(catalogBom), isEmpty);
    });

    test('a header with no data row imports nothing', () {
      expect(parseCatalogCsv('name,price,description,in_stock\n'), isEmpty);
    });
  });

  group('products', () {
    test('a price arriving as a string is still a number', () {
      // Postgres hands numeric back as a string often enough to matter, and
      // with three decimal places now that fils are stored.
      final product = Product.fromRow({
        'id': 'p1',
        'name': 'فستان',
        'price': '25.500',
        'in_stock': true,
      });

      expect(product.price, 25.5);
    });

    test('a product with no stock column recorded is in stock', () {
      final product = Product.fromRow({'id': 'p1', 'name': 'فستان'});
      expect(product.inStock, isTrue);
    });

    test('a price can be cleared, which copyWith alone cannot express', () {
      const product = Product(id: 'p1', name: 'فستان', price: 25.500);

      expect(product.copyWith(clearPrice: true).price, isNull);
      expect(product.copyWith(name: 'حذاء').price, 25.500);
    });
  });

  group('the shop', () {
    test('a workspace with no row has the assistant switched off', () {
      // Every workspace starts here, and defaulting the other way would have
      // the assistant answering customers nobody agreed to hand over.
      const shop = Shop();

      expect(shop.assistantEnabled, isFalse);
    });

    test('a shop with no currency set still has one', () {
      // The product mainly serves Jordan. A price with no unit is not an
      // answer, so there is never no currency — only an unchanged default.
      expect(const Shop().currency, 'د.ا');
      expect(Shop.fromRow({'currency': ''}).currency, 'د.ا');
      expect(Shop.fromRow({'currency': '  '}).currency, 'د.ا');
      expect(Shop.fromRow({'currency': r'$'}).currency, r'$');
    });


    test('the shop keeps what it was given', () {
      final shop = Shop.fromRow({
        'currency': 'د.ا',
        'delivery_note': 'مجاني فوق 50',
        'locations': 'عمّان، شارع الرينبو',
        'hours': 'السبت إلى الخميس',
        'about': 'الدفع عند الاستلام',
        'assistant_enabled': true,
      });

      expect(shop.deliveryNote, 'مجاني فوق 50');
      expect(shop.locations, 'عمّان، شارع الرينبو');
      expect(shop.hours, 'السبت إلى الخميس');
      expect(shop.about, 'الدفع عند الاستلام');
      expect(shop.assistantEnabled, isTrue);
    });
  });

  group('delivery zones', () {
    test('a zone with no fee keeps none', () {
      // Not free — the shop covers that place but the price depends. Turning
      // null into zero would have the assistant promising free delivery.
      final zone = DeliveryZone.fromRow({'id': 'z1', 'name': 'العقبة'});
      expect(zone.fee, isNull);
    });

    test('a fee arriving as a string is still a number', () {
      final zone = DeliveryZone.fromRow({'id': 'z2', 'name': 'عمّان', 'fee': '2.000'});
      expect(zone.fee, 2);
    });
  });

  group('showing a price', () {
    test('a price carries the currency', () {
      // 25.5 on its own is not an answer to "how much".
      expect(formatPrice(25.5, 'د.ا'), '25.500 د.ا');
    });

    test('fils are kept, not rounded away', () {
      // The dinar divides into 1000 fils. Rounding 12.750 to 12.75 would be
      // the application quietly changing a number the seller typed.
      expect(formatPrice(12.75, 'د.ا'), '12.750 د.ا');
      expect(formatPrice(0.5, 'د.ا'), '0.500 د.ا');
    });

    test('a whole price is not padded with decimals it never had', () {
      expect(formatPrice(25, 'د.ا'), '25 د.ا');
    });

    test('thousands are grouped', () {
      expect(formatPrice(1250, r'$'), r'1,250 $');
    });

    test('a price with no currency is just the number', () {
      expect(formatPrice(25), '25');
    });
  });
}
