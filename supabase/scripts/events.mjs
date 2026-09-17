// Shows what Meta actually sent. Every payload is stored in webhook_events
// before anything is done with it, so this is the answer to "did it arrive,
// and what was in it?" when behaviour does not match expectations.
//
//   npm run events                # the 10 most recent
//   npm run events -- instagram   # only Instagram deliveries
//   npm run events -- page 25     # Messenger, 25 of them
//
// Needs SUPABASE_SERVICE_ROLE_KEY in supabase/.env. webhook_events has row
// level security with no policy, so nothing but the service role can read it.

import { readFile } from "node:fs/promises";

// .env holds the Meta secrets. The Supabase ones live in .env.local, because
// `supabase secrets set --env-file` rejects any name starting with SUPABASE_.
// Read both; later file wins.
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
// Legacy service_role keys are being retired in favour of secret keys.
const key = env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  console.error(
    "Missing SUPABASE_URL or SUPABASE_SECRET_KEY in supabase/.env.local.\n" +
    "Dashboard > Settings > API Keys > secret key. See README.md.",
  );
  process.exit(1);
}

const [object, limitArg] = process.argv.slice(2);
const limit = Number(limitArg) || 10;

const query = new URLSearchParams({
  select: "id,received_at,object,signature_valid,processed_at,attempts,error,payload",
  order: "received_at.desc",
  limit: String(limit),
});
if (object) query.set("object", `eq.${object}`);

const response = await fetch(`${url}/rest/v1/webhook_events?${query}`, {
  headers: { apikey: key, Authorization: `Bearer ${key}` },
});

if (!response.ok) {
  console.error(`${response.status} ${response.statusText}: ${await response.text()}`);
  process.exit(1);
}

const rows = await response.json();
if (rows.length === 0) {
  console.log(object ? `No ${object} deliveries stored yet.` : "No deliveries stored yet.");
  process.exit(0);
}

for (const row of rows) {
  const state = row.processed_at ? "processed" : row.error ? `FAILED (${row.attempts})` : "pending";
  console.log(
    `\n#${row.id}  ${row.received_at}  object=${row.object}  ` +
    `signature=${row.signature_valid ? "ok" : "INVALID"}  ${state}`,
  );
  if (row.error) console.log(`   error: ${row.error}`);

  for (const entry of row.payload?.entry ?? []) {
    // entry.id is the Page or Instagram account id, and it is what must exist
    // in connected_accounts or the delivery is skipped as unknown-account.
    console.log(`   entry.id = ${entry.id}   <- the account id to connect`);

    for (const event of entry.messaging ?? []) {
      const message = event.message ?? {};
      const kind = message.is_echo ? "echo/outbound" : "inbound";
      const attachments = (message.attachments ?? []).map((a) => a.type).join(",") || "none";
      console.log(
        `     ${kind}  mid=${message.mid ?? "-"}  sender=${event.sender?.id ?? "-"}  ` +
        `recipient=${event.recipient?.id ?? "-"}`,
      );
      console.log(
        `       text=${JSON.stringify(message.text ?? null)}  attachments=${attachments}` +
        (message.is_unsupported ? "  IS_UNSUPPORTED" : "") +
        (message.is_deleted ? "  IS_DELETED" : ""),
      );
    }
    if (!entry.messaging) {
      console.log(`     no 'messaging' array — keys: ${Object.keys(entry).join(", ")}`);
    }
  }
}
