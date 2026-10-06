// What `alerts.dart` talks to when there is no browser.
//
// Only the tests reach this: the product is a web application and has no other
// target. It exists so that `alerts.dart` — which holds the rules worth testing
// — can be imported by `flutter test`, which runs on the Dart VM where
// `dart:js_interop` does not exist.
//
// Everything here does nothing, quietly. A test that reaches one of these has
// wandered out of the logic it meant to check.

import 'alerts.dart';

AlertPermission permission() => AlertPermission.unsupported;

Future<AlertPermission> ask() async => AlertPermission.unsupported;

bool wanted() => false;

void setWanted(bool on) {}

Future<void> prepare() async {}

void setTitle(String title) {}

void notify(String conversationId, String title, String body) {}
