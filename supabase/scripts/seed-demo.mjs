// Seeds dummy catalog data into ONE workspace: the webhook-test account's.
// Everything it adds carries a code starting "T-", so it can be removed again.
//
//   npm run seed-demo -- ../.playwright-mcp/fixtures/images.json   (photos; local only, not in git)
//   npm run seed-demo -- remove

import { readFileSync } from "node:fs";
import { randomBytes } from "node:crypto";

const supabaseDir = ".";
const [arg] = process.argv.slice(2);
const WS = "0c839c31-4a49-485b-a9f9-b2e4af479b8b";

const env = {};
for (const f of [".env", ".env.local"]) {
  let c; try { c = readFileSync(`${supabaseDir}/${f}`, "utf8"); } catch { continue; }
  for (const line of c.split(/\r?\n/)) {
    const t = line.replace(/^﻿/, "").trim();
    if (!t || t.startsWith("#") || !t.includes("=")) continue;
    const [k, ...r] = t.split("="); const v = r.join("=").trim().replace(/^["']|["']$/g, "");
    if (v) env[k.trim()] = v;
  }
}
const url = env.SUPABASE_URL.replace(/\/$/, "");
const key = env.SUPABASE_SECRET_KEY || env.SUPABASE_SERVICE_ROLE_KEY;
const h = { apikey: key, Authorization: `Bearer ${key}` };

async function rest(path, init = {}) {
  const r = await fetch(`${url}/rest/v1/${path}`, {
    ...init,
    headers: { ...h, "content-type": "application/json", Prefer: "return=representation", ...(init.headers ?? {}) },
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`${path}: ${r.status} ${text}`);
  return text ? JSON.parse(text) : null;
}

async function upload(path, base64) {
  const r = await fetch(`${url}/storage/v1/object/product-photos/${path}`, {
    method: "POST",
    headers: { ...h, "content-type": "image/jpeg" },
    body: Buffer.from(base64, "base64"),
  });
  if (!r.ok) throw new Error(`upload ${path}: ${r.status} ${await r.text()}`);
}

if (arg === "remove") {
  const products = await rest(`products?workspace_id=eq.${WS}&code=like.T-*&select=id,photos`);
  const files = [
    `${WS}/screenshot-test-clutch.jpg`,
    ...products.flatMap((p) => p.photos.flatMap((f) => [f, f.replace(/\.jpg$/, "_s.jpg")])),
  ];
  {
    await fetch(`${url}/storage/v1/object/product-photos`, {
      method: "DELETE", headers: { ...h, "content-type": "application/json" }, body: JSON.stringify({ prefixes: files }),
    });
  }
  await rest(`products?workspace_id=eq.${WS}&code=like.T-*`, { method: "DELETE" });
  for (const name of ['عرض نهاية الشهر', 'عرض العطور', 'عرض الإكسسوارات', 'عرض الشنط']) {
    await rest(`offers?workspace_id=eq.${WS}&name=eq.${encodeURIComponent(name)}`, { method: 'DELETE' });
  }
  for (const name of ["فساتين", "حقائب", "عطور", "إكسسوارات"]) {
    const [c] = await rest(`categories?workspace_id=eq.${WS}&name=eq.${encodeURIComponent(name)}&select=id`);
    const used = c ? await rest(`products?category_id=eq.${c.id}&select=id`) : [];
    if (c && used.length === 0) await rest(`categories?id=eq.${c.id}`, { method: "DELETE" });
  }
  console.log(`removed ${products.length} products, their photos, the test offers and empty categories`);
  process.exit(0);
}

const images = JSON.parse(readFileSync(arg, "utf8"));
const photos = typeof images === "string" ? JSON.parse(images) : images;

// Refuse to seed twice.
const already = await rest(`products?workspace_id=eq.${WS}&code=like.T-*&select=id`);
if (already.length) throw new Error(`already seeded (${already.length} T- products); remove first`);

const categories = {};
for (const name of ["فساتين", "حقائب", "عطور", "إكسسوارات"]) {
  const [existing] = await rest(`categories?workspace_id=eq.${WS}&name=eq.${encodeURIComponent(name)}&select=id`);
  categories[name] = existing?.id ?? (await rest("categories", { method: "POST", body: JSON.stringify({ workspace_id: WS, name }) }))[0].id;
}

const catalog = [
  ["T-001", "فستان سهرة أسود", 45, "فساتين", true, "المقاسات: S M L XL\nقماش ساتان مع حزام ذهبي، طويل للأرض\nبيجي مقاسه مظبوط"],
  ["T-002", "فستان صيفي أزرق", 25.5, "فساتين", true, "المقاسات: S M L\nقطن خفيف منقّط، طوله لتحت الركبة"],
  ["T-003", "عباية كحلية", 38, "فساتين", true, "مقاس واحد يناسب لغاية XL\nكريب مع تطريز ذهبي على الطرف"],
  ["T-004", "شنطة جلد بنية", 18, "حقائب", true, "جلد صناعي، حجم متوسط، إلها سحّاب"],
  ["T-005", "شنطة سهرة سوداء", 22, "حقائب", true, "كلاتش صغيرة مع سلسلة فضية"],
  ["T-006", "عطر ورد", 30, "عطور", true, "50 مل، ريحة ورد جوري ناعمة"],
  ["T-007", "عطر عود", 55.75, "عطور", true, "100 مل، ريحة عود ثقيلة وثابتة"],
  ["T-008", "سلسال ذهبي", 12, "إكسسوارات", true, "ستانلس ستيل مطلي، ما بيسوّد"],
  ["T-009", "نظارة شمسية", 15, "إكسسوارات", true, "إطار أسود، حماية UV400"],
  ["T-010", "حزام جلد", 9.5, "إكسسوارات", false, "جلد بني، مقاس واحد قابل للتعديل"],
];

for (const [code, name, price, category, inStock, description] of catalog) {
  const paths = [];
  if (photos[code]) {
    const path = `${WS}/${randomBytes(16).toString("hex")}.jpg`;
    await upload(path, photos[code].full);
    await upload(path.replace(/\.jpg$/, "_s.jpg"), photos[code].thumb);
    paths.push(path);
  }
  await rest("products", {
    method: "POST",
    body: JSON.stringify({
      workspace_id: WS, code, name, price, description, in_stock: inStock,
      category_id: categories[category], photos: paths,
    }),
  });
  console.log(`${code} ${name} ${paths.length ? "with photo" : "no photo"}`);
}

const offers = [
  { name: "عرض نهاية الشهر", kind: "percent", value: 20, category_ids: [categories["فساتين"]], ends_on: "2026-09-30" },
  { name: "عرض العطور", kind: "buy_get", buy: 2, get: 1, category_ids: [categories["عطور"]] },
  { name: "عرض الإكسسوارات", kind: "text", description: "خصم 10% على كل منتجات قسم إكسسوارات", ends_on: "2026-10-15" },
  { name: "عرض الشنط", kind: "text", description: "القطعة الثانية من قسم حقائب بنص السعر" },
];
for (const offer of offers) {
  await rest("offers", { method: "POST", body: JSON.stringify({ workspace_id: WS, enabled: true, ...offer }) });
  console.log(`offer: ${offer.name}`);
}

// The screenshot, somewhere a phone can open it.
const shot = `${WS}/screenshot-test-clutch.jpg`;
await fetch(`${url}/storage/v1/object/product-photos/${shot}`, {
  method: "POST", headers: { ...h, "content-type": "image/jpeg", "x-upsert": "true" }, body: Buffer.from(photos.screenshot, "base64"),
});
console.log(`screenshot: ${url}/storage/v1/object/public/product-photos/${shot}`);
