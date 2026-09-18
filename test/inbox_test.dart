// The interface rules that are easy to get wrong and invisible when they are.
//
// Ordering, message direction and the reply window are all logic a screenshot
// cannot check: each one looks plausible while being wrong, and two of them are
// wrong only in the language you did not test in.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale, TextDirection;
import 'package:flutter_test/flutter_test.dart';

import 'package:rabta/data.dart';
import 'package:rabta/l10n/app_localizations.dart';
import 'package:rabta/theme.dart';

final _now = DateTime.utc(2026, 9, 18, 12, 0);

Conversation _conversation({
  required String id,
  required Duration inboundAgo,
  Duration? repliedAgo,
}) {
  final inboundAt = _now.subtract(inboundAgo);

  return Conversation(
    id: id,
    platform: 'messenger',
    customerName: id,
    preview: null,
    lastMessageType: 'text',
    // A reply is the newest message when one exists, otherwise the customer's
    // message is.
    lastMessageAt: repliedAgo == null ? inboundAt : _now.subtract(repliedAgo),
    lastInboundAt: inboundAt,
    windowExpiresAt: inboundAt.add(const Duration(hours: 24)),
    unreadCount: repliedAgo == null ? 1 : 0,
  );
}

void main() {
  group('inbox order', () {
    test('conversations awaiting a reply come before answered ones', () {
      final order = inboxOrder([
        _conversation(
          id: 'answered',
          inboundAgo: const Duration(minutes: 30),
          repliedAgo: const Duration(minutes: 5),
        ),
        _conversation(id: 'waiting', inboundAgo: const Duration(hours: 6)),
      ]);

      expect(order.map((c) => c.id), ['waiting', 'answered']);
    });

    test('the longest wait is at the top, not the newest message', () {
      final order = inboxOrder([
        _conversation(id: 'recent', inboundAgo: const Duration(minutes: 10)),
        _conversation(id: 'oldest', inboundAgo: const Duration(hours: 20)),
        _conversation(id: 'middle', inboundAgo: const Duration(hours: 3)),
      ]);

      // Newest-first here would put 'oldest' last, where it would sit until its
      // reply window closed. This ordering is the whole reason for the group.
      expect(order.map((c) => c.id), ['oldest', 'middle', 'recent']);
    });

    test('answered conversations are newest first', () {
      final order = inboxOrder([
        _conversation(
          id: 'older',
          inboundAgo: const Duration(hours: 9),
          repliedAgo: const Duration(hours: 8),
        ),
        _conversation(
          id: 'newer',
          inboundAgo: const Duration(hours: 4),
          repliedAgo: const Duration(hours: 2),
        ),
      ]);

      expect(order.map((c) => c.id), ['newer', 'older']);
    });

    test('a seller reply moves a conversation out of the waiting group', () {
      final waiting = _conversation(id: 'c', inboundAgo: const Duration(hours: 2));
      expect(waiting.awaitingReply, isTrue);

      final answered = _conversation(
        id: 'c',
        inboundAgo: const Duration(hours: 2),
        repliedAgo: const Duration(hours: 1),
      );
      expect(answered.awaitingReply, isFalse);
    });
  });

  group('message direction', () {
    test('Arabic reads right to left', () {
      expect(directionOf('كم سعر هذا المنتج؟'), TextDirection.rtl);
    });

    test('English reads left to right', () {
      expect(directionOf('Do you have this in blue?'), TextDirection.ltr);
    });

    test('leading digits do not decide direction', () {
      // "50 riyal" in Arabic. Taking the first character rather than the first
      // strong one would render this left to right and break the line.
      expect(directionOf('50 ريال'), TextDirection.rtl);
      expect(directionOf('50 riyals'), TextDirection.ltr);
    });

    test('leading punctuation does not decide direction', () {
      expect(directionOf('«مرحبا»'), TextDirection.rtl);
    });

    test('an empty or absent message does not throw', () {
      expect(directionOf(null), TextDirection.ltr);
      expect(directionOf(''), TextDirection.ltr);
      expect(directionOf('!!!'), TextDirection.ltr);
    });
  });

  _groupLabels();
  _elapsed();
  _arabic();
  _numerals();

}

void _groupLabels() {
  group('group labels', () {
    test('hidden when every conversation is still waiting', () {
      // Observed on 18 September: an "ANSWERED" heading rendered with nothing
      // beneath it, which reads as a section that failed to load.
      expect(showGroupLabels(waiting: 1, total: 1), isFalse);
    });

    test('hidden when everyone has been answered', () {
      expect(showGroupLabels(waiting: 0, total: 3), isFalse);
    });

    test('shown only when both groups have something in them', () {
      expect(showGroupLabels(waiting: 1, total: 3), isTrue);
    });

    test('hidden on an empty inbox', () {
      expect(showGroupLabels(waiting: 0, total: 0), isFalse);
    });
  });
}

void _elapsed() {
  group('elapsed units', () {
    ({Elapsed unit, int count}) at(Duration ago) =>
        elapsedSince(_now.subtract(ago), now: _now);

    test('picks the unit a dense list has room for', () {
      expect(at(const Duration(seconds: 20)).unit, Elapsed.now);
      expect(at(const Duration(minutes: 5)), (unit: Elapsed.minutes, count: 5));
      expect(at(const Duration(hours: 3)), (unit: Elapsed.hours, count: 3));
      expect(at(const Duration(days: 2)), (unit: Elapsed.days, count: 2));
      expect(at(const Duration(days: 21)), (unit: Elapsed.weeks, count: 3));
    });

    test('a message that just arrived is not 0 minutes', () {
      expect(at(Duration.zero).unit, Elapsed.now);
    });
  });

  group('reply window', () {
    test('runs from full to empty over 24 hours', () {
      expect(
        windowRemainingFraction(_now.add(const Duration(hours: 24)), now: _now),
        1.0,
      );
      expect(
        windowRemainingFraction(_now.add(const Duration(hours: 12)), now: _now),
        closeTo(0.5, 0.001),
      );
    });

    test('a closed window is zero, never negative', () {
      expect(
        windowRemainingFraction(
          _now.subtract(const Duration(hours: 3)),
          now: _now,
        ),
        0,
      );
    });

    test('closing soon starts under four hours and ends when closed', () {
      expect(
        windowClosingSoon(_now.add(const Duration(hours: 5)), now: _now),
        isFalse,
      );
      expect(
        windowClosingSoon(_now.add(const Duration(hours: 3)), now: _now),
        isTrue,
      );
      // Already closed is not "closing soon" — it needs different wording, and
      // treating it as urgent would leave a red countdown on a dead thread.
      expect(
        windowClosingSoon(_now.subtract(const Duration(minutes: 1)), now: _now),
        isFalse,
      );
    });
  });
}

void _arabic() {
  group('Arabic', () {
    late L ar;
    late L en;

    setUp(() async {
      ar = await L.delegate.load(const Locale('ar'));
      en = await L.delegate.load(const Locale('en'));
    });

    test('the waiting count uses singular, dual and plural correctly', () async {
      // Arabic has forms English does not. Writing this by hand — "$count
      // زبون" — is wrong for every count except the large ones, which is why
      // it goes through ICU plurals rather than string interpolation.
      expect(ar.customersWaiting(1), 'زبون واحد ينتظر');
      expect(ar.customersWaiting(2), 'زبونان ينتظران');
      expect(ar.customersWaiting(3), contains('زبائن'));
      expect(ar.customersWaiting(11), contains('زبوناً'));

      expect(en.customersWaiting(1), '1 customer waiting');
      expect(en.customersWaiting(4), '4 customers waiting');
    });

    test('every screen label exists in Arabic and is not the English one', () {
      final pairs = <String, (String, String)>{
        'tagline': (ar.tagline, en.tagline),
        'signIn': (ar.signIn, en.signIn),
        'emailLabel': (ar.emailLabel, en.emailLabel),
        'passwordLabel': (ar.passwordLabel, en.passwordLabel),
        'signOut': (ar.signOut, en.signOut),
        'waitingForReply': (ar.waitingForReply, en.waitingForReply),
        'answered': (ar.answered, en.answered),
        'customer': (ar.customer, en.customer),
        'everyoneAnswered': (ar.everyoneAnswered, en.everyoneAnswered),
        'longestWait': (ar.longestWait, en.longestWait),
        'windowExplanation': (ar.windowExplanation, en.windowExplanation),
        'replyingNotBuilt': (ar.replyingNotBuilt, en.replyingNotBuilt),
        'replyWindowClosedLong':
            (ar.replyWindowClosedLong, en.replyWindowClosedLong),
        'attachmentPhoto': (ar.attachmentPhoto, en.attachmentPhoto),
        'photoExpired': (ar.photoExpired, en.photoExpired),
        'backToInbox': (ar.backToInbox, en.backToInbox),
        'noConversationsTitle':
            (ar.noConversationsTitle, en.noConversationsTitle),
        'inboxFailedTitle': (ar.inboxFailedTitle, en.inboxFailedTitle),
      };

      for (final entry in pairs.entries) {
        final (arabic, english) = entry.value;
        expect(arabic, isNotEmpty, reason: '${entry.key} is empty in Arabic');
        // An untranslated key falls back to the English value, which is the
        // failure this catches: the screen renders, and reads as English.
        expect(
          arabic,
          isNot(english),
          reason: '${entry.key} is still the English string in Arabic',
        );
        expect(
          arabic,
          matches(RegExp(r'[\u0600-\u06FF]')),
          reason: '${entry.key} contains no Arabic script',
        );
      }
    });

    test('times keep Western numerals in Arabic', () {
      // Settled in DECISIONS.md. Some Arabic locale data renders Eastern
      // numerals by default, which is exactly what this catches.
      expect(ar.hoursAgo(5), contains('5'));
      expect(ar.minutesLeftToReply(20), contains('20'));
      expect(ar.hoursAgo(5), isNot(contains('٥')));
    });
  });
}

void _numerals() {
  test('no Arabic string uses Eastern numerals', () {
    // Western numerals throughout, including in the Arabic interface — settled
    // in DECISIONS.md. Checking the file rather than a handful of getters is
    // what makes this hold: "٢٤ ساعة" was written into the explanation string
    // and two spot-checks on other strings did not see it.
    final arb = File('lib/l10n/app_ar.arb').readAsStringSync();
    final eastern = RegExp(r'[\u0660-\u0669\u06F0-\u06F9]');

    final offenders = const LineSplitter()
        .convert(arb)
        .where((line) => eastern.hasMatch(line))
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'Eastern numerals found:\n${offenders.join('\n')}',
    );
  });
}
