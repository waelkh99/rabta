// A one-time sign-in link for an account that already exists.
//
//   npm run signin -- playwright-seller@example.test
//   npm run signin -- someone@example.test http://localhost:5353
//
// For driving the interface in a browser. `npm run invite` creates accounts and
// refuses an email that already has one (email_exists), which is every test
// account after the first run. This asks Supabase for a magic link instead;
// opening it in the browser signs that account in and lands on the app.
//
// Needs SUPABASE_URL and SUPABASE_SECRET_KEY in supabase/.env.local. Prints the
// link and sends nothing: treat it like a password until it is used.

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
    const trimmed = line.replace(/^﻿/, "").trim();
    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;
    const [key, ...rest] = trimmed.split("=");
    const value = rest.join("=").trim().replace(/^["']|["']$/g, "");
    if (value) env[key.trim()] = value;
  }
}

const url = env.SUPABASE_URL?.replace(/\/$/, "");
const key = env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY;
const [email, redirect = "http://localhost:5353"] = process.argv.slice(2);

if (!url || !key || !email) {
  console.error("Usage: npm run signin -- someone@example.test [return-url]");
  process.exit(1);
}

const response = await fetch(`${url}/auth/v1/admin/generate_link`, {
  method: "POST",
  headers: { apikey: key, Authorization: `Bearer ${key}`, "content-type": "application/json" },
  body: JSON.stringify({ type: "magiclink", email, redirect_to: redirect }),
});

const body = await response.json();
const link = body.action_link ?? body.properties?.action_link;

if (!response.ok || !link) {
  console.error(`No link: ${response.status} ${JSON.stringify(body)}`);
  process.exit(1);
}

console.log(link);
