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
import 'package:rabta/strings.dart';
import 'package:rabta/theme.dart';

final _now = DateTime.utc(2026, 9, 18, 12, 0);

Conversation _conversation({
  required String id,
  required Duration inboundAgo,
  Duration? repliedAgo,
  String? aiState,
  String? aiEscalationCode,
  String? aiEscalationReason,
}) {
  final inboundAt = _now.subtract(inboundAgo);

  return Conversation(
    id: id,
    platform: 'messenger',
    customerName: id,
    customerAvatarUrl: null,
    preview: null,
    lastMessageType: 'text',
    // A reply is the newest message when one exists, otherwise the customer's
    // message is.
    lastMessageAt: repliedAgo == null ? inboundAt : _now.subtract(repliedAgo),
    lastInboundAt: inboundAt,
    windowExpiresAt: inboundAt.add(const Duration(hours: 24)),
    unreadCount: repliedAgo == null ? 1 : 0,
    aiState: aiState,
    aiEscalationCode: aiEscalationCode,
    aiEscalationReason: aiEscalationReason,
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
  group('a message arriving while the thread is open', () {
    Message msg(String mid, Duration ago, {String? text}) => Message(
          id: 'row_$mid',
          mid: mid,
          text: text ?? mid,
          attachments: const [],
          inbound: false,
          sentAt: _now.subtract(ago),
        );

    test('a reply we sent is not shown twice when its echo arrives', () {
      // The reply is shown the instant Meta accepts it, and the same reply
      // comes back through the webhook moments later as an echo. Without this
      // the seller watches their own message appear a second time.
      final pending = msg('m_1', const Duration(seconds: 2));
      final stored = msg('m_1', const Duration(seconds: 2));

      final shown = mergeMessages([stored], [pending]);

      expect(shown.length, 1);
      // The stored row wins: it is the real one, with the real id.
      expect(shown.single.id, 'row_m_1');
    });

    test('a reply that has not come back yet is still shown', () {
      // Between sending and the echo arriving there is a gap. The seller must
      // see their own message during it.
      final shown = mergeMessages(
        [msg('m_old', const Duration(hours: 1))],
        [msg('m_new', const Duration(seconds: 1))],
      );

      expect(shown.map((m) => m.mid), ['m_old', 'm_new']);
    });

    test('a message delivered late sits at its own time, not at the end', () {
      // Meta does not guarantee order. Appending would put an older message
      // below a newer one and break the time grouping in the thread.
      final shown = mergeMessages(
        [
          msg('m_first', const Duration(minutes: 30)),
          msg('m_third', const Duration(minutes: 5)),
        ],
        [msg('m_second', const Duration(minutes: 20))],
      );

      expect(shown.map((m) => m.mid), ['m_first', 'm_second', 'm_third']);
    });

    test('an empty thread and an empty pending list are both fine', () {
      expect(mergeMessages(const [], const []), isEmpty);
      expect(mergeMessages([msg('m_1', Duration.zero)], const []).length, 1);
      expect(mergeMessages(const [], [msg('m_1', Duration.zero)]).length, 1);
    });
  });

  group('whether a reply is still allowed', () {
    test('an answered conversation can still be replied to', () {
      // The bug this pins: reading "can I reply?" as "is the customer waiting?"
      // put Closed in the details pane beside "8h left to reply" on the
      // composer, about the same conversation, on the same screen. The window
      // decides, and the seller may follow up inside it.
      final answered = _conversation(
        id: 'a',
        inboundAgo: const Duration(hours: 16),
        repliedAgo: const Duration(minutes: 5),
      );

      expect(answered.awaitingReply, isFalse);
      expect(replyWindowOpen(answered.windowExpiresAt, now: _now), isTrue);
    });

    test('a conversation past its window cannot, however recent the reply', () {
      final stale = _conversation(
        id: 'a',
        inboundAgo: const Duration(hours: 30),
        repliedAgo: const Duration(minutes: 1),
      );

      expect(replyWindowOpen(stale.windowExpiresAt, now: _now), isFalse);
    });

    test('a conversation with no window at all cannot', () {
      expect(replyWindowOpen(null, now: _now), isFalse);
    });

    test('the boundary falls closed, matching what the server enforces', () {
      expect(replyWindowOpen(_now, now: _now), isFalse);
      expect(
        replyWindowOpen(_now.add(const Duration(seconds: 1)), now: _now),
        isTrue,
      );
    });
  });

  group('sending a reply', () {
    Message reply(String text) => Message(
          id: 'm_local',
          mid: 'm_local',
          text: text,
          attachments: const [],
          inbound: false,
          sentAt: _now,
        );

    test('a sent reply moves the conversation out of the waiting group', () {
      // The point of the whole two-group order. If answering does not move a
      // conversation, the list is lying about who still needs serving.
      final waiting =
          _conversation(id: 'a', inboundAgo: const Duration(hours: 3));
      expect(waiting.awaitingReply, isTrue);

      expect(waiting.afterReply(reply('On its way')).awaitingReply, isFalse);
    });

    test('a sent reply does not extend the reply window', () {
      // Meta runs the 24 hours from the customer's message. Answering does not
      // buy more time, and showing that it does would promise the seller a
      // window they do not have. Confirmed on a real echo against the live
      // database, and held here so the client cannot drift from it.
      final before =
          _conversation(id: 'a', inboundAgo: const Duration(hours: 20));
      final after = before.afterReply(reply('Yes'));

      expect(after.windowExpiresAt, before.windowExpiresAt);
      expect(after.lastInboundAt, before.lastInboundAt);
    });

    test('a sent reply clears the unread count and becomes the preview', () {
      final before =
          _conversation(id: 'a', inboundAgo: const Duration(hours: 1));
      expect(before.unreadCount, 1);

      final after = before.afterReply(reply('نعم، متوفر'));

      expect(after.unreadCount, 0);
      expect(after.preview, 'نعم، متوفر');
      expect(after.lastMessageType, 'text');
    });

    test('answering the longest waiter promotes the next one', () {
      // The seller works down the waiting group. Answering the top row has to
      // hand the top to whoever has now waited longest, or they never rise.
      final oldest =
          _conversation(id: 'oldest', inboundAgo: const Duration(hours: 20));
      final next =
          _conversation(id: 'next', inboundAgo: const Duration(hours: 6));

      final before = inboxOrder([next, oldest]);
      expect(before.first.id, 'oldest');

      final after = inboxOrder([next, oldest.afterReply(reply('Sorry!'))]);
      expect(after.first.id, 'next');
      expect(after.last.id, 'oldest');
    });
  });

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
        'composerHint': (ar.composerHint, en.composerHint),
        'accounts': (ar.accounts, en.accounts),
        'connectTitle': (ar.connectTitle, en.connectTitle),
        'connectBody': (ar.connectBody, en.connectBody),
        'connectAction': (ar.connectAction, en.connectAction),
        'accountActive': (ar.accountActive, en.accountActive),
        'accountNeedsReconnect':
            (ar.accountNeedsReconnect, en.accountNeedsReconnect),
        'accountDisconnected': (ar.accountDisconnected, en.accountDisconnected),
        'disconnect': (ar.disconnect, en.disconnect),
        'disconnectTitle': (ar.disconnectTitle, en.disconnectTitle),
        'disconnectBody': (ar.disconnectBody, en.disconnectBody),
        'connectFailed': (ar.connectFailed, en.connectFailed),
        'sendReply': (ar.sendReply, en.sendReply),
        'sending': (ar.sending, en.sending),
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

    test('every refusal a reply can meet has its own sentence, in both languages', () {
      // The server answers with a code so that this choice is made here. Two
      // codes sharing a sentence would tell the seller the same thing about
      // different problems — a closed window and an expired connection need
      // different actions from them.
      const reasons = [
        'too_long',
        'window_closed',
        'no_window',
        'disconnected',
        'unreachable',
        'not_found',
        'rejected',
      ];

      for (final language in [ar, en]) {
        final said = <String, String>{};

        for (final reason in reasons) {
          final sentence = sendRefusal(language, reason);
          expect(sentence, isNotEmpty, reason: '$reason is empty');
          expect(
            said.containsKey(sentence),
            isFalse,
            reason: '$reason says the same as ${said[sentence]}',
          );
          said[sentence] = reason;
        }
      }

      for (final reason in reasons) {
        expect(sendRefusal(ar, reason), isNot(sendRefusal(en, reason)));
        expect(sendRefusal(ar, reason), matches(RegExp(r'[؀-ۿ]')));
      }
    });

    test('a refusal we have never seen is stated plainly, not invented', () {
      // Meta adds error codes without warning. An unfamiliar one must fall
      // back to the honest sentence rather than to whichever branch is first.
      expect(sendRefusal(en, 'something_new_from_meta'), en.sendFailedRejected);
      expect(sendRefusal(ar, ''), ar.sendFailedRejected);
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
  group('what the assistant left behind', () {
    late L ar;
    late L en;

    setUp(() async {
      ar = await L.delegate.load(const Locale('ar'));
      en = await L.delegate.load(const Locale('en'));
    });

    // The failure this whole group exists for: the assistant usually speaks
    // when it hands a conversation back, and that line is an outbound message.
    // Left to the message timestamps alone, a customer the assistant said it
    // could not help lands under "Answered" — the group the seller has finished
    // reading — while a customer it never spoke to stays visible.
    test('an escalated conversation is waiting, though the assistant spoke last',
        () {
      final escalated = _conversation(
        id: 'escalated',
        inboundAgo: const Duration(hours: 3),
        repliedAgo: const Duration(hours: 2),
        aiState: 'escalated',
        aiEscalationCode: 'assistant',
      );

      expect(escalated.awaitingReply, isTrue);
    });

    test('a conversation the assistant answered is not waiting', () {
      // Answering is the case where nobody is waiting on a person. Putting
      // these in the waiting group too would fill it with work that does not
      // exist, and the group would stop meaning anything.
      final answered = _conversation(
        id: 'answered',
        inboundAgo: const Duration(hours: 3),
        repliedAgo: const Duration(hours: 2),
        aiState: 'answered',
      );

      expect(answered.awaitingReply, isFalse);
    });

    test('an escalated conversation sorts by how long the customer has waited',
        () {
      // It joins the waiting group at its true age, not at the top or the
      // bottom of it. The oldest customer is still the one to answer first.
      final order = inboxOrder([
        _conversation(id: 'recent', inboundAgo: const Duration(hours: 1)),
        _conversation(
          id: 'escalated',
          inboundAgo: const Duration(hours: 6),
          repliedAgo: const Duration(hours: 5),
          aiState: 'escalated',
          aiEscalationCode: 'assistant',
        ),
        _conversation(id: 'oldest', inboundAgo: const Duration(hours: 9)),
      ]);

      expect(order.map((c) => c.id), ['oldest', 'escalated', 'recent']);
    });

    test('the seller replying takes the mark off, without a reload', () {
      final escalated = _conversation(
        id: 'escalated',
        inboundAgo: const Duration(hours: 3),
        repliedAgo: const Duration(hours: 2),
        aiState: 'escalated',
        aiEscalationCode: 'assistant',
        aiEscalationReason: 'بتسأل عن وقت التوصيل',
      );

      final after = escalated.afterReply(Message(
        id: 'm1',
        mid: 'mid1',
        text: 'بيوصل خلال يومين',
        attachments: const [],
        inbound: false,
        sentAt: _now,
      ));

      expect(after.aiState, isNull);
      expect(after.aiEscalationReason, isNull);
      expect(after.aiEscalationCode, isNull);
      expect(after.awaitingReply, isFalse,
          reason: 'it must leave the waiting group the instant the reply goes');
    });

    test('the assistant own words are shown, not our description of them', () {
      // The only reason on this list that knows what the customer actually
      // asked. Everything else is our code describing itself.
      const written = 'بتسأل امتى بيوصل الطلب وما في وقت توصيل مكتوب';

      final note = assistantReason(
        ar,
        _conversation(
          id: 'c',
          inboundAgo: const Duration(hours: 1),
          aiState: 'escalated',
          aiEscalationCode: 'assistant',
          aiEscalationReason: written,
        ),
      );

      expect(note, written);
    });

    test('a hand-over the assistant wrote no reason for still says something',
        () {
      // In the pane, where there is room for it.
      // The model is allowed to return no reason, and a blank line under the
      // preview would read as a rendering fault rather than as a hand-over.
      for (final language in [ar, en]) {
        expect(
          assistantReason(
            language,
            _conversation(
              id: 'c',
              inboundAgo: const Duration(hours: 1),
              aiState: 'escalated',
              aiEscalationCode: 'assistant',
            ),
          ),
          language.broughtToYou,
        );
      }
    });

    test('every escalation code has its own sentence, in both languages', () {
      // Same rule as the send refusals above: two codes sharing a sentence tell
      // the seller the same thing about different problems. window_closed and
      // no_window are the deliberate exception — both mean nothing could be
      // sent, and the difference between them is ours, not theirs.
      const codes = [
        'window_closed',
        'ai_streak',
        'seller_present',
        'ceiling',
        'ungrounded',
        'not_sent',
      ];

      for (final language in [ar, en]) {
        final said = <String, String>{};

        for (final code in codes) {
          final note = assistantReason(
            language,
            _conversation(
              id: code,
              inboundAgo: const Duration(hours: 1),
              aiState: 'escalated',
              aiEscalationCode: code,
            ),
          );

          expect(note, isNotNull, reason: '$code says nothing');
          expect(note, isNotEmpty, reason: '$code is empty');
          expect(said.containsKey(note), isFalse,
              reason: '$code says the same as ${said[note]}');
          said[note!] = code;
        }
      }

      for (final code in codes) {
        final arabic = assistantReason(
          ar,
          _conversation(
            id: code,
            inboundAgo: const Duration(hours: 1),
            aiState: 'escalated',
            aiEscalationCode: code,
          ),
        );

        expect(arabic, matches(RegExp(r'[؀-ۿ]')),
            reason: '$code is not translated');
      }
    });

    test('a closed window reads the same whether it closed or never opened', () {
      Conversation of(String code) => _conversation(
            id: code,
            inboundAgo: const Duration(hours: 1),
            aiState: 'escalated',
            aiEscalationCode: code,
          );

      expect(assistantReason(en, of('no_window')),
          assistantReason(en, of('window_closed')));
    });

    test('a code the interface has never met reads as a hand-over', () {
      // Codes are added on the server first. A seller meeting a new one must
      // see a conversation that needs them, not a blank line and not a token.
      for (final language in [ar, en]) {
        expect(
          assistantReason(
            language,
            _conversation(
              id: 'c',
              inboundAgo: const Duration(hours: 1),
              aiState: 'escalated',
              aiEscalationCode: 'something_added_later',
            ),
          ),
          language.broughtToYou,
        );
      }
    });

    test('a conversation the assistant never touched says nothing at all', () {
      final untouched = _conversation(id: 'c', inboundAgo: const Duration(hours: 1));

      expect(assistantReason(en, untouched), isNull);
      expect(assistantMark(en, untouched), isNull,
          reason: 'a row it never saw must carry no mark either');
    });

    test('an answered conversation carries a mark and no reason', () {
      // A leftover reason from an earlier escalation must not be read out under
      // a conversation that has since been answered. The pane asks for the
      // reason and gets nothing; the row asks for the mark and gets the word.
      final answered = _conversation(
        id: 'c',
        inboundAgo: const Duration(hours: 1),
        aiState: 'answered',
        aiEscalationReason: 'stale',
        aiEscalationCode: 'assistant',
      );

      expect(assistantReason(en, answered), isNull);
      expect(assistantMark(en, answered), en.answeredByAssistant);
    });

    test('the row says what happened and never why', () {
      // The split this group exists to hold: the mark is one of two fixed
      // words, whatever the assistant wrote. A reason reaching the row again
      // is the regression — it was prose competing with the customer's own
      // words in a column with no room for it.
      const written = 'بتسأل امتى بيوصل الطلب وما في وقت توصيل مكتوب';

      final escalated = _conversation(
        id: 'c',
        inboundAgo: const Duration(hours: 1),
        aiState: 'escalated',
        aiEscalationCode: 'assistant',
        aiEscalationReason: written,
      );

      expect(assistantMark(ar, escalated), ar.broughtToYou);
      expect(assistantMark(ar, escalated), isNot(written));

      // Every code collapses to the same word on the row, including the ones
      // that have a sentence of their own in the pane.
      for (final code in ['window_closed', 'ungrounded', 'ceiling', 'whatever']) {
        expect(
          assistantMark(
            en,
            _conversation(
              id: code,
              inboundAgo: const Duration(hours: 1),
              aiState: 'escalated',
              aiEscalationCode: code,
            ),
          ),
          en.broughtToYou,
        );
      }
    });

    test('the mark is in the seller language, in both languages', () {
      final escalated = _conversation(
        id: 'c',
        inboundAgo: const Duration(hours: 1),
        aiState: 'escalated',
        aiEscalationCode: 'assistant',
      );
      final answered = _conversation(
        id: 'd',
        inboundAgo: const Duration(hours: 1),
        aiState: 'answered',
      );

      for (final c in [escalated, answered]) {
        expect(assistantMark(ar, c), isNot(assistantMark(en, c)));
        expect(assistantMark(ar, c), matches(RegExp(r'[؀-ۿ]')));
      }

      expect(assistantMark(en, escalated), isNot(assistantMark(en, answered)),
          reason: 'handed over and answered are opposite outcomes');
    });
  });

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
