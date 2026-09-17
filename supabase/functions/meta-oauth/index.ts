// Connecting a seller's Meta accounts.
//
// Two routes:
//
//   /meta-oauth/start?workspace=<uuid>   sends the browser to Meta
//   /meta-oauth/callback?code=&state=    exchanges the code and stores what it finds
//
// Facebook Login for Business does not use a plain OAuth dialog. The request
// carries a config_id, and that configuration decides which permissions are
// asked for and which assets the seller is offered. Without it Meta returns an
// ordinary user login with no asset-selection step and no Page access — which
// is also why Graph API Explorer cannot issue Page tokens for this app.
//
// Deployed with verify_jwt = false: the browser arrives here straight from
// Meta with no Supabase session. The signed state parameter is what protects it.

import { createClient } from "jsr:@supabase/supabase-js@2";

const APP_ID = "1759728245295705";
const CONFIG_ID = "1063344539629710";
const GRAPH = "https://graph.facebook.com/v26.0";

// Must match a Valid OAuth Redirect URI registered on the app exactly. Meta
// compares strings and rejects a mismatch with a generic error.
const REDIRECT_URI =
  "https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-oauth/callback";

// Subscribing the Page to these is what makes messages arrive at all.
const SUBSCRIBED_FIELDS = "messages,messaging_postbacks,message_echoes";

const APP_SECRET = Deno.env.get("META_APP_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

Deno.serve(async (request: Request) => {
  const { pathname, searchParams } = new URL(request.url);

  if (pathname.endsWith("/start")) return await start(searchParams);
  if (pathname.endsWith("/callback")) return await callback(searchParams);

  return text("Not found", 404);
});

// ---------------------------------------------------------------------------
// Sending the seller to Meta
// ---------------------------------------------------------------------------

async function start(params: URLSearchParams): Promise<Response> {
  const workspaceId = params.get("workspace");
  if (!workspaceId) return text("Missing workspace", 400);

  const dialog = new URL("https://www.facebook.com/v26.0/dialog/oauth");
  dialog.searchParams.set("client_id", APP_ID);
  dialog.searchParams.set("config_id", CONFIG_ID);
  dialog.searchParams.set("redirect_uri", REDIRECT_URI);
  dialog.searchParams.set("response_type", "code");
  dialog.searchParams.set("state", await signState(workspaceId));

  return Response.redirect(dialog.toString(), 302);
}

// ---------------------------------------------------------------------------
// State
//
// Ties the browser flow back to the right workspace, and is the CSRF
// protection at the same time. Signing it with the app secret means no table
// and no cleanup job: a forged state cannot be produced without the secret,
// and a replayed one can only ever reach the workspace it was issued for.
// ---------------------------------------------------------------------------

async function signState(workspaceId: string): Promise<string> {
  const nonce = crypto.randomUUID();
  const body = `${workspaceId}.${nonce}`;
  return `${body}.${await hmac(body)}`;
}

async function readState(state: string | null): Promise<string | null> {
  if (!state) return null;

  const parts = state.split(".");
  if (parts.length !== 3) return null;

  const [workspaceId, nonce, signature] = parts;
  const expected = await hmac(`${workspaceId}.${nonce}`);

  if (signature.length !== expected.length) return null;

  let diff = 0;
  for (let i = 0; i < signature.length; i++) {
    diff |= signature.charCodeAt(i) ^ expected.charCodeAt(i);
  }

  return diff === 0 ? workspaceId : null;
}

async function hmac(body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(APP_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(body),
  );

  return [...new Uint8Array(signature)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// ---------------------------------------------------------------------------
// Handling Meta's redirect back
// ---------------------------------------------------------------------------

async function callback(params: URLSearchParams): Promise<Response> {
  // The seller pressed cancel, or Meta refused. Not a failure worth a 500.
  const declined = params.get("error_description") ?? params.get("error");
  if (declined) return text(`Meta declined the connection: ${declined}`, 400);

  const workspaceId = await readState(params.get("state"));
  if (!workspaceId) return text("Invalid state", 400);

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

  const pages = await fetchPages(granted.pageIds, token.access_token);
  if (pages.length === 0) {
    // The seller has no Page, or did not grant one on the asset screen. The two
    // are indistinguishable from here, and this is the likeliest way the flow
    // fails for a real seller.
    //
    // The raw responses are included while this is being worked out. A seller
    // must never see them — this becomes a plain sentence before there is a UI.
    const debug = await fetch(
      `${GRAPH}/debug_token?input_token=${encodeURIComponent(token.access_token)}` +
        `&access_token=${APP_ID}|${encodeURIComponent(APP_SECRET)}`,
    ).then((r) => r.json()).catch((e) => ({ error: String(e) }));

    const businesses = await fetch(
      `${GRAPH}/me/businesses?access_token=${encodeURIComponent(token.access_token)}`,
    ).then((r) => r.json()).catch((e) => ({ error: String(e) }));

    return text(
      "Connected, but no Facebook Page was granted.\n\n" +
        "Rabta receives messages through a Page. Either this account has none, " +
        "or the Page was not selected on Meta's permission screen.\n\n" +
        "--- diagnostics ---\n\n" +
        `token response keys: ${JSON.stringify(Object.keys(token))}\n\n` +
        `me/accounts: ${JSON.stringify(accounts, null, 2)}\n\n` +
        `debug_token: ${JSON.stringify(debug, null, 2)}\n\n` +
        `me/businesses: ${JSON.stringify(businesses, null, 2)}`,
      200,
    );
  }

  const report: string[] = [];

  for (const page of pages) {
    await connect(workspaceId, "messenger", page.id, page.name, page.access_token);
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

  return text(`Connected.\n\n${report.join("\n")}`, 200);
}

// Which Pages and Instagram accounts this token was actually granted against.
// Every pages_* scope is granted against the same Page ids and every
// instagram_* scope against the same Instagram ids, so the union of the target
// ids under each prefix is the answer.
async function grantedAssets(
  userToken: string,
): Promise<{ pageIds: string[]; instagramIds: string[] }> {
  const debug = await fetch(
    `${GRAPH}/debug_token?input_token=${encodeURIComponent(userToken)}` +
      `&access_token=${APP_ID}|${encodeURIComponent(APP_SECRET)}`,
  ).then((r) => r.json());

  const pageIds = new Set<string>();
  const instagramIds = new Set<string>();

  for (const scope of debug?.data?.granular_scopes ?? []) {
    const name = String(scope.scope ?? "");
    const target = name.startsWith("pages_")
      ? pageIds
      : name.startsWith("instagram_")
      ? instagramIds
      : null;

    if (!target) continue;
    for (const id of scope.target_ids ?? []) target.add(String(id));
  }

  return { pageIds: [...pageIds], instagramIds: [...instagramIds] };
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
  platform: "messenger" | "instagram",
  externalId: string,
  name: string | null,
  accessToken: string,
): Promise<void> {
  const { data: account, error } = await supabase
    .from("connected_accounts")
    .upsert(
      { workspace_id: workspaceId, platform, external_id: externalId, name },
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

function text(body: string, status: number): Response {
  return new Response(body, {
    status,
    headers: { "content-type": "text/plain; charset=utf-8" },
  });
}
