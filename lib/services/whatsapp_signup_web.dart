// The calls into `web/whatsapp_signup.js`. No decisions here.

import 'dart:js_interop';

@JS('inboxaraWhatsApp.load')
external JSPromise<JSAny?> _load(String appId);

@JS('inboxaraWhatsApp.signup')
external JSPromise<JSAny?> _signup(String configId);

Future<void> load(String appId) => _load(appId).toDart;

Future<Map<String, Object?>?> signup(String configId) async {
  final result = (await _signup(configId).toDart)?.dartify();
  return result is Map ? result.cast<String, Object?>() : null;
}
