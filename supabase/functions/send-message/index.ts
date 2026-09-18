// Sending a seller's reply to a customer.
//
//   POST /send-message   { "conversation": "<uuid>", "text": "..." }
//
// Two clients, on purpose:
//
//   - the seller's own, carrying their JWT, used to read the conversation.
//     Row level security is what proves the conversation is theirs, rather
//     than a workspace filter written by hand here. A forgotten filter would
//     let one seller reply into another's conversation, under that seller's
//     name, from their Page.
//   - the service role, used to write the message and to read the access
//     token. No client may read `account_tokens` at all, which is the point of
//     doing this in a function rather than in the browser.
//
// Every refusal comes back as a code, never a sentence. The server does not
// choose a language.

import { createClient } from "jsr:@supabase/supabase-js@2";

import { corsHeaders } from "../_shared/origins.ts";

import {
  checkText,
  checkWindow,
  readSendResult,
  type Refusal,
  sendRequest,
} from "./send.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const service = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

Deno.serve(async (request: Request) => {
  // The page calls this from its own origin, so the browser asks permission
  // first and then refuses to hand the answer to the page unless this says the
  // origin back. Without it the reply is sent or refused perfectly well and the
  // seller sees neither — which is what happened the first time this was run
  // in a browser rather than with curl.
  const cors = corsHeaders(request.headers.get("Origin"));

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }

  if (request.method !== "POST") return refuse("rejected", 405, cors);

  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization) return refuse("not_found", 401, cors);

  let body: { conversation?: string; text?: string };
  try {
    body = await request.json();
  } catch {
    return refuse("rejected", 400, cors);
  }

  const conversationId = body.conversation ?? "";
  const text = body.text ?? "";
  if (!conversationId) return refuse("not_found", 404, cors);

  // As the seller. Row level security decides what this can see, so a
  // conversation belonging to someone else is simply not there.
  const seller = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });

  const { data: conversation } = await seller
    .from("conversations")
    .select(
      "id, workspace_id, account_id, customer_external_id, window_expires_at, " +
        "connected_accounts!inner(external_id, platform)",
    )
    .eq("id", conversationId)
    .maybeSingle();

  if (!conversation) return refuse("not_found", 404, cors);

  const account = conversation.connected_accounts as unknown as {
    external_id: string;
    platform: string;
  };

  const wrongText = checkText(text, account.platform);
  if (wrongText) return refuse(wrongText, 400, cors);

  // Checked here as well as in the interface. The interface states the window
  // before the seller types, which is where it belongs, but a tab left open
  // overnight would otherwise send a reply Meta has already stopped accepting.
  const closed = checkWindow(conversation.window_expires_at, new Date());
  if (closed) return refuse(closed, 409, cors);

  // Service role: no client is allowed to read this table, in any workspace.
  const { data: token } = await service
    .from("account_tokens")
    .select("access_token")
    .eq("account_id", conversation.account_id)
    .maybeSingle();

  if (!token) return refuse("disconnected", 409, cors);

  const { url, init } = sendRequest(
    account.external_id,
    conversation.customer_external_id,
    text,
    token.access_token,
  );

  let answer: unknown;
  try {
    answer = await fetch(url, init).then((r) => r.json());
  } catch (error) {
    console.error("send failed to reach Meta", { conversationId, error: String(error) });
    return refuse("unreachable", 502, cors);
  }

  const result = readSendResult(answer);

  if ("refusal" in result) {
    console.error("Meta refused a reply", {
      conversationId,
      refusal: result.refusal,
      detail: result.detail,
    });

    // The token has gone bad. Recorded on the account so that the seller can
    // be told to reconnect, rather than watching their inbox fall quiet and
    // concluding that business is slow.
    if (result.refusal === "disconnected") {
      await service
        .from("connected_accounts")
        .update({ status: "needs_reconnect" })
        .eq("id", conversation.account_id);
    }

    return refuse(result.refusal, 502, cors);
  }

  // Stored with the id Meta gave it. The echo of this same reply arrives
  // through the webhook moments later carrying that id, and `messages.mid` is
  // unique — so the duplicate is discarded by a constraint that already
  // existed rather than by a rule written here.
  const { error } = await service.from("messages").insert({
    conversation_id: conversation.id,
    workspace_id: conversation.workspace_id,
    mid: result.mid,
    direction: "outbound",
    text,
    sent_at: new Date().toISOString(),
  });

  // The reply has reached the customer. Failing the request now would invite
  // the seller to send it again, so this is logged and reported as sent — the
  // echo will store it a moment later in any case.
  if (error) {
    console.error("reply sent but not stored", { conversationId, error });
  }

  return json({ mid: result.mid }, 200, cors);
});

function refuse(
  reason: Refusal,
  status: number,
  cors: Record<string, string>,
): Response {
  return json({ reason }, status, cors);
}

function json(
  body: unknown,
  status: number,
  cors: Record<string, string>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json; charset=utf-8" },
  });
}
