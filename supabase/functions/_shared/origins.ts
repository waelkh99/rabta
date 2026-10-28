// Where the Rabta application runs.
//
// One list, because two functions need the same answer for two reasons:
//
//   - `meta-oauth` redirects a browser here after handling an access token. A
//     destination taken from the request would make it an open redirect on the
//     most sensitive endpoint in the system.
//   - `send-message` is called from the page, so the browser will not deliver
//     the answer unless the function names the origin back.
//
// Keeping them together means an origin cannot be trusted for one and not the
// other, and adding the production domain is one edit rather than a hunt.
//
// Deliberately free of Deno-specific APIs so the same code runs in Supabase
// Edge Functions and in the test harness.

/**
 * Index 0 is the default for a flow that names no origin.
 */
export const APP_ORIGINS = [
  // Production: inboxara.app since 28 October 2026, with the name. rabta.chat
  // and the Pages address stay, because Pages keeps serving them and old links
  // point there.
  "https://inboxara.app",
  "https://rabta.chat",
  "https://rabta.pages.dev",
  // Development. The port is pinned in .vscode/launch.json and README.md for
  // exactly this reason: neither an allowlist nor a CORS check can hold a port
  // that changes on every run.
  "http://localhost:5353",
];

/**
 * The headers that let the page read this function's answer, or nothing at all
 * for an origin we do not serve.
 *
 * Returning nothing is the safe failure: the browser then refuses the response
 * rather than handing it to a page we have never heard of.
 */
export function corsHeaders(origin: string | null | undefined): Record<string, string> {
  if (!origin || !APP_ORIGINS.includes(origin)) return {};

  return {
    "access-control-allow-origin": origin,
    "access-control-allow-headers":
      "authorization, content-type, apikey, x-client-info",
    "access-control-allow-methods": "POST, OPTIONS",
    // The answer differs by origin, so a cache must not serve one origin's
    // headers to another.
    "vary": "Origin",
  };
}
