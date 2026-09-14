// Verification that a webhook request genuinely came from Meta.
//
// This is the security boundary of the whole product. The webhook endpoint is
// public and it writes into sellers' inboxes, so without this check anyone who
// discovers the URL can post fabricated messages that the application will
// display as genuine customer messages.
//
// Deliberately free of Deno-specific APIs so the same code runs in Supabase
// Edge Functions and in the test harness.

const PREFIX = "sha256=";

/**
 * Meta signs each webhook POST with an HMAC-SHA256 of the request body, keyed
 * with the app secret, sent in the `X-Hub-Signature-256` header.
 *
 * `rawBody` must be the body exactly as received. Parsing and re-serialising
 * JSON changes the bytes and the signature will never match.
 */
export async function verifyMetaSignature(
  rawBody: string,
  signatureHeader: string | null | undefined,
  appSecret: string,
): Promise<boolean> {
  if (!signatureHeader || !appSecret) return false;
  if (!signatureHeader.startsWith(PREFIX)) return false;

  const provided = signatureHeader.slice(PREFIX.length);
  const expected = await hmacSha256Hex(appSecret, rawBody);

  return timingSafeEqual(provided, expected);
}

/** Hex-encoded HMAC-SHA256. Exported so tests can construct valid signatures. */
export async function hmacSha256Hex(secret: string, body: string): Promise<string> {
  const encoder = new TextEncoder();

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(body));

  return [...new Uint8Array(signature)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Compares in time that does not depend on where the first difference falls,
 * so that timing cannot be used to discover a valid signature byte by byte.
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;

  let difference = 0;
  for (let i = 0; i < a.length; i++) {
    difference |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }

  return difference === 0;
}
