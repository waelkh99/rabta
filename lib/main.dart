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
import 'package:supabase_flutter/supabase_flutter.dart';

import 'inbox_page.dart';
import 'l10n/app_localizations.dart';
import 'locale_switch.dart';
import 'sign_in_page.dart';
import 'theme.dart';

const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

/// `?lang=ar` or `?lang=en` overrides what the browser asks for.
///
/// A seller's browser is often set to English on a machine they share or did
/// not configure, which is not the language they want to work in. Until there
/// is a settings screen this is how they say so, and it is also the only way to
/// see the Arabic interface without changing the whole browser.
Locale? get _requestedLocale {
  final asked = Uri.base.queryParameters['lang'];
  return L.supportedLocales.where((l) => l.languageCode == asked).firstOrNull;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_url.isEmpty || _key.isEmpty) {
    runApp(const RabtaApp(configured: false));
    return;
  }

  await Supabase.initialize(url: _url, publishableKey: _key);

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
      locale: chosen ?? _requestedLocale,
      localeListResolutionCallback: (requested, supported) {
        for (final locale in requested ?? const <Locale>[]) {
          for (final candidate in supported) {
            if (candidate.languageCode == locale.languageCode) return candidate;
          }
        }
        return const Locale('ar');
      },

      home: configured ? const _AuthGate() : const _MissingConfiguration(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // currentSession rather than the stream event, so a restored session
        // shows the inbox immediately instead of flashing the sign-in screen.
        final session = Supabase.instance.client.auth.currentSession;
        return session == null ? const SignInPage() : const InboxPage();
      },
    );
  }
}

/// Running without configuration is a developer's mistake, not a seller's, so
/// it names exactly what is missing rather than failing somewhere later.
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
