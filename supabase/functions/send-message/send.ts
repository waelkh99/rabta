// Sending a reply, as a set of decisions that can be tested without a network.
//
// The rule that shapes all of this: Meta allows a free reply only inside 24
// hours of the customer's last message. A reply that fails after the seller has
// written it is a design failure, so every refusal here has a reason the
// interface can state in the seller's own language.
//
// Nothing in this file returns a sentence. The server does not pick a language
// — it returns a code and the client renders it, the same reasoning that put
// `last_message_type` in the database instead of the word "Photo".
//
// Deliberately free of Deno-specific APIs so the same code runs in Supabase
// Edge Functions and in the test harness.

const GRAPH = "https://graph.facebook.com/v26.0";

/**
 * Why a reply was not sent. The client maps each of these to a localised
 * sentence; none of them is ever shown as it is written here.
 */
export type Refusal =
  | "empty" // nothing typed, or only whitespace
  | "too_long" // longer than the platform accepts
  | "window_closed" // past 24 hours since the customer's last message
  | "no_window" // the customer has never written, so no window ever opened
  | "not_found" // no such conversation, or not this seller's
  | "disconnected" // the access token is no longer good
  | "rejected" // Meta refused for some other reason
  | "unreachable"; // we could not reach Meta at all

/**
 * The longest message each platform accepts, in characters.
 *
 * Instagram's limit is half of Messenger's, and refusing a 1,500 character
 * Messenger reply because Instagram could not take it would be our mistake
 * rather than Meta's.
 */
export const TEXT_LIMIT: Record<string, number> = {
  messenger: 2000,
  instagram: 1000,
};

/** What is wrong with the text, if anything. */
export function checkText(text: string, platform: string): Refusal | null {
  if (text.trim().length === 0) return "empty";

  // ponytail: counted in UTF-16 code units, which is what String.length gives.
  // Meta counts differently for characters outside the basic plane, so an
  // all-emoji message could be refused slightly early. Count code points if a
  // seller ever hits it.
  const limit = TEXT_LIMIT[platform] ?? 1000;
  return text.length > limit ? "too_long" : null;
}

/**
 * Whether the 24 hour reply window is still open.
 *
 * A conversation with no `window_expires_at` has never had an inbound message,
 * so no window was ever opened — which is a different thing from one that has
 * closed, and worth saying differently.
 */
export function checkWindow(
  windowExpiresAt: string | null | undefined,
  now: Date,
): Refusal | null {
  if (!windowExpiresAt) return "no_window";
  return new Date(windowExpiresAt) > now ? null : "window_closed";
}

/**
 * Where to post a reply, and what to post.
 *
 * Instagram and Messenger take the same request at the same Graph endpoint.
 * What differs is only which id sits in the path — the Page's for Messenger,
 * the Instagram account's for Instagram — and `connected_accounts.external_id`
 * already holds the right one for each, because that is the id Meta puts in
 * `entry.id` when a message arrives.
 */
export function sendRequest(
  accountExternalId: string,
  customerExternalId: string,
  // A string is text. An image is sent by URL, which Meta fetches itself —
  // the reason product photos live in a public bucket. Instagram and
  // Messenger take the same shape; `is_reusable` is left out because
  // Instagram does not document it.
  content: string | { image: string },
  accessToken: string,
): { url: string; init: RequestInit } {
  const message = typeof content === "string"
    ? { text: content }
    : { attachment: { type: "image", payload: { url: content.image } } };

  return {
    url: `${GRAPH}/${accountExternalId}/messages`,
    init: {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        // RESPONSE says this is a reply inside the window rather than an
        // update or a promotion. Meta enforces different rules for each.
        messaging_type: "RESPONSE",
        recipient: { id: customerExternalId },
        message,
        access_token: accessToken,
      }),
    },
  };
}

/**
 * What Meta's answer means.
 *
 * On success it carries the message id, which we store as the outbound
 * message's `mid`. That single fact is what stops the echo of our own reply
 * arriving through the webhook a moment later and appearing twice: `mid` is
 * unique and the webhook already inserts with `ignoreDuplicates`.
 */
export function readSendResult(
  body: unknown,
): { mid: string } | { refusal: Refusal; detail: string } {
  const result = body as {
    message_id?: string;
    error?: { message?: string; code?: number; error_subcode?: number };
  };

  if (result?.message_id) return { mid: result.message_id };

  const error = result?.error ?? {};
  const detail = error.message ?? JSON.stringify(body);

  return { refusal: refusalFor(error.code, error.error_subcode), detail };
}

/**
 * Meta's error codes, narrowed to the ones the seller can do something about.
 *
 * Everything else is `rejected`, which the interface states plainly rather than
 * guessing at. Meta adds codes without warning and a wrong explanation is worse
 * than an honest "this did not send".
 */
/**
 * Whether a Graph answer says the access token itself is dead.
 *
 * Shared by every caller that holds a token, because on the receiving side a
 * dead token is otherwise invisible: Meta simply stops delivering, and the
 * seller thinks business is quiet.
 */
export function tokenExpired(body: unknown): boolean {
  const error = (body as { error?: { code?: unknown } } | null)?.error;
  return error?.code === 190;
}

function refusalFor(code?: number, subcode?: number): Refusal {
  // 190 is an expired or invalidated access token. This is the failure that
  // otherwise looks like nothing at all — messages simply stop — so it is
  // worth separating from every other rejection.
  if (code === 190) return "disconnected";

  // Outside the allowed window. We check the window ourselves before calling,
  // so reaching this means our clock and Meta's disagree, or the window closed
  // between the check and the call.
  if (subcode === 2018278 || code === 10) return "window_closed";

  return "rejected";
}
