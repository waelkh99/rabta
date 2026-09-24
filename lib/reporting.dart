// Telling us when the app breaks on a seller's screen, and telling the seller
// when there is a newer version than the one in their tab.
//
// Both exist for the same reason: a seller leaves Rabta open all day. An error
// on their screen used to be invisible to anyone but them, and a fix we
// deployed at noon reached them only if they happened to reload.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// At most this many reports per tab. An error inside a build method repeats
/// on every frame; the first few say everything the rest would.
const maxReports = 5;

int _reported = 0;

/// The first line of the stack is usually enough to find it; the rest is kept
/// up to the column's limit.
String trimmed(String text, int max) =>
    text.length <= max ? text : text.substring(0, max);

/// Sends an error to `client_errors`, where the admin screen reads it. Only
/// for a signed-in seller: the table accepts nothing else. Never throws — a
/// report that fails is not worth a second error.
Future<void> reportError(Object error, StackTrace? stack) async {
  if (_reported >= maxReports) return;

  final client = _client();
  if (client?.auth.currentSession == null) return;
  _reported++;

  try {
    await client!.from('client_errors').insert({
      'message': trimmed('$error', 2000),
      'stack': stack == null ? null : trimmed('$stack', 8000),
      'url': trimmed(Uri.base.path, 500),
      'app_version': buildId.value,
    });
  } catch (_) {}
}

SupabaseClient? _client() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

/// Routes every uncaught error through [reportError], keeping Flutter's own
/// handling so the console still shows it during development.
void reportUncaughtErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    unawaited(reportError(details.exception, details.stack));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(reportError(error, stack));
    return true;
  };
}

// ---------------------------------------------------------------------------
// A newer version
// ---------------------------------------------------------------------------

/// The build this tab is running, as the hash Flutter writes into
/// flutter_bootstrap.js. Null until read, or when it cannot be.
final buildId = ValueNotifier<String?>(null);

/// Set once the deployed build differs from the one this tab started with.
final newerVersion = ValueNotifier<bool>(false);

/// The build hash in a flutter_bootstrap.js body, or null.
String? buildIdIn(String bootstrap) =>
    RegExp(r'serviceWorkerVersion:\s*"(\w+)"').firstMatch(bootstrap)?.group(1);

Future<String?> _deployedBuild() async {
  try {
    final url = Uri.base.resolve('flutter_bootstrap.js')
        .replace(queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'});
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    return response.statusCode == 200 ? buildIdIn(response.body) : null;
  } catch (_) {
    return null;
  }
}

/// Reads the build this tab started with, then checks every ten minutes for a
/// different one.
///
/// ponytail: the hash comes from Flutter's service worker version, which
/// Flutter has deprecated. When it disappears, write a build stamp file at
/// deploy time and read that instead.
void watchForNewVersion({Duration every = const Duration(minutes: 10)}) {
  if (!kIsWeb) return;
  unawaited(() async {
    buildId.value = await _deployedBuild();
    if (buildId.value == null) return;
    Timer.periodic(every, (timer) async {
      final deployed = await _deployedBuild();
      if (deployed != null && deployed != buildId.value) {
        newerVersion.value = true;
        timer.cancel();
      }
    });
  }());
}
