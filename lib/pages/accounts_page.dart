// The seller's connected Meta accounts.
//
// Two things live here. Connecting, which is the only thing a brand new seller
// can usefully do and so appears where the conversation list would be. And the
// list of what is connected, reached from the header, for adding a second
// account or turning one off later.
//
// None of this is something we can do for a seller. It runs on their own
// Facebook login and their own approval on Meta's asset screen — we never hold
// their credentials and Meta may refuse. So every step here has to say what
// happened in words they can act on.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../widgets/platform_icon.dart';
import '../strings.dart';
import '../theme.dart';

/// Sends the browser to Meta's approval page, in this tab.
///
/// The same tab on purpose: the callback redirects back to the application when
/// it is done, and a new tab would leave the seller looking at the old one
/// wondering whether it worked.
Future<void> startConnecting(BuildContext context, Inbox inbox) async {
  final l = context.l;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final colors = context.rabta;

  try {
    final url = await inbox.connectUrl();
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
  } on ConnectFailed catch (error) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          error.reason == 'not_signed_in'
              ? l.connectFailedSignedOut
              : l.connectFailed,
        ),
        backgroundColor: colors.urgent,
      ),
    );
  }
}

/// What fills the reading pane when the seller has connected nothing yet.
///
/// The inbox is empty and will stay empty until this is done, so it is the
/// only thing on the screen worth saying.
class ConnectPrompt extends StatefulWidget {
  const ConnectPrompt({super.key, required this.inbox});

  final Inbox inbox;

  @override
  State<ConnectPrompt> createState() => _ConnectPromptState();
}

class _ConnectPromptState extends State<ConnectPrompt> {
  bool _opening = false;

  Future<void> _connect() async {
    setState(() => _opening = true);
    await startConnecting(context, widget.inbox);
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Container(
      color: colors.ground,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.connectTitle, style: Style.heading.copyWith(color: colors.ink)),
            const SizedBox(height: 14),
            Text(
              l.connectBody,
              style: Style.preview.copyWith(color: colors.muted, height: 1.6),
            ),
            const SizedBox(height: 28),
            ConnectButton(onPressed: _opening ? null : _connect, busy: _opening),
          ],
        ),
      ),
    );
  }
}

/// The one accent on the screen, on the seller's own action.
class ConnectButton extends StatelessWidget {
  const ConnectButton({super.key, required this.onPressed, this.busy = false});

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l;

    return Stamp(
      enabled: onPressed != null,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
        ),
        child: Text(busy ? l.connectOpening : l.connectAction),
      ),
    );
  }
}

/// The list of what is connected, and what is not receiving any more.
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.inbox});

  final Inbox inbox;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late Future<List<Account>> _accounts = widget.inbox.accounts();
  String? _working;

  Future<void> _disconnect(Account account) async {
    final l = context.l;
    final colors = context.rabta;

    // Asked first, because it is not obvious from the outside that the
    // conversations survive it. Saying so is what makes the answer easy.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(l.disconnectTitle, style: Style.heading.copyWith(color: colors.ink)),
        content: Text(
          l.disconnectBody,
          style: Style.preview.copyWith(color: colors.muted, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel, style: Style.name.copyWith(color: colors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              l.disconnectConfirm,
              style: Style.name.copyWith(color: colors.urgent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _working = account.id);

    try {
      await widget.inbox.disconnect(account.id);
    } on ConnectFailed {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(context.l.connectFailed),
            backgroundColor: colors.urgent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = null;
          _accounts = widget.inbox.accounts();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        title: Text(l.accounts),
        shape: Border(bottom: BorderSide(color: colors.edge)),
      ),
      body: FutureBuilder<List<Account>>(
        future: _accounts,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: colors.muted,
                ),
              ),
            );
          }

          // A link the seller stopped leaves this list. Its conversations stay
          // in the inbox, and connecting it again brings it back. (The inbox
          // still counts it, so stopping every link does not hide the past
          // behind the first-run screen.)
          final accounts =
              snapshot.data!.where((a) => a.status != 'disconnected').toList();

          // A column rather than the whole window. Left to stretch, a row put
          // its name and its Turn off control a thousand pixels apart on a
          // wide screen, which stops reading as one row.
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Align(
                // Start, not centre: it lines up under the title rather than
                // drifting into the middle of a wide window on its own.
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
              Text(
                l.accountsBody,
                style: Style.preview.copyWith(color: colors.muted),
              ),
              const SizedBox(height: 24),
              for (final account in accounts)
                _AccountRow(
                  account: account,
                  busy: _working == account.id,
                  onDisconnect: () => _disconnect(account),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConnectButton(
                  onPressed: () => startConnecting(context, widget.inbox),
                ),
              ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.account,
    required this.busy,
    required this.onDisconnect,
  });

  final Account account;
  final bool busy;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    final (label, tone) = switch (account.status) {
      'needs_reconnect' => (l.accountNeedsReconnect, colors.urgent),
      'disconnected' => (l.accountDisconnected, colors.muted),
      _ => (l.accountActive, colors.muted),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          PlatformIcon(platform: account.platform, size: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name ?? platformName(context, account.platform),
                  style: Style.name.copyWith(color: colors.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(label, style: Style.meta.copyWith(color: tone)),
              ],
            ),
          ),
          if (account.receiving || account.status == 'needs_reconnect')
            TextButton(
              onPressed: busy ? null : onDisconnect,
              child: Text(
                l.disconnect,
                style: Style.meta.copyWith(
                  color: busy ? colors.muted : colors.urgent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
