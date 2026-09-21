// The only place in the application that talks to the browser's notification
// APIs. No decisions are made here — `alerts.dart` decides, this obeys.
//
// Two things about the platform shape the whole file:
//
//   * `new Notification(...)` throws on Chrome for Android. The message is
//     "Illegal constructor. Use ServiceWorkerRegistration.showNotification()
//     instead." So everything goes through the service worker, including on a
//     desktop where the constructor would have worked. One path, so the phone
//     case cannot be the one nobody ran.
//   * On an iPhone, a site open in a Safari tab has no Notification API at
//     all. Not "denied" — absent. The seller has to add Rabta to the Home
//     Screen first. `permission()` reports that as `unsupported` and the
//     interface says so, rather than offering a switch that does nothing.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'alerts.dart';
import 'prefs.dart' as prefs;

/// Registered once, lazily, and only when the seller has actually said yes.
/// A service worker registered on load would be a background thread every
/// visitor pays for so that some of them can have notifications.
web.ServiceWorkerRegistration? _worker;

/// Asked rather than assumed, because the answer is "no" on the platform this
/// product is most likely to be read on. `has` is the only way to ask without
/// touching a global that may not exist — reading `Notification.permission` on
/// an iPhone throws rather than returning anything.
bool get _supported =>
    web.window.has('Notification') && web.window.navigator.has('serviceWorker');

AlertPermission permission() {
  if (!_supported) return AlertPermission.unsupported;

  return switch (web.Notification.permission) {
    'granted' => AlertPermission.granted,
    'denied' => AlertPermission.denied,
    _ => AlertPermission.ask,
  };
}

Future<AlertPermission> ask() async {
  if (!_supported) return AlertPermission.unsupported;

  final String answer;
  try {
    answer = (await web.Notification.requestPermission().toDart).toDart;
  } catch (_) {
    // Safari has historically rejected rather than resolving when the call did
    // not come from a gesture it recognised. Treated as a refusal: the seller
    // sees the row stay as it was, which is the truth.
    return AlertPermission.denied;
  }

  if (answer != 'granted') {
    return answer == 'denied' ? AlertPermission.denied : AlertPermission.ask;
  }

  return AlertPermission.granted;
}

/// Kept in `prefs.dart` with the language, because both are the same kind of
/// thing: a choice about this browser on this device rather than about the
/// seller. See the note there on why it does not follow them between machines.
bool wanted() => prefs.alertsWanted;

void setWanted(bool on) => prefs.alertsWanted = on;

Future<void> prepare() => _register();

/// Waits for the worker to be usable, not merely registered.
///
/// A registration is returned before its worker is active, and
/// `showNotification` on an inactive registration does nothing and reports no
/// error — which is exactly the failure that looks like "notifications are
/// broken" and leaves nothing to read.
Future<void> _register() async {
  if (_worker != null) return;

  try {
    await web.window.navigator.serviceWorker.register('alerts_sw.js'.toJS).toDart;
    _worker = await web.window.navigator.serviceWorker.ready.toDart;
  } catch (_) {
    // Nothing more to do. `notify` finds no worker and stays silent, the title
    // count still works, and the inbox is unaffected.
    _worker = null;
  }
}

void setTitle(String title) => web.document.title = title;

void notify(String conversationId, String title, String body) {
  final worker = _worker;
  if (worker == null || permission() != AlertPermission.granted) return;

  worker.showNotification(
    title,
    web.NotificationOptions(
      body: body,
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      // One notification per conversation. A customer who sends three
      // fragments replaces their own notification twice instead of stacking
      // three, which matches how the assistant reads that burst as one message.
      tag: conversationId,
      // The tag alone replaces silently. This makes a replacement buzz, so a
      // second message from someone already waiting is not missed.
      renotify: true,
    ),
  );
}
