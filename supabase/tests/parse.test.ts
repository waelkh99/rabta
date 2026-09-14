import { strict as assert } from "node:assert";
import { test } from "node:test";

import { parseWebhookPayload } from "../functions/meta-webhook/parse.ts";

const PAGE_ID = "1122334455";
const CUSTOMER_ID = "9988776655";
const SENT_MS = 1_757_000_000_000;

function messengerPayload(message: Record<string, unknown>, sender = CUSTOMER_ID) {
  return {
    object: "page",
    entry: [{
      id: PAGE_ID,
      time: SENT_MS,
      messaging: [{
        sender: { id: sender },
        recipient: { id: sender === CUSTOMER_ID ? PAGE_ID : CUSTOMER_ID },
        timestamp: SENT_MS,
        message,
      }],
    }],
  };
}

test("reads an inbound Messenger message", () => {
  const { messages } = parseWebhookPayload(
    messengerPayload({ mid: "m_abc", text: "Do you have this in blue?" }),
  );

  assert.equal(messages.length, 1);
  assert.deepEqual(messages[0], {
    accountExternalId: PAGE_ID,
    platform: "messenger",
    customerExternalId: CUSTOMER_ID,
    mid: "m_abc",
    direction: "inbound",
    text: "Do you have this in blue?",
    attachments: [],
    sentAt: new Date(SENT_MS).toISOString(),
  });
});

test("maps the instagram object to the instagram platform", () => {
  const { messages } = parseWebhookPayload({
    object: "instagram",
    entry: [{
      id: "ig_account",
      messaging: [{
        sender: { id: CUSTOMER_ID },
        recipient: { id: "ig_account" },
        timestamp: SENT_MS,
        message: { mid: "m_ig", text: "hello" },
      }],
    }],
  });

  assert.equal(messages.length, 1);
  assert.equal(messages[0].platform, "instagram");
  assert.equal(messages[0].accountExternalId, "ig_account");
});

test("treats an echo as outbound and keeps the customer as the counterparty", () => {
  // The seller replied from Meta's own app. Sender and recipient are swapped
  // relative to an inbound message; getting this wrong files the seller's own
  // reply under a conversation named after their own Page.
  const { messages } = parseWebhookPayload(
    messengerPayload({ mid: "m_echo", text: "Yes, in stock", is_echo: true }, PAGE_ID),
  );

  assert.equal(messages.length, 1);
  assert.equal(messages[0].direction, "outbound");
  assert.equal(messages[0].customerExternalId, CUSTOMER_ID);
  assert.equal(messages[0].accountExternalId, PAGE_ID);
});

test("keeps an attachment-only message", () => {
  const attachments = [{ type: "image", payload: { url: "https://example.test/a.jpg" } }];
  const { messages } = parseWebhookPayload(
    messengerPayload({ mid: "m_img", attachments }),
  );

  assert.equal(messages.length, 1);
  assert.equal(messages[0].text, null);
  assert.deepEqual(messages[0].attachments, attachments);
});

test("reads every message in a batched delivery", () => {
  const { messages } = parseWebhookPayload({
    object: "page",
    entry: [
      {
        id: PAGE_ID,
        messaging: [
          {
            sender: { id: "cust_a" },
            recipient: { id: PAGE_ID },
            timestamp: SENT_MS,
            message: { mid: "m_1", text: "one" },
          },
          {
            sender: { id: "cust_b" },
            recipient: { id: PAGE_ID },
            timestamp: SENT_MS + 1000,
            message: { mid: "m_2", text: "two" },
          },
        ],
      },
      {
        id: "another_page",
        messaging: [{
          sender: { id: "cust_c" },
          recipient: { id: "another_page" },
          timestamp: SENT_MS + 2000,
          message: { mid: "m_3", text: "three" },
        }],
      },
    ],
  });

  assert.deepEqual(messages.map((m) => m.mid), ["m_1", "m_2", "m_3"]);
  assert.equal(messages[2].accountExternalId, "another_page");
});

test("skips non-message events without failing", () => {
  const { messages, skipped } = parseWebhookPayload({
    object: "page",
    entry: [{
      id: PAGE_ID,
      messaging: [
        { sender: { id: CUSTOMER_ID }, recipient: { id: PAGE_ID }, delivery: { mids: ["m_1"] } },
        { sender: { id: CUSTOMER_ID }, recipient: { id: PAGE_ID }, read: { watermark: SENT_MS } },
      ],
    }],
  });

  assert.equal(messages.length, 0);
  assert.equal(skipped.length, 2);
});

test("one malformed event does not cost us the rest of the batch", () => {
  const { messages, skipped } = parseWebhookPayload({
    object: "page",
    entry: [{
      id: PAGE_ID,
      messaging: [
        { sender: { id: CUSTOMER_ID }, timestamp: SENT_MS, message: { text: "no mid" } },
        null,
        { sender: { id: CUSTOMER_ID }, recipient: { id: PAGE_ID }, timestamp: SENT_MS, message: { mid: "m_ok", text: "fine" } },
      ],
    }],
  });

  assert.deepEqual(messages.map((m) => m.mid), ["m_ok"]);
  assert.equal(skipped.length, 2);
});

test("skips deleted messages", () => {
  const { messages } = parseWebhookPayload(
    messengerPayload({ mid: "m_gone", is_deleted: true }),
  );

  assert.equal(messages.length, 0);
});

test("survives payloads that are not shaped as expected", () => {
  for (const payload of [null, undefined, 42, "text", [], {}, { object: "page" }]) {
    assert.doesNotThrow(() => parseWebhookPayload(payload));
    assert.equal(parseWebhookPayload(payload).messages.length, 0);
  }
});

test("ignores objects we do not support", () => {
  // WhatsApp is deferred. Its events must be skipped quietly rather than
  // misread as Messenger.
  const { messages, skipped } = parseWebhookPayload({
    object: "whatsapp_business_account",
    entry: [{ id: "waba", changes: [] }],
  });

  assert.equal(messages.length, 0);
  assert.match(skipped[0], /unsupported object type/);
});
