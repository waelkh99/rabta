import { strict as assert } from "node:assert";
import { test } from "node:test";

import { parseWebhookPayload } from "../functions/meta-webhook/parse.ts";
import {
  processMessage,
  refreshCustomerProfile,
} from "../functions/meta-webhook/process.ts";
import type { AccountRef, Store } from "../functions/meta-webhook/process.ts";
import type { CustomerProfile } from "../functions/meta-webhook/profile.ts";
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

  /** Profile state, keyed by conversation id, as the real columns hold it. */
  profiles = new Map<string, CustomerProfile & { fetchedAt: string }>();
  tokens = new Map<string, string>();
  profileAsks = 0;

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

  profileFetchedAt(conversationId: string): Promise<string | null> {
    return Promise.resolve(this.profiles.get(conversationId)?.fetchedAt ?? null);
  }

  accountToken(accountId: string): Promise<string | null> {
    return Promise.resolve(this.tokens.get(accountId) ?? null);
  }

  saveProfile(conversationId: string, profile: CustomerProfile): Promise<void> {
    this.profiles.set(conversationId, {
      ...profile,
      fetchedAt: new Date().toISOString(),
    });
    return Promise.resolve();
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

  assert.deepEqual(outcome, {
    status: "stored",
    mid: "m_1",
    conversationId: "conv_1",
    accountId: "acct_messenger_1122334455",
  });
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

// ---------------------------------------------------------------------------
// Asking Meta who the customer is
// ---------------------------------------------------------------------------

/** A stand-in for Graph that records what it was asked. */
function graph(answer: unknown, { fail = false } = {}) {
  const asked: string[] = [];

  const fetcher = ((url: string) => {
    asked.push(String(url));
    if (fail) return Promise.reject(new Error("network"));
    return Promise.resolve({ json: () => Promise.resolve(answer) } as Response);
  }) as unknown as typeof fetch;

  return { fetcher, asked };
}

async function storeInbound(store: FakeStore, mid = "m_1") {
  const message = inbound(mid, "hello");
  const outcome = await processMessage(store, message);
  return { message, outcome };
}

test("a new customer is looked up and their name stored", async () => {
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);
  store.tokens.set("acct_messenger_1122334455", "page-token");

  const { message, outcome } = await storeInbound(store);
  const { fetcher, asked } = graph({ name: "Wael K. Saleh", profile_pic: "https://x/p.jpg" });

  const result = await refreshCustomerProfile(store, message, outcome, new Date(), fetcher);

  assert.equal(result, "saved");
  assert.equal(asked.length, 1);
  assert.ok(asked[0].includes(CUSTOMER_ID), "asked about the wrong customer");
  assert.ok(asked[0].includes("page-token"), "did not use the account's token");
  assert.equal(store.profiles.get("conv_1")?.name, "Wael K. Saleh");
});

test("a second message from the same customer does not ask again", async () => {
  // The whole point of recording when we asked. A chatty customer would
  // otherwise cost a Graph call per message.
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);
  store.tokens.set("acct_messenger_1122334455", "page-token");

  const first = await storeInbound(store, "m_1");
  const answer = graph({ name: "Wael K. Saleh" });
  await refreshCustomerProfile(store, first.message, first.outcome, new Date(), answer.fetcher);

  const second = await storeInbound(store, "m_2");
  const again = graph({ name: "Wael K. Saleh" });
  const result = await refreshCustomerProfile(
    store,
    second.message,
    second.outcome,
    new Date(),
    again.fetcher,
  );

  assert.equal(result, "fresh");
  assert.equal(again.asked.length, 0, "asked Meta again for a name we already had");
});

test("a customer whose name Meta withheld is not asked about again", async () => {
  // Recording the attempt is what stops this becoming a Graph call on every
  // message forever for customers who have no readable name.
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);
  store.tokens.set("acct_messenger_1122334455", "page-token");

  const first = await storeInbound(store, "m_1");
  const nothing = graph({ id: CUSTOMER_ID });
  assert.equal(
    await refreshCustomerProfile(store, first.message, first.outcome, new Date(), nothing.fetcher),
    "saved",
  );

  const second = await storeInbound(store, "m_2");
  const again = graph({ id: CUSTOMER_ID });
  assert.equal(
    await refreshCustomerProfile(store, second.message, second.outcome, new Date(), again.fetcher),
    "fresh",
  );
  assert.equal(again.asked.length, 0);
});

test("a stale profile is asked for again", async () => {
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);
  store.tokens.set("acct_messenger_1122334455", "page-token");

  const { message, outcome } = await storeInbound(store);
  store.profiles.set("conv_1", {
    name: "Old Name",
    avatarUrl: "https://x/expired.jpg",
    fetchedAt: new Date(Date.now() - 40 * 86_400_000).toISOString(),
  });

  const { fetcher, asked } = graph({ name: "New Name", profile_pic: "https://x/fresh.jpg" });
  const result = await refreshCustomerProfile(store, message, outcome, new Date(), fetcher);

  assert.equal(result, "saved");
  assert.equal(asked.length, 1);
  assert.equal(store.profiles.get("conv_1")?.name, "New Name");
});

test("Meta being unreachable records nothing, so the next message retries", async () => {
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);
  store.tokens.set("acct_messenger_1122334455", "page-token");

  const { message, outcome } = await storeInbound(store);
  const { fetcher } = graph(null, { fail: true });

  assert.equal(
    await refreshCustomerProfile(store, message, outcome, new Date(), fetcher),
    "no-answer",
  );
  assert.equal(store.profiles.has("conv_1"), false, "recorded a failure as an answer");
});

test("an account with no token is not asked about", async () => {
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);

  const { message, outcome } = await storeInbound(store);
  const { fetcher, asked } = graph({ name: "Wael" });

  assert.equal(
    await refreshCustomerProfile(store, message, outcome, new Date(), fetcher),
    "no-token",
  );
  assert.equal(asked.length, 0, "called Meta with no token");
});

test("a message for an unconnected account is never looked up", async () => {
  // There is no conversation and no token, and asking would be a call on
  // behalf of a seller who is not ours.
  const store = new FakeStore();
  const message = inbound("m_1", "hello");
  const outcome = await processMessage(store, message);
  const { fetcher, asked } = graph({ name: "Wael" });

  assert.equal(outcome.status, "unknown-account");
  assert.equal(
    await refreshCustomerProfile(store, message, outcome, new Date(), fetcher),
    "fresh",
  );
  assert.equal(asked.length, 0);
});
