// localStorage, with the two things about it that matter wrapped up once.
//
// It can throw rather than return null — a private window, or a browser with
// site data blocked — so every call is guarded. And what it holds is scoped to
// this browser on this device, which is the whole reason these preferences live
// here rather than on the seller's account.

import 'package:web/web.dart' as web;

String? read(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

void write(String key, String? value) {
  try {
    if (value == null) {
      web.window.localStorage.removeItem(key);
    } else {
      web.window.localStorage.setItem(key, value);
    }
  } catch (_) {
    // The choice holds for this page and is forgotten on reload, which is
    // better than failing the tap that made it.
  }
}
