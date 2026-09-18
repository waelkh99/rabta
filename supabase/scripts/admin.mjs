// Marks someone as one of us, rather than a seller.
//
//   npm run admin                          lists who is an admin
//   npm run admin -- them@example.com      makes them one
//   npm run admin -- them@example.com --revoke
//
// Admins are the only accounts that can create other accounts, so there is
// deliberately no screen for this: granting it needs the service key, which
// only we have. That is also the answer to the bootstrap problem — the first
// admin cannot be made from inside the product.
//
// The flag lives in app_metadata, which a user cannot write to. Putting it in
// user_metadata would let any seller make themselves an admin.

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

// Must match ADMIN_FLAG in functions/admin-invite/admin.ts.
const FLAG = "rabta_admin";

const headers = {
  apikey: KEY,
  authorization: `Bearer ${KEY}`,
  "content-type": "application/json",
};

// Exits are set rather than called. process.exit() while a fetch's socket is
// still open aborts the process on Windows — libuv asserts in async.c and the
// shell sees 127, so a script that worked looks like a missing command and a
// deliberate failure loses its exit code. Setting process.exitCode and
// returning lets Node close down on its own.

async function users() {
  const response = await fetch(`${URL_BASE}/auth/v1/admin/users?per_page=200`, { headers });
  if (!response.ok) {
    throw new Error(`Could not list users (${response.status})`);
  }
  return (await response.json()).users ?? [];
}

const args = process.argv.slice(2);
const email = args.find((a) => !a.startsWith("--"));
const revoking = args.includes("--revoke");

await main();

async function main() {
const everyone = await users();

if (!email) {
  const admins = everyone.filter((u) => u.app_metadata?.[FLAG] === true);

  console.log(`${everyone.length} account(s), ${admins.length} admin(s):\n`);
  for (const user of everyone) {
    const mark = user.app_metadata?.[FLAG] === true ? "admin " : "      ";
    console.log(`  ${mark} ${user.email}`);
  }
  console.log("\nnpm run admin -- them@example.com   to make someone an admin");
  return;
}

const user = everyone.find((u) => (u.email ?? "").toLowerCase() === email.toLowerCase());

if (!user) {
  console.error(`No account for ${email}.`);
  console.error("Invite them first: npm run invite -- " + email);
  process.exitCode = 1;
  return;
}

const response = await fetch(`${URL_BASE}/auth/v1/admin/users/${user.id}`, {
  method: "PUT",
  headers,
  // GoTrue merges app_metadata rather than replacing it, so provider details
  // survive. null removes the key outright, which is tidier than leaving a
  // false behind.
  body: JSON.stringify({ app_metadata: { [FLAG]: revoking ? null : true } }),
});

const answer = await response.json().catch(() => null);

if (!response.ok) {
  console.error(`Failed (${response.status}):`, JSON.stringify(answer, null, 2));
  process.exitCode = 1;
  return;
}

const nowAdmin = answer?.app_metadata?.[FLAG] === true;

console.log(`${email} is ${nowAdmin ? "now an admin" : "no longer an admin"}.`);
console.log(`  app_metadata: ${JSON.stringify(answer?.app_metadata)}`);

if (nowAdmin !== !revoking) {
  console.error("\nThat is not what was asked for. Check the flag name.");
  process.exitCode = 1;
  return;
}

// A token already issued still says what it said. The check on the server
// reads the user record rather than the token, so this takes effect at once.
console.log("\nTakes effect immediately: the server reads the record, not the token.");
}
