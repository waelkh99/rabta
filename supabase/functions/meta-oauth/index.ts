// Connecting a seller's Meta accounts.
//
// Four routes:
//
//   /meta-oauth/start        answers with the address of Meta's approval page
//   /meta-oauth/callback     exchanges the code and stores what it finds
//   /meta-oauth/disconnect   stops an account without losing its history
//   /meta-oauth/check        marks accounts whose token Meta no longer accepts
//
// `start`, `disconnect` and `check` are called by the application and carry the
// seller's own token; the workspace comes from that token and never from the
// request. `callback` is the one Meta itself reaches, as a plain browser
// navigation with no session, and the signed state is what protects it.
//
// Facebook Login for Business does not use a plain OAuth dialog. The request
// carries a config_id, and that configuration decides which permissions are
// asked for and which assets the seller is offered. Without it Meta returns an
// ordinary user login with no asset-selection step and no Page access — which
// is also why Graph API Explorer cannot issue Page tokens for this app.
//
// Deployed with verify_jwt = false: the browser arrives here straight from
// Meta with no Supabase session. The signed state parameter is what protects it.

import { createClient } from "jsr:@supabase/supabase-js@2.116.0";

import { corsHeaders } from "../_shared/origins.ts";
import { tokenExpired } from "../send-message/send.ts";
import { createLog, describe } from "../_shared/log.ts";

import { assetsFromScopes, type Granted, whatsappName } from "./assets.ts";
import {
  isWorkspaceId,
  readState,
  returnOriginIndex,
  signState,
} from "./state.ts";

const APP_ID = "1759728245295705";
const CONFIG_ID = "1063344539629710";
// WhatsApp's own Facebook Login for Business configuration (the "WhatsApp
// Embedded Signup" variation, system-user token). A secret rather than a
// constant only so it can be set without a deploy; absent, the button says
// connecting failed rather than opening the wrong screen.
const WHATSAPP_CONFIG_ID = Deno.env.get("META_WHATSAPP_CONFIG_ID") ?? "";
const GRAPH = "https://graph.facebook.com/v26.0";

// Must match a Valid OAuth Redirect URI registered on the app exactly. Meta
// compares strings and rejects a mismatch with a generic error.
//
// Built from the project this function runs in rather than written out: it was
// the staging address, so a production deploy would have sent every seller who
// connected back to staging. Staging and production each register their own.
const REDIRECT_URI =
  `${Deno.env.get("SUPABASE_URL")!.replace(/\/$/, "")}/functions/v1/meta-oauth/callback`;

// Subscribing the Page to these is what makes messages arrive at all.
const SUBSCRIBED_FIELDS = "messages,messaging_postbacks,message_echoes";

const APP_SECRET = Deno.env.get("META_APP_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

const log = createLog(supabase, "meta-oauth");

Deno.serve(async (request: Request) => {
  const { pathname, searchParams } = new URL(request.url);
  const cors = corsHeaders(request.headers.get("Origin"));

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }

  // The callback is the only route Meta itself reaches, and it arrives as a
  // plain browser navigation with no session. The other two are called by the
  // application, carrying the seller's own token.
  if (pathname.endsWith("/callback")) return await callback(searchParams);
  if (pathname.endsWith("/start")) return await start(request, cors);
  if (pathname.endsWith("/disconnect")) return await disconnect(request, cors);
  if (pathname.endsWith("/check")) return await check(request, cors);

  return text("Not found", 404);
});

/** The seller making this request, according to their own token. */
async function sellerWorkspace(
  request: Request,
): Promise<{ workspaceId: string; token: string } | null> {
  const token = request.headers.get("Authorization") ?? "";
  if (!token) return null;

  // Read as the seller. Row level security returns their workspace and no
  // other, so the workspace is never taken from the request.
  const seller = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false },
    global: { headers: { Authorization: token } },
  });

  const { data } = await seller.from("workspaces").select("id").maybeSingle();
  if (!data?.id || !isWorkspaceId(data.id)) return null;

  return { workspaceId: data.id, token };
}

// ---------------------------------------------------------------------------
// Sending the seller to Meta
// ---------------------------------------------------------------------------

/**
 * Answers with the address of Meta's approval page, for the application to
 * send the browser to.
 *
 * It does not redirect, because a redirect cannot carry an Authorization
 * header — and the alternative, a workspace id in the query string, is what
 * this replaces. Anyone could name any workspace and connect a Meta account
 * into a seller's inbox they do not own.
 */
async function start(
  request: Request,
  cors: Record<string, string>,
): Promise<Response> {
  const seller = await sellerWorkspace(request);
  if (!seller) return json({ reason: "not_signed_in" }, 401, cors);

  // Where the browser is sent once this is done. Rejected here, at the start,
  // so an origin we will not redirect to never reaches the point of being
  // signed into the state.
  const originIndex = returnOriginIndex(
    new URL(request.url).searchParams.get("return"),
  );
  if (originIndex === null) return json({ reason: "unknown_return" }, 400, cors);

  // ?kind=whatsapp opens WhatsApp's signup instead of the Page screen. Both
  // come back to the same callback, which tells them apart by what was granted.
  const whatsapp = new URL(request.url).searchParams.get("kind") === "whatsapp";
  if (whatsapp && !WHATSAPP_CONFIG_ID) return json({ reason: "not_configured" }, 503, cors);

  const dialog = new URL("https://www.facebook.com/v26.0/dialog/oauth");
  dialog.searchParams.set("client_id", APP_ID);
  dialog.searchParams.set("config_id", whatsapp ? WHATSAPP_CONFIG_ID : CONFIG_ID);
  if (whatsapp) {
    dialog.searchParams.set("extras", JSON.stringify({ setup: {}, sessionInfoVersion: "3" }));
  }
  dialog.searchParams.set("redirect_uri", REDIRECT_URI);
  dialog.searchParams.set("response_type", "code");
  dialog.searchParams.set(
    "state",
    await signState(APP_SECRET, seller.workspaceId, originIndex),
  );

  return json({ url: dialog.toString() }, 200, cors);
}

// ---------------------------------------------------------------------------
// Turning an account off
// ---------------------------------------------------------------------------

/**
 * Stops messages arriving from one account, without losing anything.
 *
 * Deliberately not a delete. `connected_accounts` is the parent of
 * conversations and of messages, both `on delete cascade`, so removing the row
 * would take every conversation the seller has ever had on that account with
 * it. Someone turning off notifications would lose their history and have no
 * way back. What goes is the token and the subscription; the account stays,
 * marked disconnected, and its conversations stay readable.
 */
async function disconnect(
  request: Request,
  cors: Record<string, string>,
): Promise<Response> {
  const seller = await sellerWorkspace(request);
  if (!seller) return json({ reason: "not_signed_in" }, 401, cors);

  let body: { account?: string };
  try {
    body = await request.json();
  } catch {
    return json({ reason: "bad_request" }, 400, cors);
  }

  const accountId = body.account ?? "";
  if (!accountId) return json({ reason: "not_found" }, 404, cors);

  // Read as the seller, so an account belonging to someone else is simply not
  // there rather than something we have to remember to check.
  const asSeller = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false },
    global: { headers: { Authorization: seller.token } },
  });

  const { data: account } = await asSeller
    .from("connected_accounts")
    .select("id, external_id, platform, business_account_id")
    .eq("id", accountId)
    .maybeSingle();

  if (!account) return json({ reason: "not_found" }, 404, cors);

  // Tell Meta to stop sending. Done before the token is deleted, because the
  // token is what proves we may. A failure here is logged and not fatal: the
  // token is going regardless, and an account we can no longer authenticate
  // cannot be unsubscribed anyway.
  const { data: stored } = await supabase
    .from("account_tokens")
    .select("access_token")
    .eq("account_id", account.id)
    .maybeSingle();

  // A WhatsApp number is subscribed through its business account, which may
  // hold other numbers this seller still uses. Only the last one unsubscribes.
  let subscribedId: string | null = account.external_id;
  if (account.platform === "whatsapp") {
    const { count } = await supabase
      .from("connected_accounts")
      .select("id", { count: "exact", head: true })
      .eq("business_account_id", account.business_account_id ?? "")
      .neq("status", "disconnected")
      .neq("id", account.id);
    subscribedId = account.business_account_id && !count ? account.business_account_id : null;
  }

  if (stored?.access_token && subscribedId) {
    try {
      const answer = await fetch(
        `${GRAPH}/${subscribedId}/subscribed_apps` +
          `?access_token=${encodeURIComponent(stored.access_token)}`,
        { method: "DELETE" },
      ).then((r) => r.json());

      if (!answer?.success) {
        await log("warn", "unsubscribe_refused", { account: account.id, answer }, seller.workspaceId);
      }
    } catch (cause) {
      await log("warn", "unsubscribe_unreachable", { account: account.id, error: describe(cause) }, seller.workspaceId);
    }
  }

  await supabase.from("account_tokens").delete().eq("account_id", account.id);

  const { error } = await supabase
    .from("connected_accounts")
    .update({ status: "disconnected" })
    .eq("id", account.id);

  if (error) {
    await log("error", "disconnect_not_recorded", { account: account.id, error: describe(error) }, seller.workspaceId);
    return json({ reason: "failed" }, 500, cors);
  }

  await log("info", "account_disconnected", { account: account.id }, seller.workspaceId);

  return json({ disconnected: account.id }, 200, cors);
}

// ---------------------------------------------------------------------------
// Noticing a dead token
// ---------------------------------------------------------------------------

/**
 * Asks Meta whether each of the seller's active accounts still answers to its
 * token, and marks the ones that do not.
 *
 * Called by the application when the inbox opens. The receiving side cannot
 * find this out for itself: when a token dies Meta simply stops delivering,
 * and a webhook that is never called notices nothing. The seller opening Rabta
 * is exactly when they need to hear that their inbox has gone quiet for a
 * reason.
 *
 * Only a definite 190 marks an account. Meta being unreachable, or answering
 * with any other error, says nothing about the token, and a false "reconnect
 * your account" is an alarm the seller learns to ignore.
 */
async function check(
  request: Request,
  cors: Record<string, string>,
): Promise<Response> {
  const seller = await sellerWorkspace(request);
  if (!seller) return json({ reason: "not_signed_in" }, 401, cors);

  const { data: accounts } = await supabase
    .from("connected_accounts")
    .select("id, external_id")
    .eq("workspace_id", seller.workspaceId)
    .eq("status", "active");

  const expired: string[] = [];

  for (const account of accounts ?? []) {
    const { data: stored } = await supabase
      .from("account_tokens")
      .select("access_token")
      .eq("account_id", account.id)
      .maybeSingle();

    if (!stored?.access_token) continue;

    let answer: unknown;
    try {
      answer = await fetch(
        `${GRAPH}/${account.external_id}?fields=id` +
          `&access_token=${encodeURIComponent(stored.access_token)}`,
      ).then((r) => r.json());
    } catch {
      continue;
    }

    if (!tokenExpired(answer)) continue;

    await supabase
      .from("connected_accounts")
      .update({ status: "needs_reconnect" })
      .eq("id", account.id)
      .eq("status", "active");
    expired.push(account.id);
    await log("warn", "token_dead", { account: account.id }, seller.workspaceId);
  }

  return json({ expired }, 200, cors);
}

// ---------------------------------------------------------------------------
// Handling Meta's redirect back
// ---------------------------------------------------------------------------

async function callback(params: URLSearchParams): Promise<Response> {
  // The seller pressed cancel, or Meta refused. Not a failure worth a 500.
  const declined = params.get("error_description") ?? params.get("error");
  if (declined) return text(`Meta declined the connection: ${declined}`, 400);

  const issued = await readState(APP_SECRET, params.get("state"));
  if (!issued) return text("Invalid state", 400);

  const { workspaceId, returnOrigin } = issued;

  const code = params.get("code");
  if (!code) return text("Missing code", 400);

  const tokenUrl = new URL(`${GRAPH}/oauth/access_token`);
  tokenUrl.searchParams.set("client_id", APP_ID);
  tokenUrl.searchParams.set("client_secret", APP_SECRET);
  tokenUrl.searchParams.set("redirect_uri", REDIRECT_URI);
  tokenUrl.searchParams.set("code", code);

  const token = await fetch(tokenUrl).then((r) => r.json());
  if (!token.access_token) {
    return text(`Token exchange failed: ${JSON.stringify(token)}`, 502);
  }

  // The token itself says what it was granted. /me/accounts is the documented
  // way to list Pages and returns an empty array for this app even when the
  // Page was plainly granted — observed on 17 September, with pages_show_list
  // scoped to the exact Page it omitted. debug_token reports the ids each scope
  // was granted against, and those have been reliable, so read from there.
  const granted = await grantedAssets(token.access_token);

  if (granted.whatsappIds.length > 0) {
    return await connectWhatsApp(workspaceId, returnOrigin, granted.whatsappIds, token.access_token);
  }

  const pages = await fetchPages(granted.pageIds, token.access_token);
  if (pages.length === 0) {
    // The seller has no Page, or did not grant one on the asset screen. The two
    // are indistinguishable from here, and this is the likeliest way the flow
    // fails for a real seller — so what they read has to be a plain sentence
    // about what to do next, not a description of what we asked Meta.
    //
    // The diagnostics go to the function log, where we can read them and the
    // seller cannot. They were printed on this page while the flow was being
    // worked out, which also left a reference to a variable that no longer
    // existed — so the one path that most needed to explain itself crashed.
    await log("error", "connect_no_page", { tokenKeys: Object.keys(token), granted }, workspaceId);

    return text(
      `Almost there.

Inboxara receives your messages through a Facebook Page, and no Page was
included. On Meta's permission screen, choose the Page you sell from and allow
access to its messages.

If this account has no Page yet, one has to be created before Instagram or
Messenger conversations can reach Inboxara.`,
      200,
    );
  }

  const report: string[] = [];

  for (const page of pages) {
    // Meta can return a Page without a name. Null is what the column means by
    // "no name", and undefined would silently drop the field from the write.
    await connect(workspaceId, "messenger", page.id, page.name ?? null, page.access_token);
    report.push(`Messenger: ${page.name} (${page.id})`);

    const subscribe = await fetch(
      `${GRAPH}/${page.id}/subscribed_apps` +
        `?subscribed_fields=${SUBSCRIBED_FIELDS}` +
        `&access_token=${encodeURIComponent(page.access_token)}`,
      { method: "POST" },
    ).then((r) => r.json());

    report.push(
      subscribe.success
        ? `  subscribed: ${SUBSCRIBED_FIELDS}`
        : `  SUBSCRIPTION FAILED: ${JSON.stringify(subscribe)}`,
    );

    // Reading instagram_business_account off the Page needs instagram_basic,
    // which this configuration does not request, so it is usually absent. The
    // granted scopes carry the id regardless.
    //
    // ponytail: with one Page, any granted Instagram account belongs to it.
    // Pair them through the Page field once instagram_basic is requested, which
    // is also what multiple Pages will need.
    const instagram = page.instagram_business_account ??
      (pages.length === 1 && granted.instagramIds.length > 0
        ? { id: granted.instagramIds[0], username: undefined }
        : undefined);

    if (instagram?.id) {
      // entry.id on an Instagram webhook is this id, not the Page id. Storing
      // the Page id here would make every Instagram message arrive, be stored,
      // and then be skipped as belonging to an unknown account.
      await connect(
        workspaceId,
        "instagram",
        instagram.id,
        instagram.username ?? null,
        page.access_token,
      );
      report.push(`Instagram: ${instagram.username ?? instagram.id} (${instagram.id})`);
    } else {
      report.push("  no Instagram professional account linked to this Page");
    }
  }

  // Home, to the application the seller pressed Connect in. The destination
  // came out of the allowlist in state.ts and never out of this request.
  //
  // Only on success. A seller whose connection did not work keeps the page
  // that says why, because dropping them back into an inbox that looks no
  // different is the one outcome they cannot act on.
  await log("info", "account_connected", { report }, workspaceId);

  return Response.redirect(`${returnOrigin}/?connected=1`, 302);
}

// What this token was actually granted against. See assets.ts.
async function grantedAssets(userToken: string): Promise<Granted> {
  const debug = await fetch(
    `${GRAPH}/debug_token?input_token=${encodeURIComponent(userToken)}` +
      `&access_token=${APP_ID}|${encodeURIComponent(APP_SECRET)}`,
  ).then((r) => r.json());

  return assetsFromScopes(debug?.data?.granular_scopes);
}

/**
 * The WhatsApp half of the callback: every number in every business account
 * the seller granted, each stored with the token, and each business account
 * subscribed so its messages reach the webhook.
 *
 * ponytail: a number not yet registered for the Cloud API (a brand-new number,
 * not one moved from the WhatsApp Business app through Coexistence) also needs
 * POST /{phone}/register with a two-step PIN. Logged, not done — choosing a
 * PIN the seller does not know is a decision to make, not a default.
 */
async function connectWhatsApp(
  workspaceId: string,
  returnOrigin: string,
  businessAccountIds: string[],
  accessToken: string,
): Promise<Response> {
  const report: string[] = [];
  const auth = { headers: { authorization: `Bearer ${accessToken}` } };

  for (const waba of businessAccountIds) {
    const numbers = await fetch(
      `${GRAPH}/${waba}/phone_numbers?fields=id,display_phone_number,verified_name,status`,
      auth,
    ).then((r) => r.json());

    for (const phone of numbers?.data ?? []) {
      await connect(workspaceId, "whatsapp", phone.id, whatsappName(phone), accessToken, waba);
      report.push(`WhatsApp: ${whatsappName(phone)} (${phone.id}) status=${phone.status}`);
      if (phone.status && phone.status !== "CONNECTED") {
        await log("warn", "whatsapp_number_not_registered", { phone: phone.id, status: phone.status }, workspaceId);
      }
    }

    const subscribe = await fetch(`${GRAPH}/${waba}/subscribed_apps`, { method: "POST", ...auth })
      .then((r) => r.json());
    report.push(subscribe.success ? `  subscribed ${waba}` : `  SUBSCRIPTION FAILED: ${JSON.stringify(subscribe)}`);
  }

  if (!report.some((line) => line.startsWith("WhatsApp:"))) {
    await log("error", "connect_no_whatsapp_number", { businessAccountIds }, workspaceId);
    return text(
      `Almost there.

No WhatsApp number was included. Go back to Inboxara, press Connect WhatsApp
again, and choose the number you sell from.`,
      200,
    );
  }

  await log("info", "account_connected", { report }, workspaceId);
  return Response.redirect(`${returnOrigin}/?connected=1`, 302);
}

async function fetchPages(ids: string[], userToken: string): Promise<Page[]> {
  const pages: Page[] = [];

  for (const id of ids) {
    const page = await fetch(
      `${GRAPH}/${id}?fields=id,name,access_token,instagram_business_account{id,username}` +
        `&access_token=${encodeURIComponent(userToken)}`,
    ).then((r) => r.json());

    // A Page we cannot get a token for is not connectable, and saying so beats
    // storing a row that silently never receives anything.
    if (page.access_token) pages.push(page);
  }

  return pages;
}

interface Page {
  id: string;
  name?: string;
  access_token: string;
  instagram_business_account?: { id: string; username?: string };
}

async function connect(
  workspaceId: string,
  platform: "messenger" | "instagram" | "whatsapp",
  externalId: string,
  name: string | null,
  accessToken: string,
  businessAccountId: string | null = null,
): Promise<void> {
  const { data: account, error } = await supabase
    .from("connected_accounts")
    .upsert(
      {
        workspace_id: workspaceId,
        platform,
        external_id: externalId,
        name,
        // Reconnecting an account that was turned off, or whose token had
        // expired, puts it back in service. Without this it would keep the
        // old status and read as disconnected while messages arrived.
        status: "active",
        business_account_id: businessAccountId,
      },
      { onConflict: "platform,external_id" },
    )
    .select("id")
    .single();

  if (error) throw error;

  await supabase.from("account_tokens").upsert({
    account_id: account.id,
    access_token: accessToken,
    updated_at: new Date().toISOString(),
  });
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

function text(body: string, status: number): Response {
  return new Response(body, {
    status,
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
}
