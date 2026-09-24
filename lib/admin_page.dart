// The owner's view of the whole service, inside the app.
//
// Everything a person running Rabta needs to answer "is it working, and for
// whom" without a terminal: whether Meta is still delivering, what failed,
// every seller with their accounts and activity, what the assistant costs, and
// the errors sellers hit on their own screens.
//
// One call, admin_overview, which refuses anyone who is not an admin in the
// database itself. This screen only decides whether to draw the door.

import 'package:flutter/material.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'accounts_page.dart';
import 'data.dart';
import 'invite_page.dart';
import 'locale_switch.dart';
import 'strings.dart';
import 'theme.dart';

/// admin_overview's answer, read into what the screen draws.
class AdminOverview {
  AdminOverview(this.raw);

  final Map<String, dynamic> raw;

  Map<String, dynamic> get health => Map<String, dynamic>.from(raw['health'] as Map? ?? {});
  List<Map<String, dynamic>> _list(String key) =>
      [for (final e in (raw[key] as List?) ?? const []) Map<String, dynamic>.from(e as Map)];
  List<Map<String, dynamic>> get sellers => _list('sellers');
  List<Map<String, dynamic>> get events => _list('events');
  List<Map<String, dynamic>> get clientErrors => _list('client_errors');

  int count(String key) {
    final value = health[key];
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }
  /// Postgres numeric can arrive as a number or as text; either is read.
  double get aiCostMonth {
    final value = health['ai_cost_month'];
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }
}

/// What needs the owner's attention, as health keys, most serious first.
/// Empty means everything is working.
///
/// A message that gave up after five tries, or an account that stopped
/// receiving, is a customer nobody will hear from; those lead. Errors and
/// screen errors follow. Warnings alone are not a problem — a hand-over is a
/// warning-free info event, and a single refused reply is normal.
List<String> healthProblems(AdminOverview o) => [
      for (final key in const [
        'stuck',
        'accounts_need_reconnect',
        'failing',
        'errors_24h',
        'client_errors_24h',
      ])
        if (o.count(key) > 0) key,
    ];

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.inbox, this.asHome = false});

  final Inbox inbox;

  /// The first screen, for an admin who has connected no accounts of their
  /// own. An owner running the service need not sell through it, and the
  /// "connect your account" screen alone left them with nothing (reported by
  /// the product owner, 25 September 2026). As home it has no back arrow, and
  /// carries what the inbox header otherwise would: the language, a way to
  /// connect an account after all, and signing out.
  final bool asHome;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Future<AdminOverview> _overview = _load();

  Future<AdminOverview> _load() async => AdminOverview(await widget.inbox.adminOverview());

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        elevation: 0,
        title: Text(l.adminTitle, style: Style.heading.copyWith(color: colors.ink)),
        iconTheme: IconThemeData(color: colors.ink),
        shape: Border(bottom: BorderSide(color: colors.edge)),
        automaticallyImplyLeading: !widget.asHome,
        actions: [
          if (widget.asHome) ...[
            const LocaleSwitch(compact: true),
            IconButton(
              tooltip: l.accounts,
              icon: const Icon(Icons.link, size: 19),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => AccountsPage(inbox: widget.inbox)),
              ),
            ),
          ],
          IconButton(
            tooltip: l.adminInvite,
            icon: const Icon(Icons.person_add_alt, size: 19),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => InvitePage(inbox: widget.inbox)),
            ),
          ),
          IconButton(
            tooltip: l.adminRefresh,
            icon: const Icon(Icons.refresh, size: 19),
            onPressed: () => setState(() => _overview = _load()),
          ),
          if (widget.asHome)
            IconButton(
              tooltip: l.signOut,
              icon: const Icon(Icons.logout, size: 18),
              onPressed: () => Supabase.instance.client.auth.signOut(),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<AdminOverview>(
        future: _overview,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${l.adminFailed}\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: Style.preview.copyWith(color: colors.muted, height: 1.6),
                ),
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

          final o = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              final next = _load();
              setState(() => _overview = next);
              await next;
            },
            child: Align(
              alignment: AlignmentDirectional.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    _Health(overview: o),
                    _Section(l.adminSellers),
                    for (final s in o.sellers) _Seller(seller: s),
                    _Section(l.adminEvents),
                    if (o.events.isEmpty) _Muted(l.adminNoEvents),
                    for (final e in o.events) _Event(event: e),
                    _Section(l.adminScreenErrors),
                    if (o.clientErrors.isEmpty) _Muted(l.adminNoScreenErrors),
                    for (final e in o.clientErrors) _ClientError(error: e),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _label(BuildContext context, String key) {
  final l = context.l;
  return switch (key) {
    'stuck' => l.adminStuck,
    'accounts_need_reconnect' => l.adminReconnect,
    'failing' => l.adminFailing,
    'errors_24h' => l.adminErrors,
    'client_errors_24h' => l.adminClientErrors,
    'warnings_24h' => l.adminWarnings,
    'unprocessed' => l.adminUnprocessed,
    'ai_calls_month' => l.adminAiCalls,
    _ => key,
  };
}

DateTime? _time(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

class _Health extends StatelessWidget {
  const _Health({required this.overview});
  final AdminOverview overview;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final problems = healthProblems(overview);
    final ok = problems.isEmpty;
    final tint = ok ? colors.won : colors.urgent;
    final last = _time(overview.health['last_delivery_at']);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: BorderDirectional(start: BorderSide(color: tint, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.check_circle_outline : Icons.error_outline, color: tint, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok ? l.adminAllGood : l.adminProblems,
                  style: Style.name.copyWith(color: tint, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          for (final p in problems)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 28, top: 6),
              child: Text(
                '${_label(context, p)}: ${overview.count(p)}',
                style: Style.preview.copyWith(color: colors.ink),
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _Figure(l.adminLastDelivery, last == null ? l.adminNever : waitedFor(context, last)),
              _Figure(l.adminUnprocessed, '${overview.count('unprocessed')}'),
              _Figure(l.adminWarnings, '${overview.count('warnings_24h')}'),
              _Figure(l.adminAiCost, '\$${overview.aiCostMonth.toStringAsFixed(2)}'),
              _Figure(l.adminAiCalls, '${overview.count('ai_calls_month')}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: Style.name.copyWith(color: colors.ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: Style.meta.copyWith(color: colors.muted)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 10),
        child: Text(text, style: Style.groupLabel.copyWith(color: context.rabta.muted)),
      );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Style.meta.copyWith(color: context.rabta.muted));
}

class _Seller extends StatelessWidget {
  const _Seller({required this.seller});
  final Map<String, dynamic> seller;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final s = seller;
    final accounts = [for (final a in (s['accounts'] as List?) ?? const []) Map<String, dynamic>.from(a as Map)];
    final lastMessage = _time(s['last_message_at']);
    final lastSignIn = _time(s['last_sign_in_at']);
    final cost = double.tryParse('${s['ai_cost_month']}') ?? 0;

    String status(String? value) => switch (value) {
          'active' => l.adminStatusActive,
          'needs_reconnect' => l.adminStatusReconnect,
          _ => l.adminStatusOff,
        };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    '${s['email'] ?? '—'}',
                    textAlign: Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left,
                    style: Style.name.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (s['admin'] == true)
                Container(
                  margin: const EdgeInsetsDirectional.only(start: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(l.adminYou, style: Style.meta.copyWith(color: colors.accent)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (accounts.isEmpty) _Muted(l.adminNoAccounts),
              for (final a in accounts)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: a['status'] == 'active' ? colors.line : colors.urgent,
                    ),
                  ),
                  child: Text(
                    '${platformName(context, '${a['platform']}')} · ${a['name'] ?? ''} · ${status(a['status'] as String?)}',
                    style: Style.meta.copyWith(
                      color: a['status'] == 'active' ? colors.ink : colors.urgent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              _Figure(l.adminConversations, '${s['conversations'] ?? 0}'),
              _Figure(l.adminMessages7d, '${s['messages_7d'] ?? 0}'),
              _Figure(l.adminLastMessage, lastMessage == null ? '—' : waitedFor(context, lastMessage)),
              _Figure(l.adminLastSignIn, lastSignIn == null ? '—' : waitedFor(context, lastSignIn)),
              _Figure(l.adminProducts, '${s['products'] ?? 0}'),
              _Figure(l.adminAssistant, s['assistant_on'] == true ? l.adminOn : l.adminOff),
              _Figure(l.adminAiReplies, '${s['ai_replies_month'] ?? 0}'),
              _Figure(l.adminAiCost, '\$${cost.toStringAsFixed(2)}'),
              _Figure(l.adminHandedOver, '${s['handed_over'] ?? 0}'),
              _Figure(l.adminOrdered, '${s['ordered_month'] ?? 0}'),
            ],
          ),
        ],
      ),
    );
  }
}

/// One line from ops_log. Event names are the service's own, in English on
/// purpose: they are what the function logs say too, so the two can be matched.
class _Event extends StatelessWidget {
  const _Event({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final e = event;
    final ambient = Directionality.of(context);
    final level = '${e['level']}';
    final tint = switch (level) {
      'error' => colors.urgent,
      'warn' => colors.accent,
      _ => colors.muted,
    };
    final at = _time(e['at']);
    final detail = e['detail'];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: tint, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${e['event']}  ·  ${e['source']}${e['email'] != null ? '  ·  ${e['email']}' : ''}',
                    style: Style.meta.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // The time in the interface's own direction: the row is forced
                // left to right for the service's names, and "7 د" read "د 7".
                if (at != null)
                  Text(
                    waitedFor(context, at),
                    textDirection: ambient,
                    style: Style.meta.copyWith(color: colors.muted),
                  ),
              ],
            ),
            if (detail is Map && detail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 3),
                child: SelectableText(
                  detail.entries.map((d) => '${d.key}: ${d.value}').join('   '),
                  style: Style.meta.copyWith(color: colors.muted, fontSize: 11),
                  maxLines: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClientError extends StatelessWidget {
  const _ClientError({required this.error});
  final Map<String, dynamic> error;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final ambient = Directionality.of(context);
    final at = _time(error['at']);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${error['email'] ?? '—'}  ·  ${error['url'] ?? ''}  ·  ${error['app_version'] ?? ''}',
                    style: Style.meta.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // The time in the interface's own direction: the row is forced
                // left to right for the service's names, and "7 د" read "د 7".
                if (at != null)
                  Text(
                    waitedFor(context, at),
                    textDirection: ambient,
                    style: Style.meta.copyWith(color: colors.muted),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            SelectableText(
              '${error['message']}',
              style: Style.meta.copyWith(color: colors.urgent, fontSize: 11),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}
