// Who this conversation is with, and how long is left.
//
// The third pane exists because the thread was taking the whole screen for
// content that is at most 470px wide — a message column does not get more
// readable by having more room around it.
//
// What goes in here is bounded by Phase One: no orders, no products, no notes,
// no tags. CLAUDE.md rules those out, and an empty "Orders" heading promising
// something that does not exist is worse than not having the pane. So it
// carries what we actually know — who wrote, from where, since when, and the
// state of the reply window, which is the one thing that changes while the
// seller is reading.

import 'package:flutter/material.dart';

import '../data.dart';
import 'platform_icon.dart';
import '../strings.dart';
import '../theme.dart';

class DetailsPanel extends StatelessWidget {
  const DetailsPanel({
    super.key,
    required this.conversation,
    required this.messages,
  });

  final Conversation conversation;

  /// Null while they are still loading — the panel shows everything else
  /// rather than holding the whole pane back for one line.
  final List<Message>? messages;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final c = conversation;

    final remaining = windowRemainingFraction(c.windowExpiresAt);
    final closing = windowClosingSoon(c.windowExpiresAt);
    final open = replyWindowOpen(c.windowExpiresAt);

    final firstMessage = (messages == null || messages!.isEmpty)
        ? null
        : messages!.first.sentAt;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: BorderDirectional(start: BorderSide(color: colors.edge)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Text(
            l.aboutCustomer,
            style: Style.groupLabel.copyWith(color: colors.muted),
          ),
          const SizedBox(height: 18),
          Text(
            c.customerName ?? l.customer,
            textDirection: nameLayout(context, c.customerName ?? l.customer).direction,
            textAlign: nameLayout(context, c.customerName ?? l.customer).align,
            style: display(Style.title.copyWith(color: colors.ink, fontSize: 20)),
          ),
          const SizedBox(height: 24),

          // The reply window first, because it is the only thing here that is
          // running down while the seller reads.
          _WindowCard(
            remaining: remaining,
            open: open,
            closing: closing,
            expiresAt: c.windowExpiresAt,
          ),
          const SizedBox(height: 24),

          // What the assistant did here, and why. The inbox row says only that
          // it happened; this is where the sentence it wrote is readable in
          // full instead of ellipsised into a row that had no width for it.
          //
          // A hand-over is shown above the messages instead, at every width,
          // so it is not repeated here.
          if (!c.escalated) AssistantCard(conversation: c),

          _Fact(
            label: l.detailPlatform,
            value: platformName(context, c.platform),
            mark: PlatformIcon(platform: c.platform, size: 12),
          ),
          _Fact(
            label: l.detailMessages,
            value: messages == null ? '—' : l.messageCount(messages!.length),
          ),
          _Fact(
            label: l.detailFirstWrote,
            value: firstMessage == null ? '—' : waitedFor(context, firstMessage),
          ),
        ],
      ),
    );
  }
}

/// Why the assistant stepped back, or that it answered.
///
/// Public because it is shown in two places, never both at once: here when the
/// pane is on screen, and at the top of the thread when it is not. Below
/// `_threePaneFrom` this pane does not exist at all, and without the second
/// home the assistant's own sentence was unreachable on anything narrower than
/// a wide desktop — a seller on a tablet saw that a conversation had been
/// handed to them and could not find out why.
///
/// Nothing at all when it has not touched this conversation, and nothing once
/// the seller has replied — which is the moment it stops being true, and is
/// cleared on the row by the database rather than by this pane.
///
/// Teal throughout, the colour an assistant message already carries in the
/// thread beside it, so the two read as the same voice.
class AssistantCard extends StatelessWidget {
  const AssistantCard({super.key, required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final c = conversation;

    if (!c.escalated && !c.answeredByAssistant) return const SizedBox.shrink();

    final reason = assistantReason(l, c);

    // A hand-over is loud: urgent, bordered, and headed in words that say the
    // customer is waiting. The product owner, 23 September 2026: "I honestly
    // couldn't tell this chat got handed over." Answering stays quiet teal.
    final tint = c.escalated ? colors.urgent : colors.assistant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: c.escalated ? 0.10 : 0.07),
          borderRadius: BorderRadius.circular(12),
          border: c.escalated
              ? BorderDirectional(start: BorderSide(color: tint, width: 4))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  c.escalated ? Icons.front_hand : Icons.auto_awesome_outlined,
                  size: c.escalated ? 18 : 13,
                  color: tint,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    c.escalated ? l.needsYouTitle : l.answeredByAssistant,
                    style: (c.escalated ? Style.name : Style.meta).copyWith(
                      color: tint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (reason != null) ...[
              const SizedBox(height: 10),
              // The assistant writes its own reason in the language of the
              // conversation, which is not always the language of the
              // interface around it. It cannot inherit this pane's direction.
              Directionality(
                textDirection: directionOf(reason),
                child: Text(
                  reason,
                  style: Style.preview.copyWith(color: colors.ink, height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({
    required this.remaining,
    required this.open,
    required this.closing,
    required this.expiresAt,
  });

  final double? remaining;
  final bool open;
  final bool closing;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final tone = !open
        ? colors.muted
        : closing
            ? colors.urgent
            : colors.accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.ground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.detailReplyWindow,
                  style: Style.meta.copyWith(color: colors.muted),
                ),
              ),
              Text(
                open ? l.windowOpen : l.windowClosed,
                style: Style.meta.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            open
                ? windowRemaining(context, expiresAt) ?? ''
                : l.replyWindowClosedShort,
            style: Style.name.copyWith(color: open ? colors.ink : colors.muted),
          ),
          const SizedBox(height: 12),

          // The same gauge as the list, lying down. A seller who learns it in
          // one place reads it everywhere.
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: open ? remaining : 0,
              minHeight: 5,
              backgroundColor: colors.accentSoft,
              valueColor: AlwaysStoppedAnimation(tone),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.windowExplanation,
            style: Style.meta.copyWith(color: colors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.mark});

  final String label;
  final String value;
  final Widget? mark;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Style.preview.copyWith(color: colors.muted),
            ),
          ),
          // The mark is centred on the value, not on the row's top edge.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (mark != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 7),
                  child: mark,
                ),
              Text(value, style: Style.preview.copyWith(color: colors.ink)),
            ],
          ),
        ],
      ),
    );
  }
}
