// Scripted conversations against the real API.
//
// Not a unit test and not part of `npm test`: it costs money and needs
// ANTHROPIC_API_KEY in supabase/.env. It exists because the one requirement
// nothing else can check is "does this read like a person" — and reading the
// transcripts is the only way to answer it.
//
// It has already earned its keep. Five defects came out of it that every unit
// test passed through: an English customer answered in Arabic, Eastern Arabic
// numerals, the address switching gender mid-sentence, an invented "the price
// is fixed", and a photo-only message answered in the wrong language.
//
// Run it with: npm run live
import { readFileSync } from "node:fs";
import {
  ask,
  attachmentTurn,
  claimsAreGrounded,
  HAIKU,
  MODEL,
  numbersAreGrounded,
  renderFacts,
  tidyEmoji,
  type Turn,
} from "../functions/meta-webhook/ai.ts";

/**
 * Dollars per million tokens, from the model table. Cache reads are 0.1x base
 * input and 1-hour cache writes are 2x, which is what makes the small-shop
 * comparison interesting: Haiku will not cache a prefix under 4,096 tokens and
 * Sonnet will cache one over 1,024.
 */
const PRICE: Record<string, { in: number; out: number }> = {
  [HAIKU]: { in: 1, out: 5 },
  [MODEL]: { in: 2, out: 10 },
};

function dollars(model: string, u: { inputTokens: number; outputTokens: number; cacheReadTokens: number; cacheWriteTokens: number }): number {
  const p = PRICE[model];
  return (
    u.inputTokens * p.in +
    u.outputTokens * p.out +
    u.cacheReadTokens * p.in * 0.1 +
    u.cacheWriteTokens * p.in * 2
  ) / 1_000_000;
}

const VARIANTS: { label: string; model: string; think: boolean }[] = [
  { label: "Haiku 4.5", model: HAIKU, think: false },
  { label: "Sonnet 5", model: MODEL, think: false },
  { label: "Sonnet 5 + thinking", model: MODEL, think: true },
];

const only = process.argv[2];
const variants = only ? VARIANTS.filter((v) => v.label.toLowerCase() === only.toLowerCase()) : VARIANTS;

const env = readFileSync(new URL("../.env", import.meta.url), "utf8");
const KEY = /^ANTHROPIC_API_KEY=(.*)$/m.exec(env)?.[1]?.trim() ?? "";
const WS = /^ANTHROPIC_WORKSPACE_ID=(.*)$/m.exec(env)?.[1]?.trim() ?? "";
if (!KEY) throw new Error("no key in supabase/.env");

const facts = renderFacts({
  shop: {
    currency: "د.ا",
    deliveryNote: "التوصيل مجاني للطلبات فوق 50 دينار. الدفع عند الاستلام متاح.",
    locations: "محلنا في جبل عمّان، الدوار الثالث. بنستقبل الزباين من 11 الصبح.",
    hours: "السبت إلى الخميس 11ص - 9م، الجمعة مسكّرين",
    about: "بنبيع ملابس وإكسسوارات حريمي. الطلب بيتم من هون بالرسائل. الاسترجاع خلال 3 أيام إذا القطعة ما انلبست.",
  },
  zones: [
    { name: "عمّان", fee: "2.500" },
    { name: "الزرقاء", fee: "3.000" },
    { name: "إربد", fee: "3.500" },
    { name: "العقبة", fee: null },
  ],
  products: [
    { name: "فستان سهرة أحمر", price: "45.000", description: "قماش ساتان، مقاسات S M L، بكمّ طويل", inStock: true },
    { name: "فستان صيفي مورّد", price: "22.000", description: "قطن خفيف، مقاسات S M L", inStock: true },
    { name: "بلوزة كتّان بيضا", price: "14.500", description: "كتّان، مقاس واحد بيناسب S لـ L", inStock: true },
    { name: "تنورة جينز", price: "18.000", description: "جينز غامق، مقاسات 36 لـ 42", inStock: false },
    { name: "شنطة يد جلد", price: "32.000", description: "جلد طبيعي بني، فيها جيب داخلي", inStock: true },
    { name: "شنطة قماش صغيرة", price: "9.500", description: "قماش مقوّى، مناسبة للاستخدام اليومي", inStock: true },
    { name: "طقم حلق وسلسلة", price: "11.000", description: "ستانلس ستيل مطلي ذهبي، ما بيغيّر لونه", inStock: true },
    { name: "شال صوف", price: "16.000", description: "صوف ناعم، ألوان بيج ورمادي وكحلي", inStock: true },
  ],
});

const examples = [
  "أهلاً وسهلاً، تفضلي شو بتحبي؟",
  "اكيد متوفر، بتحبي أحجزلك ياه؟",
  "التوصيل لعمّان 2.5 والتوصيل بيوصلك خلال يومين",
  "تكرمي، أي خدمة",
  "القطعة هاي بتنلبس كتير هالفترة",
  "آسفين خلصت هالمقاس، بس في عنا غيرها",
];

const scenarios: { name: string; lines: (string | { attachment: string })[] }[] = [
  { name: "the customer who does not know what they want", lines: ["مرحبا", "بدي هدية لأمي", "شو بتنصحني؟", "تمام وقديش التوصيل لإربد؟"] },
  { name: "asking for something the shop does not sell", lines: ["عندكم جزم رياضية؟"] },
  { name: "the item is out of stock", lines: ["بدي تنورة الجينز مقاس 38"] },
  { name: "a budget lower than what they asked about", lines: ["قديش فستان السهرة الأحمر؟", "غالي شوي، بدي شي تحت 25"] },
  { name: "an English customer", lines: ["hi! do you deliver to Amman? and what do you have for around 15?"] },
  { name: "Arabizi", lines: ["2adesh se3r el shanta el jild?"] },
  { name: "a photo with no words", lines: [{ attachment: "image" }] },
  // Price is read out, never negotiated and never refused. Several turns of it
  // in a row, because a customer who wants a better price asks twice.
  { name: "price talk: listed price, gently, never a flat no", lines: ["قديش الشنطة الجلد؟", "بتنزلي السعر شوي؟", "في خصم؟", "غالي شوي عليّ"] },
  { name: "just browsing, should not be chased", lines: ["شو عندكم جديد؟", "حلو، رح أفكر وبرجعلك"] },
];

const now = new Date("2026-09-20T15:00:00.000Z");

for (const variant of variants) {
  console.log(`\n\n${"#".repeat(72)}\n##  ${variant.label}\n${"#".repeat(72)}`);

  let cost = 0;
  let replies = 0;
  let heldBack = 0;
  let handedOver = 0;
  let fresh = 0;
  let cacheRead = 0;
  let cacheWrite = 0;

  for (const scenario of scenarios) {
    console.log(`\n${"=".repeat(72)}\n${scenario.name}\n${"=".repeat(72)}`);
    const turns: Turn[] = [];

    for (const line of scenario.lines) {
      const text = typeof line === "string" ? line : attachmentTurn([{ type: line.attachment }])!;
      turns.push({ inbound: true, text });
      console.log(`\n  customer > ${text}`);

      const outcome = await ask(
        KEY,
        { facts, now, examples, turns, model: variant.model, think: variant.think },
        fetch,
        WS,
      );

      if (outcome.status !== "decided") {
        console.log(`  !! ${outcome.status}` + ("detail" in outcome ? ` ${outcome.detail}` : ""));
        break;
      }

      replies++;
      cost += dollars(variant.model, outcome.usage);
      fresh += outcome.usage.inputTokens;
      cacheRead += outcome.usage.cacheReadTokens;
      cacheWrite += outcome.usage.cacheWriteTokens;

      // Exactly what the send path does, in the same order.
      const raw = outcome.decision.text;
      const reply = tidyEmoji(raw);
      const said = turns.map((t) => t.text);

      const grounded = numbersAreGrounded(reply, facts, said);
      const claim = claimsAreGrounded(reply, facts, said);
      if (!grounded || claim) heldBack++;
      if (outcome.decision.handOver) handedOver++;

      const flags = [
        outcome.decision.handOver ? `HAND OVER (${outcome.decision.reason})` : null,
        grounded ? null : "!! HELD BACK: ungrounded number",
        claim ? `!! HELD BACK: promise "${claim}"` : null,
        reply !== raw ? `emoji tidied: ${JSON.stringify(raw.slice(-12))}` : null,
        reply.length > 1000 ? "!! HELD BACK: too long" : null,
      ].filter(Boolean);

      console.log(`  shop     > ${reply}`);
      if (flags.length) console.log(`             [${flags.join(" | ")}]`);

      turns.push({ inbound: false, text: reply });
    }
  }

  const each = cost / Math.max(replies, 1);
  console.log(
    `\n--- ${variant.label}: ${replies} replies, $${each.toFixed(5)} each, ` +
      `$${(each * 1900).toFixed(2)} per seller per month at 1,900 replies. ` +
      `${handedOver} handed over, ${heldBack} held back by the grounding check.` +
      `\n    tokens: ${fresh} uncached in, ${cacheRead} cache read, ${cacheWrite} cache write` +
      `${cacheRead === 0 ? "  <- nothing cached: the prefix is under this model's minimum" : ""}`,
  );
}
