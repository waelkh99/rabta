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

import 'data.dart';
import 'platform_icon.dart';
import 'strings.dart';
import 'theme.dart';

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
    final open = c.awaitingReply && (remaining ?? 0) > 0;

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
            style: Style.heading.copyWith(color: colors.ink),
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
          if (mark != null) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 7),
              child: mark,
            ),
          ],
          Text(value, style: Style.preview.copyWith(color: colors.ink)),
        ],
      ),
    );
  }
}
