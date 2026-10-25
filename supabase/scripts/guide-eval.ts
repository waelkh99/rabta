// Reads sample guides with the real model and checks the parts of a reading
// that matter: the situations the seller named are there, the ones that come
// to the seller are marked so, what the assistant cannot do is set aside
// rather than turned into a step, and the labels stay in the seller's language.
//
//   npm run guide-eval
//
// Costs a few cents. Prints each reading, then a pass/fail per check.

import { readFileSync } from "node:fs";
import { askGuide } from "../functions/guide/guide.ts";
import type { GuideSteps } from "../functions/meta-webhook/ai.ts";

// Both files, later wins, as the other scripts read them.
const read = (name: string) => {
  try {
    return readFileSync(new URL(name, import.meta.url), "utf8");
  } catch {
    return "";
  }
};
const value = (key: string) =>
  [read("../.env"), read("../.env.local")]
    .map((text) => new RegExp(`^${key}=(.*)$`, "m").exec(text)?.[1]?.trim().replace(/^["']|["']$/g, ""))
    .filter((v) => v)
    .at(-1) ?? "";
const KEY = value("ANTHROPIC_API_KEY");
const WS = value("ANTHROPIC_WORKSPACE_ID");
if (!KEY) throw new Error("no key in supabase/.env");

const arabic = (text: string) => /[؀-ۿ]/.test(text);
const all = (s: GuideSteps) => s.rules.flatMap((r) => [r.when ?? "", ...r.do]);

const CASES: { name: string; guide: string; checks: [string, (s: GuideSteps) => boolean][] }[] = [
  {
    name: "Jordanian dialect, a clothes shop",
    guide:
      "رحب بالزبون دايماً واسأله شو بدور عليه. إذا سأل عن قطعة اسأله عن مقاسه قبل ما تحكيله إذا متوفرة. " +
      "إذا بدو يطلب خذ اسمه ومنطقته ورقم تلفونه وبعدين حوّلها إلي. أي حدا بشتكي أو زعلان حوّله إلي فوراً. " +
      "وإذا ما رد الزبون ابعتله بعد يوم تذكير.",
    checks: [
      ["labels stay in Arabic", (s) => all(s).filter(Boolean).every(arabic)],
      ["an always rule for the greeting", (s) => s.rules.some((r) => r.when === null)],
      ["ordering hands over", (s) => s.rules.some((r) => r.handover && /يطلب|طلب/.test(r.when ?? ""))],
      ["complaints hand over", (s) => s.rules.some((r) => r.handover && /يشتكي|بشتكي|شكوى|زعلان/.test(r.when ?? ""))],
      ["the follow-up a day later is set aside", (s) => s.cannot.some((c) => /تذكير|يوم/.test(c.text))],
      ["the follow-up is not a step", (s) => !all(s).some((t) => /تذكير/.test(t))],
    ],
  },
  {
    name: "English, a perfume shop, with things it cannot do",
    guide:
      "Never offer discounts yourself. If someone asks for a discount, tell them our prices are fixed. " +
      "If they ask whether a perfume is original, say all our perfumes are original with a receipt. " +
      "When a customer pays by bank transfer, check the payment came in. Call customers who order more than 3 bottles.",
    checks: [
      ["labels stay in English", (s) => all(s).filter(Boolean).every((t) => !arabic(t))],
      ["a discount rule", (s) => s.rules.some((r) => /discount/i.test(`${r.when} ${r.do.join(" ")}`))],
      ["checking payments is set aside", (s) => s.cannot.some((c) => /pay|transfer/i.test(c.text))],
      ["calling is set aside", (s) => s.cannot.some((c) => /call/i.test(c.text))],
      ["neither is a step", (s) => !all(s).some((t) => /check the payment|call/i.test(t))],
    ],
  },
  {
    name: "Not guidance at all",
    guide: "محل ورد للهدايا بعمان، فاتحين من ٢٠١٩",
    checks: [["no rules invented", (s) => s.rules.length === 0]],
  },
];

let failed = 0;
for (const c of CASES) {
  const reading = await askGuide(KEY, c.guide, { workspaceId: WS });
  console.log(`\n=== ${c.name}`);
  if (reading.status === "failed") {
    console.log(`  FAILED ${reading.detail}`);
    failed++;
    continue;
  }
  console.log(JSON.stringify(reading.steps, null, 2));
  for (const [label, check] of c.checks) {
    const ok = check(reading.steps);
    if (!ok) failed++;
    console.log(`  ${ok ? "pass" : "FAIL"}  ${label}`);
  }
  console.log(`  tokens in ${reading.usage.inputTokens}, out ${reading.usage.outputTokens}`);
}
console.log(failed ? `\n${failed} failed` : "\nall passed");
