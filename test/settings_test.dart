// The settings the shop screen now carries, and the rules behind them.
//
// The pricing stance is proven on the server, in `supabase/tests/ai.test.ts` —
// that is where it changes what a customer hears, and where the guard that used
// to refuse it lives. What is checked here is the client half: that the column
// travels both ways intact, and that the words a seller reads exist in both
// languages and say different things.

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:rabta/data.dart';
import 'package:rabta/l10n/app_localizations.dart';

void main() {
  group('the pricing stance', () {
    test('a shop that has never been asked does not haggle-proof itself', () {
      // The default is the behaviour the assistant has always had: quote the
      // price, argue nothing, hand a haggler to the seller. A shop upgrading
      // into this feature must not silently start telling customers its prices
      // are final.
      expect(const Shop().pricesFinal, isFalse);
      expect(Shop.fromRow({}).pricesFinal, isFalse);
    });

    test('a missing column reads as off rather than throwing', () {
      // The client is built and served separately from the database. A build
      // that predates the migration must degrade to the old behaviour, not
      // fail to render the screen.
      expect(Shop.fromRow({'currency': 'د.ا'}).pricesFinal, isFalse);
    });

    test('the column is read as written', () {
      expect(Shop.fromRow({'prices_final': true}).pricesFinal, isTrue);
      expect(Shop.fromRow({'prices_final': false}).pricesFinal, isFalse);
    });

    test('changing it leaves everything else alone', () {
      // copyWith is how the screen applies one saved field at a time — two
      // quick edits used to have the second undo the first, which is why the
      // screen saves one key rather than the whole row.
      const shop = Shop(
        currency: 'د.ا',
        deliveryNote: 'مجاني فوق 50',
        locations: 'عمّان',
        hours: 'السبت إلى الخميس',
        about: 'الدفع عند الاستلام',
        assistantEnabled: true,
      );

      final strict = shop.copyWith(pricesFinal: true);

      expect(strict.pricesFinal, isTrue);
      expect(strict.currency, shop.currency);
      expect(strict.deliveryNote, shop.deliveryNote);
      expect(strict.locations, shop.locations);
      expect(strict.hours, shop.hours);
      expect(strict.about, shop.about);
      expect(strict.assistantEnabled, isTrue,
          reason: 'the pricing choice must not switch the assistant off');
    });
  });

  group('the words a seller reads', () {
    late L ar;
    late L en;

    setUp(() async {
      ar = await L.delegate.load(const Locale('ar'));
      en = await L.delegate.load(const Locale('en'));
    });

    test('the two pricing choices do not describe each other', () {
      for (final l in [ar, en]) {
        expect(l.shopPricingHandOver, isNot(l.shopPricingFinal));
        expect(l.shopPricingHandOverBody, isNot(l.shopPricingFinalBody));
        expect(l.shopPricingHandOverBody, isNotEmpty);
        expect(l.shopPricingFinalBody, isNotEmpty);
      }
    });

    test('every new setting exists in Arabic and is not the English one', () {
      final pairs = <String, (String, String)>{
        'shopPricing': (ar.shopPricing, en.shopPricing),
        'shopPricingBody': (ar.shopPricingBody, en.shopPricingBody),
        'shopPricingHandOver': (ar.shopPricingHandOver, en.shopPricingHandOver),
        'shopPricingFinal': (ar.shopPricingFinal, en.shopPricingFinal),
        'settingsYou': (ar.settingsYou, en.settingsYou),
        'settingsLanguage': (ar.settingsLanguage, en.settingsLanguage),
        'alerts': (ar.alerts, en.alerts),
        'alertsBody': (ar.alertsBody, en.alertsBody),
        'password': (ar.password, en.password),
        'passwordBody': (ar.passwordBody, en.passwordBody),
        'passwordNew': (ar.passwordNew, en.passwordNew),
        'passwordRepeat': (ar.passwordRepeat, en.passwordRepeat),
        'passwordChange': (ar.passwordChange, en.passwordChange),
        'passwordChanged': (ar.passwordChanged, en.passwordChanged),
        'passwordMismatch': (ar.passwordMismatch, en.passwordMismatch),
        'passwordFailed': (ar.passwordFailed, en.passwordFailed),
      };

      for (final entry in pairs.entries) {
        final (arabic, english) = entry.value;
        expect(arabic, isNotEmpty, reason: '${entry.key} is empty in Arabic');
        // An untranslated key falls back to the English value, which renders
        // perfectly and reads as English.
        expect(arabic, isNot(english),
            reason: '${entry.key} is still the English string in Arabic');
        expect(arabic, matches(RegExp(r'[؀-ۿ]')),
            reason: '${entry.key} contains no Arabic script');
      }
    });

    test('the password rules are the ones the invitation screen already applies',
        () {
      // Reused rather than restated. A password accepted when the seller was
      // invited must not be refused when they come to change it.
      expect(en.passwordTooShort, contains('8'));
      expect(ar.passwordTooShort, contains('8'));
    });

    test('alerts say the choice belongs to this device', () {
      // It is stored in the browser, so a seller who turns it on at the counter
      // and finds it off at home has not hit a bug. Saying so costs a clause.
      expect(en.alertsBody.toLowerCase(), contains('device'));
      expect(ar.alertsBody, contains('الجهاز'));
    });
  });
}
