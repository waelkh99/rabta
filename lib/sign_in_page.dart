// Signing in.
//
// Two fields and a button, in a frame that shows what is behind them. The form
// is still the only thing with a job; the rest is there so the first screen a
// seller sees looks like a product rather than a login box. There is no
// sign-up here because a workspace is created by the database trigger the
// moment an account exists.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'locale_switch.dart';
import 'platform_icon.dart';
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

      // Tells the browser the sign-in is finished, which is what prompts it to
      // offer to save or update the password. Without it a seller is never
      // asked, and never gets an autofill entry to use next time.
      TextInput.finishAutofillContext();
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
    final l = context.l;

    return AuthFrame(
      title: l.signInWelcome,
      body: l.signInWelcomeBody,
      // Both fields in one group, which on the web is what puts them in one
      // <form> in the page.
      //
      // Without it each field is its own throwaway form holding a single
      // input, and a browser password manager has no pair to fill: it sees a
      // lone email box and no password beside it. What a seller then gets is
      // the browser painting a value into a field the application never
      // receives — the box reads full and the button says the credentials are
      // wrong.
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthField(
              controller: _email,
              label: l.emailLabel,
              icon: Icons.alternate_email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 14),
            AuthField(
              controller: _password,
              label: l.passwordLabel,
              icon: Icons.lock_outline,
              obscure: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _signIn(),
            ),
            if (_problem != null) ...[
              const SizedBox(height: 14),
              AuthProblem(_problem!),
            ],
            const SizedBox(height: 24),
            AuthButton(
              label: _busy ? l.signingIn : l.signIn,
              onPressed: _busy ? null : _signIn,
            ),
          ],
        ),
      ),
    );
  }
}

/// The frame every signed-out screen sits in: the brand on one side, a stamped
/// card holding the form on the other. At phone width the brand becomes a band
/// across the top and the card overlaps its lower edge.
///
/// The language choice is at the top of the form side, not below the button:
/// being unable to read the screen is the one failure a seller cannot click
/// past, so the way out of it should be the first thing their eye finds.
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.title,
    required this.body,
    required this.child,
  });

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    final card = Stamp(
      radius: Radii.card,
      depth: 6,
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: display(Style.title.copyWith(fontSize: 26, color: colors.ink)),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: Style.preview.copyWith(color: colors.muted, fontSize: 14),
            ),
            const SizedBox(height: 26),
            child,
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: colors.ground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // On a narrow screen the brand is a band, not a column: the form must
          // not be pushed below the fold.
          if (constraints.maxWidth < 900) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandPanel(compact: true),
                  Transform.translate(
                    offset: const Offset(0, -40),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              card,
                              const SizedBox(height: 32),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: _Pitch(onDark: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final panel = (constraints.maxWidth * 0.46).clamp(420.0, 640.0);

          return Row(
            children: [
              SizedBox(width: panel, child: const _BrandPanel()),
              Expanded(
                child: SafeArea(
                  child: Stack(
                    children: [
                      Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 64,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: card,
                          ),
                        ),
                      ),
                      const PositionedDirectional(
                        top: 20,
                        end: 24,
                        child: LocaleSwitch(),
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

/// A field on a signed-out screen: filled, with an icon saying what it is.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      style: Style.message.copyWith(color: colors.ink),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: colors.muted),
        fillColor: colors.ground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}

/// What went wrong, under the fields.
class AuthProblem extends StatelessWidget {
  const AuthProblem(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 16, color: colors.urgent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Style.meta.copyWith(color: colors.urgent, height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// The one stamped thing on the screen, on the seller's own action.
class AuthButton extends StatelessWidget {
  const AuthButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Stamp(
      enabled: onPressed != null,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: const RoundedRectangleBorder(),
        ),
        child: Text(label),
      ),
    );
  }
}

/// The half of the sign-in screen that is not a form.
///
/// It shows the product rather than describing it: two inbox rows drawn with
/// the same marks the inbox uses — a customer asking a price the way customers
/// here actually write, answered automatically, and one the assistant handed
/// over. A seller who has looked at this has already learned what the inbox
/// will show them.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    final hero = Text(
      l.signInHero,
      style: display(
        Style.hero.copyWith(
          color: colors.onNight,
          fontSize: compact ? 28 : 46,
          height: 1.15,
        ),
      ),
    );

    return Container(
      color: colors.night,
      child: Stack(
        children: [
          // Two suns behind the rows: the only large areas of colour on the
          // screen, and the reason the panel does not read as a void.
          PositionedDirectional(
            end: compact ? -110 : -150,
            top: compact ? -80 : 110,
            child: _Disc(size: compact ? 260 : 440, color: colors.accent),
          ),
          PositionedDirectional(
            end: compact ? 14 : 36,
            top: compact ? 150 : 470,
            child: _Disc(size: compact ? 72 : 130, color: colors.saffron),
          ),
          Positioned.fill(child: CustomPaint(painter: DotGrid(colors.onNight, 0.09))),
          SafeArea(
            child: Padding(
              padding: compact
                  ? const EdgeInsets.fromLTRB(22, 18, 22, 64)
                  : const EdgeInsets.fromLTRB(56, 44, 56, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Row(
                    children: [
                      // Shrinks rather than overflowing: beside both language
                      // names on a 320px phone there is not room for it whole.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Wordmark(size: compact ? 24 : 28, onDark: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Spacer(),
                      if (compact)
                        const LocaleSwitch(compact: true, onDark: true),
                    ],
                  ),
                  if (compact) const SizedBox(height: 26) else const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: hero,
                  ),
                  SizedBox(height: compact ? 20 : 32),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: _PreviewRows(compact: compact),
                  ),
                  if (!compact) ...[
                    const Spacer(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: const _Pitch(onDark: true),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The three things the inbox is built around, numbered. On the dark panel at
/// desktop width; under the form on a phone, where the space would otherwise
/// be empty sand.
class _Pitch extends StatelessWidget {
  const _Pitch({required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, line) in [l.pitchOne, l.pitchTwo, l.pitchThree].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.saffron,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: display(
                      Style.name.copyWith(color: colors.ink, height: 1),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line,
                      style: Style.preview.copyWith(
                        fontSize: 14.5,
                        color: onDark
                            ? colors.onNight.withValues(alpha: 0.86)
                            : colors.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

/// Two inbox rows as a picture of the product.
///
/// One customer writes in Arabic and one in English, in both interface
/// languages: a seller receives both whichever language they read the
/// interface in, and the pair shows each message keeping its own direction.
/// Generic on purpose — any shop could have received them. They are sample
/// content, not interface text, which is why they are not in the localisation
/// files. The labels on them are.
class _PreviewRows extends StatelessWidget {
  const _PreviewRows({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;
    final l = context.l;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    Widget pill(String label, Color fill, IconData icon) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                label,
                style: Style.meta.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

    final first = _PreviewRow(
      name: 'سارة',
      text: 'مرحبا، كم السعر؟ وهل هو متوفر؟',
      platform: 'instagram',
      time: '11:42',
      rail: 0.9,
      tag: pill(l.sentAutomatically, colors.assistant, Icons.auto_awesome),
    );
    final second = _PreviewRow(
      name: 'Alex',
      text: 'Hi! Do you deliver to my area?',
      platform: 'messenger',
      time: '11:15',
      rail: 0.12,
      tag: pill(l.needsYou, colors.urgent, Icons.front_hand),
    );

    // On a phone both rows show only where the sign-in button still lands above
    // the fold; on a short screen the second would push it under.
    if (compact) {
      if (MediaQuery.sizeOf(context).height < 760) return first;
      return Column(children: [first, const SizedBox(height: 10), second]);
    }

    return Column(
      children: [
        first,
        const SizedBox(height: 12),
        Transform.translate(
          offset: Offset(rtl ? -28 : 28, 0),
          child: second,
        ),
      ],
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.name,
    required this.text,
    required this.platform,
    required this.time,
    required this.rail,
    required this.tag,
  });

  final String name;
  final String text;
  final String platform;
  final String time;
  final double rail;
  final Widget tag;

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Stamp(
      radius: 16,
      depth: 4,
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 42,
              margin: const EdgeInsetsDirectional.only(end: 10),
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: rail,
                child: Container(
                  decoration: BoxDecoration(
                    color: rail < 4 / 24 ? colors.urgent : colors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.saffronSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      String.fromCharCode(name.runes.first),
                      style: display(Style.monogram.copyWith(color: colors.ink)),
                    ),
                  ),
                  PositionedDirectional(
                    bottom: -3,
                    end: -4,
                    child: PlatformBadge(platform: platform),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: Style.name.copyWith(color: colors.ink),
                        ),
                      ),
                      Text(time, style: Style.meta.copyWith(color: colors.muted)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Directionality(
                    textDirection: directionOf(text),
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Style.preview.copyWith(color: colors.muted),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Align(alignment: AlignmentDirectional.centerStart, child: tag),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
