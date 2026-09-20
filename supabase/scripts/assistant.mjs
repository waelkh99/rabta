// What the assistant actually did, from the database rather than the logs.
//
// The CLI has no `functions logs`, and the rows are better evidence anyway:
// they say what reached the customer, what was held back, and why.
//
//   npm run assistant          # the 5 most recently active conversations
//   npm run assistant -- 12    # more of them
//
// Needs the service role key, same as `npm run events`.

import { readFile } from "node:fs/promises";

const env = {};
for (const file of ["../.env", "../.env.local"]) {
  let contents;
  try {
    contents = await readFile(new URL(file, import.meta.url), "utf8");
  } catch {
    continue;
  }
  for (const line of contents.split(/\r?\n/)) {
    const trimmed = line.replace(/^\uFEFF/, "").trim();
    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;
    const [key, ...rest] = trimmed.split("=");
    const value = rest.join("=").trim().replace(/^["']|["']$/g, "");
    if (value) env[key.trim()] = value;
  }
}

const url = env.SUPABASE_URL?.replace(/\/$/, "");
const key = env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  console.error("Missing SUPABASE_URL or SUPABASE_SECRET_KEY in supabase/.env.local.");
  process.exit(1);
}

const headers = { apikey: key, Authorization: `Bearer ${key}` };
const get = async (path) => {
  const response = await fetch(`${url}/rest/v1/${path}`, { headers });
  if (!response.ok) {
    console.error(`${response.status}: ${await response.text()}`);
    process.exit(1);
  }
  return response.json();
};

const limit = Number(process.argv[2]) || 5;

const conversations = await get(
  "conversations?select=id,customer_name,last_message_at,window_expires_at," +
    "ai_state,ai_escalation_reason,ai_last_run_at&order=last_message_at.desc&limit=" + limit,
);

if (conversations.length === 0) {
  console.log("No conversations yet.");
  process.exit(0);
}

const now = Date.now();

for (const c of conversations) {
  const open = c.window_expires_at && new Date(c.window_expires_at).getTime() > now;

  console.log(`\n${"=".repeat(70)}`);
  console.log(`${c.customer_name ?? "(no name)"}   window ${open ? "open" : "CLOSED"}`);
  console.log(
    `ai_state = ${c.ai_state ?? "null (never looked at it)"}` +
      (c.ai_escalation_reason ? `   reason: ${c.ai_escalation_reason}` : ""),
  );
  if (c.ai_last_run_at) console.log(`last run  ${c.ai_last_run_at}`);
  console.log("=".repeat(70));

  const messages = await get(
    `messages?select=direction,origin,text,attachments,sent_at&conversation_id=eq.${c.id}` +
      "&order=sent_at.desc&limit=12",
  );

  for (const m of messages.reverse()) {
    const who = m.direction === "inbound"
      ? "customer"
      : m.origin === "ai"
      ? "SHOP(ai) "
      : "shop     ";
    const body = m.text && m.text.trim()
      ? m.text
      : `(${(m.attachments ?? []).map((a) => a.type).join(",") || "no text"})`;
    // Date as well as time: a thread can span days, and time alone makes the
    // rows look out of order.
    console.log(`  ${m.sent_at.slice(5, 16).replace("T", " ")}  ${who} > ${body}`);
  }
}

console.log(
  "\nai_state 'answered' means the customer got the assistant's own words.\n" +
    "'escalated' with a reason means it stepped back — the reason says whether\n" +
    "that was a guard, the model's own choice, or a reply held back on the way out.",
);
