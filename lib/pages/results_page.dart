// The last seven days: how conversations ended, and what to fix.
//
// Sentences and numbers first. A small shop has a few dozen conversations a
// week, and "3 customers went unanswered" says more than a chart of three.
// The one chart is the hours of the day, where the shape is the point.
//
// Everything here comes from outcome_summary, one call, scoped by row level
// security like every other read. See CLAUDE.md, "How conversations end".

import 'package:flutter/material.dart';

import '../data.dart';
import '../strings.dart';
import '../theme.dart';

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key, required this.inbox});

  final Inbox inbox;

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late Future<WeekSummary> _week = widget.inbox.week();

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        title: Text(l.resultsTitle),
        shape: Border(bottom: BorderSide(color: colors.edge)),
      ),
      body: FutureBuilder<WeekSummary>(
        future: _week,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.resultsFailed, style: Style.preview.copyWith(color: colors.muted)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _week = widget.inbox.week()),
                    child: Text(l.resultsRetry),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: colors.muted),
              ),
            );
          }

          final w = snapshot.data!;
          return Align(
            alignment: AlignmentDirectional.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: w.conversations == 0 ? [_Line(l.resultsNone)] : _sections(context, w),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _sections(BuildContext context, WeekSummary w) {
    final colors = context.rabta;
    final l = context.l;

    return [
      // The headline: how many conversations became orders.
      Text(
        l.resultsOrders(w.ordered, w.conversations),
        style: display(Style.title.copyWith(color: colors.ink, height: 1.35)),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Tile(label: l.outcomeOrdered, count: w.ordered, tint: colors.won),
          _Tile(label: l.outcomeNotBought, count: w.notBought, tint: colors.ink),
          _Tile(label: l.outcomeJustAsking, count: w.justAsking, tint: colors.ink),
          _Tile(label: l.outcomeOpen, count: w.open, tint: colors.muted),
        ],
      ),
      if (w.unanswered > 0) ...[
        const SizedBox(height: 16),
        _Callout(text: l.resultsUnanswered(w.unanswered)),
      ],

      if (w.reasons.isNotEmpty) ...[
        _Heading(l.resultsWhy),
        for (final r in w.reasons)
          _Bar(label: reasonLabel(l, r.key), count: r.value, max: w.reasons.first.value),
      ],

      if (w.products.isNotEmpty) ...[
        _Heading(l.resultsProducts),
        for (final p in w.products)
          _Row(
            title: p.name,
            detail: l.resultsProductLine(p.asked, p.ordered),
            highlight: p.ordered > 0,
          ),
      ],

      if (w.areas.isNotEmpty) ...[
        _Heading(l.resultsAreas),
        for (final a in w.areas)
          _Bar(label: a.name, count: a.count, max: w.areas.first.count),
      ],

      _Heading(l.resultsHours),
      if (w.busiestFrom != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            l.resultsBusiest(w.busiestFrom!, (w.busiestFrom! + 3) % 24),
            style: Style.preview.copyWith(color: colors.ink),
          ),
        ),
      _Hours(hours: w.hours),

      const SizedBox(height: 28),
      if (w.readByAssistant > 0) _Line(l.resultsAccuracy(w.readByAssistant, w.corrected)),
      _Line(l.resultsPending),
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 30, bottom: 12),
        child: Text(text, style: Style.groupLabel.copyWith(color: context.rabta.muted)),
      );
}

class _Line extends StatelessWidget {
  const _Line(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: Style.meta.copyWith(color: context.rabta.muted, height: 1.6)),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.count, required this.tint});
  final String label;
  final int count;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: colors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$count', style: display(Style.hero.copyWith(color: tint, fontSize: 30))),
          const SizedBox(height: 4),
          Text(label, style: Style.meta.copyWith(color: colors.muted)),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.urgent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.control),
        border: BorderDirectional(start: BorderSide(color: colors.urgent, width: 4)),
      ),
      child: Text(text, style: Style.preview.copyWith(color: colors.ink, height: 1.5)),
    );
  }
}

/// A label, a count, and a bar in proportion to the largest in its group.
class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.count, required this.max});
  final String label;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: Style.preview.copyWith(color: colors.ink)),
              ),
              Text('$count', style: Style.name.copyWith(color: colors.ink)),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, box) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                height: 6,
                width: max == 0 ? 0 : box.maxWidth * count / max,
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.detail, required this.highlight});
  final String title;
  final String detail;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Style.preview.copyWith(color: colors.ink))),
          const SizedBox(width: 12),
          Text(
            detail,
            style: Style.meta.copyWith(color: highlight ? colors.won : colors.muted),
          ),
        ],
      ),
    );
  }
}

/// Messages by hour of the day. Always midnight on the left and 24:00 on the
/// right, in both languages: a clock is not text, and a seller reading "21"
/// on the left in Arabic would have to work out which way time runs.
///
/// Seen in a browser and reported by the product owner as cut off: every bar
/// was drawn to full height with nothing above it and the axis stopped at
/// 18:00. The tallest bar now stops short of the top with its count above it,
/// and the axis runs the whole day.
class _Hours extends StatelessWidget {
  const _Hours({required this.hours});
  final List<int> hours;

  static const _chart = 64.0;
  static const _countRoom = 16.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final top = hours.fold<int>(0, (a, b) => b > a ? b : a);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, box) {
          final slot = box.maxWidth / 24;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: _chart + _countRoom,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var h = 0; h < 24; h++)
                      SizedBox(
                        width: slot,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1.5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (hours[h] > 0)
                                Text(
                                  '${hours[h]}',
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                  softWrap: false,
                                  style: Style.meta.copyWith(color: colors.muted, fontSize: 10),
                                ),
                              const SizedBox(height: 2),
                              Container(
                                height: top == 0 || hours[h] == 0
                                    ? 2
                                    : 4 + (_chart - 4) * 0.8 * hours[h] / top,
                                decoration: BoxDecoration(
                                  color: hours[h] == 0 ? colors.line : colors.accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 16,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final h in const [0, 6, 12, 18, 24])
                      Positioned(
                        left: h == 24 ? null : h * slot,
                        right: h == 24 ? 0 : null,
                        child: Text(
                          '$h:00',
                          style: Style.meta.copyWith(color: colors.muted),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
