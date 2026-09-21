// What the seller is told, and what they are deliberately not told.
//
// The browser is not here. `alerts.dart` holds the rules and no browser calls;
// `alerts_web.dart` holds the browser calls and no rules. This file is the
// reason for that split — every decision below is one that would otherwise only
// be checkable by sitting in front of a tab and waiting for a customer.

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:rabta/alerts.dart';
import 'package:rabta/data.dart';
import 'package:rabta/l10n/app_localizations.dart';

final _now = DateTime.utc(2026, 9, 21, 12, 0);

Conversation _c(
  String id, {
  Duration inboundAgo = const Duration(hours: 1),
  Duration? repliedAgo,
  String? aiState,
  String? name,
}) {
  final inboundAt = _now.subtract(inboundAgo);

  return Conversation(
    id: id,
    platform: 'messenger',
    customerName: name ?? id,
    customerAvatarUrl: null,
    preview: null,
    lastMessageType: 'text',
    lastMessageAt: repliedAgo == null ? inboundAt : _now.subtract(repliedAgo),
    lastInboundAt: inboundAt,
    windowExpiresAt: inboundAt.add(const Duration(hours: 24)),
    unreadCount: repliedAgo == null ? 1 : 0,
    aiState: aiState,
    aiEscalationCode: aiState == 'escalated' ? 'assistant' : null,
  );
}

void main() {
  group('what is worth interrupting for', () {
    test('the first list of the session announces nothing', () {
      // Otherwise opening Rabta to nine waiting customers fires nine
      // notifications about customers already on screen. This is the single
      // most likely way for this feature to become something the seller turns
      // off and never turns on again.
      final first = [_c('a'), _c('b'), _c('c')];

      expect(alertsFor(null, first), isEmpty);
    });

    test('a customer who writes for the first time is announced', () {
      final before = [_c('a')];
      final after = [_c('a'), _c('b')];

      expect(alertsFor(before, after), [Alert(after[1], AlertKind.wrote)]);
    });

    test('a customer who writes again is announced', () {
      final before = [_c('a', inboundAgo: const Duration(hours: 3))];
      final after = [_c('a', inboundAgo: const Duration(minutes: 1))];

      expect(alertsFor(before, after), [Alert(after.first, AlertKind.wrote)]);
    });

    test('a second message is caught even after the assistant answered the first',
        () {
      // Compared on the inbound timestamp and not on the unread count, which
      // an assistant reply resets to zero. A customer who writes, is answered,
      // and writes again would otherwise look unchanged and be announced to
      // nobody.
      final before = [
        _c('a',
            inboundAgo: const Duration(hours: 2),
            repliedAgo: const Duration(hours: 2),
            aiState: 'answered'),
      ];
      final after = [_c('a', inboundAgo: const Duration(minutes: 1))];

      expect(alertsFor(before, after), [Alert(after.first, AlertKind.wrote)]);
    });

    test('the assistant handing a conversation back is announced', () {
      final before = [_c('a', repliedAgo: const Duration(hours: 1))];
      final after = [
        _c('a', repliedAgo: const Duration(hours: 1), aiState: 'escalated'),
      ];

      expect(alertsFor(before, after), [Alert(after.first, AlertKind.handedOver)]);
    });

    test('a hand-over on a message that just arrived is announced once, as a hand-over',
        () {
      // Both things are true at the same moment: the customer wrote, and the
      // assistant gave up on it. Two notifications for one event is noise, and
      // of the two the hand-over is the one that tells the seller something
      // they do not already assume.
      final before = [_c('a', inboundAgo: const Duration(hours: 5))];
      final after = [
        _c('a', inboundAgo: const Duration(minutes: 1), aiState: 'escalated'),
      ];

      final alerts = alertsFor(before, after);

      expect(alerts, hasLength(1));
      expect(alerts.single.kind, AlertKind.handedOver);
    });

    test('a conversation already escalated is not announced again', () {
      // The assistant marks it once and nothing clears it but the seller's own
      // reply. Every unrelated refresh would otherwise re-announce it.
      final before = [_c('a', aiState: 'escalated')];
      final after = [_c('a', aiState: 'escalated')];

      expect(alertsFor(before, after), isEmpty);
    });

    test('the conversation the seller is reading is never announced', () {
      final before = [_c('a', inboundAgo: const Duration(hours: 3))];
      final after = [_c('a', inboundAgo: const Duration(minutes: 1))];

      expect(alertsFor(before, after, openId: 'a'), isEmpty);
      expect(alertsFor(before, after, openId: 'b'), hasLength(1),
          reason: 'and someone else writing while they read still is');
    });

    test('the assistant answering on its own is not announced', () {
      // Nobody is waiting. The row says the assistant answered and the seller
      // can read it whenever they like; a notification would be telling them
      // about work that is already done.
      final before = [_c('a')];
      final after = [
        _c('a', repliedAgo: const Duration(minutes: 1), aiState: 'answered'),
      ];

      expect(alertsFor(before, after), isEmpty);
    });

    test('the seller answering is not announced', () {
      final before = [_c('a')];
      final after = [_c('a', repliedAgo: const Duration(minutes: 1))];

      expect(alertsFor(before, after), isEmpty);
    });

    test('a conversation that arrives already answered is not announced', () {
      // It can: a seller replying from Messenger on their phone creates rows
      // here through the echo, and the conversation appears in this tab for
      // the first time with nobody waiting on it.
      final before = <Conversation>[];
      final after = [
        _c('a', repliedAgo: const Duration(minutes: 1)),
      ];

      expect(alertsFor(before, after), isEmpty);
    });

    test('several customers at once are all announced', () {
      final before = [_c('a')];
      final after = [_c('a'), _c('b'), _c('c', aiState: 'escalated')];

      final alerts = alertsFor(before, after);

      expect(alerts.map((a) => a.conversation.id), ['b', 'c']);
      expect(alerts.map((a) => a.kind),
          [AlertKind.wrote, AlertKind.handedOver]);
    });

    test('a conversation that disappears is not announced', () {
      expect(alertsFor([_c('a'), _c('b')], [_c('a')]), isEmpty);
    });
  });

  group('the count in the tab title', () {
    test('leads, because that is all a narrow background tab shows', () {
      expect(titleFor('Rabta', 3), '(3) Rabta');
    });

    test('nothing waiting reads as the plain name, not as zero', () {
      // "(0) Rabta" is a number that costs a glance to discover means nothing.
      expect(titleFor('Rabta', 0), 'Rabta');
    });
  });

  group('what a notification says', () {
    late L ar;
    late L en;

    setUp(() async {
      ar = await L.delegate.load(const Locale('ar'));
      en = await L.delegate.load(const Locale('en'));
    });

    test('never quotes the customer', () async {
      // A notification shows on a locked screen and over a shared desk. What a
      // customer writes to a shop is theirs, and the seller only needs to know
      // there is something to open.
      const secret = 'بدي أرجع القطعة، مقاسها غلط';

      final conversation = Conversation(
        id: 'a',
        platform: 'messenger',
        customerName: 'ليلى',
        customerAvatarUrl: null,
        preview: secret,
        lastMessageType: 'text',
        lastMessageAt: _now,
        lastInboundAt: _now,
        windowExpiresAt: _now.add(const Duration(hours: 24)),
        unreadCount: 1,
      );

      for (final kind in AlertKind.values) {
        final said = alertText(ar, Alert(conversation, kind));
        expect(said.title, isNot(contains(secret)));
        expect(said.body, isNot(contains(secret)));
      }
    });

    test('names the customer, so the seller knows who is waiting', () {
      final said = alertText(en, Alert(_c('a', name: 'Layla'), AlertKind.wrote));
      expect(said.title, 'Layla');
    });

    test('a customer with no name still says something', () {
      // Meta sends an opaque id and the profile fetch can fail. A notification
      // headed with nothing at all is worse than one headed "Customer".
      final nameless = Conversation(
        id: 'a',
        platform: 'messenger',
        customerName: null,
        customerAvatarUrl: null,
        preview: null,
        lastMessageType: 'text',
        lastMessageAt: _now,
        lastInboundAt: _now,
        windowExpiresAt: null,
        unreadCount: 1,
      );

      expect(alertText(en, Alert(nameless, AlertKind.wrote)).title, en.customer);
    });

    test('the two kinds do not say the same thing, in either language', () {
      for (final l in [ar, en]) {
        final wrote = alertText(l, Alert(_c('a'), AlertKind.wrote));
        final handed = alertText(l, Alert(_c('a'), AlertKind.handedOver));

        expect(wrote.body, isNot(handed.body));
        expect(wrote.body, isNotEmpty);
        expect(handed.body, isNotEmpty);
      }
    });

    test('the Arabic is Arabic', () {
      for (final kind in AlertKind.values) {
        expect(
          alertText(ar, Alert(_c('a'), kind)).body,
          matches(RegExp(r'[؀-ۿ]')),
        );
        expect(
          alertText(ar, Alert(_c('a'), kind)).body,
          isNot(alertText(en, Alert(_c('a'), kind)).body),
        );
      }
    });

    test('the states that are not a choice each explain themselves', () {
      for (final l in [ar, en]) {
        final said = {
          alertStateLabel(l, AlertState.on),
          alertStateLabel(l, AlertState.blocked),
          alertStateLabel(l, AlertState.unsupported),
        };

        expect(said, hasLength(3),
            reason: 'refused and unavailable are different things to a seller');
      }

      // On and off share a label because the switch beside them carries the
      // difference. A second wording would say the same thing twice, and the
      // two would drift.
      expect(alertStateLabel(en, AlertState.on),
          alertStateLabel(en, AlertState.off));

      // The one a seller on an iPhone reads. It must not sound like a fault:
      // they have not done anything wrong, they have not been refused, and
      // adding Rabta to the home screen fixes it.
      expect(en.alertsUnsupported, isNot(en.alertsDenied));
      expect(ar.alertsUnsupported, matches(RegExp(r'[؀-ۿ]')));
    });
  });

  group('turning them on and off', () {
    test('granted and wanted is the only state that shows anything', () {
      expect(
        alertStateFrom(AlertPermission.granted, true),
        AlertState.on,
      );
    });

    test('a seller who switches them off stays off, though the browser still permits it',
        () {
      // The reason this state exists at all. A granted permission cannot be
      // handed back from code — Notification.permission stays "granted" until
      // someone changes it in browser settings — so "off" has to be ours.
      expect(
        alertStateFrom(AlertPermission.granted, false),
        AlertState.off,
      );
    });

    test('never asked reads as off, whatever is stored', () {
      // The stored preference defaults to true, so without this a browser that
      // has never been asked would show the switch already on and then never
      // show a notification.
      for (final wanted in [true, false]) {
        expect(alertStateFrom(AlertPermission.ask, wanted), AlertState.off);
      }
    });

    test('blocked and unavailable are never reported as off', () {
      // Off is a state the seller can leave by flipping a switch. These two
      // are not, and calling them off would put a switch on the row that
      // cannot do anything.
      for (final wanted in [true, false]) {
        expect(alertStateFrom(AlertPermission.denied, wanted), AlertState.blocked);
        expect(
          alertStateFrom(AlertPermission.unsupported, wanted),
          AlertState.unsupported,
        );
      }
    });

    test('only two of the four states are a choice', () {
      final choosable = [
        for (final permission in AlertPermission.values)
          for (final wanted in [true, false])
            alertStateFrom(permission, wanted),
      ].where((s) => s == AlertState.on || s == AlertState.off);

      expect(choosable, isNotEmpty);
      expect(
        AlertState.values.toSet(),
        {AlertState.on, AlertState.off, AlertState.blocked, AlertState.unsupported},
        reason: 'a new state needs a decision about whether it carries a switch',
      );
    });
  });
}
