// The plan meter, and the diagram of the seller's guide.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rabta/data.dart';
import 'package:rabta/l10n/app_localizations.dart';
import 'package:rabta/pages/guide_page.dart';
import 'package:rabta/pages/shop_page.dart';
import 'package:rabta/theme.dart';

Widget _app(Widget child, {String locale = 'en'}) => MaterialApp(
      theme: rabtaTheme(brightness: Brightness.light),
      locale: Locale(locale),
      supportedLocales: L.supportedLocales,
      localizationsDelegates: L.localizationsDelegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  final en = lookupL(const Locale('en'));
  final ar = lookupL(const Locale('ar'));

  group('the allowance', () {
    test('warns from 80%, and is used up at the limit, not past it', () {
      const limit = 1000;
      expect(const Allowance(plan: 'basic', limit: limit, used: 799).nearlyUsed, isFalse);
      expect(const Allowance(plan: 'basic', limit: limit, used: 800).nearlyUsed, isTrue);
      expect(const Allowance(plan: 'basic', limit: limit, used: 999).usedUp, isFalse);
      expect(const Allowance(plan: 'basic', limit: limit, used: 1000).usedUp, isTrue);
      // Used up is its own state, not also "nearly".
      expect(const Allowance(plan: 'basic', limit: limit, used: 1000).nearlyUsed, isFalse);
    });

    testWidgets('says nothing extra while there is room', (tester) async {
      await tester.pumpWidget(_app(const AllowanceMeter(
        allowance: Allowance(plan: 'basic', limit: 1000, used: 120),
      )));
      expect(find.text(en.allowanceUsed('120', '1000')), findsOneWidget);
      expect(find.text(en.allowancePlan(en.planBasic)), findsOneWidget);
      expect(find.text(en.allowanceNearly), findsNothing);
      expect(find.text(en.allowanceUsedUp), findsNothing);
    });

    testWidgets('says what happens next when the replies run out, in Arabic too', (tester) async {
      await tester.pumpWidget(_app(
        const AllowanceMeter(allowance: Allowance(plan: 'ultimate', limit: 5000, used: 5000)),
        locale: 'ar',
      ));
      expect(find.text(ar.allowanceUsedUp), findsOneWidget);
      expect(find.text(ar.allowancePlan(ar.planUltimate)), findsOneWidget);
    });
  });

  group('the guide diagram', () {
    test('a malformed reading draws nothing rather than throwing', () {
      expect(GuideSteps.fromJson(null), isNull);
      expect(GuideSteps.fromJson('x'), isNull);
      expect(GuideSteps.fromJson({'rules': 'x', 'cannot': []}), isNull);
      final steps = GuideSteps.fromJson({
        'rules': [
          {'when': 1, 'do': ['ok', 2], 'handover': 'yes'},
          'junk',
        ],
        'cannot': [{'text': 'call'}, {'why': 'no text'}],
      })!;
      expect(steps.rules.single.when, isNull);
      expect(steps.rules.single.actions, ['ok']);
      expect(steps.rules.single.handover, isFalse);
      expect(steps.cannot.single, (text: 'call', why: ''));
    });

    testWidgets('every situation, what it does, and what comes to the seller', (tester) async {
      final steps = GuideSteps.fromJson({
        'rules': [
          {'when': 'the customer complains', 'do': <String>[], 'handover': true},
          {'when': null, 'do': ['Ask their size first'], 'handover': false},
          {'when': 'they want to order', 'do': ['Take name, area and phone'], 'handover': true},
        ],
        'cannot': [{'text': 'Call them back', 'why': 'it cannot phone'}],
      })!;

      await tester.pumpWidget(_app(GuideDiagram(steps: steps)));

      expect(find.text(en.guideStart), findsOneWidget);
      expect(find.text(en.guideAlways), findsOneWidget);
      expect(find.text('Ask their size first'), findsOneWidget);
      expect(find.text('Take name, area and phone'), findsOneWidget);
      expect(find.text(en.guideHandover), findsNWidgets(2));
      expect(find.text(en.guideCannot), findsOneWidget);
      expect(find.text('Call them back — it cannot phone'), findsOneWidget);

      // "Always" is drawn before any situation, whatever order it was read in.
      final always = tester.getTopLeft(find.text(en.guideAlways)).dy;
      final complains = tester.getTopLeft(find.textContaining('the customer complains')).dy;
      expect(always, lessThan(complains));
    });

    testWidgets('a reading with nothing in it says so', (tester) async {
      await tester.pumpWidget(_app(const GuideDiagram(steps: GuideSteps(rules: [], cannot: []))));
      expect(find.text(en.guideNothing), findsOneWidget);
    });
  });
}
