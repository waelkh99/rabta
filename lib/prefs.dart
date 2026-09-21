// The handful of choices that belong to this browser rather than to the seller.
//
// Language and alerts are both per-device on purpose. The same seller may work
// in Arabic on the machine at the counter and in English on a laptop they
// share, and may want to be notified at one and not the other. A preference
// that followed them between the two would be wrong in one place every time.
//
// Storage can be unavailable outright — a private window, blocked site data —
// and both accessors throw rather than returning null when it is. Every read
// falls back to a default and every write is allowed to fail, so a browser that
// refuses to remember still works; it simply forgets.

import 'prefs_stub.dart' if (dart.library.js_interop) 'prefs_web.dart' as store;

/// The language the seller last chose, or null if they never have.
///
/// Null is not "Arabic". It means nothing was chosen, and the application then
/// follows the browser's own languages, which is the better guess for a seller
/// who has just been sent a link.
String? get savedLanguage {
  final saved = store.read(_language);
  return saved == 'ar' || saved == 'en' ? saved : null;
}

set savedLanguage(String? code) => store.write(_language, code);

/// Whether the seller wants notifications in this browser.
///
/// Defaults to true, so a seller who granted permission and never touched the
/// switch gets what they agreed to. Only an explicit "off" is stored as off,
/// and this says nothing about whether the browser permits them — see
/// `alerts.dart`, which reads the two together.
bool get alertsWanted => store.read(_alerts) != 'off';

set alertsWanted(bool on) => store.write(_alerts, on ? 'on' : 'off');

const _language = 'rabta.language';
const _alerts = 'rabta.alerts';
