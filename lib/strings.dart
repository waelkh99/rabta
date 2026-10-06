// Turning the two things the interface measures — a gap and a remaining window
// — into words, through the localisation files rather than around them.
//
// Kept out of the widgets so that "5 minutes ago" is written once per language
// instead of once per screen, and so the unit choice can be tested without a
// widget tree.

import 'package:flutter/widgets.dart';

import 'data.dart';
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

/// The short version, for a row in the inbox: what the assistant did, and
/// nothing about why.
///
/// The why lives in the details pane, where there is room to read it. On a row
/// it was a third line of prose competing with the customer's own words, and it
/// was ellipsised at exactly the point it started saying anything.
///
/// Null when the assistant has not touched this conversation, or when the
/// seller has since replied — replying is what clears all of it.
String? assistantMark(L l, Conversation c) {
  if (c.answeredByAssistant) return l.answeredByAssistant;
  if (c.escalated) return l.broughtToYou;
  return null;
}

/// Why the assistant stepped back, in full, for the details pane.
///
/// Null when it has not touched this conversation, or when the seller has since
/// replied — replying is what clears all of it, on the row and in the database.
///
/// The escalation reason has two sources and they are not interchangeable. When
/// the assistant itself decided a person was needed it writes the reason, in the
/// language of the conversation, and that sentence is shown as written: it is
/// the only one that knows what the customer actually asked. Every other
/// escalation is our own code stepping in, and those are named here so the
/// seller reads them in their own language rather than in ours.
///
/// A code the interface has not met reads as a plain hand-over. New ones will
/// be added on the server before they are added here, and a seller meeting one
/// should see a conversation that needs them — not a blank line, and not a
/// token.
///
/// Takes `L` rather than a context for the same reason `sendRefusal` does:
/// every case can then be checked in both languages without a widget tree.
String? assistantReason(L l, Conversation c) {
  if (!c.escalated) return null;

  // The assistant's own words come first, whatever the code says. It is the
  // only reason on this list that mentions the customer's actual question.
  final written = c.aiEscalationReason?.trim();
  if (c.aiEscalationCode == 'assistant' && written != null && written.isNotEmpty) {
    return written;
  }

  return switch (c.aiEscalationCode) {
    // Two codes, one meaning to a seller: nothing could be sent, because Meta
    // would not have carried it. The distinction between "closed" and "never
    // opened" is ours and tells them nothing they can act on.
    'window_closed' || 'no_window' => l.escalatedWindowClosed,
    'ai_streak' => l.escalatedAiStreak,
    'seller_present' => l.escalatedSellerPresent,
    'ceiling' => l.escalatedCeiling,
    'ungrounded' => l.escalatedUngrounded,
    // Its own line, because it tells the seller what to do: add a photo.
    // With the product's name, from the seller's own catalog, so they know
    // which photo to add without opening the conversation to find out.
    'no_photo' => c.aiEscalationReason?.trim().isNotEmpty == true
        ? '${l.escalatedNoPhoto}: ${c.aiEscalationReason!.trim()}'
        : l.escalatedNoPhoto,
    'not_sent' => l.escalatedNotSent,

    // Null, not a general sentence. Wherever this is shown there is already a
    // heading saying the conversation was handed over, and repeating it
    // underneath itself reads as a rendering fault. A code the interface has
    // not met is a hand-over with nothing to add, which is exactly what the
    // heading alone says.
    _ => null,
  };
}

String platformName(BuildContext context, String platform) =>
    switch (platform) {
      'instagram' => L.of(context)!.platformInstagram,
      'whatsapp' => L.of(context)!.platformWhatsApp,
      _ => L.of(context)!.platformMessenger,
    };

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

/// What goes between the parts of a row's second line: "45 د.ا · P-001 · فساتين".
///
/// In Arabic the dot is fenced with right-to-left marks. Left bare, a dot
/// between two Latin parts — a code and an English category — joins them
/// into one left-to-right run, and the line reads in a different order from
/// every row around it. Seen in the Playwright pass of 22 September.
String metaSeparator(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl ? '‏ · ‏' : ' · ';

/// How a conversation ended, in the seller's language. An unfamiliar code
/// reads as still open rather than as a token.
String outcomeLabel(L l, String? outcome) => switch (outcome) {
      'ordered' => l.outcomeOrdered,
      'not_bought' => l.outcomeNotBought,
      'just_asking' => l.outcomeJustAsking,
      _ => l.outcomeOpen,
    };

/// Why a customer did not buy. An unfamiliar code reads as no clear reason.
String reasonLabel(L l, String? reason) => switch (reason) {
      'price' => l.reason_price,
      'delivery_fee' => l.reason_delivery_fee,
      'delivery_time' => l.reason_delivery_time,
      'size_or_variant' => l.reason_size_or_variant,
      'out_of_stock' => l.reason_out_of_stock,
      'not_sold' => l.reason_not_sold,
      'no_answer' => l.reason_no_answer,
      _ => l.reason_unknown,
    };
