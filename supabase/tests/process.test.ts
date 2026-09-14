import { strict as assert } from "node:assert";
import { test } from "node:test";

import { parseWebhookPayload } from "../functions/meta-webhook/parse.ts";
import { processMessage } from "../functions/meta-webhook/process.ts";
import type { AccountRef, Store } from "../functions/meta-webhook/process.ts";
import type { NormalisedMessage, Platform } from "../functions/meta-webhook/parse.ts";

const PAGE_ID = "1122334455";
const CUSTOMER_ID = "9988776655";
const SENT_MS = 1_757_000_000_000;

/** In-memory stand-in with the same duplicate behaviour as the real schema. */
class FakeStore implements Store {
  accounts = new Map<string, AccountRef>();
  conversations = new Map<string, string>();
  messages = new Map<string, NormalisedMessage & { conversationId: string }>();
  conversationsCreated = 0;

  connect(platform: Platform, externalId: string, workspaceId = "ws_1"): void {
    // Keyed on platform as well as id, because the real table is unique on
    // (platform, external_id) and hands back a distinct row for each.
    this.accounts.set(`${platform}:${externalId}`, {
      id: `acct_${platform}_${externalId}`,
      workspaceId,
    });
  }

  findAccount(platform: Platform, externalId: string): Promise<AccountRef | null> {
    return Promise.resolve(this.accounts.get(`${platform}:${externalId}`) ?? null);
  }

  findOrCreateConversation(account: AccountRef, customerExternalId: string): Promise<string> {
    const key = `${account.id}:${customerExternalId}`;
    const existing = this.conversations.get(key);
    if (existing) return Promise.resolve(existing);

    const id = `conv_${this.conversations.size + 1}`;
    this.conversations.set(key, id);
    this.conversationsCreated++;
    return Promise.resolve(id);
  }

  insertMessageIfNew(
    conversationId: string,
    _workspaceId: string,
    message: NormalisedMessage,
  ): Promise<boolean> {
    // Mirrors the unique constraint on messages.mid.
    if (this.messages.has(message.mid)) return Promise.resolve(false);

    this.messages.set(message.mid, { ...message, conversationId });
    return Promise.resolve(true);
  }
}

function inbound(mid: string, text: string, sender = CUSTOMER_ID): NormalisedMessage {
  return {
    accountExternalId: PAGE_ID,
    platform: "messenger",
    customerExternalId: sender,
    mid,
    direction: "inbound",
    text,
    attachments: [],
    sentAt: new Date(SENT_MS).toISOString(),
  };
}

test("stores a message for a connected account", async () => {
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);

  const outcome = await processMessage(store, inbound("m_1", "hello"));

  assert.deepEqual(outcome, { status: "stored", mid: "m_1" });
  assert.equal(store.messages.size, 1);
  assert.equal(store.conversationsCreated, 1);
});

test("redelivery of the same message stores nothing the second time", async () => {
  // Meta retries. Without this the seller sees doubled messages and inflated
  // unread counts.
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);

  const first = await processMessage(store, inbound("m_dup", "hello"));
  const second = await processMessage(store, inbound("m_dup", "hello"));

  assert.equal(first.status, "stored");
  assert.equal(second.status, "duplicate");
  assert.equal(store.messages.size, 1);
});

test("a second message from the same customer reuses the conversation", async () => {
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);

  await processMessage(store, inbound("m_1", "hello"));
  await processMessage(store, inbound("m_2", "still there?"));

  assert.equal(store.messages.size, 2);
  assert.equal(store.conversationsCreated, 1);
});

test("different customers get different conversations", async () => {
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);

  await processMessage(store, inbound("m_1", "hello", "cust_a"));
  await processMessage(store, inbound("m_2", "hello", "cust_b"));

  assert.equal(store.conversationsCreated, 2);
});

test("the same customer id on two platforms stays separate", async () => {
  // Meta's customer ids are scoped to the account. Identical ids across
  // platforms are coincidence, not the same person, and merging them would
  // show one seller's customer inside another conversation.
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);
  store.connect("instagram", PAGE_ID);

  await processMessage(store, inbound("m_1", "hello"));
  await processMessage(store, {
    ...inbound("m_2", "hello"),
    platform: "instagram",
  });

  assert.equal(store.conversationsCreated, 2);
});

test("a message for an unconnected account is reported, not thrown", async () => {
  const store = new FakeStore();

  const outcome = await processMessage(store, inbound("m_1", "hello"));

  assert.equal(outcome.status, "unknown-account");
  assert.equal(store.messages.size, 0);
});

test("an unconnected account does not stop the rest of the batch", async () => {
  const store = new FakeStore();
  store.connect("messenger", "known_page");

  const { messages } = parseWebhookPayload({
    object: "page",
    entry: [
      {
        id: "unknown_page",
        messaging: [{
          sender: { id: CUSTOMER_ID },
          recipient: { id: "unknown_page" },
          timestamp: SENT_MS,
          message: { mid: "m_skip", text: "not ours" },
        }],
      },
      {
        id: "known_page",
        messaging: [{
          sender: { id: CUSTOMER_ID },
          recipient: { id: "known_page" },
          timestamp: SENT_MS,
          message: { mid: "m_keep", text: "ours" },
        }],
      },
    ],
  });

  const outcomes = [];
  for (const message of messages) outcomes.push(await processMessage(store, message));

  assert.deepEqual(outcomes.map((o) => o.status), ["unknown-account", "stored"]);
  assert.deepEqual([...store.messages.keys()], ["m_keep"]);
});

test("an echo is filed against the customer's conversation, not a new one", async () => {
  // The customer writes, then the seller answers from the Instagram app. Both
  // belong in one thread.
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);

  const { messages } = parseWebhookPayload({
    object: "page",
    entry: [{
      id: PAGE_ID,
      messaging: [
        {
          sender: { id: CUSTOMER_ID },
          recipient: { id: PAGE_ID },
          timestamp: SENT_MS,
          message: { mid: "m_in", text: "Do you deliver?" },
        },
        {
          sender: { id: PAGE_ID },
          recipient: { id: CUSTOMER_ID },
          timestamp: SENT_MS + 60_000,
          message: { mid: "m_out", text: "Yes we do", is_echo: true },
        },
      ],
    }],
  });

  for (const message of messages) await processMessage(store, message);

  assert.equal(store.conversationsCreated, 1);
  assert.equal(store.messages.size, 2);
  assert.equal(store.messages.get("m_out")!.direction, "outbound");
  assert.equal(
    store.messages.get("m_out")!.conversationId,
    store.messages.get("m_in")!.conversationId,
  );
});

test("an echo of our own reply does not duplicate the stored message", async () => {
  // send-message stores the outbound row using the mid Meta returns, then the
  // echo for that same message arrives by webhook moments later.
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);

  await processMessage(store, inbound("m_in", "Do you deliver?"));

  const ourReply: NormalisedMessage = {
    accountExternalId: PAGE_ID,
    platform: "messenger",
    customerExternalId: CUSTOMER_ID,
    mid: "m_reply",
    direction: "outbound",
    text: "Yes we do",
    attachments: [],
    sentAt: new Date(SENT_MS + 30_000).toISOString(),
  };

  const sent = await processMessage(store, ourReply);
  const echoed = await processMessage(store, ourReply);

  assert.equal(sent.status, "stored");
  assert.equal(echoed.status, "duplicate");
  assert.equal(store.messages.size, 2);
});
