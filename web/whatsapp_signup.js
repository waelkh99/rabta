// WhatsApp's Embedded Signup, which Meta runs only through its JavaScript SDK
// (developers.facebook.com/docs/whatsapp/embedded-signup/implementation).
// Kept in plain JavaScript, close to Meta's own example, so it can be checked
// against the docs line by line. `lib/services/whatsapp_signup_web.dart` calls it.
//
// Two calls, split for the browser's popup blocker: `load` fetches the SDK
// before the button is pressed, so `signup` can open Meta's window straight
// from the click.

(function () {
  let ready = null;

  /** Loads and initialises Meta's SDK once. */
  function load(appId) {
    if (ready) return ready;
    ready = new Promise((resolve, reject) => {
      window.fbAsyncInit = function () {
        FB.init({ appId: appId, autoLogAppEvents: true, xfbml: false, version: 'v26.0' });
        resolve();
      };
      const script = document.createElement('script');
      script.src = 'https://connect.facebook.net/en_US/sdk.js';
      script.async = true;
      script.defer = true;
      script.crossOrigin = 'anonymous';
      script.onerror = () => { ready = null; reject(new Error('sdk_unreachable')); };
      document.head.appendChild(script);
    });
    return ready;
  }

  /**
   * Opens Meta's signup. Resolves with { code, waba_id, phone_number_id, event }
   * or null if the seller cancelled. The code arrives through FB.login's
   * callback and the rest through a separate postMessage, in either order.
   */
  function signup(configId) {
    return new Promise((resolve) => {
      let session = null;
      let code;

      const finish = () => {
        window.removeEventListener('message', onMessage);
        resolve(code ? Object.assign({ code: code }, session) : null);
      };

      const onMessage = (event) => {
        if (!event.origin.endsWith('facebook.com')) return;
        let data;
        try { data = JSON.parse(event.data); } catch (_) { return; }
        if (data.type !== 'WA_EMBEDDED_SIGNUP') return;
        session = {
          event: data.event,
          waba_id: data.data && data.data.waba_id,
          phone_number_id: data.data && data.data.phone_number_id,
        };
        if (code !== undefined) finish();
      };
      window.addEventListener('message', onMessage);

      // Not an async function: the SDK refuses one as a callback.
      FB.login(function (response) {
        code = (response.authResponse && response.authResponse.code) || null;
        // The session info usually comes first. If it has not, give it a
        // moment; the code lives 30 seconds, and the server works without it.
        if (session || !code) finish(); else setTimeout(finish, 1500);
      }, {
        config_id: configId,
        response_type: 'code',
        override_default_response_type: true,
        extras: {
          setup: {},
          // A seller keeps the WhatsApp Business app on the same number
          // (Coexistence, owner 28 Oct).
          featureType: 'whatsapp_business_app_onboarding',
          sessionInfoVersion: '3',
        },
      });
    });
  }

  window.inboxaraWhatsApp = { load: load, signup: signup };
})();
