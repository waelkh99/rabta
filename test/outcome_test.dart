// How a conversation ended, on the client: what is drawn, and the week.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rabta/data.dart';
import 'package:rabta/l10n/app_localizations.dart';
import 'package:rabta/widgets/outcome.dart';

Conversation _c({String? outcome, String? reason, String? by}) => Conversation(
      id: '1',
      platform: 'messenger',
      customerName: 'x',
      customerAvatarUrl: null,
      preview: null,
      lastMessageType: 'text',
      lastMessageAt: null,
      lastInboundAt: null,
      windowExpiresAt: null,
      unreadCount: 0,
      outcome: outcome,
      outcomeReason: reason,
      outcomeBy: by,
    );

void main() {
  final en = lookupL(const Locale('en'));
  final ar = lookupL(const Locale('ar'));

  group('what is drawn', () {
    test('nothing while open, or undecided', () {
      expect(_c().shownOutcome, isNull);
      expect(_c(outcome: 'undecided').shownOutcome, isNull);
      expect(_c(outcome: 'ordered').shownOutcome, 'ordered');
    });

    test('a lost customer carries the reason when there is one', () {
      expect(outcomeText(en, _c(outcome: 'not_bought', reason: 'price')), "Didn't buy · Price");
      expect(outcomeText(en, _c(outcome: 'not_bought', reason: 'unknown')), "Didn't buy");
      expect(outcomeText(ar, _c(outcome: 'not_bought', reason: 'delivery_fee')), 'لم يشترِ · رسوم التوصيل');
    });

    test('an unfamiliar reason reads as no clear reason, never as a token', () {
      expect(outcomeText(en, _c(outcome: 'not_bought', reason: 'weather')), "Didn't buy · No clear reason");
    });

    test('a correction survives a reply', () {
      final corrected = _c(outcome: 'not_bought', reason: 'price', by: 'ai')
          .copyWith(outcome: 'ordered', outcomeBy: 'seller', clearReason: true);
      expect(corrected.outcome, 'ordered');
      expect(corrected.outcomeReason, isNull);
      final replied = corrected.afterReply(Message(
        id: 'm', mid: 'm', text: 'x', attachments: const [], inbound: false, sentAt: DateTime.utc(2026),
      ));
      expect(replied.outcome, 'ordered');
      expect(replied.outcomeBy, 'seller');
    });
  });

  group('the week', () {
    final json = {
      'conversations': 5,
      'ordered': 2,
      'not_bought': 2,
      'just_asking': 0,
      'open': 1,
      'reasons': {'delivery_fee': 1, 'price': 3},
      'products': [
        {'name': 'فستان أحمر', 'asked': 2, 'ordered': 1},
      ],
      'areas': [
        {'name': 'إربد', 'count': 2},
      ],
      'unanswered': 1,
      'hours': [for (var h = 0; h < 24; h++) h == 21 ? 5 : (h == 22 ? 4 : (h == 10 ? 3 : 0))],
      'read_by_assistant': 4,
      'corrected': 1,
    };

    test('reads what outcome_summary returns', () {
      final w = WeekSummary.fromJson(json);
      expect(w.conversations, 5);
      expect(w.products.single.name, 'فستان أحمر');
      expect(w.areas.single.count, 2);
      expect(w.hours.length, 24);
      expect(w.corrected, 1);
    });

    test('reasons come most common first', () {
      expect(WeekSummary.fromJson(json).reasons.map((e) => e.key), ['price', 'delivery_fee']);
    });

    test('the busiest three hours, not the busiest one', () {
      expect(WeekSummary.fromJson(json).busiestFrom, 20);
    });

    test('an empty week has no busiest time', () {
      expect(WeekSummary.fromJson({...json, 'hours': List.filled(24, 0)}).busiestFrom, isNull);
    });

    test('a busy stretch across midnight is found', () {
      final hours = List.filled(24, 0)
        ..[23] = 4
        ..[0] = 4
        ..[1] = 4;
      expect(WeekSummary.fromJson({...json, 'hours': hours}).busiestFrom, 23);
    });
  });
}
