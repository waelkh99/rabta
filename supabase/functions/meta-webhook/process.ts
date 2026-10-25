// Turning a normalised message into stored rows.
//
// The logic here is deliberately separated from Supabase's query builder by a
// narrow interface, so the rules that matter — routing to the right account,
// and surviving redelivery — can be tested without a database.

import type { NormalisedMessage, Platform } from "./parse.ts";
import {
  type CustomerProfile,
  profileIsStale,
  profileRequest,
  readProfile,
} from "./profile.ts";
import {
  ask,
  attachmentTurn,
  claimsAreGrounded,
  type DeliveryZone,
  type EscalationCode,
  guard,
  HANDOVER_LINE,
  isSpoken,
  mentionsPhoto,
  MODEL,
  type Usage,
  usageCost,
  numbersAreGrounded,
  type GuideSteps,
  type Offer,
  photosMissing,
  photosToSend,
  type Product,
  readsAsArabic,
  type ReplyContext,
  renderFacts,
  type Shop,
  tidyEmoji,
  todayInAmman,
  type Turn,
  wordedOfferPrices,
} from "./ai.ts";
// Imported across function directories rather than copied. The CLI bundles the
// entrypoint's whole module graph, which is why send-message can already
// import ../_shared/origins.ts. These are pure and already tested.
import { checkText, GRAPH, readSendResult, sendRequest, tokenExpired } from "../send-message/send.ts";

export interface AccountRef {
  id: string;
  workspaceId: string;
}

export interface Store {
  /** Null when the account is not connected here. */
  findAccount(platform: Platform, externalId: string): Promise<AccountRef | null>;

  /** Returns the conversation id, creating the conversation if needed. */
  findOrCreateConversation(
    account: AccountRef,
    customerExternalId: string,
  ): Promise<string>;

  /**
   * Must not raise on a duplicate `mid`, and must not re-run any side effect
   * for one. Returns whether a row was actually inserted.
   */
  insertMessageIfNew(
    conversationId: string,
    workspaceId: string,
    message: NormalisedMessage,
  ): Promise<boolean>;

  /** When Meta was last asked who this customer is. Null means never. */
  profileFetchedAt(conversationId: string): Promise<string | null>;

  /** The account's own token, which is what Meta answers a profile ask for. */
  accountToken(accountId: string): Promise<string | null>;

  /**
   * Records what Meta said, including when it said nothing — so a customer
   * whose name is withheld is not looked up again on every message.
   */
  saveProfile(conversationId: string, profile: CustomerProfile): Promise<void>;

  /**
   * Meta says this account's token is dead. Marked so the seller is told to
   * reconnect, rather than left wondering why nobody writes any more.
   */
  markNeedsReconnect(accountId: string): Promise<void>;

  /** Keeps a file a customer sent, and returns the URL it can be read at. */
  saveMedia(path: string, bytes: Uint8Array, contentType: string): Promise<string>;

  /** Everything the guards need, in one read. Null when the row has gone. */
  aiContext(conversationId: string): Promise<AiContext | null>;

  /**
   * Takes the conversation for one AI run, or returns false because another
   * run already holds it. A conditional update, not a flag.
   *
   * `answering` is the timestamp of the message being answered: a run that
   * started before it cannot have considered it, so the claim is allowed.
   * Without that, a follow-up arriving inside the stale window was dropped
   * without a trace — seen in production 36 seconds after a reply.
   */
  claimAiRun(conversationId: string, now: Date, answering: string): Promise<boolean>;

  /** The catalog, the shop's own voice, and the conversation so far. */
  aiPrompt(workspaceId: string, conversationId: string): Promise<AiPrompt>;

  /**
   * Stores the AI's reply under the id Meta returned, so its echo is a
   * duplicate. A photo is stored with null text and its attachment, in the
   * shape Meta itself delivers, so the inbox shows it like any other.
   */
  insertAiReply(
    conversationId: string,
    workspaceId: string,
    mid: string,
    text: string | null,
    attachments?: unknown[],
  ): Promise<void>;

  /** What a model call cost, for the admin screen. Optional: tests omit it. */
  recordUsage?(workspaceId: string, kind: "reply" | "outcome", usage: Usage): Promise<void>;

  /** Records what the AI did, which is what the seller sees on the row. */
  finishAiRun(
    conversationId: string,
    state: "answered" | "escalated",
    reason: string | null,
    code: EscalationCode | null,
  ): Promise<void>;
}

export interface AiContext extends ReplyContext {
  workspaceId: string;
  /**
   * What Meta says this customer is called. Read here rather than in aiPrompt
   * because the conversation row is already being fetched, so it costs nothing.
   */
  customerName: string | null;
  /**
   * The conversation's newest message. Compared against the message that
   * triggered this run: if it has moved, a later delivery owns the burst and
   * this run steps aside rather than answering a half-finished thought.
   */
  lastMessageAt: string | null;
}

export interface AiPrompt {
  shop: Shop | null;
  zones: DeliveryZone[];
  products: Product[];
  /** Every offer; renderFacts writes only those running today. */
  offers?: Offer[];
  examples: string[];
  turns: Turn[];
}

export type Outcome =
  | { status: "stored"; mid: string; conversationId: string; accountId: string; workspaceId: string }
  | { status: "duplicate"; mid: string; conversationId: string; accountId: string; workspaceId: string }
  | { status: "unknown-account"; mid: string; accountExternalId: string };

export async function processMessage(
  store: Store,
  message: NormalisedMessage,
  fetcher: typeof fetch = fetch,
): Promise<Outcome> {
  const account = await store.findAccount(message.platform, message.accountExternalId);

  // Meta can deliver events for an account we no longer hold — a seller
  // disconnecting, or a Page subscribed to the app but not set up here. Not an
  // error, and it must not stop the rest of the batch.
  if (!account) {
    return {
      status: "unknown-account",
      mid: message.mid,
      accountExternalId: message.accountExternalId,
    };
  }

  if (message.platform === "whatsapp") {
    message = await keepWhatsAppMedia(store, account, message, fetcher);
  }

  const conversationId = await store.findOrCreateConversation(
    account,
    message.customerExternalId,
  );

  const inserted = await store.insertMessageIfNew(
    conversationId,
    account.workspaceId,
    message,
  );

  return {
    status: inserted ? "stored" : "duplicate",
    mid: message.mid,
    conversationId,
    accountId: account.id,
    workspaceId: account.workspaceId,
  };
}

const EXTENSIONS: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "video/mp4": "mp4",
  "audio/ogg": "ogg",
  "audio/mpeg": "mp3",
  "application/pdf": "pdf",
};

/**
 * WhatsApp sends a media id, not a URL, and fetching it needs the account's
 * token — so neither the app nor Meta's own image fetch could use it as it
 * comes. Each file is downloaded once and kept in our storage, and the
 * attachment gains a `payload.url` in the same place Messenger's carries one,
 * so the inbox and the assistant read it unchanged.
 *
 * A file that cannot be fetched leaves the attachment without a URL: the
 * message is still stored, and the seller sees that something was sent.
 *
 * ponytail: downloaded before the duplicate check, so a redelivered message
 * stores its file twice. Rare and small; check the mid first if it ever shows.
 */
async function keepWhatsAppMedia(
  store: Store,
  account: AccountRef,
  message: NormalisedMessage,
  fetcher: typeof fetch,
): Promise<NormalisedMessage> {
  const wanted = message.attachments.some((a) => (a as { payload?: { media_id?: string } })?.payload?.media_id);
  if (!wanted) return message;

  const token = await store.accountToken(account.id);
  if (!token) return message;
  const headers = { authorization: `Bearer ${token}` };

  const attachments = await Promise.all(message.attachments.map(async (raw) => {
    const attachment = raw as { type: string; payload?: { media_id?: string; mime_type?: string } };
    const id = attachment.payload?.media_id;
    if (!id) return raw;

    try {
      const meta = await fetcher(`${GRAPH}/${encodeURIComponent(id)}`, { headers });
      const info = await meta.json() as { url?: string; mime_type?: string };
      if (!meta.ok || !info.url) return raw;

      const file = await fetcher(info.url, { headers });
      if (!file.ok) return raw;

      const contentType = info.mime_type ?? attachment.payload?.mime_type ?? "application/octet-stream";
      const extension = EXTENSIONS[contentType.split(";")[0]] ?? "bin";
      const url = await store.saveMedia(
        `${account.workspaceId}/${crypto.randomUUID()}.${extension}`,
        new Uint8Array(await file.arrayBuffer()),
        contentType,
      );
      return { ...attachment, payload: { ...attachment.payload, url } };
    } catch {
      return raw;
    }
  }));

  return { ...message, attachments };
}

/** What asking Meta about a customer came to. Returned so it can be logged. */
export type ProfileOutcome =
  | "fresh" // what we hold is recent enough
  | "saved" // asked, and recorded the answer
  | "no-token" // the account has no usable token
  | "token-dead" // Meta says the token no longer works; the account is marked
  | "no-answer"; // Meta errored, or could not be reached

/**
 * Asks Meta who this customer is, when it is worth asking.
 *
 * Runs after the 200 has gone back to Meta, so the extra call costs the seller
 * nothing and costs Meta no retry. It is also why a failure here must never
 * throw: a name we could not fetch is not a reason to lose the message, which
 * is already stored by the time this runs.
 *
 * `fetcher` is injected so the decisions can be tested without a network.
 */
export async function refreshCustomerProfile(
  store: Store,
  message: NormalisedMessage,
  outcome: Outcome,
  now: Date = new Date(),
  fetcher: typeof fetch = fetch,
): Promise<ProfileOutcome> {
  if (outcome.status === "unknown-account") return "fresh";

  const fetchedAt = await store.profileFetchedAt(outcome.conversationId);
  if (!profileIsStale(fetchedAt, now)) return "fresh";

  // WhatsApp has no profile to ask for: the name the customer gave WhatsApp
  // arrives with every message, and there is no photo.
  if (message.platform === "whatsapp") {
    if (!message.customerName) return "no-answer";
    await store.saveProfile(outcome.conversationId, { name: message.customerName, avatarUrl: null });
    return "saved";
  }

  const token = await store.accountToken(outcome.accountId);
  if (!token) return "no-token";

  const url = profileRequest(message.platform, message.customerExternalId, token);

  let answer: unknown = null;
  try {
    answer = await fetcher(url).then((response) => response.json());
  } catch {
    // Meta unreachable, or an answer that was not JSON. Left unrecorded so the
    // next message tries again.
    return "no-answer";
  }

  // The one place the receiving side talks to Meta with the seller's token, so
  // the one place it can notice the token has died.
  if (tokenExpired(answer)) {
    await store.markNeedsReconnect(outcome.accountId);
    return "token-dead";
  }

  const profile = readProfile(answer);
  if (!profile) return "no-answer";

  await store.saveProfile(outcome.conversationId, profile);
  return "saved";
}

// ---------------------------------------------------------------------------
// Answering the customer
// ---------------------------------------------------------------------------

/**
 * How long to wait before answering.
 *
 * Customers send three fragments in a row — "hi", "is this available", "the
 * red one" — and answering the first is both more expensive and worse manners
 * than answering the lot. Each delivery starts its own wait; whichever wakes
 * up last finds its message still newest and takes the conversation, and the
 * others stand down.
 *
 * Wall clock, not CPU, so it sits well inside the Edge Function budget. If the
 * isolate is recycled mid-wait nothing is sent, the conversation stays in the
 * seller's waiting group, and they answer it themselves. Silence is the right
 * way for this to fail.
 */
export const DEBOUNCE_MS = 30_000;

/**
 * Whether the assistant may answer in this conversation: the shop has it on,
 * and the seller has not taken this one over. A missing value is off, never
 * on — every workspace starts with the assistant switched off.
 */
export function assistantOn(shopEnabled: unknown, paused: unknown): boolean {
  return shopEnabled === true && paused !== true;
}

/** What the AI did, for the log. */
export type AutoReplyOutcome =
  | "not-applicable" // an echo, a duplicate, or an account we do not hold
  | "off" // the seller has not switched it on
  | "superseded" // a newer message arrived; another run owns this burst
  | "busy" // another run already holds this conversation
  | "escalated"
  | "answered"
  | "failed";

/**
 * Answers a customer, or hands the conversation back.
 *
 * Runs after the 200 has gone to Meta, alongside the profile refresh, and must
 * never throw for the same reason: the message is already stored, and losing
 * it over a failed reply would be a poor trade.
 *
 * `fetcher` and `wait` are injected so every decision here is testable without
 * a network and without actually waiting thirty seconds.
 */
export async function autoReply(
  store: Store,
  apiKey: string,
  message: NormalisedMessage,
  outcome: Outcome,
  options: {
    clock?: () => Date;
    fetcher?: typeof fetch;
    wait?: (ms: number) => Promise<void>;
    /** Needed only for an organisation-level key, which names no workspace. */
    workspaceId?: string;
  } = {},
): Promise<AutoReplyOutcome> {
  const clock = options.clock ?? (() => new Date());
  const fetcher = options.fetcher ?? fetch;
  const wait = options.wait ?? ((ms: number) => new Promise((done) => setTimeout(done, ms)));
  const workspaceId = options.workspaceId ?? "";

  // Only a genuinely new inbound message is worth answering. A duplicate is a
  // redelivery of something already handled, and an echo is the seller's own
  // reply coming back.
  if (outcome.status !== "stored") return "not-applicable";
  if (message.direction !== "inbound") return "not-applicable";

  if (!apiKey) return "off";

  await wait(DEBOUNCE_MS);

  const context = await store.aiContext(outcome.conversationId);
  if (!context) return "not-applicable";

  // Something arrived while we waited. Whoever delivered it is now running
  // this same code and will find its own message newest.
  if (context.lastMessageAt && context.lastMessageAt > message.sentAt) {
    return "superseded";
  }

  const now = clock();
  const blocked = guard(context, now);

  // The common case by far, and the one that must stay free: almost every
  // workspace has this switched off. Nothing is written and nothing is marked,
  // because a conversation the AI was never going to touch is not escalated.
  if (blocked === "disabled") return "off";

  if (!await store.claimAiRun(outcome.conversationId, now, message.sentAt)) {
    return "busy";
  }

  /**
   * Sends a message to the customer and records it under the id Meta returned,
   * so the echo arriving a moment later is a duplicate rather than a second
   * bubble.
   *
   * One helper because there are three things worth sending — the model's
   * reply, a product photo, and the hand-over line — and duplicating a Graph
   * send is how they quietly stop behaving the same way.
   */
  const send = async (
    content: string | { image: string; product: string },
  ): Promise<SendOutcome> => {
    const token = await store.accountToken(outcome.accountId);
    if (!token) return { sent: false, retry: false, reason: "no access token" };

    const request = sendRequest(
      message.accountExternalId,
      message.customerExternalId,
      typeof content === "string" ? content : { image: content.image },
      token,
      message.platform,
    );

    let sent: unknown;
    try {
      sent = await fetcher(request.url, request.init).then((response) => response.json());
    } catch {
      // Meta unreachable. Nothing is marked, the claim ages out, and the
      // customer's next message gets a fresh attempt.
      return { sent: false, retry: true, reason: "send unreachable" };
    }

    const result = readSendResult(sent);

    // Most likely the window closed in the gap. No message row is written for
    // something the customer never received.
    if ("refusal" in result) {
      return { sent: false, retry: false, reason: `send ${result.refusal}` };
    }

    if (typeof content === "string") {
      await store.insertAiReply(outcome.conversationId, context.workspaceId, result.mid, content);
    } else {
      // The product's name travels with the photo, so the next turn can see
      // which one was already sent — see attachmentTurn.
      await store.insertAiReply(outcome.conversationId, context.workspaceId, result.mid, null, [
        { type: "image", payload: { url: content.image }, product: content.product },
      ]);
    }

    return { sent: true };
  };

  const say = (text: string) => send(text);

  /**
   * Hands the conversation to the seller, and tells the customer so.
   *
   * The whole point of the reshape: every one of these paths used to end here
   * silently, and a customer who is told nothing cannot tell the difference
   * between an assistant that handed them over and one that broke. The line is
   * fixed text — see HANDOVER_LINE — because most of these paths are reached
   * precisely when the model cannot be relied on to write one.
   */
  const handOver = async (
    code: EscalationCode,
    reason: string,
    speak: boolean,
  ): Promise<AutoReplyOutcome> => {
    // The message being answered decides the language, which is the same
    // signal the prompt itself uses.
    if (speak) {
      const arabic = readsAsArabic(message.text ?? "");
      await say(arabic ? HANDOVER_LINE.arabic : HANDOVER_LINE.english);
    }

    await store.finishAiRun(outcome.conversationId, "escalated", reason, code);
    return "escalated";
  };

  // A guard reason is already an escalation code, and is its own detail: there
  // is no prose to add to "the reply window had closed".
  if (blocked) return handOver(blocked, blocked, isSpoken(blocked, context));

  const prompt = await store.aiPrompt(context.workspaceId, outcome.conversationId);

  // One string, used twice: it is what the model is told, and it is what the
  // grounding check searches. Rendering it once is what stops a delivery fee
  // the model was given being refused on the way out as invented.
  const facts = renderFacts({
    shop: prompt.shop,
    zones: prompt.zones,
    products: prompt.products,
    offers: prompt.offers ?? [],
    today: todayInAmman(now),
  });

  const answer = await ask(apiKey, {
    facts,
    now,
    examples: prompt.examples,
    turns: prompt.turns,
    customerName: context.customerName,
    // For the thumbnails, when the customer's latest message is a photo.
    products: prompt.products,
  }, fetcher, workspaceId);

  // The only place a seller's running cost is visible. `cacheRead` staying at
  // zero across requests for a shop with a large catalog is the signal that
  // the cached prefix is being invalidated — which would roughly ten times the
  // input cost, silently.
  if (answer.status !== "failed") {
    await store.recordUsage?.(context.workspaceId, "reply", answer.usage);
    const u = answer.usage;
    console.log(
      `ai usage ${outcome.conversationId}: in ${u.inputTokens}, out ${u.outputTokens}, ` +
        `cacheRead ${u.cacheReadTokens}, cacheWrite ${u.cacheWriteTokens}`,
    );
  }

  if (answer.status === "failed") {
    // Left unmarked on purpose. The claim ages out in a couple of minutes, and
    // the customer's next message gets a fresh attempt.
    return "failed";
  }

  if (answer.status === "unusable") {
    // Logged, because the customer gets the fixed line instead of an answer
    // and nothing else would say why. Seen once in a live run and not
    // reproduced on the same input.
    console.log(`ai unusable ${outcome.conversationId}: ${answer.detail}`);
    return handOver("unusable", answer.detail, true);
  }

  // Emoji are trimmed rather than escalated: at most one safe one, at the end.
  // Removing an emoji changes nothing the customer needed to read, so it is
  // the one case where editing the finished reply beats withholding it.
  const reply = tidyEmoji(answer.decision.text);
  const decision = { ...answer.decision, text: reply };

  const refusal = reasonNotToSend(
    decision.text,
    facts,
    prompt.turns,
    message.platform,
    wordedOfferPrices(prompt.products, prompt.offers ?? [], todayInAmman(now)),
  );
  if (refusal) return handOver("ungrounded", refusal, true);

  // A photo it cannot send, in a reply that talks about one, is a promise
  // that will not be kept. The seller is the one who can take the photo, so
  // it goes to them. Without the talk, the missing photo is simply not sent.
  const missing = photosMissing(decision.photos, prompt.products);
  if (missing.length > 0 && mentionsPhoto(decision.text)) {
    // Its own code, so the seller's row says what to do: add a photo.
    return handOver("no_photo", missing.join(", "), true);
  }

  const delivery = await say(decision.text);

  if (!delivery.sent) {
    // Nothing reached the customer, so the hand-over line would not reach them
    // either — the same send is what failed.
    if (delivery.retry) return "failed";
    await store.finishAiRun(outcome.conversationId, "escalated", delivery.reason, "not_sent");
    return "escalated";
  }

  // After the text, never instead of it, and never ahead of it: "هاي هي الصورة"
  // above a photo reads right, and a photo arriving before its sentence does
  // not. A photo that fails to send is logged and dropped — the answer already
  // reached the customer, and failing the whole run over a picture would hand
  // over a conversation the assistant had handled.
  for (const photo of photosToSend(decision.photos, prompt.products, prompt.turns)) {
    const sent = await send({ image: photo.url, product: photo.product });
    if (!sent.sent) console.log(`ai photo not sent ${outcome.conversationId}: ${sent.reason}`);
  }

  // Answered AND handed over, which the old shape could not express: a customer
  // who asks two things, one of them answerable, gets the answer and the seller
  // gets the rest.
  // The model's own words, shown to the seller as written. Everything else on
  // this path is our code describing itself; this is the assistant describing
  // what it could not do, which is the only one worth reading.
  if (decision.handOver) {
    await store.finishAiRun(
      outcome.conversationId,
      "escalated",
      decision.reason,
      "assistant",
    );
    return "escalated";
  }

  await store.finishAiRun(outcome.conversationId, "answered", null, null);

  return "answered";
}

/** What came of a Graph send. `retry` separates "try again" from "give up". */
type SendOutcome =
  | { sent: true }
  | { sent: false; retry: boolean; reason: string };

/**
 * The checks that run on what the model wrote, before a customer sees it.
 *
 * All three are cheap and deterministic, and each catches a failure the
 * instructions alone did not: a number nobody authorised, a promise nobody
 * made, and a reply Meta would reject for length while the customer receives
 * nothing at all.
 */
/**
 * When the seller last wrote to this customer themselves, from rows newest
 * first. What the seller-present guard needs.
 */
export function lastSellerReply(
  rows: { direction: string; origin?: string | null; sent_at: string }[],
): string | null {
  return rows.find((row) => row.direction === "outbound" && row.origin === "seller")?.sent_at ?? null;
}

/** The URL of an image the customer sent, from Meta's attachment shape. */
export function customerPhoto(attachments: unknown): string | undefined {
  if (!Array.isArray(attachments)) return undefined;
  const first = attachments[0] as { type?: unknown; payload?: { url?: unknown } } | undefined;
  return first?.type === "image" && typeof first.payload?.url === "string" ? first.payload.url : undefined;
}

function reasonNotToSend(
  text: string,
  facts: string,
  turns: Turn[],
  platform: Platform,
  offerPrices: number[] = [],
): string | null {
  const said = turns.map((turn) => turn.text);

  if (!numbersAreGrounded(text, facts, said, offerPrices)) {
    return "a number the shop never gave it";
  }

  // The same rule for the claims that carry no digits, which is what the
  // number check was blind to and what leaked in practice.
  const claim = claimsAreGrounded(text, facts, said);
  if (claim) return `a promise the shop never made: "${claim}"`;

  const refusal = checkText(text, platform);
  if (refusal) return `text ${refusal}`;

  return null;
}

// ---------------------------------------------------------------------------
// Supabase-backed implementation
// ---------------------------------------------------------------------------

/** The slice of supabase-js this module uses. */
interface SupabaseLike {
  from(table: string): any;
  storage: {
    from(bucket: string): {
      getPublicUrl(path: string): { data: { publicUrl: string } };
      upload(
        path: string,
        body: Uint8Array,
        options: { contentType: string },
      ): Promise<{ error: { message: string } | null }>;
    };
  };
}

export function createSupabaseStore(client: SupabaseLike): Store {
  return {
    async findAccount(platform, externalId) {
      const { data, error } = await client
        .from("connected_accounts")
        .select("id, workspace_id")
        .eq("platform", platform)
        .eq("external_id", externalId)
        // A link the seller stopped receives nothing, even if Meta still
        // delivers: unsubscribing a WhatsApp number happens on its business
        // account, which we do not hold yet (NEXT.md, B2).
        .neq("status", "disconnected")
        .maybeSingle();

      if (error) throw new Error(`account lookup failed: ${error.message}`);
      if (!data) return null;

      return { id: data.id, workspaceId: data.workspace_id };
    },

    async findOrCreateConversation(account, customerExternalId) {
      const existing = await client
        .from("conversations")
        .select("id")
        .eq("account_id", account.id)
        .eq("customer_external_id", customerExternalId)
        .maybeSingle();

      if (existing.error) {
        throw new Error(`conversation lookup failed: ${existing.error.message}`);
      }
      if (existing.data) return existing.data.id;

      const inserted = await client
        .from("conversations")
        .upsert(
          {
            account_id: account.id,
            workspace_id: account.workspaceId,
            customer_external_id: customerExternalId,
          },
          { onConflict: "account_id,customer_external_id", ignoreDuplicates: true },
        )
        .select("id")
        .maybeSingle();

      if (inserted.error) {
        throw new Error(`conversation insert failed: ${inserted.error.message}`);
      }
      if (inserted.data) return inserted.data.id;

      // Another delivery created it between our select and insert. Read it back.
      const raced = await client
        .from("conversations")
        .select("id")
        .eq("account_id", account.id)
        .eq("customer_external_id", customerExternalId)
        .single();

      if (raced.error) {
        throw new Error(`conversation re-read failed: ${raced.error.message}`);
      }
      return raced.data.id;
    },

    async insertMessageIfNew(conversationId, workspaceId, message) {
      // ignoreDuplicates means a redelivered message inserts nothing, so the
      // trigger that maintains unread counts does not run twice for it.
      const { data, error } = await client
        .from("messages")
        .upsert(
          {
            conversation_id: conversationId,
            workspace_id: workspaceId,
            mid: message.mid,
            direction: message.direction,
            text: message.text,
            attachments: message.attachments,
            sent_at: message.sentAt,
          },
          { onConflict: "mid", ignoreDuplicates: true },
        )
        .select("id");

      if (error) throw new Error(`message insert failed: ${error.message}`);

      return Array.isArray(data) && data.length > 0;
    },

    async profileFetchedAt(conversationId) {
      const { data, error } = await client
        .from("conversations")
        .select("customer_profile_fetched_at")
        .eq("id", conversationId)
        .maybeSingle();

      if (error) throw new Error(`profile lookup failed: ${error.message}`);
      return data?.customer_profile_fetched_at ?? null;
    },

    async accountToken(accountId) {
      const { data, error } = await client
        .from("account_tokens")
        .select("access_token")
        .eq("account_id", accountId)
        .maybeSingle();

      if (error) throw new Error(`token lookup failed: ${error.message}`);
      return data?.access_token ?? null;
    },

    async recordUsage(workspaceId, kind, usage) {
      // Never allowed to fail the reply it describes.
      await client.from("ai_usage").insert({
        workspace_id: workspaceId,
        kind,
        model: MODEL,
        input_tokens: usage.inputTokens,
        output_tokens: usage.outputTokens,
        cache_read: usage.cacheReadTokens,
        cache_write: usage.cacheWriteTokens,
        cost_usd: usageCost(MODEL, usage),
      });
    },

    async markNeedsReconnect(accountId) {
      // Only an active account. One the seller turned off stays off, rather
      // than being brought back as something that needs their attention.
      const { error } = await client
        .from("connected_accounts")
        .update({ status: "needs_reconnect" })
        .eq("id", accountId)
        .eq("status", "active");

      if (error) throw new Error(`reconnect mark failed: ${error.message}`);
    },

    async saveMedia(path, bytes, contentType) {
      const bucket = client.storage.from("customer-media");
      const { error } = await bucket.upload(path, bytes, { contentType });
      if (error) throw new Error(`media upload failed: ${error.message}`);
      return bucket.getPublicUrl(path).data.publicUrl;
    },

    async saveProfile(conversationId, profile) {
      const { error } = await client
        .from("conversations")
        .update({
          customer_name: profile.name,
          customer_avatar_url: profile.avatarUrl,
          customer_profile_fetched_at: new Date().toISOString(),
        })
        .eq("id", conversationId);

      if (error) throw new Error(`profile save failed: ${error.message}`);
    },

    async aiContext(conversationId) {
      // last_message_type is no longer read. An attachment-only message reaches
      // the model now, written out by attachmentTurn, rather than being refused
      // before it gets there.
      const { data, error } = await client
        .from("conversations")
        .select("workspace_id, window_expires_at, last_message_at, customer_name, ai_paused")
        .eq("id", conversationId)
        .maybeSingle();

      if (error) throw new Error(`ai context failed: ${error.message}`);
      if (!data) return null;

      const workspaceId = data.workspace_id;

      const settings = await client
        .from("shop")
        .select("assistant_enabled")
        .eq("workspace_id", workspaceId)
        .maybeSingle();

      if (settings.error) throw new Error(`shop settings failed: ${settings.error.message}`);

      // No row means the assistant has never been switched on for this
      // workspace, which is the state every workspace starts in.
      const enabled = assistantOn(settings.data?.assistant_enabled, data.ai_paused);

      // The seller's own latest message, for the seller-present guard.
      const recent = await client
        .from("messages")
        .select("direction, origin, sent_at, text")
        .eq("conversation_id", conversationId)
        .order("sent_at", { ascending: false })
        .limit(60);

      if (recent.error) throw new Error(`ai history failed: ${recent.error.message}`);

      const lastSellerReplyAt = lastSellerReply(recent.data ?? []);

      const month = new Date();
      month.setUTCDate(1);
      month.setUTCHours(0, 0, 0, 0);

      const counted = await client
        .from("messages")
        .select("id", { count: "exact", head: true })
        .eq("workspace_id", workspaceId)
        .eq("origin", "ai")
        .gte("created_at", month.toISOString());

      if (counted.error) throw new Error(`ai count failed: ${counted.error.message}`);

      // The limit comes with the plan. Every workspace has one — the column
      // is not null with a foreign key — so a missing answer is an error, not
      // a reason to guess a number in either direction.
      const plan = await client
        .from("workspaces")
        .select("plans(replies_per_month)")
        .eq("id", workspaceId)
        .single();

      if (plan.error) throw new Error(`plan failed: ${plan.error.message}`);

      const limit = (plan.data?.plans as { replies_per_month?: unknown } | null)?.replies_per_month;
      if (typeof limit !== "number") throw new Error("plan failed: no limit");

      return {
        workspaceId,
        enabled,
        customerName: data.customer_name ?? null,
        windowExpiresAt: data.window_expires_at ?? null,
        lastMessageAt: data.last_message_at ?? null,
        lastSellerReplyAt,
        aiRepliesThisMonth: counted.count ?? 0,
        aiReplyLimit: limit,
      };
    },

    async claimAiRun(conversationId, now, answering) {
      // Atomic by Postgres guarantee rather than by hope: a second update
      // blocks on the row lock, then re-evaluates this filter against the
      // committed new value and matches nothing. Zero rows back means someone
      // else owns the conversation.
      //
      // The question is "has this message been considered yet", not "was there
      // a run recently". A window alone silently dropped any follow-up a
      // customer sent within it — seen in production, a message 36 seconds
      // after a reply was never answered — because the previous run's own
      // timestamp locked the conversation against genuinely new work.
      //
      // A run that started before this message arrived cannot have considered
      // it, so this claim is allowed. A concurrent run for the same message
      // fails: the first sets ai_last_run_at to now, and now is after the
      // message, so the second matches neither clause.
      const stale = new Date(now.getTime() - 2 * 60_000).toISOString();

      const { data, error } = await client
        .from("conversations")
        .update({ ai_last_run_at: now.toISOString() })
        .eq("id", conversationId)
        .or(
          `ai_last_run_at.is.null,ai_last_run_at.lt.${stale},` +
            `ai_last_run_at.lt.${answering}`,
        )
        .select("id");

      if (error) throw new Error(`ai claim failed: ${error.message}`);
      return Array.isArray(data) && data.length > 0;
    },

    async aiPrompt(workspaceId, conversationId) {
      // The facts that are not products: currency, where it delivers and for
      // how much, where it is, when it is open, and whatever else the seller
      // wrote down. Without these the assistant hands back most of a normal
      // conversation.
      const shopRow = await client
        .from("shop")
        .select("currency, delivery_note, locations, hours, about, price_stance, guide, guide_steps")
        .eq("workspace_id", workspaceId)
        .maybeSingle();

      if (shopRow.error) throw new Error(`shop failed: ${shopRow.error.message}`);

      const zones = await client
        .from("delivery_zones")
        .select("name, fee")
        .eq("workspace_id", workspaceId)
        .order("name", { ascending: true })
        .order("id", { ascending: true });

      if (zones.error) throw new Error(`delivery zones failed: ${zones.error.message}`);

      // Ordered so the rendering is byte-identical between calls. The cached
      // prefix depends on it; an unstable order means a cache write per
      // request and no reads at all.
      const products = await client
        .from("products")
        .select("id, code, name, price, description, in_stock, category_id, photos, categories(name)")
        .eq("workspace_id", workspaceId)
        .order("name", { ascending: true })
        .order("id", { ascending: true });

      if (products.error) throw new Error(`catalog failed: ${products.error.message}`);

      // Every offer, running or not: which are on today is decided in
      // renderFacts, against Amman's date, where it can be tested. Ordered so
      // the rendering is byte-identical between calls, like the catalog.
      const offers = await client
        .from("offers")
        .select("name, kind, value, description, buy, get, category_ids, product_ids, starts_on, ends_on, enabled")
        .eq("workspace_id", workspaceId)
        .order("created_at", { ascending: true })
        .order("id", { ascending: true });

      if (offers.error) throw new Error(`offers failed: ${offers.error.message}`);

      // The seller's own recent replies, as examples of how this shop talks.
      // Taken from across the workspace rather than this conversation, because
      // a new customer would otherwise get no voice at all.
      const examples = await client
        .from("messages")
        .select("text")
        .eq("workspace_id", workspaceId)
        .eq("direction", "outbound")
        .eq("origin", "seller")
        .not("text", "is", null)
        .order("sent_at", { ascending: false })
        .limit(40);

      if (examples.error) throw new Error(`examples failed: ${examples.error.message}`);

      // Attachment-only rows are kept rather than filtered out. A customer who
      // sends a screenshot and writes nothing was previously invisible to the
      // model, which then answered whatever they had said before it.
      const turns = await client
        .from("messages")
        .select("direction, text, attachments")
        .eq("conversation_id", conversationId)
        .order("sent_at", { ascending: false })
        .limit(10);

      if (turns.error) throw new Error(`turns failed: ${turns.error.message}`);

      return {
        shop: shopRow.data
          ? {
              currency: String(shopRow.data.currency ?? ""),
              deliveryNote: (shopRow.data.delivery_note ?? null) as string | null,
              locations: (shopRow.data.locations ?? null) as string | null,
              hours: (shopRow.data.hours ?? null) as string | null,
              about: (shopRow.data.about ?? null) as string | null,
              // Anything unrecognised reads as notify. A stance this build has
              // never heard of must not silently become a licence to tell
              // customers the price is final.
              priceStance: shopRow.data.price_stance === "strict" ? "strict" : "notify",
              guide: (shopRow.data.guide ?? null) as string | null,
              guideSteps: (shopRow.data.guide_steps ?? null) as GuideSteps | null,
            }
          : null,
        zones: (zones.data ?? []).map((row: Record<string, unknown>) => ({
          name: String(row.name),
          fee: (row.fee ?? null) as number | string | null,
        })),
        products: (products.data ?? []).map((row: Record<string, unknown>) => ({
          id: String(row.id),
          categoryId: (row.category_id ?? null) as string | null,
          code: (row.code ?? null) as string | null,
          name: String(row.name),
          price: (row.price ?? null) as number | string | null,
          description: (row.description ?? null) as string | null,
          inStock: row.in_stock !== false,
          category: ((row.categories as { name?: string } | null)?.name ?? null),
          // The cover only: it is the one the assistant sends.
          photo: Array.isArray(row.photos) && row.photos.length > 0
            ? client.storage.from("product-photos").getPublicUrl(String(row.photos[0])).data.publicUrl
            : null,
          // The small copy beside it — see thumbnailOf in lib/data.dart.
          thumb: Array.isArray(row.photos) && row.photos.length > 0
            ? client.storage.from("product-photos")
              .getPublicUrl(String(row.photos[0]).replace(/\.jpg$/, "_s.jpg")).data.publicUrl
            : null,
        })),
        offers: (offers.data ?? []).map((row: Record<string, unknown>) => ({
          name: (row.name ?? null) as string | null,
          kind: row.kind as Offer["kind"],
          value: (row.value ?? null) as number | string | null,
          buy: (row.buy ?? null) as number | null,
          get: (row.get ?? null) as number | null,
          categoryIds: (row.category_ids ?? []) as string[],
          productIds: (row.product_ids ?? []) as string[],
          startsOn: (row.starts_on ?? null) as string | null,
          endsOn: (row.ends_on ?? null) as string | null,
          enabled: row.enabled !== false,
          description: (row.description ?? null) as string | null,
        })),
        examples: (examples.data ?? [])
          .map((row: { text: string }) => row.text)
          .filter((text: string) => text && text.trim().length > 0),
        // Read newest first so the limit takes the most recent, then flipped
        // because a conversation reads forwards.
        turns: (turns.data ?? [])
          .slice()
          .reverse()
          .map((row: { direction: string; text: string | null; attachments: unknown }) => ({
            inbound: row.direction === "inbound",
            text: row.text && row.text.trim().length > 0
              ? row.text
              : (attachmentTurn(row.attachments as unknown[], row.direction === "inbound") ?? ""),
            // A photo the customer sent, so it can be shown to the model.
            image: row.direction === "inbound" ? customerPhoto(row.attachments) : undefined,
          }))
          // toMessages drops empty turns anyway; doing it here keeps the
          // conversation the grounding check searches the same as the one the
          // model reads.
          .filter((turn: Turn) => turn.text.length > 0),
      };
    },

    async insertAiReply(conversationId, workspaceId, mid, text, attachments = []) {
      const { error } = await client.from("messages").insert({
        conversation_id: conversationId,
        workspace_id: workspaceId,
        mid,
        direction: "outbound",
        text,
        attachments,
        sent_at: new Date().toISOString(),
        origin: "ai",
      });

      // Stored under the id Meta returned, so the echo arriving a moment later
      // is a duplicate and does not appear twice.
      if (error) throw new Error(`ai reply insert failed: ${error.message}`);
    },

    async finishAiRun(conversationId, state, reason, code) {
      const { error } = await client
        .from("conversations")
        .update({
          ai_state: state,
          ai_escalation_reason: reason,
          ai_escalation_code: code,
        })
        .eq("id", conversationId);

      if (error) throw new Error(`ai finish failed: ${error.message}`);
    },
  };
}
