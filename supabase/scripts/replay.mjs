// Replays a conversation against the REAL production catalog.
//
// The scripted harness uses an eight-product shop. A real seller may have one,
// and behaviour differs: with one item there is nothing to compare it against,
// so every "offer an alternative" rule has nowhere to go.
//
//   npm run replay
//
// Reads the shop from the database and the key from .env. Sends to Anthropic;
// sends nothing to Meta and writes nothing back.

import { readFile } from "node:fs/promises";
import { ask, renderFacts, tidyEmoji, claimsAreGrounded, numbersAreGrounded } from "../functions/meta-webhook/ai.ts";

const env = {};
for (const file of ["../.env", "../.env.local"]) {
  let c; try { c = await readFile(new URL(file, import.meta.url), "utf8"); } catch { continue; }
  for (const line of c.split(/\r?\n/)) {
    const t = line.replace(/^\uFEFF/, "").trim();
    if (!t || t.startsWith("#") || !t.includes("=")) continue;
    const [k, ...r] = t.split("="); const v = r.join("=").trim().replace(/^["']|["']$/g, "");
    if (v) env[k.trim()] = v;
  }
}

const url = env.SUPABASE_URL?.replace(/\/$/, "");
const key = env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY;
const headers = { apikey: key, Authorization: `Bearer ${key}` };
const get = async (p) => (await fetch(`${url}/rest/v1/${p}`, { headers })).json();

const products = await get("products?select=name,price,description,in_stock&order=name");
const [shopRow] = await get("shop?select=currency,delivery_note,locations,hours,about,price_stance");

// Whatever Meta told us this customer is called, which is what decides how the
// assistant addresses them in Arabic. Overridable so an ambiguous name can be
// tried without touching the database.
const nameArg = process.env.REPLAY_NAME;
const [conv] = await get("conversations?select=customer_name&order=last_message_at.desc&limit=1");
const customerName = nameArg !== undefined ? nameArg : (conv?.customer_name ?? null);
console.log(`--- customer name: ${customerName || "(none)"} ---`);
const zones = await get("delivery_zones?select=name,fee&order=name");

const facts = renderFacts({
  shop: shopRow ? {
    currency: shopRow.currency ?? "", deliveryNote: shopRow.delivery_note,
    locations: shopRow.locations, hours: shopRow.hours, about: shopRow.about,
    priceStance: shopRow.price_stance === "strict" ? "strict" : "notify",
  } : null,
  zones: zones.map((z) => ({ name: z.name, fee: z.fee })),
  products: products.map((p) => ({
    name: p.name, price: p.price, description: p.description, inStock: p.in_stock !== false,
  })),
});

console.log(`--- the real shop: ${products.length} product(s) ---\n${facts}\n`);

// The examples the assistant is really being given, same query as aiPrompt.
const examples = (await get(
  "messages?select=text&direction=eq.outbound&origin=eq.seller&text=not.is.null" +
  "&order=sent_at.desc&limit=40",
)).map((m) => m.text).filter((t) => t && t.trim());

console.log(`--- voice examples it is learning from (${examples.length}) ---`);
for (const e of examples) console.log(`  - ${e}`);

const lines = process.argv.slice(2).length
  ? process.argv.slice(2)
  : ["يعطيك العافية", "بدور على هدية لعيد الام كيف ممكن تساعدني", "حلو، قديش سعره؟", "تمام بدي اشتريه"];

const turns = [];
console.log("\n--- replay ---");
for (const line of lines) {
  turns.push({ inbound: true, text: line });
  console.log(`\n  customer > ${line}`);

  const out = await ask(env.ANTHROPIC_API_KEY, { facts, now: new Date(), examples, turns, customerName },
    fetch, env.ANTHROPIC_WORKSPACE_ID ?? "");
  if (out.status !== "decided") { console.log(`  !! ${out.status}`); break; }

  const reply = tidyEmoji(out.decision.text);
  const said = turns.map((t) => t.text);
  const claim = claimsAreGrounded(reply, facts, said);
  console.log(`  shop     > ${reply}`);
  const flags = [
    out.decision.handOver ? `hand over (${out.decision.reason})` : null,
    claim ? `!! HELD BACK: "${claim}"` : null,
    numbersAreGrounded(reply, facts, said) ? null : "!! HELD BACK: number",
  ].filter(Boolean);
  if (flags.length) console.log(`             [${flags.join(" | ")}]`);
  turns.push({ inbound: false, text: reply });
}
