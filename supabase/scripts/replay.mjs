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
import { ask, renderFacts, tidyEmoji, claimsAreGrounded, numbersAreGrounded, mentionsPhoto, photosMissing, photosToSend, todayInAmman, wordedOfferPrices } from "../functions/meta-webhook/ai.ts";

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

// The same columns aiPrompt reads, so the replay sees what production sees:
// codes, categories, photos and offers included.
// One shop at a time. REPLAY_WORKSPACE names it; without it, the first
// workspace that has a catalog. Unfiltered, a project with more than one
// seller mixed their catalogs into one prompt.
const workspace = process.env.REPLAY_WORKSPACE ??
  (await get("products?select=workspace_id&limit=1"))[0]?.workspace_id;
const ws = `workspace_id=eq.${workspace}`;

const products = await get("products?" + ws + "&select=id,code,name,price,description,in_stock,category_id,photos,categories(name)&order=name");
const offers = await get("offers?" + ws + "&select=name,kind,value,description,buy,get,category_ids,product_ids,starts_on,ends_on,enabled&order=created_at");
const [shopRow] = await get("shop?" + ws + "&select=currency,delivery_note,locations,hours,about,price_stance");

// Whatever Meta told us this customer is called, which is what decides how the
// assistant addresses them in Arabic. Overridable so an ambiguous name can be
// tried without touching the database.
const nameArg = process.env.REPLAY_NAME;
const [conv] = await get("conversations?" + ws + "&select=customer_name&order=last_message_at.desc&limit=1");
const customerName = nameArg !== undefined ? nameArg : (conv?.customer_name ?? null);
console.log(`--- customer name: ${customerName || "(none)"} ---`);
const zones = await get("delivery_zones?" + ws + "&select=name,fee&order=name");

const catalog = products.map((p) => ({
  id: p.id, code: p.code, categoryId: p.category_id, category: p.categories?.name ?? null,
  name: p.name, price: p.price, description: p.description, inStock: p.in_stock !== false,
  photo: p.photos?.length ? `${url}/storage/v1/object/public/product-photos/${p.photos[0]}` : null,
  thumb: p.photos?.length ? `${url}/storage/v1/object/public/product-photos/${p.photos[0].replace(/\.jpg$/, "_s.jpg")}` : null,
}));

const offerRows = offers.map((o) => ({
  name: o.name, kind: o.kind, value: o.value, buy: o.buy, get: o.get, description: o.description,
  categoryIds: o.category_ids ?? [], productIds: o.product_ids ?? [],
  startsOn: o.starts_on, endsOn: o.ends_on, enabled: o.enabled !== false,
}));

const facts = renderFacts({
  shop: shopRow ? {
    currency: shopRow.currency ?? "", deliveryNote: shopRow.delivery_note,
    locations: shopRow.locations, hours: shopRow.hours, about: shopRow.about,
    priceStance: shopRow.price_stance === "strict" ? "strict" : "notify",
  } : null,
  zones: zones.map((z) => ({ name: z.name, fee: z.fee })),
  products: catalog,
  offers: offerRows,
  today: todayInAmman(new Date()),
});

console.log(`--- the real shop: ${products.length} product(s) ---\n${facts}\n`);

// The examples the assistant is really being given, same query as aiPrompt.
const examples = (await get(
  "messages?" + ws + "&select=text&direction=eq.outbound&origin=eq.seller&text=not.is.null" +
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
  const photo = line.startsWith("img:") ? line.slice(4).split("|") : null;
  const text = photo ? (photo[1] || "[the customer sent a photo]") : line;
  turns.push(photo ? { inbound: true, text, image: photo[0] } : { inbound: true, text });
  console.log(`\n  customer > ${photo ? `[photo ${photo[0].split("/").pop()}] ` : ""}${photo ? (photo[1] ?? "") : line}`);

  const out = await ask(env.ANTHROPIC_API_KEY, { facts, now: new Date(), examples, turns, customerName, products: catalog },
    fetch, env.ANTHROPIC_WORKSPACE_ID ?? "");
  if (out.status !== "decided") { console.log(`  !! ${out.status}`); break; }

  const reply = tidyEmoji(out.decision.text);
  const said = turns.map((t) => t.text);
  const claim = claimsAreGrounded(reply, facts, said);
  console.log(`  shop     > ${reply}`);
  // What production would send after the text: the photos it asked for that
  // are real, not already sent, and at most two.
  for (const photo of photosToSend(out.decision.photos, catalog, turns)) {
    console.log(`  shop     > [photo of ${photo.product}] ${photo.url}`);
  }
  const flags = [
    out.decision.handOver ? `hand over (${out.decision.reason})` : null,
    claim ? `!! HELD BACK: "${claim}"` : null,
    numbersAreGrounded(reply, facts, said, wordedOfferPrices(catalog, offerRows, todayInAmman(new Date()))) ? null : "!! HELD BACK: number",
    photosMissing(out.decision.photos, catalog).length && mentionsPhoto(reply) ? `!! HELD BACK: no photo of ${photosMissing(out.decision.photos, catalog).join(", ")}` : null,
  ].filter(Boolean);
  if (flags.length) console.log(`             [${flags.join(" | ")}]`);
  turns.push({ inbound: false, text: reply });
}
