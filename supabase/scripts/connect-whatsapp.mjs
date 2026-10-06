// Connects a WhatsApp number to a seller's workspace, by hand.
//
//   npm run connect-whatsapp -- seller@example.test
//
// For Meta's test number while the in-app "Connect WhatsApp" button does not
// exist yet (NEXT.md, B2). Reads from supabase/.env:
//
//   WHATSAPP_PHONE_NUMBER_ID, WHATSAPP_WABA_ID, WHATSAPP_TOKEN — from the Meta
//   app's WhatsApp > API Setup, and a system-user token that never expires.
//
// It records the number and its token the same way meta-oauth does for a Page,
// and subscribes the Rabta app to the WhatsApp Business Account so Meta starts
// delivering its messages to the webhook. Safe to run again.

import { readFile } from "node:fs/promises";

const env = {};
const envFiles =
  process.env.RABTA_ENV === "prod" ? ["../.env.prod"] : ["../.env", "../.env.local"];
for (const file of envFiles) {
  let contents;
  try {
    contents = await readFile(new URL(file, import.meta.url), "utf8");
  } catch {
    continue;
  }
  for (const line of contents.split(/\r?\n/)) {
    const trimmed = line.replace(/^﻿/, "").trim();
    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;
    const [key, ...rest] = trimmed.split("=");
    const value = rest.join("=").trim().replace(/^["']|["']$/g, "");
    if (value) env[key.trim()] = value;
  }
}

const GRAPH = "https://graph.facebook.com/v26.0";
const url = env.SUPABASE_URL?.replace(/\/$/, "");
const key = env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY;
const phoneId = env.WHATSAPP_PHONE_NUMBER_ID;
const wabaId = env.WHATSAPP_WABA_ID;
const token = env.WHATSAPP_TOKEN;
const [email] = process.argv.slice(2);

if (!url || !key || !phoneId || !wabaId || !token || !email) {
  console.error("Usage: npm run connect-whatsapp -- seller@example.test");
  console.error("Needs SUPABASE_URL, a service key and the three WHATSAPP_ values in supabase/.env.");
  process.exit(1);
}

const supabase = { apikey: key, Authorization: `Bearer ${key}`, "content-type": "application/json" };
const meta = { Authorization: `Bearer ${token}` };

async function json(response, what) {
  const body = await response.json().catch(() => null);
  if (!response.ok) {
    console.error(`${what} failed (${response.status}):`, JSON.stringify(body));
    process.exit(1);
  }
  return body;
}

// 1. Whose workspace.
const users = await json(
  await fetch(`${url}/auth/v1/admin/users?per_page=1000`, { headers: supabase }),
  "listing users",
);
const user = users.users.find((u) => u.email?.toLowerCase() === email.toLowerCase());
if (!user) {
  console.error(`No account for ${email}.`);
  process.exit(1);
}
const [workspace] = await json(
  await fetch(`${url}/rest/v1/workspaces?owner_id=eq.${user.id}&select=id`, { headers: supabase }),
  "finding the workspace",
);
if (!workspace) {
  console.error(`${email} has no workspace.`);
  process.exit(1);
}

// 2. What the number is called, as the seller will see it on the Accounts page.
const number = await json(
  await fetch(`${GRAPH}/${phoneId}?fields=display_phone_number,verified_name`, { headers: meta }),
  "reading the number from Meta",
);
const name = `${number.verified_name} (${number.display_phone_number})`;

// 3. The account and its token. Upserted on (platform, external_id), the same
// key meta-oauth uses, so a second run updates rather than duplicates.
const [account] = await json(
  await fetch(`${url}/rest/v1/connected_accounts?on_conflict=platform,external_id`, {
    method: "POST",
    headers: { ...supabase, Prefer: "resolution=merge-duplicates,return=representation" },
    body: JSON.stringify({
      workspace_id: workspace.id,
      platform: "whatsapp",
      external_id: phoneId,
      name,
      status: "active",
      business_account_id: wabaId,
    }),
  }),
  "saving the account",
);
await json(
  await fetch(`${url}/rest/v1/account_tokens?on_conflict=account_id`, {
    method: "POST",
    headers: { ...supabase, Prefer: "resolution=merge-duplicates,return=minimal" },
    body: JSON.stringify({ account_id: account.id, access_token: token, updated_at: new Date().toISOString() }),
  }),
  "saving the token",
);

// 4. Ask Meta to deliver this account's messages to our app.
const subscribed = await json(
  await fetch(`${GRAPH}/${wabaId}/subscribed_apps`, { method: "POST", headers: meta }),
  "subscribing the app",
);

console.log(`Connected ${name} to ${email}'s workspace (account ${account.id}).`);
console.log(`Subscribed to WhatsApp account ${wabaId}: ${JSON.stringify(subscribed)}`);
