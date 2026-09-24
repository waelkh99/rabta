// How well the assistant reads how a conversation ended.
//
// Scripted Jordanian conversations with the answer written down beside each,
// run against the real model. Costs money, so not part of `npm test`.
//
//   node scripts/outcomes-eval.ts          # every case, twice
//   node scripts/outcomes-eval.ts 1        # every case, once
import { readFileSync } from "node:fs";
import { MODEL } from "../functions/meta-webhook/ai.ts";
import { askOutcome, type Line, type LostReason, type Outcome } from "../functions/meta-webhook/outcome.ts";

const env = readFileSync(new URL("../.env", import.meta.url), "utf8");
const KEY = /^ANTHROPIC_API_KEY=(.*)$/m.exec(env)?.[1]?.trim() ?? "";
const WS = /^ANTHROPIC_WORKSPACE_ID=(.*)$/m.exec(env)?.[1]?.trim() ?? "";
if (!KEY) throw new Error("no key in supabase/.env");

/** The demo shop's catalog, as seeded. */
const CATALOG = [
  "فستان سهرة أسود", "فستان صيفي أزرق", "عباية كحلية", "شنطة جلد بنية", "شنطة سهرة سوداء",
  "عطر ورد", "عطر عود", "سلسال ذهبي", "نظارة شمسية", "حزام جلد", "فستان أحمر",
];

interface Case {
  name: string;
  outcome: Outcome;
  reason?: LostReason;
  products?: string[];
  area?: string;
  lines: [string, string][]; // ["c" | "s", text]
}

const CASES: Case[] = [
  {
    name: "address sent", outcome: "ordered", products: ["فستان سهرة أسود"], area: "إربد",
    lines: [["c", "قديش الفستان الاسود السهرة؟"], ["s", "36 دينار بدل 45، عليه خصم 20%"], ["c", "حلو، بدي ياه مقاس M"], ["s", "تمام، وين بدك التوصيل؟"], ["c", "إربد، شارع الجامعة، 0791234567"]],
  },
  {
    name: "shop confirms order", outcome: "ordered", products: ["عطر عود"],
    lines: [["c", "بدي عطر العود"], ["s", "55.75 دينار، متوفر"], ["c", "ماشي ابعتلي ياه"], ["s", "تم تسجيل طلبك، بيوصلك بكرا إن شاء الله"]],
  },
  {
    name: "haggle then order", outcome: "ordered", products: ["شنطة جلد بنية"], area: "عمّان",
    lines: [["c", "الشنطة البنية بكم؟"], ["s", "18 دينار"], ["c", "غالية شوي، بتنزلي؟"], ["s", "السعر ثابت للأسف"], ["c", "طيب ماشي، عبدون عمان، 0788888888"]],
  },
  {
    name: "arabizi order", outcome: "ordered", products: ["نظارة شمسية"], area: "الزرقاء",
    lines: [["c", "2adesh el nadara?"], ["s", "النظارة بـ 15 دينار"], ["c", "tamam bdi yaha, zarqa, 0777000111"]],
  },
  {
    name: "english order", outcome: "ordered", products: ["عطر ورد"],
    lines: [["c", "How much is the rose perfume?"], ["s", "It's 30 dinars."], ["c", "Great, I'll take it. Send it to Sweifieh please, my number is 0790000000"]],
  },
  {
    name: "too expensive", outcome: "not_bought", reason: "price", products: ["عباية كحلية"],
    lines: [["c", "العباية الكحلية بكم؟"], ["s", "30.4 بدل 38"], ["c", "كتير غالية، شكراً"]],
  },
  {
    name: "delivery fee", outcome: "not_bought", reason: "delivery_fee", products: ["سلسال ذهبي"], area: "العقبة",
    lines: [["c", "السلسال بكم مع التوصيل للعقبة؟"], ["s", "السلسال 12 والتوصيل للعقبة 5 دنانير"], ["c", "التوصيل أغلى من نص السلسال، خلص ما بدي"]],
  },
  {
    name: "size missing", outcome: "not_bought", reason: "size_or_variant", products: ["فستان صيفي أزرق"],
    lines: [["c", "الفستان الصيفي في منه XL؟"], ["s", "للأسف المقاسات S M L بس"], ["c", "آه خسارة، أوكي"]],
  },
  {
    name: "out of stock", outcome: "not_bought", reason: "out_of_stock", products: ["حزام جلد"],
    lines: [["c", "بدي الحزام الجلد"], ["s", "للأسف خلص حالياً"], ["c", "طيب اوكي"]],
  },
  {
    name: "not sold", outcome: "not_bought", reason: "not_sold",
    lines: [["c", "عندكم أحذية رياضية؟"], ["s", "لا للأسف ما منبيع أحذية"], ["c", "تمام شكراً"]],
  },
  {
    name: "shop never answered", outcome: "not_bought", reason: "no_answer", products: ["شنطة سهرة سوداء"],
    lines: [["c", "مرحبا، الشنطة السهرة السودا متوفرة؟"], ["c", "؟؟"], ["c", "في حدا؟"]],
  },
  {
    name: "silent after price", outcome: "not_bought", reason: "unknown", products: ["فستان أحمر"],
    lines: [["c", "قديش الفستان الأحمر"], ["s", "25.5 دينار، متوفر S M L"]],
  },
  {
    name: "delivery too slow", outcome: "not_bought", reason: "delivery_time", products: ["عطر ورد"],
    lines: [["c", "بدي عطر الورد بكرا ضروري هدية"], ["s", "التوصيل بياخد 3 أيام"], ["c", "لا ما بلحق، بشوف من محل تاني"]],
  },
  {
    name: "thanks, no order", outcome: "not_bought", reason: "unknown", products: ["سلسال ذهبي"],
    lines: [["c", "السلسال الذهبي بيسوّد؟"], ["s", "لا، ستانلس مطلي ما بيسوّد"], ["c", "حلو كتير يسلموا 🌸"]],
  },
  {
    name: "location only", outcome: "just_asking",
    lines: [["c", "وين محلكم؟"], ["s", "بعمان، الصويفية، جنب مكة مول"], ["c", "تمام شكراً"]],
  },
  {
    name: "greeting", outcome: "just_asking",
    lines: [["c", "مرحبا"], ["s", "أهلين! كيف بقدر أساعدك؟"]],
  },
  {
    name: "complaint about earlier order", outcome: "just_asking",
    lines: [["c", "طلبت من أسبوع لسا ما وصل الطلب"], ["s", "بعتذر، رح أتابع مع شركة التوصيل وأرجعلك"]],
  },
  {
    name: "hours", outcome: "just_asking",
    lines: [["c", "Are you open on Friday?"], ["s", "Yes, from 4 pm to 10 pm."], ["c", "Thanks!"]],
  },
  {
    name: "will think", outcome: "undecided", products: ["عباية كحلية"],
    lines: [["c", "العباية بكم؟"], ["s", "30.4 دينار عليها عرض"], ["c", "بفكر وبرجعلك"]],
  },
  {
    name: "ask husband", outcome: "undecided", products: ["فستان سهرة أسود"],
    lines: [["c", "الفستان الأسود حلو، بس بدي أسأل جوزي أول"], ["s", "أكيد خدي راحتك"]],
  },
  {
    name: "two items, bought one", outcome: "ordered", products: ["عطر ورد", "عطر عود"], area: "السلط",
    lines: [["c", "عطر العود وعطر الورد بكم؟"], ["s", "العود 55.75 والورد 30"], ["c", "العود غالي، بس بدي الورد، السلط 0795555555"]],
  },
  {
    name: "photo then order", outcome: "ordered", products: ["شنطة سهرة سوداء"],
    lines: [["c", "بدي أشوف صورة الشنطة السودا"], ["s", "أكيد"], ["s", "[photo: شنطة سهرة سوداء]"], ["c", "بجنن! احجزيلي وحدة وبمرق آخدها من المحل"]],
  },
];

/**
 * Written after the instructions were last changed, and never used to tune
 * them. `node scripts/outcomes-eval.ts 2 heldout` runs only these — the honest
 * number, since the cases above are the ones the wording was fixed against.
 */
const HELDOUT: Case[] = [
  {
    name: "H cash on delivery order", outcome: "ordered", products: ["عباية كحلية"], area: "جبل الحسين",
    lines: [["c", "العباية الكحلية لسا عليها عرض؟"], ["s", "آه لآخر الشهر، 30.4"], ["c", "الدفع عند الاستلام؟"], ["s", "أكيد"], ["c", "خلص سجليها، جبل الحسين، 0786543210"]],
  },
  {
    name: "H asks colour then leaves", outcome: "not_bought", reason: "size_or_variant", products: ["شنطة جلد بنية"],
    lines: [["c", "الشنطة الجلد في منها لون أسود؟"], ["s", "لا بس البني"], ["c", "اوكي"]],
  },
  {
    name: "H discount refused", outcome: "not_bought", reason: "price", products: ["عطر عود"],
    lines: [["c", "عطر العود بـ 40 بتعطيني ياه؟"], ["s", "للأسف سعره 55.75"], ["c", "لا خلص، مشكورة"]],
  },
  {
    name: "H arabizi just location", outcome: "just_asking",
    lines: [["c", "wein makankom?"], ["s", "بالصويفية جنب مكة مول"], ["c", "ok thx"]],
  },
  {
    name: "H will come to shop", outcome: "undecided", products: ["فستان صيفي أزرق"],
    lines: [["c", "الفستان الأزرق بكم؟"], ["s", "20.4 بدل 25.5"], ["c", "بمرق عالمحل بكرا بشوفه وبقرر"]],
  },
  {
    name: "H english too slow", outcome: "not_bought", reason: "delivery_time", products: ["نظارة شمسية"],
    lines: [["c", "Can the sunglasses arrive today?"], ["s", "Delivery takes 2 days."], ["c", "Too late, never mind."]],
  },
  {
    name: "H order for two", outcome: "ordered", products: ["سلسال ذهبي"], area: "مادبا",
    lines: [["c", "بدي 2 من السلسال الذهبي"], ["s", "تمام، 24 دينار"], ["c", "مادبا، 0799999999، باسم رهف"]],
  },
  {
    name: "H thanks after delivery", outcome: "just_asking",
    lines: [["c", "وصلني الطلب، يسلمو إيديكم كتير حلو"], ["s", "الله يسلمك، بالعافية عليكي"]],
  },
  {
    name: "H unanswered price", outcome: "not_bought", reason: "no_answer", products: ["عطر ورد"],
    lines: [["c", "عطر الورد بكم"]],
  },
  {
    name: "H delivery fee to north", outcome: "not_bought", reason: "delivery_fee", area: "المفرق",
    lines: [["c", "بتوصلوا المفرق؟ وكم التوصيل؟"], ["s", "آه، التوصيل 6 دنانير"], ["c", "كتير، بشوف غير مرة"]],
  },
];

const PRICE = { in: 2, out: 10 }; // claude-sonnet-5, $ per million
const runs = Number(process.argv[2]) || 2;

let outcomeRight = 0, reasonRight = 0, reasonTotal = 0, productsRight = 0, areaRight = 0, areaTotal = 0, total = 0, failed = 0;
let cost = 0;
const disagreements: string[] = [];

const SET = process.argv[3] === "heldout" ? HELDOUT : CASES;
for (const c of SET) {
  const lines: Line[] = c.lines.map(([who, text]) => ({ fromCustomer: who === "c", text }));
  const seen: string[] = [];
  for (let i = 0; i < runs; i++) {
    const result = await askOutcome(KEY, lines, CATALOG, { workspaceId: WS });
    total++;
    if (result.status !== "read") {
      failed++;
      console.log(`FAIL ${c.name}: ${result.detail}`);
      continue;
    }
    const r = result.reading;
    const u = result.usage;
    cost += (u.inputTokens * PRICE.in + u.outputTokens * PRICE.out + u.cacheReadTokens * PRICE.in * 0.1 + u.cacheWriteTokens * PRICE.in * 2) / 1e6;

    const okOutcome = r.outcome === c.outcome;
    if (okOutcome) outcomeRight++;
    if (c.reason) {
      reasonTotal++;
      if (r.reason === c.reason) reasonRight++;
    }
    const expected = [...(c.products ?? [])].sort().join("|");
    if ([...r.products].sort().join("|") === expected) productsRight++;
    if (c.area) {
      areaTotal++;
      if (r.area && (r.area.includes(c.area) || c.area.includes(r.area) || (c.area === "عمّان" && /عم/.test(r.area)))) areaRight++;
    }

    const line = `${r.outcome}${r.reason ? `/${r.reason}` : ""} [${r.products.join(", ")}] ${r.area ?? "-"} {${r.topics.join(",")}} «${r.evidence}»`;
    seen.push(line);
    if (!okOutcome || (c.reason && r.reason !== c.reason) || [...r.products].sort().join("|") !== expected) {
      disagreements.push(`${c.name}: expected ${c.outcome}${c.reason ? `/${c.reason}` : ""} [${(c.products ?? []).join(", ")}]\n    got ${line}`);
    }
  }
  console.log(`${c.name.padEnd(30)} ${seen[0] ?? "-"}${seen.length > 1 && seen[1] !== seen[0] ? `\n${"".padEnd(31)}${seen[1]}` : ""}`);
}

const pct = (a: number, b: number) => `${a}/${b} (${Math.round((a / b) * 100)}%)`;
console.log(`\nmodel ${MODEL}, ${SET.length} cases × ${runs}`);
console.log(`outcome   ${pct(outcomeRight, total - failed)}`);
console.log(`reason    ${pct(reasonRight, reasonTotal)}`);
console.log(`products  ${pct(productsRight, total - failed)}`);
console.log(`area      ${pct(areaRight, areaTotal)}`);
console.log(`failed    ${failed}`);
console.log(`cost      $${cost.toFixed(4)} total, $${(cost / (total - failed)).toFixed(5)} per conversation`);
if (disagreements.length) console.log(`\nDisagreements:\n${disagreements.join("\n")}`);
