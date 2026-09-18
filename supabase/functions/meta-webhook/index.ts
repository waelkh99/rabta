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

import { createClient } from "jsr:@supabase/supabase-js@2";
import { verifyMetaSignature } from "./signature.ts";
import { parseWebhookPayload } from "./parse.ts";
import {
  createSupabaseStore,
  processMessage,
  refreshCustomerProfile,
} from "./process.ts";

const APP_SECRET = Deno.env.get("META_APP_SECRET") ?? "";
const VERIFY_TOKEN = Deno.env.get("META_VERIFY_TOKEN") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const store = createSupabaseStore(supabase);

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
    console.warn("Rejected webhook with invalid signature");
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
    console.error("Failed to store webhook event", error);
    return new Response("Storage failed", { status: 500 });
  }

  // Answer Meta now; do the work afterwards. If this process dies mid-way the
  // raw event is already stored with processed_at still null, and the sweep
  // will pick it up.
  const work = processStoredEvent(event.id, payload);
  if (typeof EdgeRuntime !== "undefined") {
    EdgeRuntime.waitUntil(work);
  } else {
    await work;
  }

  return new Response("OK", { status: 200 });
}

async function processStoredEvent(eventId: number, payload: unknown): Promise<void> {
  try {
    const { messages, skipped } = parseWebhookPayload(payload);

    if (skipped.length > 0) {
      console.log(`Event ${eventId}: skipped ${skipped.length}`, skipped);
    }

    for (const message of messages) {
      const outcome = await processMessage(store, message);

      if (outcome.status === "unknown-account") {
        console.warn(
          `Event ${eventId}: message ${outcome.mid} is for account ` +
            `${outcome.accountExternalId}, which is not connected here`,
        );
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
        if (profile !== "fresh") {
          console.log(`Event ${eventId}: profile ${profile} for ${outcome.conversationId}`);
        }
      } catch (cause) {
        console.error(`Event ${eventId}: profile lookup failed`, cause);
      }
    }

    await supabase
      .from("webhook_events")
      .update({ processed_at: new Date().toISOString(), error: null })
      .eq("id", eventId);
  } catch (cause) {
    const reason = cause instanceof Error ? cause.message : String(cause);
    console.error(`Event ${eventId} failed to process: ${reason}`);

    // Left unprocessed on purpose, so the sweep retries it.
    await supabase
      .from("webhook_events")
      .update({ error: reason })
      .eq("id", eventId);
  }
}

// Provided by the Supabase Edge runtime; absent when running elsewhere.
declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void } | undefined;
