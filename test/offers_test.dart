// What an offer does to a price, as the seller sees it on the product row.
//
// The assistant works the same number out on the server. The cases are shared
// with supabase/tests/ai.test.ts through test/fixtures/offers.json, so if the
// two ever disagree, one of these fails — rather than the seller seeing one
// price and a customer being told another.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rabta/data.dart';

void main() {
  final shared = jsonDecode(File('test/fixtures/offers.json').readAsStringSync()) as Map<String, dynamic>;

  group('sale price, shared with the server', () {
    for (final example in (shared['cases'] as List).cast<Map<String, dynamic>>()) {
      test(example['name'] as String, () {
        final p = example['product'] as Map<String, dynamic>;
        final product = Product(
          id: p['id'] as String,
          name: 'x',
          price: (p['price'] as num?)?.toDouble(),
          categoryId: p['categoryId'] as String?,
        );

        final offers = [
          for (final o in (example['offers'] as List).cast<Map<String, dynamic>>())
            Offer(
              kind: OfferKind.of(o['kind'] as String),
              value: (o['value'] as num?)?.toDouble(),
              buy: o['buy'] as int?,
              get: o['get'] as int?,
              categoryIds: [...?(o['categoryIds'] as List?)?.cast<String>()],
              productIds: [...?(o['productIds'] as List?)?.cast<String>()],
              startsOn: o['startsOn'] as String?,
              endsOn: o['endsOn'] as String?,
              enabled: o['enabled'] as bool? ?? true,
            ),
        ];

        final expected = (example['expected'] as num?)?.toDouble();
        expect(salePrice(product, offers, example['today'] as String), expected);
      });
    }
  });

  group('an offer', () {
    test('reads back from its row, and writes the same row', () {
      final row = {
        'id': 'o1',
        'name': 'عرض العيد',
        'kind': 'buy_get',
        'value': null,
        'buy': 2,
        'get': 1,
        'category_ids': ['c1'],
        'product_ids': <String>[],
        'starts_on': '2026-09-20',
        'ends_on': '2026-09-30',
        'enabled': true,
        'description': null,
      };

      final offer = Offer.fromRow(row);
      expect(offer.kind, OfferKind.buyGet);
      expect(offer.toRow(), {...row}..remove('id'));
    });

    test('a kind this build does not know is read as a percentage, not a crash', () {
      expect(OfferKind.of('bundle'), OfferKind.percent);
    });

    test('a blank name is stored as none, so the offer is described by what it does', () {
      const offer = Offer(name: '  ', kind: OfferKind.percent, value: 10);
      expect(offer.toRow()['name'], isNull);
    });

    test('a buy X get Y offer never carries a value, whatever the editor left in it', () {
      const offer = Offer(kind: OfferKind.buyGet, value: 10, buy: 2, get: 1);
      expect(offer.toRow()['value'], isNull);
    });

    test('knows whether it is running, scheduled, ended or off', () {
      const offer = Offer(
        kind: OfferKind.percent,
        value: 10,
        startsOn: '2026-09-20',
        endsOn: '2026-09-30',
      );

      expect(offer.stateOn('2026-09-19'), OfferState.scheduled);
      expect(offer.stateOn('2026-09-20'), OfferState.running);
      expect(offer.stateOn('2026-09-30'), OfferState.running);
      expect(offer.stateOn('2026-10-01'), OfferState.ended);
      expect(offer.copyWith(enabled: false).stateOn('2026-09-25'), OfferState.off);
    });
  });

  test("today is Amman's date, not the browser's", () {
    // 22:30 UTC on the 22nd is already the 23rd in Amman.
    expect(todayInAmman(DateTime.utc(2026, 9, 22, 22, 30)), '2026-09-23');
    expect(todayInAmman(DateTime.utc(2026, 9, 22, 12)), '2026-09-22');
  });

  group("an offer in the seller's own words", () {
    test('keeps its words and nothing else', () {
      const offer = Offer(kind: OfferKind.text, description: '  خصم 20% على الفساتين  ', value: 20, buy: 2, get: 1);
      final row = offer.toRow();

      expect(row['kind'], 'text');
      expect(row['description'], 'خصم 20% على الفساتين');
      // A value on it would be a second version of the offer the seller never
      // sees; the database refuses one, so it is never sent.
      expect(row['value'], isNull);
      expect(row['buy'], isNull);
      expect(row['get'], isNull);
    });

    test('reads back as the same kind', () {
      final offer = Offer.fromRow({'id': 'o1', 'kind': 'text', 'description': 'القطعة الثانية بنص السعر'});
      expect(offer.kind, OfferKind.text);
      expect(offer.description, 'القطعة الثانية بنص السعر');
    });

    test('a structured offer never carries words', () {
      const offer = Offer(kind: OfferKind.percent, value: 10, description: 'left over from the editor');
      expect(offer.toRow()['description'], isNull);
    });

    test('keeps its words when switched on and off', () {
      const offer = Offer(kind: OfferKind.text, description: 'x');
      expect(offer.copyWith(enabled: false).description, 'x');
    });
  });
}
