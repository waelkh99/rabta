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
}

export type Outcome =
  | { status: "stored"; mid: string; conversationId: string; accountId: string }
  | { status: "duplicate"; mid: string; conversationId: string; accountId: string }
  | { status: "unknown-account"; mid: string; accountExternalId: string };

export async function processMessage(
  store: Store,
  message: NormalisedMessage,
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
  };
}

/** What asking Meta about a customer came to. Returned so it can be logged. */
export type ProfileOutcome =
  | "fresh" // what we hold is recent enough
  | "saved" // asked, and recorded the answer
  | "no-token" // the account has no usable token
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

  const profile = readProfile(answer);
  if (!profile) return "no-answer";

  await store.saveProfile(outcome.conversationId, profile);
  return "saved";
}

// ---------------------------------------------------------------------------
// Supabase-backed implementation
// ---------------------------------------------------------------------------

/** The slice of supabase-js this module uses. */
interface SupabaseLike {
  from(table: string): any;
}

export function createSupabaseStore(client: SupabaseLike): Store {
  return {
    async findAccount(platform, externalId) {
      const { data, error } = await client
        .from("connected_accounts")
        .select("id, workspace_id")
        .eq("platform", platform)
        .eq("external_id", externalId)
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
  };
}
