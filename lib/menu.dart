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

import 'data.dart';
import 'invite_page.dart';
import 'strings.dart';
import 'theme.dart';
import 'wordmark.dart';

class AppMenu extends StatelessWidget {
  const AppMenu({
    super.key,
    required this.inbox,
    required this.onProducts,
    required this.onOffers,
    required this.onShop,
    required this.onAccounts,
    required this.onResults,
    this.onAdmin,
  });

  final Inbox inbox;
  final VoidCallback onProducts;
  final VoidCallback onOffers;
  final VoidCallback onShop;
  final VoidCallback onAccounts;
  final VoidCallback onResults;

  /// Only passed for an admin; the item is not drawn otherwise.
  final VoidCallback? onAdmin;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    // Night rather than surface: the one dark panel inside the app, so opening
    // the menu is unmistakably going somewhere else.
    return Drawer(
      backgroundColor: colors.night,
      // A square panel rather than a floating card with rounded corners: it
      // reads as part of the window, which is what it is.
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsetsDirectional.fromSTEB(24, 26, 24, 22),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wordmark(onDark: true),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 8),
              child: Text(
                l.menu,
                style: Style.groupLabel.copyWith(
                  color: colors.onNight.withValues(alpha: 0.55),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.inbox_outlined,
              label: l.inbox,
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            if (onAdmin != null)
              _MenuItem(
                icon: Icons.admin_panel_settings_outlined,
                label: l.admin,
                onTap: () {
                  Navigator.pop(context);
                  onAdmin!();
                },
              ),
            _MenuItem(
              icon: Icons.insights_outlined,
              label: l.results,
              onTap: () {
                Navigator.pop(context);
                onResults();
              },
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
              icon: Icons.percent,
              label: l.offers,
              onTap: () {
                Navigator.pop(context);
                onOffers();
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
            Divider(height: 1, color: colors.onNight.withValues(alpha: 0.12)),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
              child: InviteButton(inbox: inbox, onDark: true),
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

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;

  /// Null for a row that states something rather than doing something. InkWell
  /// takes that to mean disabled, so it also stops drawing a ripple — which is
  /// the right answer: a ripple promises an effect.
  final VoidCallback? onTap;

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    final text = selected ? colors.ink : colors.onNight;

    // The current place is a saffron pill: the same colour that marks the open
    // row in the list, so "where am I" has one answer everywhere.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? colors.saffron : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.control),
      hoverColor: colors.onNight.withValues(alpha: 0.06),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 13, 14, 13),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? colors.ink : colors.onNight.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: Style.name.copyWith(color: text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }
}
