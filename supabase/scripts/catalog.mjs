// What the assistant is actually allowed to know, straight from the database.
//
// The answer to "did it make that up?" — if a detail is not printed here, the
// model did not get it from us.
//
//   npm run catalog

import { readFile } from "node:fs/promises";

const env = {};
for (const file of ["../.env", "../.env.local"]) {
  let contents;
  try { contents = await readFile(new URL(file, import.meta.url), "utf8"); } catch { continue; }
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
  const res = await fetch(`${url}/rest/v1/${path}`, { headers });
  if (!res.ok) { console.error(`${res.status}: ${await res.text()}`); process.exit(1); }
  return res.json();
};

const products = await get("products?select=name,price,description,in_stock&order=name");
const shop = await get("shop?select=currency,delivery_note,locations,hours,about");
const zones = await get("delivery_zones?select=name,fee&order=name");

console.log("PRODUCTS");
for (const p of products) {
  console.log(`  ${p.name}`);
  console.log(`     price       ${p.price ?? "(none)"}`);
  console.log(`     description ${p.description ?? "(none)"}`);
  console.log(`     in stock    ${p.in_stock}`);
}
if (products.length === 0) console.log("  (none)");

console.log("\nSHOP");
for (const s of shop) {
  for (const [k, v] of Object.entries(s)) console.log(`  ${k.padEnd(14)} ${v ?? "(none)"}`);
}
if (shop.length === 0) console.log("  (no row — the assistant knows nothing but the catalog)");

console.log("\nDELIVERY ZONES");
for (const z of zones) console.log(`  ${z.name}: ${z.fee ?? "(varies)"}`);
if (zones.length === 0) console.log("  (none)");

console.log(
  "\nAnything the assistant said that is not above, it invented.",
);
