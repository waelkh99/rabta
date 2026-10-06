// Telling the seller something happened while they were looking elsewhere.
//
// Two different things, deliberately kept apart:
//
//   * The count in the tab title, which needs no permission and is always on.
//     It answers "is anything waiting" from a glance at a background tab.
//   * A system notification, which needs permission and says who and why.
//
// What is announced is decided here, in plain Dart with no browser in sight, so
// the rules can be tested. `alerts_web.dart` does the talking to the browser and
// contains no decisions at all.
//
// Nothing here reaches a phone in a Safari tab, which cannot show a notification
// at all until the site is added to the Home Screen. That is written up in
// docs/DECISIONS.md rather than worked around.

import 'alerts_stub.dart' if (dart.library.js_interop) 'alerts_web.dart' as browser;
import '../data.dart';
import '../l10n/app_localizations.dart';

/// Why the seller is being told about a conversation.
enum AlertKind {
  /// A customer wrote, and nobody has answered them.
  wrote,

  /// The assistant looked at it and handed it back.
  handedOver,
}

/// One thing worth interrupting the seller for.
class Alert {
  const Alert(this.conversation, this.kind);

  final Conversation conversation;
  final AlertKind kind;

  @override
  bool operator ==(Object other) =>
      other is Alert &&
      other.conversation.id == conversation.id &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(conversation.id, kind);

  @override
  String toString() => 'Alert(${conversation.id}, ${kind.name})';
}

/// What changed between two readings of the inbox that the seller should hear
/// about.
///
/// Driven by comparing lists rather than by listening for events, because the
/// realtime subscription is deliberately used as a signal and never as a source
/// of data — every change causes the list to be read again through the ordinary
/// query. So the list is the only thing that is ever true, and diffing it is
/// the only way to be sure an announcement matches what is on screen.
///
/// [before] being null means this is the first list of the session. Nothing is
/// announced: everything in it is new to this tab, and a seller who opens Rabta
/// to nine waiting customers does not want nine notifications about customers
/// they can already see.
///
/// [openId] is the conversation the seller is reading. It is never announced —
/// they are looking straight at it.
List<Alert> alertsFor(
  List<Conversation>? before,
  List<Conversation> after, {
  String? openId,
}) {
  if (before == null) return const [];

  final was = {for (final c in before) c.id: c};
  final alerts = <Alert>[];

  for (final now in after) {
    if (now.id == openId) continue;

    final then = was[now.id];

    // Handing back is checked first and wins, because a conversation can do
    // both at once — the customer wrote, the assistant tried, and it gave up —
    // and of the two that is the one the seller needs to read.
    if (now.escalated && !(then?.escalated ?? false)) {
      alerts.add(Alert(now, AlertKind.handedOver));
      continue;
    }

    // A conversation that was not in the previous list is new to this tab.
    // Announced only when it is actually waiting: a conversation that arrives
    // already answered is not news.
    if (then == null) {
      if (now.awaitingReply) alerts.add(Alert(now, AlertKind.wrote));
      continue;
    }

    // The customer wrote again. Compared on the inbound timestamp rather than
    // on the unread count, which an assistant reply resets to zero — so a
    // customer who writes, gets answered, and writes again would otherwise
    // look unchanged.
    final moved = now.lastInboundAt != null &&
        (then.lastInboundAt == null ||
            now.lastInboundAt!.isAfter(then.lastInboundAt!));

    if (moved && now.awaitingReply) alerts.add(Alert(now, AlertKind.wrote));
  }

  return alerts;
}

/// The tab title, with the number of customers waiting in front of it.
///
/// The count leads, because in a narrow background tab that is all the seller
/// can see. Zero reads as the plain name rather than "(0)", which is a number
/// that costs a glance to discover means nothing.
String titleFor(String name, int waiting) =>
    waiting > 0 ? '($waiting) $name' : name;

/// What a notification says, in the seller's language.
///
/// The customer's own words are never quoted. A notification is visible on a
/// locked screen and over a shared desk, and what a customer writes to a shop
/// is theirs. The seller learns who and what kind, and opens Rabta to read it.
({String title, String body}) alertText(L l, Alert alert) {
  final name = alert.conversation.customerName ?? l.customer;

  return switch (alert.kind) {
    AlertKind.wrote => (title: name, body: l.alertWrote),
    AlertKind.handedOver => (title: name, body: l.alertHandedOver),
  };
}

// ---------------------------------------------------------------------------
// The browser, kept behind one wall
// ---------------------------------------------------------------------------

/// Whether the seller has been asked, and what they said.
enum AlertPermission {
  /// Never asked. The only state in which asking is allowed.
  ask,
  granted,

  /// Refused, or blocked at the browser level. Asking again does nothing at
  /// all in every browser — there is no second prompt — so the interface says
  /// so rather than offering a button that cannot work.
  denied,

  /// No notifications here whatever the seller wants: a Safari tab on an
  /// iPhone, or any browser old enough to lack the API.
  unsupported,
}

AlertPermission alertPermission() => browser.permission();

/// What the seller sees and can act on, which is not the same as what the
/// browser permits.
///
/// A granted permission cannot be taken back from code — `Notification
/// .permission` stays "granted" until someone changes it in browser settings,
/// and there is no API to revoke it. So turning alerts off is our own
/// preference laid over the browser's, and the two have to be read together.
enum AlertState {
  /// No notifications here whatever anyone wants: a Safari tab on an iPhone,
  /// or a browser too old for the API. Not a refusal, and it must not read
  /// as one.
  unsupported,

  /// Refused, or blocked at the browser level. No browser offers a second
  /// prompt, so this is a statement rather than something to tap.
  blocked,

  /// Either never asked, or asked, granted and since switched off. The two are
  /// deliberately one state: from the seller's side both mean "not getting
  /// notifications, and I can change that", and turning it on does whatever is
  /// needed.
  off,

  on,
}

/// Decided from the two inputs rather than read from anywhere, so every
/// combination can be checked without a browser.
AlertState alertStateFrom(AlertPermission permission, bool wanted) =>
    switch (permission) {
      AlertPermission.unsupported => AlertState.unsupported,
      AlertPermission.denied => AlertState.blocked,
      AlertPermission.ask => AlertState.off,
      AlertPermission.granted => wanted ? AlertState.on : AlertState.off,
    };

AlertState alertState() => alertStateFrom(browser.permission(), browser.wanted());

/// Whether a notification should actually be shown right now.
bool alertsAreOn() => alertState() == AlertState.on;

/// Turns them on, asking the browser only if it has not been asked yet.
///
/// Every browser requires the permission prompt to come from a user gesture,
/// and one fired on page load is refused by some of them before the seller
/// sees it — so this is only ever called from a tap. A seller who turns alerts
/// off and on again is not asked a second time; the permission was never lost.
Future<AlertState> turnAlertsOn() async {
  var permission = browser.permission();

  if (permission == AlertPermission.ask) {
    permission = await browser.ask();
  }

  if (permission != AlertPermission.granted) {
    return alertStateFrom(permission, false);
  }

  browser.setWanted(true);
  await browser.prepare();
  return AlertState.on;
}

/// Turns them off without touching the browser's permission, which cannot be
/// given back without another prompt — and on a browser that has already been
/// asked once, there is no second prompt to give.
void turnAlertsOff() => browser.setWanted(false);

/// Registers the service worker when alerts are already on from a previous
/// visit.
///
/// Needed because registration used to happen only inside the permission
/// prompt, so a seller who reloaded the page kept a menu row saying alerts
/// were on while `notify` quietly found no worker and did nothing. Called once
/// as the inbox starts.
Future<void> prepareAlerts() async {
  if (alertsAreOn()) await browser.prepare();
}

/// Puts the count in front of the tab title.
void showWaitingCount(String name, int waiting) =>
    browser.setTitle(titleFor(name, waiting));

/// Shows one notification through the service worker.
///
/// Through the worker and never through `new Notification()`, which throws on
/// Chrome for Android — "Illegal constructor. Use
/// ServiceWorkerRegistration.showNotification() instead." One path for every
/// platform means the desktop case cannot quietly work while the phone case
/// has never been run.
void announce(Alert alert, String title, String body) =>
    browser.notify(alert.conversation.id, title, body);

/// What the menu row says. Only two of the four states can be acted on, and
/// the other two have to explain themselves rather than leave a switch that
/// does nothing.
String alertStateLabel(L l, AlertState state) => switch (state) {
      AlertState.unsupported => l.alertsUnsupported,
      AlertState.blocked => l.alertsDenied,
      AlertState.off || AlertState.on => l.alerts,
    };
