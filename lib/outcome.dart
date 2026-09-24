// How a conversation ended, on the row and in the thread.
//
// The assistant marks it once the conversation settles; the seller corrects it
// here. See CLAUDE.md, "How conversations end". The mark says whose it is — a
// small sparkle when the assistant set it — because the assistant's reading
// is a suggestion, and the seller should never have to wonder which labels
// they can trust as their own.

import 'package:flutter/material.dart';

import 'data.dart';
import 'l10n/app_localizations.dart';
import 'strings.dart';
import 'theme.dart';

IconData _icon(String outcome) => switch (outcome) {
      'ordered' => Icons.check_circle_outline,
      'not_bought' => Icons.remove_shopping_cart_outlined,
      'just_asking' => Icons.chat_bubble_outline,
      _ => Icons.radio_button_unchecked,
    };

Color _tint(RabtaColors colors, String outcome) =>
    outcome == 'ordered' ? colors.won : colors.muted;

/// "Didn't buy · Price", or just the outcome. Shared by the row and the button.
String outcomeText(L l, Conversation c) {
  final outcome = c.shownOutcome;
  if (outcome == null) return l.outcomeOpen;
  final label = outcomeLabel(l, outcome);
  final reason = c.outcomeReason;
  return outcome == 'not_bought' && reason != null && reason != 'unknown'
      ? '$label$metaSeparatorText${reasonLabel(l, reason)}'
      : label;
}

const metaSeparatorText = ' · ';

/// The outcome on a row. Nothing at all while the conversation is open.
class OutcomeMark extends StatelessWidget {
  const OutcomeMark({super.key, required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final outcome = conversation.shownOutcome;
    if (outcome == null) return const SizedBox.shrink();

    final colors = context.rabta;
    final tint = _tint(colors, outcome);
    final l = context.l;

    return Tooltip(
      message: conversation.outcomeBy == 'ai' ? l.outcomeByAssistant : l.outcomeBySeller,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(outcome), size: 12, color: tint),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              outcomeText(l, conversation),
              style: Style.meta.copyWith(
                color: tint,
                fontWeight: outcome == 'ordered' ? FontWeight.w700 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (conversation.outcomeBy == 'ai') ...[
            const SizedBox(width: 3),
            Icon(Icons.auto_awesome, size: 9, color: colors.muted),
          ],
        ],
      ),
    );
  }
}

/// The outcome in the thread header, and the way to change it.
class OutcomeButton extends StatelessWidget {
  const OutcomeButton({
    super.key,
    required this.conversation,
    required this.onChanged,
    this.compact = false,
  });

  final Conversation conversation;

  /// Icon only, for a phone-width header where the words would starve the
  /// customer's name of room. The row in the list still says it in words.
  final bool compact;

  /// The outcome and, for `not_bought`, the reason chosen.
  final void Function(String outcome, String? reason) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final c = conversation;
    final outcome = c.shownOutcome;
    final tint = outcome == null ? colors.muted : _tint(colors, outcome);

    MenuItemButton item(String value) => MenuItemButton(
          leadingIcon: Icon(_icon(value), size: 16, color: _tint(colors, value)),
          trailingIcon: c.outcome == value ? Icon(Icons.check, size: 16, color: colors.accent) : null,
          onPressed: () => onChanged(value, null),
          child: Text(outcomeLabel(l, value)),
        );

    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 6),
          // Whose label it is, said here rather than in a tooltip: a tooltip
          // on the button sat on top of this menu once it opened.
          child: Text(
            c.outcomeBy == 'ai' ? l.outcomeByAssistant : l.outcomeQuestion,
            style: Style.meta.copyWith(color: colors.muted),
          ),
        ),
        item('ordered'),
        // Not a submenu. At phone width a cascading menu opened off the edge
        // of the screen and the reasons could not be reached at all — seen in
        // a browser. One list, the reasons indented under their heading.
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 2),
          child: Row(
            children: [
              Icon(_icon('not_bought'), size: 16, color: colors.muted),
              const SizedBox(width: 12),
              Text(l.outcomeNotBought, style: Style.preview.copyWith(color: colors.ink)),
            ],
          ),
        ),
        for (final reason in [...lostReasons.where((r) => r != 'unknown'), 'unknown'])
          MenuItemButton(
            style: MenuItemButton.styleFrom(
              padding: const EdgeInsetsDirectional.only(start: 40, end: 12),
            ),
            trailingIcon: c.outcome == 'not_bought' && (c.outcomeReason ?? 'unknown') == reason
                ? Icon(Icons.check, size: 16, color: colors.accent)
                : null,
            onPressed: () => onChanged('not_bought', reason),
            child: Text(
              reason == 'unknown' ? l.outcomeNoReason : reasonLabel(l, reason),
              style: Style.meta.copyWith(color: colors.ink),
            ),
          ),
        item('just_asking'),
        item('undecided'),
      ],
      builder: (context, controller, _) => Semantics(
        label: l.outcomeQuestion,
        child: TextButton.icon(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          style: TextButton.styleFrom(
            foregroundColor: tint,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: outcome == 'ordered' ? tint : colors.edge),
            ),
          ),
          icon: Icon(outcome == null ? Icons.flag_outlined : _icon(outcome), size: 15),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!compact) ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 170),
                child: Text(
                  outcome == null ? l.outcomeSet : outcomeText(l, c),
                  style: Style.meta.copyWith(color: tint, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (c.outcomeBy == 'ai' && !compact) ...[
                const SizedBox(width: 4),
                Icon(Icons.auto_awesome, size: 10, color: colors.muted),
              ],
              const SizedBox(width: 2),
              Icon(Icons.expand_more, size: 15, color: tint),
            ],
          ),
        ),
      ),
    );
  }
}
