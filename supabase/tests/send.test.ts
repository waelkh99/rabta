// Sending a reply.
//
// The decisions worth testing are the refusals: a reply that fails after the
// seller has written it is the failure this whole design exists to avoid.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import {
  checkText,
  checkWindow,
  readSendResult,
  sendRequest,
  TEXT_LIMIT,
  tokenExpired,
} from "../functions/send-message/send.ts";

const NOW = new Date("2026-09-18T12:00:00.000Z");
const hoursFromNow = (hours: number) =>
  new Date(NOW.getTime() + hours * 3600_000).toISOString();

// ---------------------------------------------------------------------------
// The 24 hour window
// ---------------------------------------------------------------------------

test("a window with time left is open", () => {
  assert.equal(checkWindow(hoursFromNow(1), NOW), null);
  assert.equal(checkWindow(hoursFromNow(23.9), NOW), null);
});

test("a window that has passed is closed", () => {
  assert.equal(checkWindow(hoursFromNow(-1), NOW), "window_closed");
  assert.equal(checkWindow(hoursFromNow(-0.001), NOW), "window_closed");
});

test("a window expiring exactly now is closed, not open", () => {
  // The boundary falls closed. Sending at the instant of expiry is a request
  // Meta decides on with its own clock, and losing that race shows the seller
  // a failure after they have written the reply.
  assert.equal(checkWindow(NOW.toISOString(), NOW), "window_closed");
});

test("a conversation that never had an inbound message is not the same as a closed one", () => {
  // No window was ever opened. The seller needs to be told something
  // different, so this must not collapse into window_closed.
  assert.equal(checkWindow(null, NOW), "no_window");
  assert.equal(checkWindow(undefined, NOW), "no_window");
  assert.equal(checkWindow("", NOW), "no_window");
});

// ---------------------------------------------------------------------------
// What the seller typed
// ---------------------------------------------------------------------------

test("an empty or whitespace-only reply is refused before Meta is called", () => {
  for (const nothing of ["", " ", "\n", "\t  \n", " "]) {
    assert.equal(checkText(nothing, "messenger"), "empty", `sent ${JSON.stringify(nothing)}`);
  }
});

test("a reply of ordinary length is accepted in both languages", () => {
  assert.equal(checkText("Yes, it is available.", "messenger"), null);
  assert.equal(checkText("نعم، متوفر. السعر 1200 دولار.", "instagram"), null);
});

test("Instagram's shorter limit is not applied to Messenger", () => {
  // Refusing a 1,500 character Messenger reply because Instagram could not
  // take it would be our mistake rather than Meta's.
  const long = "x".repeat(1500);

  assert.equal(checkText(long, "messenger"), null);
  assert.equal(checkText(long, "instagram"), "too_long");
});

test("each platform accepts exactly its limit and refuses one more", () => {
  for (const [platform, limit] of Object.entries(TEXT_LIMIT)) {
    assert.equal(checkText("x".repeat(limit), platform), null, `${platform} at limit`);
    assert.equal(checkText("x".repeat(limit + 1), platform), "too_long", `${platform} over`);
  }
});

test("an unknown platform falls back to the shorter limit", () => {
  // WhatsApp is deferred, not cancelled. A platform added without touching
  // this file must not send messages that are silently truncated.
  assert.equal(checkText("x".repeat(1000), "whatsapp"), null);
  assert.equal(checkText("x".repeat(1001), "whatsapp"), "too_long");
});

// ---------------------------------------------------------------------------
// The request to Meta
// ---------------------------------------------------------------------------

test("the reply is addressed to the account, and the customer is the recipient", () => {
  // Getting these the wrong way round sends the seller's reply to themselves.
  const { url, init } = sendRequest("1427711713749572", "24055173887453000", "Hello", "tok");

  assert.equal(url, "https://graph.facebook.com/v26.0/1427711713749572/messages");

  const body = JSON.parse(init.body as string);
  assert.equal(body.recipient.id, "24055173887453000");
  assert.equal(body.message.text, "Hello");
  assert.equal(body.messaging_type, "RESPONSE");
});

test("Instagram is addressed by its own id, not the Page's", () => {
  // entry.id on an Instagram delivery is the Instagram account id, which is
  // what connected_accounts stores — so the same call works for both platforms
  // and the Page id must not appear here.
  const { url } = sendRequest("17841401424316998", "customer", "مرحبا", "tok");

  assert.equal(url, "https://graph.facebook.com/v26.0/17841401424316998/messages");
});

test("Arabic survives being put into the request body", () => {
  const arabic = "سعر iPhone 15 Pro هو 1200 دولار؟";
  const { init } = sendRequest("account", "customer", arabic, "tok");

  assert.equal(JSON.parse(init.body as string).message.text, arabic);
});

test("the access token is in the body, never in the url", () => {
  // A token in a query string is a token in logs, in proxies, and in browser
  // history. The body keeps it out of all three.
  const { url, init } = sendRequest("account", "customer", "hi", "secret-token");

  assert.ok(!url.includes("secret-token"), "token leaked into the url");
  assert.equal(JSON.parse(init.body as string).access_token, "secret-token");
});

// ---------------------------------------------------------------------------
// What Meta answered
// ---------------------------------------------------------------------------

test("a sent reply gives back the id the echo will arrive with", () => {
  // Storing this id is the whole of what stops our own reply appearing twice:
  // messages.mid is unique and the webhook inserts with ignoreDuplicates.
  const result = readSendResult({
    recipient_id: "24055173887453000",
    message_id: "m_AG5Hc2tf3Z9",
  });

  assert.deepEqual(result, { mid: "m_AG5Hc2tf3Z9" });
});

test("an expired token is reported as a disconnection, not a generic failure", () => {
  // This is the failure that otherwise looks like nothing at all: messages
  // stop arriving and the seller concludes business is quiet.
  const result = readSendResult({
    error: { message: "Error validating access token", code: 190 },
  });

  assert.equal("refusal" in result && result.refusal, "disconnected");
});

test("a window that closed between our check and Meta's is reported as closed", () => {
  const result = readSendResult({
    error: {
      message: "This message is sent outside of allowed window.",
      code: 10,
      error_subcode: 2018278,
    },
  });

  assert.equal("refusal" in result && result.refusal, "window_closed");
});

test("an unfamiliar error is reported plainly rather than guessed at", () => {
  // Meta adds codes without warning. A wrong explanation is worse than an
  // honest "this did not send".
  const result = readSendResult({
    error: { message: "Something new", code: 99999 },
  });

  assert.equal("refusal" in result && result.refusal, "rejected");
  assert.equal("detail" in result && result.detail, "Something new");
});

test("a response that is neither a success nor a recognisable error is a refusal", () => {
  // Never a silent success. Treating an unreadable answer as sent would show
  // the seller a reply the customer never received.
  for (const answer of [{}, null, undefined, "", { message_id: "" }, { error: {} }]) {
    const result = readSendResult(answer);
    assert.ok("refusal" in result, `treated ${JSON.stringify(answer)} as sent`);
  }
});

test("only Meta's code 190 means the token is dead", () => {
  // A false positive tells a seller to reconnect an account that works.
  assert.equal(tokenExpired({ error: { message: "Error validating access token", code: 190 } }), true);
  assert.equal(tokenExpired({ error: { message: "Unsupported get request", code: 100 } }), false);
  assert.equal(tokenExpired({ error: { code: "190" } }), false, "a string is not Meta's code");
  assert.equal(tokenExpired({ id: "1427711713749572" }), false);
  assert.equal(tokenExpired(null), false);
});
