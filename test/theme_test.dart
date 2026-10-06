import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rabta/theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('each platform has its own mark colour', () {
    const c = RabtaColors.light;

    test('WhatsApp is not drawn as Messenger', () {
      expect(c.platform('whatsapp'), c.whatsapp);
      expect(c.platform('instagram'), c.instagram);
      expect(c.platform('messenger'), c.messenger);
      expect({c.whatsapp, c.instagram, c.messenger}, hasLength(3));
    });

    // 3:1 is the threshold for a graphic. The mark beside a name, and the
    // white glyph on the badge.
    for (final name in ['instagram', 'messenger', 'whatsapp']) {
      test('$name: the mark is visible on the list and its badge glyph on it', () {
        expect(_contrast(c.platform(name), c.surface), greaterThanOrEqualTo(3));
        expect(_contrast(Colors.white, c.platform(name)), greaterThanOrEqualTo(3));
      });
    }
  });

  group('every pair of text and ground the interface draws is readable', () {
    const c = RabtaColors.light;

    // 4.5:1 is the AA threshold for normal text. Each pair is one the
    // interface actually draws; the comment says where.
    final pairs = <String, (Color, Color)>{
      'names on the list': (c.ink, c.surface),
      'text on the sand ground': (c.ink, c.ground),
      'previews on the list': (c.muted, c.surface),
      'previews on the sand ground': (c.muted, c.ground),
      'the open row': (c.ink, c.raised),
      'the waiting count on saffron': (c.ink, c.saffron),
      'the seller\'s own bubble': (c.onAccent, c.accent),
      'links and text buttons': (c.accent, c.surface),
      'the menu and the sign-in panel': (c.onNight, c.night),
      'the saffron wordmark on night': (c.saffron, c.night),
      'the needs-you pill': (Colors.white, c.urgent),
      'urgent text on the list': (c.urgent, c.surface),
      'the assistant\'s marks on the list': (c.assistant, c.surface),
      'an order on the list': (c.won, c.surface),
    };

    for (final MapEntry(key: where, value: (text, ground)) in pairs.entries) {
      test(where, () {
        expect(_contrast(text, ground), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('a customer name', () {
    Widget within(TextDirection direction, void Function(BuildContext) check) =>
        Directionality(
          textDirection: direction,
          child: Builder(builder: (context) {
            check(context);
            return const SizedBox();
          }),
        );

    testWidgets('keeps its own order inside the Arabic interface',
        (tester) async {
      await tester.pumpWidget(within(TextDirection.rtl, (context) {
        final layout = nameLayout(context, 'Dana K.');
        // Taking the interface's direction drew ".Dana K".
        expect(layout.direction, TextDirection.ltr);
        expect(layout.align, TextAlign.right);
      }));
    });

    testWidgets('lines up with the English interface when it is Arabic',
        (tester) async {
      await tester.pumpWidget(within(TextDirection.ltr, (context) {
        final layout = nameLayout(context, 'ليان');
        expect(layout.direction, TextDirection.rtl);
        expect(layout.align, TextAlign.left);
      }));
    });
  });

  test('an address inside an Arabic sentence is isolated left to right', () {
    final wrapped = isolated('a+b@example.com');
    // Left-to-right isolate (2066) and pop directional isolate (2069), and nothing
    // else changed.
    expect(wrapped.runes.first, 0x2066);
    expect(wrapped.runes.last, 0x2069);
    expect(wrapped.substring(1, wrapped.length - 1), 'a+b@example.com');
  });

  test('a piece of a joined line takes its own first-strong direction', () {
    final wrapped = ownDirection('التوصيل مجاني.');
    // First strong isolate (2068) and pop directional isolate (2069).
    expect(wrapped.runes.first, 0x2068);
    expect(wrapped.runes.last, 0x2069);
    expect(wrapped.substring(1, wrapped.length - 1), 'التوصيل مجاني.');
  });
}
