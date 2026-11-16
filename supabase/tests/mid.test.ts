import { strict as assert } from "node:assert";
import { test } from "node:test";

import { canonicalMid } from "../functions/_shared/mid.ts";
import { parseWebhookPayload } from "../functions/meta-webhook/parse.ts";
import { readSendResult } from "../functions/send-message/send.ts";

// One assistant reply on production, 16 November 2026: what the Send API
// returned, and the mid on the echo that arrived a second later.
const SENT =
  "bmV3X2lnX2RtX2l0ZAW06MTpJR01lc3NhZA2VJRDoxNzg0MTQwMTQyNDMxNjk5ODozNDAyODIzNjY4NDE3MTAzMDEyNDQyNTk4ODE0MjA0OTE0NTkzNzA6MzMxMDkyNjU3OTI1ODY5NjEwMzMxMDEyNTkzODY2NTA2MjQZD";
const ECHO =
  "aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDAxNDI0MzE2OTk4OjM0MDI4MjM2Njg0MTcxMDMwMTI0NDI1OTg4MTQyMDQ5MTQ1OTM3MDozMzEwOTI2NTc5MjU4Njk2MTAzMzEwMTI1OTM4NjY1MDYyNAZDZD";
// The customer's message just before it: a different message.
const INBOUND =
  "aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQxNDAxNDI0MzE2OTk4OjM0MDI4MjM2Njg0MTcxMDMwMTI0NDI1OTg4MTQyMDQ5MTQ1OTM3MDozMzEwOTI2NDk5Mjk4MDg3MDk1MDY4MTAwNTkzODE4MDA5NgZDZD";

const ACCOUNT = "17841401424316998";
const CUSTOMER = "1448814650090774";

function instagramEcho(mid: string) {
  return {
    object: "instagram",
    entry: [{
      id: ACCOUNT,
      time: 1794856896000,
      messaging: [{
        sender: { id: ACCOUNT },
        recipient: { id: CUSTOMER },
        timestamp: 1794856895086,
        message: { mid, text: "Hey! How can I help you today?", is_echo: true },
      }],
    }],
  };
}

test("the id the Send API returns and the id on its echo are the same message", () => {
  assert.equal(canonicalMid(SENT), canonicalMid(ECHO));
});

test("an Instagram reply's echo is stored under the id the reply was stored under", () => {
  // The real paths: what send-message and the assistant store, and what the
  // webhook stores for the echo. Equal ids are what make the echo a duplicate.
  const sent = readSendResult({ recipient_id: CUSTOMER, message_id: SENT });
  const echo = parseWebhookPayload(instagramEcho(ECHO)).messages[0];
  assert.ok("mid" in sent);
  assert.equal(echo.direction, "outbound");
  assert.equal(echo.mid, sent.mid);
});

test("two different Instagram messages stay different", () => {
  assert.notEqual(canonicalMid(INBOUND), canonicalMid(ECHO));
});

test("the stored form is the decoded id without Meta's 'new_'", () => {
  assert.equal(
    canonicalMid(SENT),
    "ig_dm_item:1:IGMessageID:17841401424316998:340282366841710301244259881420491459370:33109265792586961033101259386650624",
  );
});

test("Messenger and WhatsApp ids are left exactly as they are", () => {
  for (const mid of [
    "m_GUperp7ut5y4G54ePF0ZznrznN-uRXk0Ud7nmKW3VfvMrnONkj9xMOJ4fzMWgYtH44KyflMM9Xf5GyFymK1NKg",
    "wamid.HBgMOTYyNzg2NTQ4NzY4FQIAEhggQTQ5RkY4QjM0QkFDRjM2RkFCMjU3MzE3NjgyMDE2NjQA",
  ]) assert.equal(canonicalMid(mid), mid);
});

test("an id that only looks Instagram-shaped is left alone rather than mangled", () => {
  for (const mid of ["aWdf", "aWdf!!not-base64", "aWdfZAG1faXRlbQ", "bmV3X2lnX3NvbWV0aGluZ19lbHNl"]) {
    assert.equal(canonicalMid(mid), mid);
  }
});
