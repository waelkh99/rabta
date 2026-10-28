// WhatsApp's Embedded Signup, which Meta runs only in the page, through its
// JavaScript SDK. `web/whatsapp_signup.js` does the work; this is the door.

import 'whatsapp_signup_stub.dart'
    if (dart.library.js_interop) 'whatsapp_signup_web.dart' as browser;

/// Loads Meta's SDK ahead of the click, so the window it opens is not taken
/// for a popup nobody asked for.
Future<void> loadWhatsAppSignup(String appId) => browser.load(appId);

/// Opens Meta's signup. What it handed back — `code`, and usually `waba_id`,
/// `phone_number_id` and `event` — or null if the seller cancelled.
Future<Map<String, Object?>?> openWhatsAppSignup(String configId) =>
    browser.signup(configId);
