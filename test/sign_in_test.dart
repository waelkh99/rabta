// The sign-in screen, and the one thing about it that broke silently.
//
// A browser password manager fills a credential pair by finding a username
// field and a password field in the same form. Flutter on the web builds that
// form from an AutofillGroup — and without one, each field becomes its own
// throwaway form holding a single input, with no password beside the email.
//
// What a seller saw was the browser painting a value into the email box while
// the controller behind it stayed empty: the field reads full and the button
// says the credentials are wrong. Nothing in the code looks wrong, which is
// why it is pinned here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rabta/l10n/app_localizations.dart';
import 'package:rabta/sign_in_page.dart';
import 'package:rabta/theme.dart';

Widget _app({Locale locale = const Locale('en')}) => MaterialApp(
      theme: rabtaTheme(brightness: Brightness.light),
      locale: locale,
      supportedLocales: L.supportedLocales,
      localizationsDelegates: L.localizationsDelegates,
      home: const SignInPage(),
    );

void main() {
  testWidgets('both fields sit inside one autofill group', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final group = find.byType(AutofillGroup);
    expect(group, findsOneWidget, reason: 'no AutofillGroup on the sign-in form');

    // Both, and in the same one. A group around only the email field would
    // leave the browser with nothing to pair it against, which is the bug.
    expect(
      find.descendant(of: group, matching: find.byType(TextField)),
      findsNWidgets(2),
    );
  });

  testWidgets('the fields say what they are, so a password manager can fill them',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();

    final hints = fields.map((f) => f.autofillHints?.toList() ?? []).toList();

    expect(hints, [
      [AutofillHints.email],
      [AutofillHints.password],
    ]);

    // The password field must be the obscured one. Getting these the wrong way
    // round would put the password in the browser's email autofill entry.
    expect(fields[0].obscureText, isFalse);
    expect(fields[1].obscureText, isTrue);
  });

  testWidgets('the layout still holds at phone width', (tester) async {
    // The group wraps the column the fields live in, so a mistake in where it
    // was inserted shows up as a broken layout rather than a failed autofill.
    tester.view.physicalSize = const Size(420, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the screen reads in Arabic too', (tester) async {
    await tester.pumpWidget(_app(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(TextField).first)),
        TextDirection.rtl);
  });
}
