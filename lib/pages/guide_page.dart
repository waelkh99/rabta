// The seller's guide for the assistant, and the diagram of how it was read.
//
// The seller writes in plain words how they want conversations run, the way
// they would brief a new employee. Saving reads it — one model call — and the
// reading is drawn back underneath: which situations the assistant will notice,
// what it does in each, which ones come to the seller, and what it was asked
// to do that it cannot.
//
// The words are the only thing the seller edits. The diagram is read-only on
// purpose: a seller fixes a wrong reading by saying it differently, which is
// what they would do with a person too. Boxes to drag would be a tool for
// someone who builds flows, and that is not who this is for.

import 'package:flutter/material.dart';

import '../data.dart';
import '../strings.dart';
import '../theme.dart';

class GuidePage extends StatefulWidget {
  const GuidePage({super.key, required this.inbox, required this.shop});

  final Inbox inbox;
  final Shop shop;

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  late final _text = TextEditingController(text: widget.shop.guide ?? '');
  late String _saved = (widget.shop.guide ?? '').trim();
  late GuideSteps? _steps = widget.shop.guideSteps;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    final typed = _text.text.trim();

    setState(() => _busy = true);

    try {
      final steps = await widget.inbox.saveGuide(typed);
      if (!mounted) return;
      setState(() {
        _saved = typed;
        _steps = steps;
      });
      messenger.showSnackBar(
        SnackBar(content: Text(typed.isEmpty ? l.guideCleared : l.guideSaved)),
      );
    } on GuideRefused catch (refused) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            refused.reason == 'too_long' ? l.guideTooLong : l.guideFailed,
          ),
          backgroundColor: context.rabta.urgent,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        title: Text(l.guideTitle),
        shape: Border(bottom: BorderSide(color: colors.edge)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _text,
                builder: (context, value, _) {
                  final stale = value.text.trim() != _saved;
                  final steps = _steps;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.guideBody,
                        style: Style.preview.copyWith(
                          color: colors.muted,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Measured 26 October with replay: the assistant does what a
                      // step says and nothing it only implies. "Ask their size
                      // first" got the size asked, and "available" said anyway, in
                      // 8 runs of 8; holding availability back took saying so. So
                      // the page tells sellers to spell out what matters.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.lightbulb_outline,
                              size: 16,
                              color: colors.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.guideTip,
                              style: Style.meta.copyWith(
                                color: colors.ink,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _text,
                        enabled: !_busy,
                        minLines: 6,
                        maxLines: 14,
                        maxLength: 4000,
                        textDirection: directionOf(
                          value.text.isEmpty ? l.guideHint : value.text,
                        ),
                        style: Style.message.copyWith(
                          color: colors.ink,
                          height: 1.6,
                        ),
                        decoration: InputDecoration(
                          hintText: l.guideHint,
                          hintMaxLines: 4,
                          hintStyle: Style.message.copyWith(
                            color: colors.muted,
                            height: 1.6,
                          ),
                          filled: true,
                          fillColor: colors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Radii.control),
                            borderSide: BorderSide(color: colors.line),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Radii.control),
                            borderSide: BorderSide(color: colors.line),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(Radii.control),
                            borderSide: BorderSide(color: colors.accent),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton(
                          onPressed: _busy || !stale ? null : _save,
                          child: Text(_busy ? l.guideSaving : l.guideSave),
                        ),
                      ),
                      if (_saved.isNotEmpty && steps != null) ...[
                        const SizedBox(height: 36),
                        Text(
                          l.guideUnderstood,
                          style: Style.heading.copyWith(color: colors.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stale ? l.guideStale : l.guideFix,
                          style: Style.preview.copyWith(
                            color: stale ? colors.urgent : colors.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Faded rather than hidden while the words have moved on:
                        // still the reading in force, no longer of what is typed.
                        Opacity(
                          opacity: stale ? 0.45 : 1,
                          child: GuideDiagram(steps: steps),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The reading, as a flow: a customer writes, then each situation hangs off
/// one line, with what the assistant does in it and whether it ends with the
/// seller. Vertical at every width, so a phone draws the same diagram as a
/// desktop rather than a squeezed one.
class GuideDiagram extends StatelessWidget {
  const GuideDiagram({super.key, required this.steps});

  final GuideSteps steps;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    if (steps.isEmpty) {
      return Text(
        l.guideNothing,
        style: Style.preview.copyWith(color: colors.muted),
      );
    }

    // "Always" first: it applies before any situation does.
    final rules = [
      ...steps.rules.where((r) => r.when == null),
      ...steps.rules.where((r) => r.when != null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colors.night,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline, size: 15, color: colors.onNight),
              const SizedBox(width: 8),
              Text(
                l.guideStart,
                style: Style.name.copyWith(color: colors.onNight),
              ),
            ],
          ),
        ),
        for (var i = 0; i < rules.length; i++)
          _Branch(rule: rules[i], last: i == rules.length - 1),
        if (steps.cannot.isNotEmpty) ...[
          const SizedBox(height: 22),
          _Cannot(items: steps.cannot),
        ],
      ],
    );
  }
}

/// One situation, hung off the trunk with an elbow.
class _Branch extends StatelessWidget {
  const _Branch({required this.rule, required this.last});

  final GuideRule rule;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: CustomPaint(
              painter: _Elbow(
                color: colors.edge,
                last: last,
                direction: Directionality.of(context),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rule.when == null)
                      Text(
                        l.guideAlways,
                        style: Style.name.copyWith(color: colors.ink),
                      )
                    else
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${l.guideWhen} ',
                              style: Style.name.copyWith(color: colors.muted),
                            ),
                            TextSpan(
                              text: rule.when,
                              style: Style.name.copyWith(color: colors.ink),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (var i = 0; i < rule.actions.length; i++) ...[
                          if (i > 0) _Arrow(color: colors.muted),
                          _Step(
                            text: rule.actions[i],
                            fill: colors.raised,
                            ink: colors.ink,
                            edge: colors.assistant,
                          ),
                        ],
                        if (rule.handover) ...[
                          if (rule.actions.isNotEmpty)
                            _Arrow(color: colors.muted),
                          _Step(
                            text: l.guideHandover,
                            fill: colors.accentSoft,
                            ink: colors.accent,
                            edge: colors.accent,
                            icon: Icons.person_outline,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.text,
    required this.fill,
    required this.ink,
    required this.edge,
    this.icon,
  });

  final String text;
  final Color fill;
  final Color ink;
  final Color edge;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
        border: BorderDirectional(start: BorderSide(color: edge, width: 3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: ink),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              // The reading is in the seller's language, which need not be the
              // interface's.
              textDirection: directionOf(text),
              style: Style.preview.copyWith(color: ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.color});
  final Color color;

  // arrow_forward mirrors itself in a right-to-left layout.
  @override
  Widget build(BuildContext context) =>
      Icon(Icons.arrow_forward, size: 15, color: color);
}

class _Cannot extends StatelessWidget {
  const _Cannot({required this.items});

  final List<({String text, String why})> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.saffronSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block, size: 16, color: colors.ink),
              const SizedBox(width: 8),
              Text(
                l.guideCannot,
                style: Style.name.copyWith(color: colors.ink),
              ),
            ],
          ),
          for (final item in items) ...[
            const SizedBox(height: 8),
            Text(
              item.why.isEmpty ? item.text : '${item.text} — ${item.why}',
              textDirection: directionOf(item.text),
              style: Style.preview.copyWith(color: colors.ink, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// The trunk and the elbow into one branch. The trunk stops at the last
/// branch rather than running on past it.
class _Elbow extends CustomPainter {
  _Elbow({required this.color, required this.last, required this.direction});

  final Color color;
  final bool last;
  final TextDirection direction;

  static const _y = 32.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rtl = direction == TextDirection.rtl;
    final x = rtl ? size.width - 14 : 14.0;
    final end = rtl ? 0.0 : size.width;

    canvas.drawLine(Offset(x, 0), Offset(x, last ? _y : size.height), paint);
    canvas.drawLine(Offset(x, _y), Offset(end, _y), paint);
  }

  @override
  bool shouldRepaint(_Elbow old) =>
      old.color != color || old.last != last || old.direction != direction;
}
