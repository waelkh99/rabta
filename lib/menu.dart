// Where the seller goes when they are not reading messages.
//
// The inbox is the product and everything else is somewhere you visit and come
// back from, so the menu lives on the inbox and the other screens carry a back
// arrow. One way in, one way out, and no question about where you are.
//
// It replaces a row of unlabelled icons in the list header. Three icons a
// seller has to hover to identify is three guesses a day; a named list is
// none.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alerts.dart';
import 'data.dart';
import 'invite_page.dart';
import 'strings.dart';
import 'theme.dart';

class AppMenu extends StatelessWidget {
  const AppMenu({
    super.key,
    required this.inbox,
    required this.onProducts,
    required this.onShop,
    required this.onAccounts,
  });

  final Inbox inbox;
  final VoidCallback onProducts;
  final VoidCallback onShop;
  final VoidCallback onAccounts;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Drawer(
      backgroundColor: colors.surface,
      // A square panel rather than a floating card with rounded corners: it
      // reads as part of the window, which is what it is.
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 22, 24, 18),
              child: Text(
                l.menu,
                style: Style.groupLabel.copyWith(color: colors.muted),
              ),
            ),
            _MenuItem(
              icon: Icons.inbox_outlined,
              label: l.inbox,
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            _MenuItem(
              icon: Icons.sell_outlined,
              label: l.products,
              onTap: () {
                Navigator.pop(context);
                onProducts();
              },
            ),
            _MenuItem(
              icon: Icons.storefront_outlined,
              label: l.shop,
              onTap: () {
                Navigator.pop(context);
                onShop();
              },
            ),
            _MenuItem(
              icon: Icons.link,
              label: l.accounts,
              onTap: () {
                Navigator.pop(context);
                onAccounts();
              },
            ),
            const Spacer(),
            Divider(height: 1, color: colors.line),
            const _AlertsItem(),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
              child: InviteButton(inbox: inbox),
            ),
            _MenuItem(
              icon: Icons.logout,
              label: l.signOut,
              onTap: () {
                Navigator.pop(context);
                Supabase.instance.client.auth.signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Turning system notifications on, which cannot be done anywhere else.
///
/// Every browser requires the permission prompt to come from something the
/// seller did, so there has to be a thing to tap. It lives here rather than as
/// a strip above the inbox or a dialog on load: the menu is already the place
/// the seller goes when they are not reading messages, and a prompt that
/// appears by itself is the pattern browsers now punish by refusing it before
/// anyone sees it.
///
/// The row states what is true rather than offering a switch in every case.
/// Refused once, no browser will ask again — a button that silently does
/// nothing would be worse than a sentence saying so. And in a Safari tab on an
/// iPhone the API is absent entirely, which is not a refusal and must not read
/// as a fault: the seller has to add Rabta to their home screen first.
class _AlertsItem extends StatefulWidget {
  const _AlertsItem();

  @override
  State<_AlertsItem> createState() => _AlertsItemState();
}

class _AlertsItemState extends State<_AlertsItem> {
  late AlertState _state = alertState();
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;

    if (_state == AlertState.on) {
      turnAlertsOff();
      setState(() => _state = alertState());
      return;
    }

    // Asking the browser can take as long as the seller takes to read the
    // prompt, and the switch must not look stuck or accept a second tap while
    // it does.
    setState(() => _busy = true);
    final next = await turnAlertsOn();
    if (mounted) {
      setState(() {
        _state = next;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    // Two of the four states are not a choice. A switch beside them would be
    // a control that cannot move, which is worse than no control: the sentence
    // is the whole answer.
    final choosable = _state == AlertState.on || _state == AlertState.off;
    final on = _state == AlertState.on;

    return _MenuItem(
      icon: on ? Icons.notifications_active_outlined : Icons.notifications_none,
      label: alertStateLabel(l, _state),
      onTap: choosable && !_busy ? _toggle : null,
      trailing: choosable
          ? Switch(
              value: on,
              // The row is the target; the switch follows it. Two separate hit
              // areas on one row is two ways to do the same thing and one of
              // them always feels broken.
              onChanged: _busy ? null : (_) => _toggle(),
              activeThumbColor: colors.accent,
            )
          : null,
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final IconData icon;
  final String label;

  /// A control at the end of the row, for the one item that is a setting
  /// rather than a destination.
  final Widget? trailing;

  /// Null for a row that states something rather than doing something. InkWell
  /// takes that to mean disabled, so it also stops drawing a ripple — which is
  /// the right answer: a ripple promises an effect.
  final VoidCallback? onTap;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? colors.raised : null,
        padding: EdgeInsetsDirectional.fromSTEB(24, trailing == null ? 14 : 4, 24, trailing == null ? 14 : 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? colors.accent : colors.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Style.name.copyWith(
                  color: selected ? colors.accent : colors.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
