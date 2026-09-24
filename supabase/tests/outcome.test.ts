// Reading how a conversation ended. The model's judgement is measured by
// scripts/outcomes-eval.ts against the real API; these cover what we do with
// its answer, which is where a wrong label would otherwise slip through.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { buildOutcomeRequest, readOutcome, transcript } from "../functions/meta-webhook/outcome.ts";

const CATALOG = ["فستان أحمر", "عطر ورد"];

const answer = (fields: Record<string, unknown>) => ({
  content: [{
    type: "text",
    text: JSON.stringify({
      outcome: "ordered",
      reason: null,
      products: [],
      area: null,
      topics: [],
      evidence: "",
      ...fields,
    }),
  }],
});

test("a product the shop never listed is dropped, not trusted", () => {
  const r = readOutcome(answer({ products: ["فستان أحمر", "حذاء رياضي", "فستان أحمر"] }), CATALOG);
  assert.deepEqual(r?.products, ["فستان أحمر"]);
});

test("a reason is kept only for a customer who did not buy", () => {
  assert.equal(readOutcome(answer({ outcome: "ordered", reason: "price" }), CATALOG)?.reason, null);
  assert.equal(readOutcome(answer({ outcome: "not_bought", reason: "price" }), CATALOG)?.reason, "price");
});

test("a lost customer with no usable reason reads as unknown, never as nothing", () => {
  assert.equal(readOutcome(answer({ outcome: "not_bought", reason: null }), CATALOG)?.reason, "unknown");
  assert.equal(readOutcome(answer({ outcome: "not_bought", reason: "vibes" }), CATALOG)?.reason, "unknown");
});

test("an outcome outside the four is no answer at all", () => {
  assert.equal(readOutcome(answer({ outcome: "maybe" }), CATALOG), null);
  assert.equal(readOutcome({ content: [{ type: "text", text: "not json" }] }, CATALOG), null);
  assert.equal(readOutcome(null, CATALOG), null);
});

test("topics outside the list are dropped, and repeats collapse", () => {
  const r = readOutcome(answer({ topics: ["price", "price", "weather"] }), CATALOG);
  assert.deepEqual(r?.topics, ["price"]);
});

test("an empty area is no area", () => {
  assert.equal(readOutcome(answer({ area: "  " }), CATALOG)?.area, null);
  assert.equal(readOutcome(answer({ area: " إربد " }), CATALOG)?.area, "إربد");
});

test("the transcript says who spoke and skips empty lines", () => {
  assert.equal(
    transcript([
      { fromCustomer: true, text: "بكم؟" },
      { fromCustomer: false, text: "  " },
      { fromCustomer: false, text: "25 دينار" },
    ]),
    "Customer: بكم؟\nShop: 25 دينار",
  );
});

test("the request asks for the schema and turns thinking off explicitly", () => {
  // Omitting thinking runs adaptive on Sonnet 5 and bills for it silently.
  const request = buildOutcomeRequest([{ fromCustomer: true, text: "hi" }], CATALOG);
  assert.deepEqual(request.thinking, { type: "disabled" });
  const format = (request.output_config as { format: { type: string } }).format;
  assert.equal(format.type, "json_schema");
});
