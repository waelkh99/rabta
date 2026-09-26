// Creating an account for a seller.
//
// Rabta has no public sign-up, so this is the only door into the product, and
// it is ours rather than a seller's. The button is only drawn for an admin —
// but that is presentation and nothing more. Whether an invitation is actually
// created is decided on the server, from the user's own record, and this file
// could be rewritten by anyone with the browser open without changing it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';
import 'l10n/app_localizations.dart';
import 'strings.dart';
import 'theme.dart';

/// Matches ADMIN_FLAG in supabase/functions/admin-invite/admin.ts.
const _adminFlag = 'rabta_admin';

/// Whether to offer this account the invite screen at all.
///
/// Read from `app_metadata`, which a user cannot write to — `user_metadata` is
/// theirs to change. Strictly `true`, for the same reason the server is strict:
/// a truthy string would otherwise do.
bool signedInUserIsAdmin() {
  final user = Supabase.instance.client.auth.currentUser;
  return user?.appMetadata[_adminFlag] == true;
}

/// The way in, drawn only for an admin and nothing at all for anyone else.
class InviteButton extends StatelessWidget {
  const InviteButton({super.key, required this.inbox, this.onDark = false});

  final Inbox inbox;

  /// On the menu's dark panel.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (!signedInUserIsAdmin()) return const SizedBox.shrink();

    final colors = context.rabta;

    return IconButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => InvitePage(inbox: inbox)),
      ),
      icon: const Icon(Icons.person_add_alt, size: 17),
      color: onDark ? colors.onNight : colors.muted,
      tooltip: context.l.invite,
      visualDensity: VisualDensity.compact,
    );
  }
}

class InvitePage extends StatefulWidget {
  const InvitePage({super.key, required this.inbox});

  final Inbox inbox;

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  final _email = TextEditingController();
  bool _creating = false;
  String? _problem;

  /// Who was invited, once they have been; and the link, when it has to be
  /// sent by hand rather than having been emailed.
  String? _invited;
  String? _link;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating) return;

    final email = _email.text.trim();

    setState(() {
      _creating = true;
      _problem = null;
    });

    try {
      final link = await widget.inbox.invite(email);
      if (mounted) {
        setState(() {
          _link = link;
          _invited = email;
        });
      }
    } on InviteFailed catch (error) {
      if (mounted) setState(() => _problem = _sentence(context.l, error.reason));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  /// The server answers with a code so the language is chosen here, like every
  /// other sentence in the product.
  String _sentence(L l, String reason) => switch (reason) {
        'not_admin' => l.inviteFailedNotAdmin,
        'already_exists' => l.inviteFailedExists,
        'invalid_email' => l.inviteFailedInvalid,
        'empty_email' => l.inviteFailedEmpty,
        _ => l.inviteFailedOther,
      };

  Future<void> _copy() async {
    final link = _link;
    if (link == null) return;

    await Clipboard.setData(ClipboardData(text: link));

    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(context.l.linkCopied),
          backgroundColor: context.rabta.accent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Scaffold(
      backgroundColor: colors.ground,
      appBar: AppBar(
        title: Text(l.inviteTitle),
        shape: Border(bottom: BorderSide(color: colors.edge)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _invited == null
                  ? _form(colors, l)
                  : _link == null
                      ? _sent(colors, l)
                      : _ready(colors, l),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(RabtaColors colors, L l) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.inviteBody,
            style: Style.preview.copyWith(color: colors.muted, height: 1.6),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            enabled: !_creating,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            // Not an autofill hint: this is somebody else's address, and
            // offering the seller their own saved email here is wrong.
            onSubmitted: (_) => _create(),
            style: Style.message.copyWith(color: colors.ink),
            cursorColor: colors.accent,
            // An address is always written left to right, whatever the
            // interface language is doing around it.
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l.emailLabel,
              labelStyle: Style.preview.copyWith(color: colors.muted),
              floatingLabelStyle: Style.meta.copyWith(color: colors.accent),
              errorText: _problem,
              errorStyle: Style.meta.copyWith(color: colors.urgent),
              errorMaxLines: 3,
              filled: true,
              fillColor: colors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              border: _border(colors.line),
              enabledBorder: _border(colors.line),
              focusedBorder: _border(colors.accent, 1.5),
              disabledBorder: _border(colors.line),
            ),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              onPressed: _creating ? null : _create,
              style: _buttonStyle(colors),
              child: Text(_creating ? l.inviteCreating : l.inviteAction),
            ),
          ),
        ],
      );

  void _again() => setState(() {
        _link = null;
        _invited = null;
        _email.clear();
      });

  Widget _sent(RabtaColors colors, L l) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.saffron,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.mark_email_read_outlined, size: 19, color: colors.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.inviteSentTitle,
                  style: display(Style.heading.copyWith(color: colors.ink, fontSize: 18)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l.inviteSentBody(isolated(_invited ?? '')),
            style: Style.preview.copyWith(color: colors.muted, height: 1.6),
          ),
          const SizedBox(height: 20),
          TextButton(onPressed: _again, child: Text(l.inviteAnother)),
        ],
      );

  Widget _ready(RabtaColors colors, L l) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.inviteLinkTitle,
            style: Style.heading.copyWith(color: colors.ink),
          ),
          const SizedBox(height: 10),
          Text(
            l.inviteLinkBody(_invited ?? ''),
            style: Style.preview.copyWith(color: colors.muted, height: 1.6),
          ),
          const SizedBox(height: 18),

          // The link itself, selectable as well as copyable — a seller on a
          // machine where the clipboard misbehaves can still get it out.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(color: colors.line),
            ),
            child: SelectableText(
              _link!,
              textDirection: TextDirection.ltr,
              style: Style.meta.copyWith(color: colors.ink, height: 1.5),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton(
                onPressed: _copy,
                style: _buttonStyle(colors),
                child: Text(l.copyLink),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: _again,
                child: Text(
                  l.inviteAnother,
                  style: Style.name.copyWith(color: colors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 15, color: colors.muted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  l.inviteNoEmailYet,
                  style: Style.meta.copyWith(color: colors.muted, height: 1.5),
                ),
              ),
            ],
          ),
        ],
      );
}

ButtonStyle _buttonStyle(RabtaColors colors) => FilledButton.styleFrom(
      backgroundColor: colors.accent,
      foregroundColor: colors.onAccent,
      disabledBackgroundColor: colors.accentSoft,
      disabledForegroundColor: colors.muted,
      textStyle: Style.name,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.control)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
    );

OutlineInputBorder _border(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.control),
      borderSide: BorderSide(color: color, width: width),
    );
