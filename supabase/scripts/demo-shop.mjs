// The demo shop: a login anyone can be given, to see what Rabta looks like.
//
//   $env:RABTA_ENV="prod"; npm run demo-shop
//
// Creates DEMO_EMAIL with DEMO_PASSWORD (from the env file) if it does not
// exist, and restores the password if it does. Then empties that one
// workspace and fills it again: a fictional boutique in Amman, its catalog
// with photos, offers, delivery areas, two "connected" accounts and a week of
// conversations. Run it again whenever a visitor has made a mess of it — or
// just to make the conversations recent again, since their times are set
// relative to now and a reply window only lasts 24 hours.
//
// Safe to share, by construction:
//   - The accounts have no Meta token. A reply from the demo is refused as
//     "disconnected" and never leaves; the account check skips it.
//   - Every conversation is marked as already read, so the assistant never
//     reads one and it costs nothing.
//   - It is an ordinary seller: no admin rights, and row level security keeps
//     it to its own workspace.
//
// Photos are drawn by tool/demo_photos.py into supabase/demo/photos.

import { readFile } from "node:fs/promises";
import { randomBytes, randomUUID } from "node:crypto";

// RABTA_ENV=prod reads the production file and nothing else, so a command
// meant for production can never pick up a staging key, or the reverse.
const envFiles =
  process.env.RABTA_ENV === "prod" ? ["../.env.prod"] : ["../.env", "../.env.local"];
const env = {};
for (const file of envFiles) {
  let contents;
  try {
    contents = await readFile(new URL(file, import.meta.url), "utf8");
  } catch {
    continue;
  }
  for (const line of contents.split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*"?([^"]*)"?\s*$/);
    if (match) env[match[1]] = match[2];
  }
}

const URL_BASE = env.SUPABASE_URL?.replace(/\/$/, "");
const KEY = env.SUPABASE_SECRET_KEY ?? env.SUPABASE_SERVICE_ROLE_KEY;
const EMAIL = env.DEMO_EMAIL;
const PASSWORD = env.DEMO_PASSWORD;
if (!URL_BASE || !KEY || !EMAIL || !PASSWORD) {
  console.error("Missing SUPABASE_URL, a service key, DEMO_EMAIL or DEMO_PASSWORD.");
  process.exit(1);
}

const auth = { apikey: KEY, Authorization: `Bearer ${KEY}` };

async function call(path, init = {}) {
  const response = await fetch(`${URL_BASE}${path}`, {
    ...init,
    headers: { ...auth, "content-type": "application/json", ...(init.headers ?? {}) },
  });
  const text = await response.text();
  if (!response.ok) throw new Error(`${init.method ?? "GET"} ${path}: ${response.status} ${text}`);
  return text ? JSON.parse(text) : null;
}

const rest = (path, init = {}) =>
  call(`/rest/v1/${path}`, { ...init, headers: { Prefer: "return=representation", ...(init.headers ?? {}) } });

// ---------------------------------------------------------------------------
// The account
// ---------------------------------------------------------------------------

const { users } = await call("/auth/v1/admin/users?per_page=1000");
let user = users.find((u) => u.email === EMAIL);
if (user) {
  await call(`/auth/v1/admin/users/${user.id}`, {
    method: "PUT",
    body: JSON.stringify({ password: PASSWORD, email_confirm: true }),
  });
  console.log(`${EMAIL}: exists, password restored`);
} else {
  user = await call("/auth/v1/admin/users", {
    method: "POST",
    body: JSON.stringify({ email: EMAIL, password: PASSWORD, email_confirm: true }),
  });
  console.log(`${EMAIL}: created`);
}
if (user.app_metadata?.rabta_admin === true) {
  throw new Error("The demo account must never be an admin. Stopping.");
}

const [workspace] = await rest(`workspaces?owner_id=eq.${user.id}&select=id`);
if (!workspace) throw new Error("No workspace for the demo account.");
const WS = workspace.id;

// ---------------------------------------------------------------------------
// Emptying it
// ---------------------------------------------------------------------------

for (const table of ["connected_accounts", "offers", "products", "categories", "delivery_zones"]) {
  await rest(`${table}?workspace_id=eq.${WS}`, { method: "DELETE", headers: { Prefer: "return=minimal" } });
}
const stored = await call("/storage/v1/object/list/product-photos", {
  method: "POST",
  body: JSON.stringify({ prefix: WS, limit: 1000 }),
});
if (stored.length) {
  await call("/storage/v1/object/product-photos", {
    method: "DELETE",
    body: JSON.stringify({ prefixes: stored.map((f) => `${WS}/${f.name}`) }),
  });
}

// ---------------------------------------------------------------------------
// The shop
// ---------------------------------------------------------------------------

await rest(`workspaces?id=eq.${WS}`, { method: "PATCH", body: JSON.stringify({ name: "ليالي بوتيك" }) });

await rest("shop?on_conflict=workspace_id", {
  method: "POST",
  headers: { Prefer: "resolution=merge-duplicates,return=minimal" },
  body: JSON.stringify({
    workspace_id: WS,
    currency: "د.ا",
    about: "بوتيك نسائي في عمّان: فساتين، شنط، عطور وإكسسوارات. كل القطع مختارة بعناية.",
    locations: "عمّان، الصويفية، شارع الوكالات، بجانب مخبز الشعلان",
    hours: "يومياً من 10 صباحاً حتى 10 مساءً، والجمعة من 2 ظهراً",
    delivery_note: "التوصيل خلال يوم إلى يومين، والدفع عند الاستلام. التبديل خلال 3 أيام إذا القطعة بحالتها.",
    assistant_enabled: true,
    price_stance: "notify",
  }),
});

await rest("delivery_zones", {
  method: "POST",
  headers: { Prefer: "return=minimal" },
  body: JSON.stringify([
    { workspace_id: WS, name: "عمّان", fee: 2 },
    { workspace_id: WS, name: "الزرقاء", fee: 3 },
    { workspace_id: WS, name: "إربد", fee: 3.5 },
    { workspace_id: WS, name: "باقي المحافظات", fee: 4 },
  ]),
});

const categories = Object.fromEntries(
  (await rest("categories", {
    method: "POST",
    body: JSON.stringify(
      ["فساتين", "شنط", "عطور", "أحذية وإكسسوارات"].map((name) => ({ workspace_id: WS, name })),
    ),
  })).map((c) => [c.name, c.id]),
);

async function uploadPhoto(name) {
  const path = `${WS}/${randomBytes(16).toString("hex")}.jpg`;
  for (const [suffix, target] of [["", path], ["_s", path.replace(/\.jpg$/, "_s.jpg")]]) {
    const body = await readFile(new URL(`../demo/photos/${name}${suffix}.jpg`, import.meta.url));
    const response = await fetch(`${URL_BASE}/storage/v1/object/product-photos/${target}`, {
      method: "POST",
      headers: { ...auth, "content-type": "image/jpeg" },
      body,
    });
    if (!response.ok) throw new Error(`upload ${name}: ${response.status} ${await response.text()}`);
  }
  return path;
}

const catalog = [
  { code: "D-001", name: "فستان سهرة أسود", price: 45, category: "فساتين", photo: "evening-dress",
    description: "قماش كريب ثقيل، طول ميدي. المقاسات S و M و L و XL. الألوان: أسود وكحلي." },
  { code: "D-002", name: "فستان صيفي منقّط", price: 28, category: "فساتين", photo: "floral-dress",
    description: "قطن خفيف، مناسب للصيف. المقاسات S و M و L. الألوان: زهري وأبيض." },
  { code: "D-003", name: "شنطة جلد بني", price: 32, category: "شنط", photo: "leather-bag",
    description: "جلد طبيعي، 30×22 سم، بجيب داخلي بسحّاب. تتسع لجهاز لوحي صغير." },
  { code: "D-004", name: "شنطة كروس بنفسجي", price: 22, category: "شنط", photo: "crossbody-bag",
    description: "شنطة صغيرة بحزام طويل قابل للتعديل. الألوان: بنفسجي وأسود." },
  { code: "D-005", name: "عطر ورد دمشقي", price: 25, category: "عطور", photo: "rose-perfume",
    description: "50 مل، رائحة ورد ناعمة تدوم حتى 8 ساعات." },
  { code: "D-006", name: "عطر عود ملكي", price: 40, category: "عطور", photo: "oud-perfume",
    description: "100 مل، عود مع لمسة عنبر. مناسب للمساء." },
  { code: "D-007", name: "حذاء كعب أحمر", price: 30, category: "أحذية وإكسسوارات", photo: "red-heels",
    description: "كعب 8 سم. المقاسات من 36 إلى 40." },
  { code: "D-008", name: "شال حرير", price: 12, category: "أحذية وإكسسوارات", photo: "silk-scarf",
    description: "حرير صناعي ناعم، 90×90 سم. الألوان: أخضر زيتي وكحلي." },
  { code: "D-009", name: "ساعة نسائية ذهبية", price: 55, category: "أحذية وإكسسوارات", photo: "gold-watch",
    description: "ستانلس ستيل مطلي، مقاومة للماء. كفالة سنة.", inStock: false },
];

const products = {};
for (const item of catalog) {
  const [row] = await rest("products", {
    method: "POST",
    body: JSON.stringify({
      workspace_id: WS,
      code: item.code,
      name: item.name,
      price: item.price,
      description: item.description,
      category_id: categories[item.category],
      in_stock: item.inStock ?? true,
      photos: [await uploadPhoto(item.photo)],
    }),
  });
  products[item.code] = row;
}

const inAMonth = new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10);
// One shape for every row: a bulk insert refuses rows whose keys differ.
const offer = (fields) => ({
  workspace_id: WS, value: null, buy: null, get: null, description: null,
  category_ids: [], product_ids: [], starts_on: null, ends_on: null, enabled: true,
  ...fields,
});
await rest("offers", {
  method: "POST",
  headers: { Prefer: "return=minimal" },
  body: JSON.stringify([
    offer({ name: "خصم العطور", kind: "percent", value: 10,
      category_ids: [categories["عطور"]], ends_on: inAMonth }),
    offer({ name: "اشترِ شالين والثالث مجاناً", kind: "buy_get", buy: 2, get: 1,
      product_ids: [products["D-008"].id] }),
    offer({ name: "توصيل مجاني", kind: "text",
      description: "التوصيل مجاني داخل عمّان للطلبات فوق 50 دينار." }),
  ]),
});

// ---------------------------------------------------------------------------
// The inbox
// ---------------------------------------------------------------------------

const accounts = Object.fromEntries(
  (await rest("connected_accounts", {
    method: "POST",
    body: JSON.stringify([
      // Not Meta ids, and with no token: nothing can be received or sent.
      { workspace_id: WS, platform: "instagram", external_id: `demo-instagram-${WS}`, name: "@layali.boutique", status: "active" },
      { workspace_id: WS, platform: "messenger", external_id: `demo-page-${WS}`, name: "Layali Boutique", status: "active" },
    ]),
  })).map((a) => [a.platform, a.id]),
);

const photoUrl = (code) =>
  `${URL_BASE}/storage/v1/object/public/product-photos/${products[code].photos[0]}`;

// Minutes before now. Customers write the way customers here do: Jordanian
// Arabic, some English, some Arabizi.
const conversations = [
  {
    platform: "messenger", name: "Omar Haddad", unread: 1,
    ai: { state: "escalated", reason: "يسأل عن التوصيل إلى العقبة، والعقبة ليست في مناطق التوصيل التي كتبتها." },
    messages: [
      ["in", "Hi, is the leather bag still available?", 200],
      ["ai", "أهلاً عمر! نعم، شنطة الجلد البني متوفرة، وسعرها 32 د.ا.", 199],
      ["in", "Great. Do you deliver to Aqaba? How much?", 190],
    ],
  },
  {
    platform: "instagram", name: "ليان الحسن", unread: 2, paused: true,
    messages: [
      ["in", "مرحبا، شفت الفستان الأسود عندكم بالستوري 😍", 21 * 60 + 20],
      ["seller", "أهلاً ليان! متوفر بمقاسات S و M و L و XL، وسعره 45 د.ا.", 21 * 60 + 10],
      ["in", { image: "D-001" }, 21 * 60 + 6],
      ["in", "هاد نفسه؟ بدي M بس بالكحلي إذا في", 21 * 60 + 5],
    ],
  },
  {
    platform: "instagram", name: "رنا العلي", unread: 1,
    ai: { state: "answered" },
    messages: [
      ["in", "مرحبا، الشنطة البنفسجي الصغيرة متوفرة؟", 70],
      ["ai", "أهلاً رنا! شنطة الكروس البنفسجي متوفرة، سعرها 22 د.ا، وفي منها أسود كمان.", 69],
      ["in", "حلو، التوصيل للزرقاء قديش؟", 48],
    ],
  },
  {
    platform: "instagram", name: "Dana K.", unread: 1,
    messages: [["in", { image: "D-005" }, 35]],
  },
  {
    platform: "messenger", name: "محمد العمري", unread: 1,
    ai: { state: "answered" },
    messages: [
      ["in", "السلام عليكم، عطر العود قديش حقه؟", 30],
      ["ai", "وعليكم السلام! عطر عود ملكي 100 مل سعره 40 د.ا، وعليه اليوم خصم 10% فيصير 36 د.ا.", 29],
      ["in", "تمام، بستنى ردك عشان أطلب", 12],
    ],
  },
  {
    platform: "instagram", name: "سلمى", outcome: ["ordered", null, ["فستان سهرة أسود"], "عمّان", ["price", "size", "delivery"]],
    ai: { state: "answered" },
    messages: [
      ["in", "قديش الفستان الأسود؟ وفي L؟", 26 * 60],
      ["ai", "أهلاً سلمى! فستان السهرة الأسود سعره 45 د.ا، ومقاس L متوفر.", 26 * 60 - 1],
      ["in", "بدي واحد، التوصيل لعمّان خلدا", 25 * 60 + 40],
      ["seller", "تم يا سلمى، بيوصلك بكرة. المجموع 47 د.ا مع التوصيل.", 25 * 60 + 20],
      ["in", "شكراً كتير 🌸", 25 * 60 + 15],
      ["seller", "العفو يا سلمى، إن شاء الله يعجبك 🌸", 25 * 60 + 10],
    ],
  },
  {
    platform: "messenger", name: "Yazan", outcome: ["not_bought", "price", ["عطر عود ملكي"], null, ["price", "offer"]],
    messages: [
      ["in", "kam se3r el 3ood?", 50 * 60],
      ["seller", "أهلاً يزن! عطر العود 40 د.ا، وعليه خصم 10% هالأسبوع.", 49 * 60],
      ["in", "ok thanks, a bit much for me", 48 * 60 + 50],
      ["seller", "ولا يهمك يزن، وإذا حبيت عندنا عطر الورد بـ 22.5 د.ا بعد الخصم.", 48 * 60 + 40],
    ],
  },
  {
    platform: "instagram", name: "هبة", outcome: ["just_asking", null, [], null, ["location_hours"]],
    ai: { state: "answered" },
    messages: [
      ["in", "وين محلكم بالزبط؟ وبتفتحوا الجمعة؟", 70 * 60],
      ["ai", "أهلاً هبة! المحل في الصويفية، شارع الوكالات، جنب مخبز الشعلان. نفتح يومياً من 10 الصبح لـ 10 بالليل، والجمعة من 2 الظهر.", 70 * 60 - 1],
      ["in", "تمام شكراً", 69 * 60 + 50],
      ["seller", "أهلاً وسهلاً يا هبة، بنستناكِ!", 69 * 60 + 45],
    ],
  },
  {
    platform: "instagram", name: "نور", outcome: ["not_bought", "out_of_stock", ["ساعة نسائية ذهبية"], null, ["availability"]],
    messages: [
      ["in", "الساعة الذهبية لسا موجودة؟", 76 * 60],
      ["seller", "للأسف خلصت يا نور، بترجع بعد أسبوعين إن شاء الله.", 75 * 60],
    ],
  },
  {
    platform: "messenger", name: "أحمد", outcome: ["ordered", null, ["عطر ورد دمشقي", "شال حرير"], "إربد", ["price", "delivery", "offer"]],
    ai: { state: "answered" },
    messages: [
      ["in", "بدي هدية لأختي، عطر الورد والشال قديش؟", 98 * 60],
      ["ai", "أهلاً أحمد! عطر الورد الدمشقي 25 د.ا وعليه خصم 10%، والشال الحرير 12 د.ا. التوصيل لإربد 3.5 د.ا.", 98 * 60 - 1],
      ["in", "تمام بدي الثنتين، الدفع عند الاستلام؟", 97 * 60 + 30],
      ["seller", "أكيد، الدفع عند الاستلام. بيوصلك خلال يومين.", 97 * 60],
    ],
  },
];

const now = Date.now();
const at = (minutesAgo) => new Date(now - minutesAgo * 60000).toISOString();

for (const [index, c] of conversations.entries()) {
  const lines = c.messages.map(([who, body, minutesAgo]) => ({
    inbound: who === "in",
    origin: who === "ai" ? "ai" : "seller",
    text: typeof body === "string" ? body : null,
    attachments: typeof body === "string" ? [] : [{ type: "image", payload: { url: photoUrl(body.image) } }],
    sentAt: at(minutesAgo),
  }));
  const last = lines[lines.length - 1];
  const lastInbound = [...lines].reverse().find((l) => l.inbound);
  const [outcome, reason, outcomeProducts, area, topics] = c.outcome ?? [null, null, [], null, []];

  const fields = {
    customer_name: c.name,
    last_message_at: last.sentAt,
    last_message_preview: last.text,
    last_message_type: last.text ? "text" : "image",
    last_inbound_at: lastInbound.sentAt,
    window_expires_at: new Date(Date.parse(lastInbound.sentAt) + 24 * 3600000).toISOString(),
    unread_count: c.unread ?? 0,
    customer_profile_fetched_at: new Date(now).toISOString(),
    ai_state: c.ai?.state ?? null,
    ai_escalation_reason: c.ai?.reason ?? null,
    ai_paused: c.paused ?? false,
    ai_outcome: outcome,
    ai_outcome_reason: reason,
    outcome_products: outcomeProducts,
    outcome_area: area,
    outcome_topics: topics,
    // Already read up to its last message, so the assistant never reads it.
    ai_outcome_read_up_to: last.sentAt,
  };

  const [row] = await rest("conversations", {
    method: "POST",
    body: JSON.stringify({
      account_id: accounts[c.platform],
      workspace_id: WS,
      customer_external_id: `demo-customer-${index + 1}`,
      ...fields,
    }),
  });

  await rest("messages", {
    method: "POST",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify(lines.map((l) => ({
      conversation_id: row.id,
      workspace_id: WS,
      mid: `demo-${randomUUID()}`,
      direction: l.inbound ? "inbound" : "outbound",
      origin: l.origin,
      text: l.text,
      attachments: l.attachments,
      sent_at: l.sentAt,
    }))),
  });

  // Set again after the messages: the triggers that keep a conversation in
  // step with its messages move the times, count unread messages and clear
  // the assistant's state when the seller replies. Here the story decides.
  await rest(`conversations?id=eq.${row.id}`, {
    method: "PATCH",
    headers: { Prefer: "return=minimal" },
    body: JSON.stringify(fields),
  });
}

console.log(
  `Demo shop ready in workspace ${WS}: ${catalog.length} products, 3 offers, ` +
    `${conversations.length} conversations. Sign in as ${EMAIL}.`,
);
