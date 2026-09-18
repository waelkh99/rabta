// Choosing a password, after arriving from an invitation.
//
// Rabta has no public sign-up. An account is created by inviting someone, and
// the invitation link brings them here already signed in but with no password
// of their own. Without this screen that session is the only way they will ever
// get in: it expires, and then the account is unreachable.
//
// The same screen serves a password reset, because the link works the same way.
// Nothing sends a reset email yet.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'locale_switch.dart';
import 'strings.dart';
import 'theme.dart';
import 'wordmark.dart';

/// Supabase accepts six. Eight is asked for here because this password opens
/// other people's customer conversations.
const _minimumLength = 8;

class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({
    super.key,
    required this.onDone,
    this.returning = false,
  });

  /// Called once the password is saved and the account is usable.
  final VoidCallback onDone;

  /// A reset rather than an invitation, which wants different words.
  final bool returning;

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _password = TextEditingController();
  bool _visible = false;
  bool _saving = false;
  String? _problem;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;

    if (password.length < _minimumLength) {
      setState(() => _problem = context.l.passwordTooShort);
      return;
    }

    setState(() {
      _saving = true;
      _problem = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (mounted) widget.onDone();
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          // An invitation that sat in an inbox too long. Saying so is the
          // difference between asking us for a new link and giving up.
          _problem = error.statusCode == '401' || error.statusCode == '403'
              ? context.l.inviteExpired
              : context.l.setPasswordFailed(error.message);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _problem = context.l.setPasswordFailed('$error'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wordmark(size: 30),
                  const SizedBox(height: 36),
                  Text(
                    l.setPasswordTitle,
                    style: Style.heading.copyWith(color: colors.ink),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.returning ? l.setPasswordRenew : l.setPasswordWelcome,
                    style:
                        Style.preview.copyWith(color: colors.muted, height: 1.6),
                  ),
                  const SizedBox(height: 28),

                  // One field with a reveal, rather than asking for it twice.
                  // A seller can see what they typed, which is what a second
                  // box is really for.
                  //
                  // In an AutofillGroup with newPassword, so the browser offers
                  // to save it — otherwise they set a password here and have
                  // nothing to autofill next time.
                  AutofillGroup(
                    child: TextField(
                      controller: _password,
                      obscureText: !_visible,
                      autofocus: true,
                      autofillHints: const [AutofillHints.newPassword],
                      onSubmitted: (_) => _save(),
                      style: Style.message.copyWith(color: colors.ink),
                      cursorColor: colors.accent,
                      decoration: InputDecoration(
                        labelText: l.newPasswordLabel,
                        labelStyle:
                            Style.preview.copyWith(color: colors.muted),
                        floatingLabelStyle:
                            Style.meta.copyWith(color: colors.accent),
                        // The rule is stated up front, and the same slot
                        // carries the complaint when it is broken. Shown as a
                        // separate line instead, a rejected password printed
                        // the identical sentence twice, which reads as a fault
                        // in the screen rather than an answer to the seller.
                        helperText: l.passwordTooShort,
                        helperStyle: Style.meta.copyWith(color: colors.muted),
                        errorText: _problem,
                        errorStyle: Style.meta.copyWith(color: colors.urgent),
                        errorMaxLines: 3,
                        filled: true,
                        fillColor: colors.surface,
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _visible = !_visible),
                          icon: Icon(
                            _visible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 19,
                          ),
                          color: colors.muted,
                          tooltip:
                              _visible ? l.hidePassword : l.showPassword,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        border: _border(colors.line),
                        enabledBorder: _border(colors.line),
                        focusedBorder: _border(colors.accent, 1.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: colors.onAccent,
                        disabledBackgroundColor: colors.accentSoft,
                        disabledForegroundColor: colors.muted,
                        textStyle: Style.name,
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                      ),
                      child: Text(
                        _saving ? l.setPasswordSaving : l.setPasswordAction,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  // The same reasoning as the sign-in screen: being unable to
                  // read this one is a failure a seller cannot click past.
                  Row(
                    children: [
                      Text(
                        l.language,
                        style: Style.meta.copyWith(color: colors.muted),
                      ),
                      const SizedBox(width: 10),
                      const LocaleSwitch(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

OutlineInputBorder _border(Color color, [double width = 1]) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: color, width: width),
    );
