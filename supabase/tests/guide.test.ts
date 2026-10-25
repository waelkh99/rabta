// The seller's guide: what we keep of the model's reading, and how it reaches
// the assistant. The reading itself is measured against the real API by
// scripts/guide-eval.ts (npm run guide-eval); these cover what we do with its answer.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { buildGuideRequest, readGuide } from "../functions/guide/guide.ts";
import { claimsAreGrounded, renderFacts, renderGuide } from "../functions/meta-webhook/ai.ts";

const answer = (fields: Record<string, unknown>) => ({
  content: [{ type: "text", text: JSON.stringify({ rules: [], cannot: [], ...fields }) }],
});

test("a reading keeps the seller's situations, in order", () => {
  const steps = readGuide(answer({
    rules: [
      { when: null, do: ["رحّب بالزبون"], handover: false },
      { when: "الزبون طلب خصم", do: [], handover: true },
      { when: "الزبون بدو يطلب", do: ["اسأل عن الاسم والمنطقة والرقم"], handover: true },
    ],
  }));
  assert.deepEqual(steps?.rules.map((r) => r.when), [null, "الزبون طلب خصم", "الزبون بدو يطلب"]);
  assert.equal(steps?.rules[1].handover, true);
});

test("a rule that does nothing and hands nothing over is dropped", () => {
  const steps = readGuide(answer({
    rules: [{ when: "x", do: ["  ", ""], handover: false }, { when: "y", do: ["reply"], handover: false }],
  }));
  assert.deepEqual(steps?.rules.map((r) => r.when), ["y"]);
});

test("labels are tidied and capped so a diagram box cannot swallow a page", () => {
  const steps = readGuide(answer({
    rules: [{ when: "  two\n lines ", do: ["a".repeat(500)], handover: false }],
  }));
  assert.equal(steps?.rules[0].when, "two lines");
  assert.equal(steps?.rules[0].do[0].length, 160);
  assert.ok(steps?.rules[0].do[0].endsWith("…"));
});

test("too many rules are cut rather than drawn", () => {
  const rules = Array.from({ length: 30 }, (_, i) => ({ when: `case ${i}`, do: ["x"], handover: false }));
  assert.equal(readGuide(answer({ rules }))?.rules.length, 12);
});

test("what the assistant cannot do is kept for the diagram", () => {
  const steps = readGuide(answer({ cannot: [{ text: "اتصل فيهم", why: "المساعد ما بقدر يتصل" }, { text: "" }] }));
  assert.deepEqual(steps?.cannot, [{ text: "اتصل فيهم", why: "المساعد ما بقدر يتصل" }]);
});

test("an answer that is not the schema is no reading at all", () => {
  assert.equal(readGuide({ content: [{ type: "text", text: "not json" }] }), null);
  assert.equal(readGuide({ content: [{ type: "text", text: '{"rules": "x"}' }] }), null);
  assert.equal(readGuide({}), null);
});

test("the request asks for the schema and no thinking", () => {
  const request = buildGuideRequest("always greet") as Record<string, any>;
  assert.equal(request.output_config.format.type, "json_schema");
  assert.deepEqual(request.thinking, { type: "disabled" });
  assert.match(request.messages[0].content, /always greet/);
});

// -- how it reaches the assistant ----------------------------------------------

const STEPS = {
  rules: [
    { when: null, do: ["ask which size first"], handover: false },
    { when: "the customer complains", do: [], handover: true },
  ],
  cannot: [{ text: "call them back", why: "it cannot phone" }],
};

test("the assistant gets the seller's words and the steps they checked", () => {
  const text = renderGuide("Ask the size first. Complaints come to me. Call them back.", STEPS)!;
  assert.match(text, /in their own words:\nAsk the size first/);
  assert.match(text, /- Always: ask which size first/);
  assert.match(text, /- When the customer complains: hand the conversation to the seller/);
});

test("what it cannot do is never given to the assistant as a step", () => {
  const text = renderGuide("x", STEPS)!;
  assert.doesNotMatch(text.split("which the seller has checked")[1], /call them back/);
});

test("no guide writes nothing", () => {
  assert.equal(renderGuide(null, STEPS), null);
  assert.equal(renderGuide("   ", null), null);
});

test("the guide is part of the facts, so what the seller wrote there is grounded", () => {
  // The standing rule's step 3: a discount the seller wrote in their guide is
  // something the shop wrote down, and the guard must let it through.
  const reply = "في خصم 10% على أول طلب";
  const without = renderFacts({ shop: null, zones: [], products: [] });
  const shop = {
    currency: "دينار",
    deliveryNote: null,
    locations: null,
    hours: null,
    about: null,
    priceStance: "notify" as const,
    guide: "أي زبون أول مرة بطلب، احكيله في خصم 10% على أول طلب",
    guideSteps: null,
  };
  const withGuide = renderFacts({ shop, zones: [], products: [] });

  assert.notEqual(claimsAreGrounded(reply, without, []), null, "the guard should refuse it with no guide");
  assert.equal(claimsAreGrounded(reply, withGuide, []), null);
});
