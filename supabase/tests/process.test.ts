import { strict as assert } from "node:assert";
import { test } from "node:test";

import { parseWebhookPayload } from "../functions/meta-webhook/parse.ts";
import {
  autoReply,
  processMessage,
  refreshCustomerProfile,
} from "../functions/meta-webhook/process.ts";
import type {
  AccountRef,
  AiContext,
  AiPrompt,
  Store,
} from "../functions/meta-webhook/process.ts";
import { HANDOVER_LINE, MAX_CONSECUTIVE_AI } from "../functions/meta-webhook/ai.ts";
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

  // -- the AI path -----------------------------------------------------------

  /** Overridden per test. Defaults to a workspace with the AI switched on. */
  context: AiContext | null = {
    workspaceId: "ws_1",
    enabled: true,
    customerName: "سارة",
    windowExpiresAt: new Date(SENT_MS + 12 * 3_600_000).toISOString(),
    lastMessageAt: new Date(SENT_MS).toISOString(),
    lastSellerReplyAt: null,
    consecutiveAiReplies: 0,
    aiRepliesThisMonth: 0,
  };

  prompt: AiPrompt = {
    shop: {
      currency: "د.ا",
      deliveryNote: null,
      locations: null,
      hours: null,
      about: null,
      priceStance: "notify" as const,
    },
    zones: [{ name: "عمّان", fee: "2.000" }],
    products: [{ name: "فستان أحمر", price: "25.500", description: null, inStock: true }],
    examples: ["اهلا وسهلا"],
    turns: [{ inbound: true, text: "قديش سعر الفستان؟" }],
  };

  /** Mirrors the conditional update: the first caller wins, the rest do not. */
  claimed = new Set<string>();
  claims = 0;
  finished: { state: string; reason: string | null; code: string | null }[] = [];
  aiReplies: { mid: string; text: string }[] = [];

  aiContext(_conversationId: string): Promise<AiContext | null> {
    return Promise.resolve(this.context);
  }

  /**
   * Mirrors the real predicate: a run that started before the message it is
   * answering has not considered it, so it may claim. A second run for the
   * same message finds the timestamp already past it and cannot.
   */
  claimedAt = new Map<string, string>();

  claimAiRun(conversationId: string, now: Date, answering: string): Promise<boolean> {
    this.claims++;

    const held = this.claimedAt.get(conversationId);
    const stale = new Date(now.getTime() - 2 * 60_000).toISOString();
    const free = held === undefined || held < stale || held < answering;

    if (!free) return Promise.resolve(false);

    this.claimedAt.set(conversationId, now.toISOString());
    this.claimed.add(conversationId);
    return Promise.resolve(true);
  }

  aiPrompt(_workspaceId: string, _conversationId: string): Promise<AiPrompt> {
    return Promise.resolve(this.prompt);
  }

  insertAiReply(
    _conversationId: string,
    _workspaceId: string,
    mid: string,
    text: string,
  ): Promise<void> {
    this.aiReplies.push({ mid, text });
    return Promise.resolve();
  }

  finishAiRun(
    _conversationId: string,
    state: "answered" | "escalated",
    reason: string | null,
    code: string | null,
  ): Promise<void> {
    this.finished.push({ state, reason, code });
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

// ---------------------------------------------------------------------------
// Answering the customer
//
// Every path through autoReply, exercised against the fake store. These also
// stand in for a type check: nothing in this project typechecks the Edge
// Functions, so a Store the fake does not really satisfy has to be caught by
// running it.
// ---------------------------------------------------------------------------

/** The model and Meta, both faked. Records what each was sent. */
function assistant(decision: unknown, { sendFails = false, metaError = false } = {}) {
  const calls: string[] = [];
  /** The request bodies, so a test can assert what reached the model. */
  const sent: string[] = [];

  const fetcher = ((url: string, init?: RequestInit) => {
    const target = String(url);
    calls.push(target);
    if (typeof init?.body === "string") sent.push(init.body);

    if (target.includes("anthropic")) {
      return Promise.resolve({
        ok: true,
        status: 200,
        json: () =>
          Promise.resolve({
            content: [{ type: "text", text: JSON.stringify(decision) }],
            usage: { cache_read_input_tokens: 9000 },
          }),
      } as Response);
    }

    if (sendFails) return Promise.reject(new Error("network"));

    return Promise.resolve({
      json: () =>
        Promise.resolve(
          metaError
            ? { error: { message: "outside window", code: 10 } }
            : { message_id: "mid_from_meta" },
        ),
    } as Response);
  }) as unknown as typeof fetch;

  return { fetcher, calls, sent };
}

/** No waiting, and a clock fixed just after the message arrived. */
const immediately = (fetcher: typeof fetch) => ({
  fetcher,
  wait: () => Promise.resolve(),
  clock: () => new Date(SENT_MS + 30_000),
});

async function storedInbound(store: FakeStore, mid = "ai_1", text = "بكم الفستان؟") {
  store.connect("messenger", PAGE_ID);
  const message = inbound(mid, text);
  const outcome = await processMessage(store, message);
  return { message, outcome };
}

test("a customer asking a catalog question gets an answer", async () => {
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  const { message, outcome } = await storedInbound(store);

  const { fetcher, calls } = assistant({ handOver: false, text: "25.500 دينار" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "answered");
  assert.deepEqual(store.aiReplies, [{ mid: "mid_from_meta", text: "25.500 دينار" }]);
  assert.deepEqual(store.finished, [{ state: "answered", reason: null, code: null }]);

  // Stored under Meta's id, which is what stops the echo of our own reply
  // arriving through the webhook and appearing twice.
  assert.ok(calls.some((url) => url.includes("anthropic")));
  assert.ok(calls.some((url) => url.includes("graph.facebook.com")));
});

test("the AI stays silent when the seller has not switched it on", async () => {
  // The state every workspace starts in, so this is the common path.
  const store = new FakeStore();
  store.context = { ...store.context!, enabled: false };
  const { message, outcome } = await storedInbound(store);

  const { fetcher, calls } = assistant({ handOver: false, text: "anything" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "off");
  assert.equal(calls.length, 0, "nothing may be spent on a workspace with the AI off");
  assert.equal(store.finished.length, 0, "and nothing is marked on the conversation");
});

test("no API key is the same as the AI being off", async () => {
  const store = new FakeStore();
  const { message, outcome } = await storedInbound(store);

  const { fetcher, calls } = assistant({ handOver: false, text: "hi" });
  const result = await autoReply(store, "", message, outcome, immediately(fetcher));

  assert.equal(result, "off");
  assert.equal(calls.length, 0);
});

test("a redelivered message is not answered again", async () => {
  // Meta retries, and answering twice would send the customer the same
  // sentence twice, which cannot be repaired afterwards.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  const { message, outcome } = await storedInbound(store);

  const { fetcher } = assistant({ handOver: false, text: "25.500" });
  await autoReply(store, "key", message, outcome, immediately(fetcher));

  const again = await processMessage(store, message);
  assert.equal(again.status, "duplicate");

  const second = await autoReply(store, "key", message, again, immediately(fetcher));
  assert.equal(second, "not-applicable");
  assert.equal(store.aiReplies.length, 1, "the customer was written to once");
});

test("the echo of our own reply is not answered", async () => {
  const store = new FakeStore();
  store.connect("messenger", PAGE_ID);

  const echo: NormalisedMessage = { ...inbound("echo_1", "25000"), direction: "outbound" };
  const outcome = await processMessage(store, echo);

  const { fetcher, calls } = assistant({ handOver: false, text: "again" });
  const result = await autoReply(store, "key", echo, outcome, immediately(fetcher));

  assert.equal(result, "not-applicable");
  assert.equal(calls.length, 0);
});

test("a burst of messages produces one reply, not three", async () => {
  // The customer sends three fragments. Each delivery starts its own run; the
  // ones that wake to find a newer message stand down.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  store.connect("messenger", PAGE_ID);

  const first = inbound("burst_1", "هلو");
  const outcomeFirst = await processMessage(store, first);

  // By the time this run wakes, a later fragment has landed.
  store.context = {
    ...store.context!,
    lastMessageAt: new Date(SENT_MS + 5_000).toISOString(),
  };

  const { fetcher, calls } = assistant({ handOver: false, text: "25.500" });
  const result = await autoReply(store, "key", first, outcomeFirst, immediately(fetcher));

  assert.equal(result, "superseded");
  assert.equal(calls.length, 0, "the model is not asked about a half-finished thought");
  assert.equal(store.claims, 0, "and the conversation is not claimed");
});

test("two runs for the same conversation cannot both answer", async () => {
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  const { message, outcome } = await storedInbound(store);

  const { fetcher } = assistant({ handOver: false, text: "25.500" });

  const first = await autoReply(store, "key", message, outcome, immediately(fetcher));
  const second = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(first, "answered");
  assert.equal(second, "busy");
  assert.equal(store.aiReplies.length, 1);
});

test("a customer's follow-up is answered, not swallowed by the last run", async () => {
  // The bug this pins: the assistant answered "مرحبا", the customer wrote
  // again 36 seconds later, and that message was silently dropped because the
  // conversation was still inside the claim window. It looked, from outside,
  // as though the assistant had died mid-conversation.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  store.connect("messenger", PAGE_ID);

  const first = inbound("follow_1", "مرحبا");
  const firstOutcome = await processMessage(store, first);

  const { fetcher } = assistant({ handOver: false, text: "مرحبا، كيف أساعدك؟" });
  assert.equal(
    await autoReply(store, "key", first, firstOutcome, immediately(fetcher)),
    "answered",
  );

  // Half a minute later, well inside the window the old claim held.
  const laterMs = SENT_MS + 36_000;
  const second: NormalisedMessage = {
    ...inbound("follow_2", "شفت عندكم فستان"),
    sentAt: new Date(laterMs).toISOString(),
  };
  const secondOutcome = await processMessage(store, second);

  store.context = { ...store.context!, lastMessageAt: new Date(laterMs).toISOString() };

  const { fetcher: again } = assistant({ handOver: false, text: "عندنا فستان أحمر" });
  const result = await autoReply(store, "key", second, secondOutcome, {
    fetcher: again,
    wait: () => Promise.resolve(),
    clock: () => new Date(laterMs + 30_000),
  });

  assert.equal(result, "answered", "the follow-up must be answered too");
  assert.equal(store.aiReplies.length, 2);
});

test("a guard that fires hands over instead of asking the model", async () => {
  // The seller is at their desk, so the guard is cheaper than a model call and
  // the customer is about to be answered by a person anyway.
  const store = new FakeStore();
  store.context = { ...store.context!, lastSellerReplyAt: new Date(SENT_MS).toISOString() };
  const { message, outcome } = await storedInbound(store);

  const { fetcher, calls } = assistant({ handOver: false, text: "hello" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "escalated");
  assert.equal(calls.length, 0, "a guard must be cheaper than a model call");
  assert.deepEqual(store.finished, [
    { state: "escalated", reason: "seller_present", code: "seller_present" },
  ]);
  assert.equal(store.aiReplies.length, 0, "the seller is here; no line is needed");
});

test("running out of replies tells the customer instead of going quiet", async () => {
  // This is the change. A conversation that hit the streak cap used to simply
  // stop, with nothing sent, which from the customer's side is identical to
  // the assistant having died.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  store.context = { ...store.context!, consecutiveAiReplies: MAX_CONSECUTIVE_AI };
  const { message, outcome } = await storedInbound(store);

  const { fetcher, calls } = assistant({ handOver: false, text: "never asked for" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "escalated");
  assert.equal(calls.length, 1, "Meta was asked to send, the model was not asked anything");
  assert.equal(store.aiReplies.length, 1);
  assert.equal(store.aiReplies[0].text, HANDOVER_LINE.arabic);
  assert.deepEqual(store.finished, [
    { state: "escalated", reason: "ai_streak", code: "ai_streak" },
  ]);
});

test("the hand-over line is said once, not on every message after it", async () => {
  // The line is itself an AI reply, so it pushes the streak one past the cap.
  // A customer who keeps writing must not keep receiving the same sentence.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  store.context = { ...store.context!, consecutiveAiReplies: MAX_CONSECUTIVE_AI + 1 };
  const { message, outcome } = await storedInbound(store);

  const { fetcher } = assistant({ handOver: false, text: "never asked for" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "escalated");
  assert.equal(store.aiReplies.length, 0, "they have already been told");
});

test("an English customer is handed over in English", async () => {
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  store.connect("messenger", PAGE_ID);
  store.context = { ...store.context!, consecutiveAiReplies: MAX_CONSECUTIVE_AI };

  const message = inbound("en_1", "do you have it in blue?");
  const outcome = await processMessage(store, message);

  const { fetcher } = assistant({ handOver: false, text: "unused" });
  await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(store.aiReplies[0].text, HANDOVER_LINE.english);
});

test("nothing is said when the send would fail anyway", async () => {
  // Outside the window Meta refuses everything, so a hand-over line would burn
  // a Graph call to produce a message nobody receives.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  store.context = {
    ...store.context!,
    windowExpiresAt: new Date(SENT_MS - 1000).toISOString(),
    consecutiveAiReplies: MAX_CONSECUTIVE_AI,
  };
  const { message, outcome } = await storedInbound(store);

  const { fetcher, calls } = assistant({ handOver: false, text: "unused" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "escalated");
  assert.equal(calls.length, 0);
  assert.equal(store.aiReplies.length, 0);
  assert.deepEqual(store.finished, [
    { state: "escalated", reason: "window_closed", code: "window_closed" },
  ]);
});

test("the model handing over still answers the customer", async () => {
  // The heart of it. Answering and handing over used to be alternatives, so a
  // customer who asked one answerable thing and one unanswerable one got
  // nothing at all.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");

  // The customer raised the discount, so the assistant may say the word back.
  // Without that it would be a promise nobody made and would be held — which
  // is the claim check behaving correctly, and is why the turns matter here.
  store.prompt = {
    ...store.prompt,
    turns: [{ inbound: true, text: "قديش الفستان؟ وفي خصم؟" }],
  };

  const { message, outcome } = await storedInbound(store);

  const { fetcher } = assistant({
    text: "الفستان 25.5. بخصوص الخصم، صاحب المحل رح يرد عليك",
    handOver: true,
    reason: "wants a discount",
  });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "escalated");
  assert.deepEqual(store.finished, [
    { state: "escalated", reason: "wants a discount", code: "assistant" },
  ]);
  assert.equal(store.aiReplies.length, 1, "the customer hears back even so");
  assert.match(store.aiReplies[0].text, /25\.5/);
});

test("an answer the model could not produce still says something", async () => {
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  const { message, outcome } = await storedInbound(store);

  const { fetcher } = assistant({ nonsense: true });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "escalated");

  // The code is what the seller's row reads; the reason is the detail behind
  // it, which here is whatever nonsense came back, kept for `npm run assistant`.
  assert.equal(store.finished.length, 1);
  assert.equal(store.finished[0].state, "escalated");
  assert.equal(store.finished[0].code, "unusable");
  assert.equal(store.aiReplies[0].text, HANDOVER_LINE.arabic);
});

test("an invented price never reaches the customer", async () => {
  // The catalog says 25.500. The model says 19.750. Nothing is sent.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  const { message, outcome } = await storedInbound(store);

  const { fetcher, calls } = assistant({ handOver: false, text: "19.750 دينار" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "escalated");
  assert.match(store.finished[0].reason ?? "", /never gave it/);
  assert.equal(store.finished[0].code, "ungrounded");

  // The invented number is what must not reach them. Something does — the
  // fixed hand-over line, which carries no numbers at all.
  assert.equal(store.aiReplies.length, 1);
  assert.equal(store.aiReplies[0].text, HANDOVER_LINE.arabic);
  assert.ok(
    !calls.some((url) => url.includes("19.750")),
    "the invented price was never sent",
  );
});

test("the customer's name travels from the conversation row to the model", async () => {
  // It sat in the database unused. Without it the model had no signal for
  // which grammatical gender to address an Arabic customer in.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  store.context = { ...store.context!, customerName: "سارة الخطيب" };
  const { message, outcome } = await storedInbound(store);

  const { fetcher, sent } = assistant({ handOver: false, text: "أهلين" });
  await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.ok(
    sent.some((body) => body.includes("سارة الخطيب")),
    "the name must reach the request",
  );
});

test("a promise the shop never made never reaches the customer", async () => {
  // The catalog says nothing about when anything arrives. The number check is
  // blind to this — "بكرا" has no digits — which is exactly why it exists.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  const { message, outcome } = await storedInbound(store);

  const { fetcher } = assistant({ handOver: false, text: "أكيد، بنوصلك بكرا" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "escalated");
  assert.match(store.finished[0].reason ?? "", /promise the shop never made/);
  assert.equal(store.finished[0].code, "ungrounded");

  // And they are still told something, rather than left waiting.
  assert.equal(store.aiReplies.length, 1);
  assert.equal(store.aiReplies[0].text, HANDOVER_LINE.arabic);
});

test("a promise the shop DID make goes through untouched", async () => {
  // Otherwise the guard withholds the shop's own words from its own customer.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  store.prompt = {
    ...store.prompt,
    shop: { ...store.prompt.shop!, deliveryNote: "بنوصل بكرا لعمّان" },
  };
  const { message, outcome } = await storedInbound(store);

  const { fetcher } = assistant({ handOver: false, text: "أكيد، بنوصلك بكرا" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "answered");
  assert.equal(store.aiReplies[0].text, "أكيد، بنوصلك بكرا");
});

test("emoji are tidied rather than held back", async () => {
  // Unlike an invented fact. Removing an emoji costs the customer nothing, so
  // withholding the whole reply over one would be the wrong trade.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  const { message, outcome } = await storedInbound(store);

  const { fetcher } = assistant({ handOver: false, text: "تمام 😍 خدي وقتك 🌸🌸" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "answered");
  assert.equal(store.aiReplies[0].text, "تمام خدي وقتك 🌸");
});

test("a reply too long for Instagram escalates rather than being rejected", async () => {
  const store = new FakeStore();
  store.tokens.set(`acct_instagram_${PAGE_ID}`, "page-token");
  store.connect("instagram", PAGE_ID);

  const message: NormalisedMessage = { ...inbound("ig_1", "بكم؟"), platform: "instagram" };
  const outcome = await processMessage(store, message);

  const { fetcher } = assistant({ handOver: false, text: "ا".repeat(1200) });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "escalated");
  assert.match(store.finished[0].reason ?? "", /too_long/);
  assert.equal(store.finished[0].code, "ungrounded");

  // Meta would have rejected the long one and the customer would have received
  // nothing. The hand-over line fits.
  assert.equal(store.aiReplies.length, 1);
  assert.equal(store.aiReplies[0].text.length < 1000, true);
});

test("Meta refusing the send leaves the conversation with the seller", async () => {
  // The window closed between our check and the call. No message row is
  // written for something the customer never received.
  const store = new FakeStore();
  store.tokens.set(`acct_messenger_${PAGE_ID}`, "page-token");
  const { message, outcome } = await storedInbound(store);

  const { fetcher } = assistant({ handOver: false, text: "25.500" }, { metaError: true });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "escalated");
  assert.equal(store.aiReplies.length, 0, "nothing is stored that was not sent");
  assert.match(store.finished[0].reason ?? "", /send window_closed/);
  assert.equal(store.finished[0].code, "not_sent");
});

test("an account with no token escalates rather than throwing", async () => {
  const store = new FakeStore();
  const { message, outcome } = await storedInbound(store);

  const { fetcher } = assistant({ handOver: false, text: "25.500" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "escalated");
  assert.match(store.finished[0].reason ?? "", /token/);
  assert.equal(store.finished[0].code, "not_sent");
});

test("the model being unreachable marks nothing, so the next message retries", async () => {
  const store = new FakeStore();
  const { message, outcome } = await storedInbound(store);

  const fetcher = (() => Promise.reject(new Error("network"))) as unknown as typeof fetch;
  const result = await autoReply(store, "key", message, outcome, {
    fetcher,
    wait: () => Promise.resolve(),
    clock: () => new Date(SENT_MS + 30_000),
  });

  assert.equal(result, "failed");
  assert.equal(store.finished.length, 0, "an unreachable model is not an escalation");
});

test("a message for an account we do not hold is left alone", async () => {
  const store = new FakeStore();
  const message = inbound("orphan_1", "hello");
  const outcome = await processMessage(store, message);

  assert.equal(outcome.status, "unknown-account");

  const { fetcher, calls } = assistant({ handOver: false, text: "hi" });
  const result = await autoReply(store, "key", message, outcome, immediately(fetcher));

  assert.equal(result, "not-applicable");
  assert.equal(calls.length, 0);
});
