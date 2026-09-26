// Creates a Rabta account by inviting someone to it.
//
//   npm run invite -- someone@example.com
//   npm run invite -- someone@example.com --link
//   npm run invite -- someone@example.com --return http://localhost:5353
//
// Public sign-up is off, so this is the only way an account comes into
// existence. The seller sets their own password from the link, which means we
// never know it and it never travels through a chat.
//
// `--link` prints the link instead of sending it. That is the mode to use until
// custom SMTP is configured: Supabase's built-in sender is rate limited to a
// handful of messages an hour and is explicitly not for production, so a real
// invitation can silently fail to arrive at the worst possible moment.
//
// Needs SUPABASE_SERVICE_ROLE_KEY in supabase/.env, or SUPABASE_SECRET_KEY in
// supabase/.env.local. Creating users is not something any client may do.

import { readFile } from "node:fs/promises";

const env = {};
// RABTA_ENV=prod reads the production file and nothing else, so a command
// meant for production can never pick up a staging key, or the reverse.
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
    const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (match) env[match[1]] = match[2];
  }
}

const URL_BASE = env.SUPABASE_URL;
const KEY = env.SUPABASE_SECRET_KEY ?? env.SUPABASE_SERVICE_ROLE_KEY;

if (!URL_BASE || !KEY) {
  console.error(
    "Missing SUPABASE_URL and a service key.\n" +
      "Put them in supabase/.env.local (SUPABASE_SECRET_KEY) or supabase/.env.",
  );
  process.exit(1);
}

const args = process.argv.slice(2);
const email = args.find((a) => !a.startsWith("--"));
const linkOnly = args.includes("--link");

// Where the invitation link lands. It must be an allowed redirect URL on the
// project, or Supabase refuses it — and it must be an origin the application is
// actually served from, or the seller arrives nowhere.
const returnAt = args[args.indexOf("--return") + 1];
const redirectTo = args.includes("--return") ? returnAt : env.APP_URL ?? "http://localhost:5353";

if (!email) {
  console.error("Usage: npm run invite -- someone@example.com [--link] [--return <origin>]");
  process.exit(1);
}

const headers = {
  apikey: KEY,
  authorization: `Bearer ${KEY}`,
  "content-type": "application/json",
};

const endpoint = linkOnly
  ? `${URL_BASE}/auth/v1/admin/generate_link`
  : `${URL_BASE}/auth/v1/invite`;

// redirect_to is a top-level field on both endpoints. Nested under `options`
// it is silently ignored and the link falls back to the project's Site URL,
// which is how an invitation ends up pointing at a server nobody is running.
const body = linkOnly
  ? { type: "invite", email, redirect_to: redirectTo }
  : { email, redirect_to: redirectTo };

const response = await fetch(
  linkOnly ? endpoint : `${endpoint}?redirect_to=${encodeURIComponent(redirectTo)}`,
  { method: "POST", headers, body: JSON.stringify(body) },
);

const answer = await response.json().catch(() => null);

// Set rather than called. process.exit() while the fetch's socket is still
// open aborts the process on Windows — libuv asserts in async.c and the shell
// sees 127, so a deliberate failure loses its exit code and a clean run looks
// like a missing command.
if (!response.ok) {
  console.error(`Failed (${response.status}):`, JSON.stringify(answer, null, 2));
  process.exitCode = 1;
} else {
  console.log(`Invited ${email}`);
  console.log(`  lands at: ${redirectTo}`);

  if (linkOnly) {
    console.log(`\n  ${answer.action_link}\n`);
    console.log("Send that to them yourself. It expires — Supabase's default is");
    console.log("24 hours — and it is single use.");
  } else {
    console.log("\nAn invitation email has been sent.");
    console.log("If it does not arrive, custom SMTP is probably not configured:");
    console.log("Supabase's built-in sender is rate limited and not for production.");
  }
}

// The workspace is created by the handle_new_user trigger the moment the user
// row exists, so there is nothing else to set up for them.
