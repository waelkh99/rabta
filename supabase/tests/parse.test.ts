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
  const { messages, skipped } = parseWebhookPayload({
    object: "user",
    entry: [{ id: "x", changes: [] }],
  });

  assert.equal(messages.length, 0);
  assert.match(skipped[0], /unsupported object type/);
});

// ---------------------------------------------------------------------------
// WhatsApp: a different shape. entry[].changes[].value, the account is the
// phone number id in metadata, timestamps in seconds, media by id.
// ---------------------------------------------------------------------------

const PHONE_ID = "106540352242922";
const WA_ID = "962790000000";
const SENT_S = 1_757_000_000;

function whatsappPayload(value: Record<string, unknown>, field = "messages") {
  return {
    object: "whatsapp_business_account",
    entry: [{
      id: "waba_1",
      changes: [{
        field,
        value: {
          messaging_product: "whatsapp",
          metadata: { display_phone_number: "15550000000", phone_number_id: PHONE_ID },
          ...value,
        },
      }],
    }],
  };
}

test("reads an inbound WhatsApp text, with the customer's name", () => {
  const { messages } = parseWebhookPayload(whatsappPayload({
    contacts: [{ profile: { name: "Lina" }, wa_id: WA_ID }],
    messages: [{
      from: WA_ID,
      id: "wamid.A",
      timestamp: String(SENT_S),
      type: "text",
      text: { body: "بكم هاد؟" },
    }],
  }));

  assert.deepEqual(messages, [{
    accountExternalId: PHONE_ID,
    platform: "whatsapp",
    customerExternalId: WA_ID,
    customerName: "Lina",
    mid: "wamid.A",
    direction: "inbound",
    text: "بكم هاد؟",
    attachments: [],
    sentAt: new Date(SENT_S * 1000).toISOString(),
  }]);
});

test("reads WhatsApp media as an attachment by id, caption as text", () => {
  const { messages } = parseWebhookPayload(whatsappPayload({
    contacts: [{ profile: { name: "Lina" }, wa_id: WA_ID }],
    messages: [
      {
        from: WA_ID, id: "wamid.I", timestamp: String(SENT_S), type: "image",
        image: { id: "media_1", mime_type: "image/jpeg", caption: "هاد" },
      },
      {
        from: WA_ID, id: "wamid.D", timestamp: String(SENT_S), type: "document",
        document: { id: "media_2", mime_type: "application/pdf", filename: "a.pdf" },
      },
    ],
  }));

  assert.equal(messages.length, 2);
  assert.equal(messages[0].text, "هاد");
  assert.deepEqual(messages[0].attachments, [
    { type: "image", payload: { media_id: "media_1", mime_type: "image/jpeg" } },
  ]);
  // Meta's Messenger vocabulary, so the rest of the system reads it unchanged.
  assert.equal((messages[1].attachments[0] as { type: string }).type, "file");
});

test("reads a reply the seller sent from the WhatsApp Business app as outbound", () => {
  const { messages } = parseWebhookPayload(whatsappPayload({
    message_echoes: [{
      from: "15550000000",
      to: WA_ID,
      id: "wamid.E",
      timestamp: String(SENT_S),
      type: "text",
      text: { body: "15 دينار" },
    }],
  }, "smb_message_echoes"));

  assert.equal(messages.length, 1);
  assert.equal(messages[0].direction, "outbound");
  assert.equal(messages[0].customerExternalId, WA_ID);
  assert.equal(messages[0].text, "15 دينار");
});

test("skips WhatsApp delivery statuses and reactions without storing them", () => {
  const { messages, skipped } = parseWebhookPayload(whatsappPayload({
    statuses: [{ id: "wamid.A", status: "read", timestamp: String(SENT_S), recipient_id: WA_ID }],
    messages: [{
      from: WA_ID, id: "wamid.R", timestamp: String(SENT_S), type: "reaction",
      reaction: { message_id: "wamid.A", emoji: "👍" },
    }],
  }));

  assert.equal(messages.length, 0);
  assert.ok(skipped.length >= 1);
});

test("survives WhatsApp payloads that are not shaped as expected", () => {
  for (const value of [{}, { messages: "x" }, { messages: [null, { id: "w" }] }]) {
    assert.doesNotThrow(() => parseWebhookPayload(whatsappPayload(value)));
    assert.equal(parseWebhookPayload(whatsappPayload(value)).messages.length, 0);
  }
  assert.equal(
    parseWebhookPayload({ object: "whatsapp_business_account", entry: [{ changes: [{ value: {} }] }] })
      .messages.length,
    0,
  );
});
// ---------------------------------------------------------------------------
// Captured from Meta, not written by us.
//
// Every other payload in this file is our idea of what Meta sends. This one is
// a real delivery, recorded from webhook_events on 15 September 2026 after a
// message was sent to the connected Page. Ids and the message id are left
// exactly as they arrived, because the point of the fixture is that nothing
// about it was cleaned up to suit the parser.
//
// If Meta changes the shape, this is the test that should fail.
// ---------------------------------------------------------------------------

const REAL_MESSENGER_DELIVERY = {
  entry: [
    {
      id: "1427711713749572",
      time: 1789503863897,
      messaging: [
        {
          sender: { id: "28847995138118550" },
          message: {
            mid:
              "m_eLEOOGcXWhMXArhPPQujKXrznN-uRXk0Ud7nmKW3VfsrDhDrojwu8ezvpirRPjvM5hLC-7ln2CUf8v4xNXqOpQ",
            text: "Test Message",
          },
          recipient: { id: "1427711713749572" },
          timestamp: 1789503862440,
        },
      ],
    },
  ],
  object: "page",
};

test("parses a real Messenger delivery captured from Meta", () => {
  const { messages, skipped } = parseWebhookPayload(REAL_MESSENGER_DELIVERY);

  assert.deepEqual(skipped, []);
  assert.equal(messages.length, 1);

  const [message] = messages;

  // entry.id is the Page, and it is the account the message belongs to. Note
  // that Meta puts the same id in recipient.id here — reading the account from
  // recipient would appear to work and would break on the first echo.
  assert.equal(message.accountExternalId, "1427711713749572");
  assert.equal(message.platform, "messenger");

  // The customer is the sender on an inbound message.
  assert.equal(message.customerExternalId, "28847995138118550");
  assert.equal(message.direction, "inbound");
  assert.equal(message.text, "Test Message");
  assert.deepEqual(message.attachments, []);

  // Meta sends milliseconds. Seconds would put this in 1970.
  assert.equal(message.sentAt, "2026-09-15T20:24:22.440Z");
});

// Also captured from Meta on 15 September 2026, same Page, same session.

const REAL_ARABIC_DELIVERY = {
  entry: [
    {
      id: "1427711713749572",
      time: 1789504252150,
      messaging: [
        {
          sender: { id: "28847995138118550" },
          message: {
            mid:
              "m_WSdXT_Azy1zqiuq9FMc_bXrznN-uRXk0Ud7nmKW3VfszKRXxul2wfee_kd6dXHZsdaKcBjXuiQfsvZ0W55YgMg",
            text: "كم سغر هذا المنتج؟",
          },
          recipient: { id: "1427711713749572" },
          timestamp: 1789504251574,
        },
      ],
    },
  ],
  object: "page",
};

const REAL_IMAGE_DELIVERY = {
  entry: [
    {
      id: "1427711713749572",
      time: 1789504254019,
      messaging: [
        {
          sender: { id: "28847995138118550" },
          message: {
            mid:
              "m_q2JedGBisE85-QUIpcbCoHrznN-uRXk0Ud7nmKW3VfsAN92dx79BuGZSinrr96_Io5FSqgxShuNzDrte8scStA",
            attachments: [
              {
                type: "image",
                payload: {
                  // Left whole on purpose. The signed query string is the part
                  // that expires, and a trimmed URL would not be the shape we
                  // actually have to handle. The test never fetches it.
                  url:
                    "https://scontent.xx.fbcdn.net/v/t1.15752-9/800421101_29333507219584310_8507343186071293518_n.png?_nc_cat=110&ccb=1-7&_nc_sid=eb2e90&_nc_ohc=ayrGh00s7K4Q7kNvwEx6ztA&_nc_oc=AdqswCkSIsxVCEqynzOYYucSKGC0OUjr6pJIUGoZIx-lLbvvPgfc_f-1zpaA-AIKJfwMVE2m59zG7C3M0YhxhXb2&_nc_ad=z-m&_nc_cid=0&_nc_zt=23&_nc_ht=scontent.xx&oh=03_Q7cD6QFI-16JxNELzBoyZcK0bcX9AuRq36KY_X1DH50kzJl_qw&oe=6AD12753",
                },
              },
            ],
          },
          recipient: { id: "1427711713749572" },
          timestamp: 1789504252847,
        },
      ],
    },
  ],
  object: "page",
};

test("preserves Arabic text from a real delivery", () => {
  const { messages, skipped } = parseWebhookPayload(REAL_ARABIC_DELIVERY);

  assert.deepEqual(skipped, []);
  assert.equal(messages.length, 1);

  // Byte-for-byte. Arabic is a primary language for this product, so a parser
  // that mangles it is not a cosmetic problem. The trailing character is the
  // Arabic question mark U+061F, not an ASCII one.
  assert.equal(messages[0].text, "كم سغر هذا المنتج؟");
  assert.equal(messages[0].text?.length, 18);
  assert.equal(messages[0].text?.at(-1), "\u061F");
});

test("reads an image attachment from a real delivery", () => {
  const { messages, skipped } = parseWebhookPayload(REAL_IMAGE_DELIVERY);

  assert.deepEqual(skipped, []);
  assert.equal(messages.length, 1);

  const [message] = messages;

  // An attachment-only message carries no text at all. Defaulting this to an
  // empty string would make the inbox show a blank message rather than an
  // image.
  assert.equal(message.text, null);
  assert.equal(message.attachments.length, 1);

  const attachment = message.attachments[0] as {
    type: string;
    payload: { url: string };
  };
  assert.equal(attachment.type, "image");
  assert.match(attachment.payload.url, /^https:\/\/scontent\..*fbcdn\.net\//);

  // The signed URL expires. Measured from this delivery, Meta gave it roughly
  // 30 days — see the note in docs/DECISIONS.md about storing versus proxying.
  assert.match(attachment.payload.url, /[?&]oe=[0-9A-F]+/);
});

const REAL_ECHO_DELIVERY = {
  entry: [
    {
      id: "1427711713749572",
      time: 1789504927820,
      messaging: [
        {
          // On an echo the Page is the sender and the customer is the
          // recipient. This is the inverse of every other case in this file,
          // and reading the customer from sender.id here would quietly file
          // the seller's own replies under a conversation with themselves.
          sender: { id: "1427711713749572" },
          message: {
            mid:
              "m_HcQ4tBJvNZxfG83qwlJBj3rznN-uRXk0Ud7nmKW3VftCu5LuqHceUiPHJn7BW0eOlJqn_HaIcDeLKn0HMkVvjA",
            text: "test 33",
            app_id: 263902037430900,
            is_echo: true,
          },
          recipient: { id: "28847995138118550" },
          timestamp: 1789504927533,
        },
      ],
    },
  ],
  object: "page",
};

test("reads a real echo of a reply sent from Meta's own apps", () => {
  const { messages, skipped } = parseWebhookPayload(REAL_ECHO_DELIVERY);

  assert.deepEqual(skipped, []);
  assert.equal(messages.length, 1);

  const [message] = messages;

  assert.equal(message.direction, "outbound");
  assert.equal(message.text, "test 33");

  // The account is still the Page, taken from entry.id rather than from
  // sender or recipient, both of which move depending on who sent the message.
  assert.equal(message.accountExternalId, "1427711713749572");

  // The customer is the recipient here, not the sender.
  assert.equal(message.customerExternalId, "28847995138118550");
});
