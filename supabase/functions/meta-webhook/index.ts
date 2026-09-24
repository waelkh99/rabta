// Meta webhook endpoint.
//
// Does as little as possible: verify the request, store the raw payload,
// return 200. Meta expects a fast 200 and retries anything else, and sustained
// failures can get the webhook subscription disabled for the whole app —
// breaking delivery for every connected seller, not just the one whose event
// failed. Processing therefore happens after the response has been sent.
//
// Deployed with verify_jwt = false, because Meta does not send an auth token.
// The signature check is what replaces that protection.

import { createClient } from "jsr:@supabase/supabase-js@2.116.0";
import { verifyMetaSignature } from "./signature.ts";
import { parseWebhookPayload } from "./parse.ts";
import {
  autoReply,
  createSupabaseStore,
  processMessage,
  refreshCustomerProfile,
} from "./process.ts";
import { createSweepStore, sweep } from "./sweep.ts";
import { askOutcome, createOutcomeStore, readSettled } from "./outcome.ts";
import { createLog, describe } from "../_shared/log.ts";

const APP_SECRET = Deno.env.get("META_APP_SECRET") ?? "";
const VERIFY_TOKEN = Deno.env.get("META_VERIFY_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Absent until the key is configured, which is the same as the AI being off.
// Deliberately not a startup failure: the inbox must keep receiving messages
// whether or not anyone has set this up.
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";

// Only needed while the key is organisation-level rather than scoped to one
// workspace. Empty is fine for a scoped key.
const ANTHROPIC_WORKSPACE_ID = Deno.env.get("ANTHROPIC_WORKSPACE_ID") ?? "";

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const store = createSupabaseStore(supabase);
const sweepStore = createSweepStore(supabase);
const outcomeStore = createOutcomeStore(supabase);
const log = createLog(supabase, "meta-webhook");

Deno.serve(async (request: Request) => {
  if (request.method === "GET") return handleVerification(request);
  if (request.method === "POST") return await handleDelivery(request);

  return new Response("Method not allowed", { status: 405 });
});

/**
 * Meta confirms the endpoint before it will deliver anything, and again on
 * every subscription change. The challenge must come back as plain text and
 * nothing else.
 */
function handleVerification(request: Request): Response {
  const params = new URL(request.url).searchParams;

  const mode = params.get("hub.mode");
  const token = params.get("hub.verify_token");
  const challenge = params.get("hub.challenge");

  if (mode === "subscribe" && token === VERIFY_TOKEN && challenge) {
    return new Response(challenge, {
      status: 200,
      headers: { "content-type": "text/plain" },
    });
  }

  return new Response("Forbidden", { status: 403 });
}

async function handleDelivery(request: Request): Promise<Response> {
  // Must be read as raw text. Re-serialising the JSON would change the bytes
  // and the signature would never match.
  const rawBody = await request.text();

  const valid = await verifyMetaSignature(
    rawBody,
    request.headers.get("x-hub-signature-256"),
    APP_SECRET,
  );

  if (!valid) {
    await log("warn", "signature_invalid");
    return new Response("Invalid signature", { status: 401 });
  }

  let payload: unknown;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    // Signed by Meta but unparseable. Worth recording rather than discarding.
    await supabase.from("webhook_events").insert({
      payload: { unparseable: rawBody.slice(0, 10_000) },
      signature_valid: true,
      error: "body was not valid JSON",
    });
    return new Response("OK", { status: 200 });
  }

  const objectType = typeof (payload as { object?: unknown })?.object === "string"
    ? (payload as { object: string }).object
    : null;

  const { data: event, error } = await supabase
    .from("webhook_events")
    .insert({ object: objectType, payload, signature_valid: true })
    .select("id")
    .single();

  if (error) {
    // Storing failed, so returning 200 would lose the event. Let Meta retry.
    await log("error", "event_not_stored", { error: describe(error) });
    return new Response("Storage failed", { status: 500 });
  }

  // Answer Meta now; do the work afterwards. If this process dies mid-way the
  // raw event is already stored with processed_at still null, and the sweep
  // will pick it up.
  // Then anything an earlier delivery failed to finish. After this one, so a
  // backlog never delays the customer who has just written.
  const work = processStoredEvent(event.id, payload).then(retryFailed).then(readOutcomes).then(prune);
  if (typeof EdgeRuntime !== "undefined") {
    EdgeRuntime.waitUntil(work);
  } else {
    await work;
  }

  return new Response("OK", { status: 200 });
}

/**
 * Processes events an earlier run left unfinished. Never answers the customer:
 * a reply minutes late to a message the seller may already have seen is worse
 * than none, and the conversation is in their waiting group either way.
 */
async function retryFailed(): Promise<void> {
  try {
    const retried = await sweep(
      sweepStore,
      (id, payload) => processStoredEvent(id, payload, { reply: false }),
    );
    if (retried.length > 0) await log("warn", "events_retried", { events: retried });
  } catch (cause) {
    await log("error", "sweep_failed", { error: describe(cause) });
  }
}

/**
 * Reads how settled conversations ended — see outcome.ts. Last, after the
 * customer who just wrote and anything that failed, because nothing is
 * waiting on it. Off without an API key, like the assistant.
 *
 * ponytail: runs only when a delivery arrives, like the sweep. A shop that
 * goes quiet for a day has its last conversations read on the next message.
 * A schedule is the upgrade if that ever leaves the weekly view stale.
 */
async function readOutcomes(): Promise<void> {
  if (!ANTHROPIC_API_KEY) return;

  try {
    const { read, failed } = await readSettled(
      outcomeStore,
      (lines, catalog) => askOutcome(ANTHROPIC_API_KEY, lines, catalog, { workspaceId: ANTHROPIC_WORKSPACE_ID }),
    );
    if (failed.length) await log("warn", "outcomes_failed", { read: read.length, failed });
    else if (read.length) console.log(JSON.stringify({ event: "outcomes_read", read: read.length }));
  } catch (cause) {
    await log("error", "outcomes_crashed", { error: describe(cause) });
  }
}

/**
 * Raw payloads older than a month, and logs older than three. Cheap enough to
 * run after every delivery: the deletes are indexed and usually find nothing.
 */
async function prune(): Promise<void> {
  const { data, error } = await supabase.rpc("prune_old_records", {});
  if (error) await log("error", "prune_failed", { error: error.message });
  else if (data && Object.values(data as Record<string, number>).some((n) => n > 0)) {
    console.log(JSON.stringify({ event: "pruned", ...data }));
  }
}

async function processStoredEvent(
  eventId: number,
  payload: unknown,
  { reply = true }: { reply?: boolean } = {},
): Promise<void> {
  try {
    const { messages, skipped } = parseWebhookPayload(payload);

    if (skipped.length > 0) {
      console.log(`Event ${eventId}: skipped ${skipped.length}`, skipped);
    }

    for (const message of messages) {
      const outcome = await processMessage(store, message);

      if (outcome.status === "unknown-account") {
        await log("info", "unknown_account", { event: eventId, account: outcome.accountExternalId });
        continue;
      }

      // Who the customer is. Meta sends only an opaque id with the message, so
      // without this every conversation in the inbox reads as "Customer" and a
      // seller cannot tell one row from another.
      //
      // Deliberately not allowed to fail the event: the message is already
      // stored, and losing it over a missing name would be a poor trade.
      try {
        const profile = await refreshCustomerProfile(store, message, outcome);
        if (profile === "token-dead") {
          await log("warn", "token_dead", { account: outcome.accountId }, outcome.workspaceId);
        } else if (profile !== "fresh") {
          console.log(JSON.stringify({ event: "profile", result: profile, conversation: outcome.conversationId }));
        }
      } catch (cause) {
        await log("error", "profile_failed", { event: eventId, error: describe(cause) }, outcome.workspaceId);
      }

      // Answering the customer, when the seller has switched that on. Waits
      // half a minute first so a burst of fragments gets one reply rather than
      // three — see DEBOUNCE_MS.
      //
      // Held to the same rule as the profile lookup: it must never fail the
      // event. The message is already stored, and a reply we could not write
      // is not a reason to lose it. Worst case the conversation simply stays
      // in the seller's waiting group, which is where it would have been
      // without any of this.
      if (!reply) continue;

      try {
        const replied = await autoReply(store, ANTHROPIC_API_KEY, message, outcome, {
          workspaceId: ANTHROPIC_WORKSPACE_ID,
        });
        if (replied === "failed") {
          await log("warn", "ai_failed", { conversation: outcome.conversationId }, outcome.workspaceId);
        } else if (replied === "escalated") {
          await log("info", "ai_handed_over", { conversation: outcome.conversationId }, outcome.workspaceId);
        } else if (replied !== "off" && replied !== "not-applicable") {
          console.log(JSON.stringify({ event: "ai", result: replied, conversation: outcome.conversationId }));
        }
      } catch (cause) {
        await log("error", "ai_crashed", { event: eventId, error: describe(cause) }, outcome.workspaceId);
      }
    }

    await supabase
      .from("webhook_events")
      .update({ processed_at: new Date().toISOString(), error: null })
      .eq("id", eventId);
  } catch (cause) {
    const reason = describe(cause);
    await log("error", "event_failed", { event: eventId, error: reason });

    // Left unprocessed on purpose, so the sweep retries it — see sweep.ts.
    await supabase
      .from("webhook_events")
      .update({ error: reason })
      .eq("id", eventId);
  }
}

// Provided by the Supabase Edge runtime; absent when running elsewhere.
declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void } | undefined;
