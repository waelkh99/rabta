// Signing in.
//
// One screen, two fields, nothing else. This is not where a seller wants to
// spend attention, and there is no sign-up here because a workspace is created
// by the database trigger the moment an account exists.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'locale_switch.dart';
import 'strings.dart';
import 'theme.dart';
import 'wordmark.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _problem;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _problem = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _problem = error.message.contains('Invalid login')
            ? context.l.signInWrongCredentials
            : context.l.signInFailed(error.message));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _problem = context.l.signInFailed('$error'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    Widget buildForm({required bool withHeading}) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Only when the panel is not already saying it. Repeating the
                // name and the tagline a hand's width apart reads as a mistake.
                if (withHeading) ...[
                  const Wordmark(size: 34),
                  const SizedBox(height: 14),
                  Text(
                    l.tagline,
                    style: Style.preview.copyWith(color: colors.muted),
                  ),
                  const SizedBox(height: 44),
                ],
                _Field(
                  controller: _email,
                  label: l.emailLabel,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 20),
                _Field(
                  controller: _password,
                  label: l.passwordLabel,
                  obscure: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _signIn(),
                ),
                if (_problem != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    _problem!,
                    style: Style.meta.copyWith(color: colors.urgent),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  // The one accent, on the seller's own action.
                  child: FilledButton(
                    onPressed: _busy ? null : _signIn,
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
                    child: Text(_busy ? l.signingIn : l.signIn),
                  ),
                ),
                const SizedBox(height: 28),
                // The language choice belongs on this screen: being unable to
                // read it is the one failure a seller cannot click past.
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
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // On a narrow screen the panel would push the form below the fold, so
          // it is dropped rather than stacked. The form is the job here.
          if (constraints.maxWidth < 900) {
            return SafeArea(child: buildForm(withHeading: true));
          }

          // A share of the width rather than half of it, and capped: at 50%
          // the panel became a wall of purple on a wide monitor, and the form
          // — the only thing on this screen with a job — drifted to the far
          // edge. Clamped so it does not collapse on a small laptop either.
          final panel = (constraints.maxWidth * 0.34).clamp(340.0, 460.0);

          return Row(
            children: [
              SizedBox(width: panel, child: const _BrandPanel()),
              Expanded(
                child: SafeArea(child: buildForm(withHeading: false)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The half of the sign-in screen that is not a form.
///
/// It says what the product does, in three lines that are the three decisions
/// the inbox is built around — one inbox, longest wait first, and the reply
/// window. Not a feature list: a seller reading this has already decided to
/// sign in, so it is there to tell them what they are about to see.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Container(
      color: colors.accent,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wordmark(size: 34, onAccent: true),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(
              l.tagline,
              style: Style.message.copyWith(
                fontSize: 17,
                color: colors.onAccent.withValues(alpha: 0.88),
              ),
            ),
          ),
          const SizedBox(height: 44),
          for (final line in [l.pitchOne, l.pitchTwo, l.pitchThree])
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsetsDirectional.only(top: 7, end: 12),
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.onAccent.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line,
                        style: Style.preview.copyWith(
                          fontSize: 14,
                          color: colors.onAccent.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    // A filled field rather than an outlined one: fewer lines on the screen,
    // and the fill is what separates it from the ground without a border.
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      style: Style.message.copyWith(color: colors.ink),
      cursorColor: colors.accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: Style.preview.copyWith(color: colors.muted),
        floatingLabelStyle: Style.meta.copyWith(color: colors.accent),
        filled: true,
        fillColor: colors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
      ),
    );
  }
}
