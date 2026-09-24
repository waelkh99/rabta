// Rabta — one inbox for Instagram and Facebook Messenger conversations.
//
// The Supabase URL and publishable key are supplied at build time rather than
// committed. The publishable key is designed to be public and is safe in a
// browser — row level security is what protects the data, not the key — but
// keeping it out of the repository means a key can be rotated without a commit.
//
// They live in env.json, which is not committed, and are passed with:
//
//   flutter run -d chrome --dart-define-from-file=env.json
//
// These are compile-time constants, so a build without them produces an
// application that cannot reach the database no matter what is in the
// environment at the time it runs. .vscode/launch.json passes the file, so
// starting a debug session from the editor already works.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'inbox_page.dart';
import 'l10n/app_localizations.dart';
import 'locale_switch.dart';
import 'reporting.dart';
import 'set_password_page.dart';
import 'sign_in_page.dart';
import 'theme.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// `?lang=ar` or `?lang=en` overrides what the browser asks for.
///
/// A seller's browser is often set to English on a machine they share or did
/// not configure, which is not the language they want to work in. The switch on
/// the sign-in screen is how they say so, and since 22 September the choice is
/// remembered — see `locale_switch.dart`. This stays because a link is still
/// the only way to open Rabta in a given language without touching the
/// interface first, which is what makes it useful for showing someone.
Locale? get _requestedLocale {
  final asked = Uri.base.queryParameters['lang'];
  return L.supportedLocales.where((l) => l.languageCode == asked).firstOrNull;
}

/// Why this browser was opened, according to the link that opened it.
///
/// An invitation arrives as `#access_token=...&type=invite`, which signs the
/// seller in with no password of their own. Read here, before
/// `Supabase.initialize`, because that consumes the fragment and clears it —
/// after which nothing distinguishes an invited seller from a returning one,
/// and they would be dropped into the inbox with an account they can never sign
/// into again.
String? _linkType;

String? _typeFromUrl() {
  final fragment = Uri.base.fragment;
  if (fragment.isEmpty || !fragment.contains('type=')) return null;

  try {
    return Uri.splitQueryString(fragment)['type'];
  } catch (_) {
    return null;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Western digits in Arabic too, as decided on 17 September. Flutter's own
  // date picker formats through intl, which uses Arabic-Indic digits for
  // Arabic by default — the picker showed "٢٢ سبتمبر ٢٠٢٦" above a grid of
  // 1 to 30. Found in the Playwright pass of 22 September.
  DateFormat.useNativeDigitsByDefaultFor('ar', false);

  _linkType = _typeFromUrl();

  if (_url.isEmpty || _key.isEmpty) {
    runApp(const RabtaApp(configured: false));
    return;
  }

  await Supabase.initialize(url: _url, publishableKey: _key);

  // After Supabase, because a report is written through it.
  reportUncaughtErrors();
  watchForNewVersion();

  runApp(const RabtaApp());
}

class RabtaApp extends StatelessWidget {
  const RabtaApp({super.key, this.configured = true});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    // Rebuilt when the seller picks a language, so the switch takes effect
    // where they pressed it rather than on the next reload.
    return ValueListenableBuilder<Locale?>(
      valueListenable: currentLocale,
      builder: (context, chosen, _) => _app(chosen),
    );
  }

  Widget _app(Locale? chosen) {
    return MaterialApp(
      onGenerateTitle: (context) => 'Rabta',
      debugShowCheckedModeBanner: false,
      theme: rabtaTheme(brightness: Brightness.light),

      // Arabic first. It is the language this product is for, so it is the
      // fallback when the browser asks for something we do not have, not an
      // alternative reached through a setting. Interface direction follows the
      // locale automatically, which is why no screen sets one by hand.
      supportedLocales: L.supportedLocales,
      localizationsDelegates: L.localizationsDelegates,
      // In order of how recently the seller said it: what they picked in this
      // tab, then the link that opened it, then what they picked on a previous
      // visit. A stale saved language must not override a `?lang=` somebody has
      // just been sent.
      locale: chosen ?? _requestedLocale ?? savedLocale,
      localeListResolutionCallback: (requested, supported) {
        for (final locale in requested ?? const <Locale>[]) {
          for (final candidate in supported) {
            if (candidate.languageCode == locale.languageCode) return candidate;
          }
        }
        return const Locale('ar');
      },

      home: configured ? const _AuthGate() : const _MissingConfiguration(),
      builder: (context, child) => Column(
        children: [
          Expanded(child: child ?? const SizedBox.shrink()),
          const _NewVersionBar(),
        ],
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  /// Set when the seller arrived on a link that hands them a session without a
  /// password: an invitation, or a reset. They go to the inbox only once they
  /// have chosen one, because the session they arrived on will expire and take
  /// the account with it.
  late bool _mustChoosePassword =
      _linkType == 'invite' || _linkType == 'recovery';

  bool get _returning => _linkType == 'recovery';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // A reset can also arrive as an event rather than in the URL.
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          _mustChoosePassword = true;
        }

        // currentSession rather than the stream event, so a restored session
        // shows the inbox immediately instead of flashing the sign-in screen.
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const SignInPage();

        if (_mustChoosePassword) {
          return SetPasswordPage(
            returning: _returning,
            onDone: () => setState(() {
              _mustChoosePassword = false;
              _linkType = null;
            }),
          );
        }

        return const InboxPage();
      },
    );
  }
}

/// Running without configuration is a developer's mistake, not a seller's, so
/// it names exactly what is missing rather than failing somewhere later.
/// "A new version is ready — Reload", once the deployed build differs from
/// the one this tab started with. At the bottom and quiet: the seller may be
/// mid-reply, and nothing here should take the page from them.
class _NewVersionBar extends StatelessWidget {
  const _NewVersionBar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: newerVersion,
      builder: (context, newer, _) {
        if (!newer) return const SizedBox.shrink();
        final colors = context.rabta;
        final l = L.of(context)!;
        return Material(
          color: colors.ink,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 6, 8, 6),
              child: Row(
                children: [
                  Icon(Icons.system_update_alt, size: 16, color: colors.surface),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l.newVersion, style: Style.meta.copyWith(color: colors.surface)),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(Uri.base, webOnlyWindowName: '_self'),
                    style: TextButton.styleFrom(foregroundColor: colors.surface),
                    child: Text(l.reload, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MissingConfiguration extends StatelessWidget {
  const _MissingConfiguration();

  @override
  Widget build(BuildContext context) {
    final colors = context.rabta;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.of(context)!.missingConfigurationTitle,
                  style: Style.heading.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  L.of(context)!.missingConfigurationBody,
                  style: Style.preview.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
