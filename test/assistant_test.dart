// Telling the assistant's words apart from the seller's own.
//
// The seller is accountable for everything that leaves their inbox, so the one
// thing they must never have to guess at is which messages they wrote. The
// colour carries that, and the wording carries it for anyone who cannot
// separate the two colours.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rabta/data.dart';
import 'package:rabta/l10n/app_localizations.dart';
import 'package:rabta/theme.dart';

/// WCAG relative luminance, so the contrast claims here are measured rather
/// than asserted.
double _luminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('which messages the assistant wrote', () {
    test('an outbound message stored as ai is the assistant', () {
      final message = Message.fromRow({
        'id': 'm1',
        'mid': 'mid1',
        'text': '25000 دينار',
        'direction': 'outbound',
        'origin': 'ai',
        'sent_at': '2026-09-19T12:00:00.000Z',
      });

      expect(message.byAssistant, isTrue);
    });

    test("the seller's own reply is not the assistant", () {
      final message = Message.fromRow({
        'id': 'm2',
        'mid': 'mid2',
        'text': 'شكرا',
        'direction': 'outbound',
        'origin': 'seller',
        'sent_at': '2026-09-19T12:00:00.000Z',
      });

      expect(message.byAssistant, isFalse);
    });

    test('an inbound message is never the assistant, whatever origin says', () {
      // origin carries a value on inbound rows where it means nothing. Reading
      // it without checking direction would paint the customer's own messages
      // as machine-written.
      final message = Message.fromRow({
        'id': 'm3',
        'mid': 'mid3',
        'text': 'بكم؟',
        'direction': 'inbound',
        'origin': 'ai',
        'sent_at': '2026-09-19T12:00:00.000Z',
      });

      expect(message.byAssistant, isFalse);
    });

    test('a row from before the column existed is the seller', () {
      // Every message already in the database was written by a person.
      final message = Message.fromRow({
        'id': 'm4',
        'mid': 'mid4',
        'text': 'hello',
        'direction': 'outbound',
        'sent_at': '2026-09-19T12:00:00.000Z',
      });

      expect(message.byAssistant, isFalse);
    });
  });

  group('the assistant colour', () {
    for (final (name, colors) in [
      ('light', RabtaColors.light),
      ('dark', RabtaColors.dark),
    ]) {
      test('$name: is not the colour of the seller\'s own words', () {
        // theme.dart reserves the accent for the seller and nothing else.
        expect(colors.assistant, isNot(colors.accent));
      });

      test('$name: is not the colour that means a window is closing', () {
        // urgent is reserved for one thing. Sharing it would make every
        // automatic reply look like a problem.
        expect(colors.assistant, isNot(colors.urgent));
      });

      test('$name: is not either platform colour', () {
        // Both appear in the same list, on the row the message belongs to.
        expect(colors.assistant, isNot(colors.instagram));
        expect(colors.assistant, isNot(colors.messenger));
      });

      test('$name: message text on it is readable', () {
        // The same text colour sits on the accent and on this, so it has to
        // work on both. 4.5:1 is the AA threshold for normal text.
        expect(_contrast(colors.onAccent, colors.assistant),
            greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('the assistant is named, not only coloured', () {
    late L ar;
    late L en;

    setUp(() async {
      ar = await L.delegate.load(const Locale('ar'));
      en = await L.delegate.load(const Locale('en'));
    });

    test('both languages say plainly that the reply was automatic', () {
      // The fallback for a seller who cannot tell teal from violet. Without
      // it the distinction is carried by colour alone.
      expect(ar.sentAutomatically.trim(), isNotEmpty);
      expect(en.sentAutomatically.trim(), isNotEmpty);
      expect(ar.sentAutomatically, isNot(en.sentAutomatically));
    });

    test('the Arabic is Arabic', () {
      expect(ar.sentAutomatically, matches(RegExp(r'[؀-ۿ]')));
    });

    test('it stays short enough to sit above a message', () {
      // It appears on every automatic reply. A sentence there would bury the
      // reply itself.
      expect(ar.sentAutomatically.length, lessThan(24));
      expect(en.sentAutomatically.length, lessThan(24));
    });
  });
}
