// Search, reading a conversation, pausing the assistant, and saving an answer.
//
// Pure rules, tested here; how they look is checked in a browser.

import 'package:flutter_test/flutter_test.dart';

import 'package:rabta/data.dart';

Conversation _c(String id, {String? name, String? preview, int unread = 0}) =>
    Conversation(
      id: id,
      platform: 'messenger',
      customerName: name,
      customerAvatarUrl: null,
      preview: preview,
      lastMessageType: 'text',
      lastMessageAt: DateTime.utc(2026, 9, 24),
      lastInboundAt: DateTime.utc(2026, 9, 24),
      windowExpiresAt: null,
      unreadCount: unread,
      aiState: 'escalated',
    );

void main() {
  final all = [
    _c('1', name: 'سارة أحمد', preview: 'قديش سعر الفستان؟'),
    _c('2', name: 'Wael K. Saleh', preview: 'Is the RED bag available?'),
    _c('3', name: null, preview: null),
  ];

  group('search', () {
    test('an empty query is no filter at all', () {
      expect(searchConversations(all, ''), all);
      expect(searchConversations(all, '   '), all);
    });

    test('matches a name, in Arabic and in English, ignoring case', () {
      expect(searchConversations(all, 'سارة').map((c) => c.id), ['1']);
      expect(searchConversations(all, 'wael').map((c) => c.id), ['2']);
    });

    test('matches the latest message', () {
      expect(searchConversations(all, 'الفستان').map((c) => c.id), ['1']);
      expect(searchConversations(all, 'red bag').map((c) => c.id), ['2']);
    });

    test('includes what matched further back in the history', () {
      // The server found it in an older message; the preview says nothing.
      expect(
        searchConversations(all, 'إربد', inHistory: {'3'}).map((c) => c.id),
        ['3'],
      );
    });

    test('a conversation with no name or preview does not match everything', () {
      expect(searchConversations(all, 'zzz'), isEmpty);
    });
  });

  group('copyWith', () {
    test('opening a conversation clears only its unread count', () {
      final read = _c('1', name: 'x', unread: 3).copyWith(unreadCount: 0);
      expect(read.unreadCount, 0);
      expect(read.escalated, isTrue, reason: 'reading is not answering');
    });

    test('pausing survives a reply', () {
      final paused = _c('1').copyWith(aiPaused: true);
      final replied = paused.afterReply(Message(
        id: 'm',
        mid: 'm',
        text: 'hi',
        attachments: const [],
        inbound: false,
        sentAt: DateTime.utc(2026, 9, 24, 1),
      ));
      expect(replied.aiPaused, isTrue,
          reason: 'a paused conversation stays paused until the seller says');
    });
  });

  group('saving an answer', () {
    test('the draft carries the question and the answer', () {
      expect(answerDraft('امتى بيوصل؟', 'بيوصل خلال يومين'),
          'امتى بيوصل؟ — بيوصل خلال يومين');
    });

    test('with no question, the answer alone', () {
      expect(answerDraft(null, '  بيوصل خلال يومين '), 'بيوصل خلال يومين');
      expect(answerDraft('  ', 'x'), 'x');
    });

    test('added on its own line after what the shop already wrote', () {
      expect(appendAnswer('نفتح من 10', 'التوصيل يومين'), 'نفتح من 10\nالتوصيل يومين');
    });

    test('into an empty field, just the answer', () {
      expect(appendAnswer(null, 'التوصيل يومين'), 'التوصيل يومين');
      expect(appendAnswer('  ', 'التوصيل يومين'), 'التوصيل يومين');
    });

    test('an empty answer changes nothing', () {
      expect(appendAnswer('نفتح من 10', '   '), 'نفتح من 10');
    });
  });
}
