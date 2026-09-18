// Turning the two things the interface measures — a gap and a remaining window
// — into words, through the localisation files rather than around them.
//
// Kept out of the widgets so that "5 minutes ago" is written once per language
// instead of once per screen, and so the unit choice can be tested without a
// widget tree.

import 'package:flutter/widgets.dart';

import 'l10n/app_localizations.dart';
import 'theme.dart';

extension Words on BuildContext {
  L get l => L.of(this)!;
}

/// How long ago, in the short form a dense list has room for.
String waitedFor(BuildContext context, DateTime? since, {DateTime? now}) {
  if (since == null) return '';

  final l = L.of(context)!;
  final (:unit, :count) = elapsedSince(since, now: now);

  return switch (unit) {
    Elapsed.now => l.justNow,
    Elapsed.minutes => l.minutesAgo(count),
    Elapsed.hours => l.hoursAgo(count),
    Elapsed.days => l.daysAgo(count),
    Elapsed.weeks => l.weeksAgo(count),
  };
}

/// What is left of the reply window, stated before the seller types rather than
/// after a reply fails. Null once it has closed.
String? windowRemaining(BuildContext context, DateTime? expiresAt,
    {DateTime? now}) {
  if (expiresAt == null) return null;

  final left = expiresAt.toUtc().difference(now ?? DateTime.now().toUtc());
  if (left.isNegative) return null;

  final l = L.of(context)!;
  return left.inMinutes < 60
      ? l.minutesLeftToReply(left.inMinutes)
      : l.hoursLeftToReply(left.inHours);
}

/// Why a reply was not sent, in the seller's language.
///
/// `send-message` answers with a code precisely so that this choice is made
/// here. An unfamiliar code reads as a plain refusal rather than as something
/// invented to fill the gap.
///
/// Takes `L` rather than a context because it needs nothing else from one, and
/// because that lets every code be checked in both languages without a widget
/// tree.
String sendRefusal(L l, String reason) => switch (reason) {
      'too_long' => l.sendFailedTooLong,
      'window_closed' => l.sendFailedWindowClosed,
      'no_window' => l.sendFailedNoWindow,
      'disconnected' => l.sendFailedDisconnected,
      'unreachable' => l.sendFailedUnreachable,
      'not_found' => l.sendFailedNotFound,
      _ => l.sendFailedRejected,
    };

String platformName(BuildContext context, String platform) =>
    platform == 'instagram'
        ? L.of(context)!.platformInstagram
        : L.of(context)!.platformMessenger;

/// The label for a message that carries an attachment and no text. Built here
/// rather than stored, so the database never holds a user-facing string in one
/// language.
String attachmentLabel(BuildContext context, String? type) {
  final l = L.of(context)!;
  return switch (type) {
    'image' => l.attachmentPhoto,
    'video' => l.attachmentVideo,
    'audio' => l.attachmentVoice,
    'file' => l.attachmentFile,
    'share' => l.attachmentShare,
    _ => l.attachmentOther,
  };
}
