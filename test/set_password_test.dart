// Choosing a password from an invitation: typed twice, and refused before
// anything is sent when the two differ or the password is too weak.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rabta/l10n/app_localizations.dart';
import 'package:rabta/set_password_page.dart';
import 'package:rabta/theme.dart';

Widget _app({required VoidCallback onDone}) => MaterialApp(
      theme: rabtaTheme(brightness: Brightness.light),
      locale: const Locale('en'),
      supportedLocales: L.supportedLocales,
      localizationsDelegates: L.localizationsDelegates,
      home: SetPasswordPage(onDone: onDone),
    );

void main() {
  final en = lookupL(const Locale('en'));

  testWidgets('it asks for the password twice, both in the autofill group', (tester) async {
    await tester.pumpWidget(_app(onDone: () {}));
    await tester.pumpAndSettle();

    final group = find.byType(AutofillGroup);
    expect(find.descendant(of: group, matching: find.byType(TextField)), findsNWidgets(2));
    expect(find.text(en.passwordRepeat), findsOneWidget);
  });

  testWidgets('two different passwords are refused under the second box', (tester) async {
    var done = false;
    await tester.pumpWidget(_app(onDone: () => done = true));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Rabta2026ok');
    await tester.enterText(find.byType(TextField).at(1), 'Rabta2026oK');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text(en.passwordMismatch), findsOneWidget);
    expect(done, isFalse, reason: 'saved a password the seller typed two ways');
  });

  testWidgets('an error follows the language when the seller switches', (tester) async {
    // It used to be stored as finished text: shown in English, it stayed
    // English after switching to Arabic.
    final locale = ValueNotifier(const Locale('en'));
    await tester.pumpWidget(ValueListenableBuilder<Locale>(
      valueListenable: locale,
      builder: (_, value, __) => MaterialApp(
        theme: rabtaTheme(brightness: Brightness.light),
        locale: value,
        supportedLocales: L.supportedLocales,
        localizationsDelegates: L.localizationsDelegates,
        home: SetPasswordPage(onDone: () {}),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Rabta2026ok');
    await tester.enterText(find.byType(TextField).at(1), 'different1A');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text(en.passwordMismatch), findsOneWidget);

    locale.value = const Locale('ar');
    await tester.pumpAndSettle();
    expect(find.text(lookupL(const Locale('ar')).passwordMismatch), findsOneWidget);
    expect(find.text(en.passwordMismatch), findsNothing);
  });

  testWidgets('a weak password is refused before the match is even checked', (tester) async {
    await tester.pumpWidget(_app(onDone: () {}));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'short');
    await tester.enterText(find.byType(TextField).at(1), 'short');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // The rule is both the helper text and the error, so it appears in the
    // error slot; the mismatch message does not appear at all.
    expect(find.text(en.passwordMismatch), findsNothing);
    expect(find.text(en.passwordTooShort), findsWidgets);
  });
}
