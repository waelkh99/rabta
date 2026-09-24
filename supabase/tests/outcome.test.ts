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

// ---------------------------------------------------------------------------
// Reading settled conversations
// ---------------------------------------------------------------------------

import { type Due, type OutcomeStore, readSettled, type Reading, toLine } from "../functions/meta-webhook/outcome.ts";

const READING: Reading = { outcome: "ordered", reason: null, products: [], area: null, topics: [], evidence: "" };

class FakeOutcomes implements OutcomeStore {
  due: Due[] = [];
  saved: { id: string; readUpTo: string }[] = [];
  claimDue() {
    return Promise.resolve(this.due);
  }
  lines() {
    return Promise.resolve([{ fromCustomer: true, text: "بدي ياه" }]);
  }
  catalog() {
    return Promise.resolve(CATALOG);
  }
  save(id: string, _reading: Reading, readUpTo: string) {
    this.saved.push({ id, readUpTo });
    return Promise.resolve();
  }
}

test("a reading is stored against the message it covered, not the time it ran", async () => {
  // Stored as the time read up to, so a message that arrives while the model
  // is reading still makes the conversation due again.
  const store = new FakeOutcomes();
  store.due = [{ id: "c1", workspaceId: "w", readUpTo: "2026-09-20T10:00:00Z" }];

  const result = await readSettled(store, () => Promise.resolve({ status: "read", reading: READING, usage: { inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0 } }));

  assert.deepEqual(result.read, ["c1"]);
  assert.deepEqual(store.saved, [{ id: "c1", readUpTo: "2026-09-20T10:00:00Z" }]);
});

test("a failed reading stores nothing, and the others still get read", async () => {
  const store = new FakeOutcomes();
  store.due = [
    { id: "bad", workspaceId: "w", readUpTo: "t1" },
    { id: "good", workspaceId: "w", readUpTo: "t2" },
  ];
  let calls = 0;

  const result = await readSettled(store, () =>
    Promise.resolve(
      calls++ === 0
        ? { status: "failed", detail: "http 529" }
        : { status: "read", reading: READING, usage: { inputTokens: 0, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0 } },
    ));

  assert.deepEqual(result, { read: ["good"], failed: ["bad"] });
  assert.deepEqual(store.saved.map((s) => s.id), ["good"]);
});

test("a photo is named for the reader, never lost", () => {
  assert.deepEqual(
    toLine({ direction: "outbound", text: null, attachments: [{ type: "image", product: "عطر ورد" }] }),
    { fromCustomer: false, text: "[photo of عطر ورد]" },
  );
  assert.deepEqual(
    toLine({ direction: "inbound", text: null, attachments: [{ type: "image", payload: {} }] }),
    { fromCustomer: true, text: "[image]" },
  );
  assert.equal(toLine({ direction: "inbound", text: "  ", attachments: [] }), null);
});

import { withCustomersArea } from "../functions/meta-webhook/outcome.ts";

test("an area only the shop mentioned is not the customer's", () => {
  const lines = [
    { fromCustomer: true, text: "قديش سعرها؟" },
    { fromCustomer: false, text: "25.5 دينار، والتوصيل لعمّان 2.5" },
  ];
  assert.equal(withCustomersArea({ ...READING, area: "عمّان" }, lines).area, null);
});

test("an area the customer wrote is kept, even in other letters", () => {
  const said = [{ fromCustomer: true, text: "بدي ياه على إربد" }, { fromCustomer: false, text: "التوصيل لإربد 3" }];
  assert.equal(withCustomersArea({ ...READING, area: "إربد" }, said).area, "إربد");
  const latin = [{ fromCustomer: true, text: "tamam, zarqa" }];
  assert.equal(withCustomersArea({ ...READING, area: "الزرقاء" }, latin).area, "الزرقاء");
});
