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

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? colors.raised : null,
        padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 24, 14),
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
          ],
        ),
      ),
    );
  }
}
