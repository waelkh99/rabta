// How conversations end, in the database: which conversations are due to be
// read, which label is shown, and the week the seller sees.

import { strict as assert } from "node:assert";
import { after, before, describe, test } from "node:test";

import {
  addMessage,
  connectAccount,
  createSeller,
  freshDb,
  startConversation,
  type TestDb,
} from "./helpers/db.ts";

const HOUR = 3_600_000;
const T0 = new Date("2026-09-20T10:00:00.000Z");
const at = (hours: number) => new Date(T0.getTime() + hours * HOUR).toISOString();

const claim = (db: TestDb, now: string, limit = 10) =>
  db.sql("select * from claim_outcomes_due($1, interval '12 hours', $2)", [now, limit]);

describe("reading how conversations end", () => {
  let db: TestDb;
  let seller: { userId: string; workspaceId: string };
  let account: string;
  let n = 0;

  const conversation = async (messages: [("in" | "out"), number][]) => {
    const id = await startConversation(db, seller.workspaceId, account, `cust-${++n}`);
    for (const [dir, hours] of messages) {
      await addMessage(db, id, seller.workspaceId, {
        mid: `m-${n}-${hours}-${dir}`,
        direction: dir === "in" ? "inbound" : "outbound",
        text: "x",
        sentAt: at(hours),
      });
    }
    return id;
  };

  before(async () => {
    db = await freshDb();
    seller = await createSeller(db, "outcomes@example.test");
    account = await connectAccount(db, seller.workspaceId, "messenger", "page-outcomes");
  });

  after(async () => {
    await db.close();
  });

  test("only a conversation quiet for twelve hours is due", async () => {
    const settled = await conversation([["in", 0], ["out", 1]]);
    const fresh = await conversation([["in", 0], ["out", 20]]);

    const due = (await claim(db, at(14))).map((r) => r.id);

    assert.ok(due.includes(settled));
    assert.ok(!due.includes(fresh), "read a conversation still going");
  });

  test("a claimed conversation is not claimed twice", async () => {
    const id = await conversation([["in", 100], ["out", 101]]);
    const now = at(120);

    const first = (await claim(db, now)).map((r) => r.id);
    const second = (await claim(db, now)).map((r) => r.id);

    assert.ok(first.includes(id));
    assert.ok(!second.includes(id), "two deliveries would both pay to read it");
  });

  test("a claim that died is taken again after ten minutes", async () => {
    const id = await conversation([["in", 200], ["out", 201]]);
    await claim(db, at(220));

    const again = (await claim(db, new Date(Date.parse(at(220)) + 11 * 60_000).toISOString()))
      .map((r) => r.id);
    assert.ok(again.includes(id));
  });

  test("a read conversation is due again only once the customer writes again", async () => {
    const id = await conversation([["in", 300], ["out", 301]]);
    const [row] = (await claim(db, at(320))).filter((r) => r.id === id);

    await db.sql(
      "update conversations set ai_outcome = 'not_bought', ai_outcome_read_up_to = $2, outcome_claimed_at = null where id = $1",
      [id, row.read_up_to],
    );
    assert.ok(!(await claim(db, at(330))).some((r) => r.id === id), "read the same messages twice");

    await addMessage(db, id, seller.workspaceId, { mid: "back", direction: "inbound", text: "بدي ياه", sentAt: at(340) });
    assert.ok((await claim(db, at(360))).some((r) => r.id === id), "missed the customer coming back");
  });

  test("a disconnected account's conversations are not read", async () => {
    const other = await connectAccount(db, seller.workspaceId, "instagram", "ig-off");
    const id = await startConversation(db, seller.workspaceId, other, "cust-off");
    await addMessage(db, id, seller.workspaceId, { mid: "off-1", direction: "inbound", text: "x", sentAt: at(400) });
    await db.sql("update connected_accounts set status = 'disconnected' where id = $1", [other]);

    assert.ok(!(await claim(db, at(420))).some((r) => r.id === id));
  });

  test("a seller cannot call the claim", async () => {
    await assert.rejects(
      db.asUser(seller.userId, () => claim(db, at(500))),
      /permission denied/,
    );
  });
});

describe("which label is shown", () => {
  let db: TestDb;
  let id: string;
  let workspaceId: string;

  before(async () => {
    db = await freshDb();
    const seller = await createSeller(db, "labels@example.test");
    workspaceId = seller.workspaceId;
    const account = await connectAccount(db, workspaceId, "messenger", "page-labels");
    id = await startConversation(db, workspaceId, account, "c1");
    await addMessage(db, id, workspaceId, { mid: "l1", direction: "inbound", text: "x", sentAt: at(0) });
  });

  after(async () => {
    await db.close();
  });

  const shown = async () =>
    (await db.sql("select outcome, outcome_reason, outcome_by from conversations where id = $1", [id]))[0];

  test("nothing, before anyone has said", async () => {
    assert.deepEqual(await shown(), { outcome: null, outcome_reason: null, outcome_by: null });
  });

  test("the assistant's reading", async () => {
    await db.sql(
      "update conversations set ai_outcome = 'not_bought', ai_outcome_reason = 'price', ai_outcome_read_up_to = $2 where id = $1",
      [id, at(0)],
    );
    assert.deepEqual(await shown(), { outcome: "not_bought", outcome_reason: "price", outcome_by: "ai" });
  });

  test("the seller's correction wins over the reading it corrected", async () => {
    await db.sql(
      "update conversations set seller_outcome = 'ordered', seller_outcome_reason = null, seller_outcome_at = $2 where id = $1",
      [id, at(5)],
    );
    assert.deepEqual(await shown(), { outcome: "ordered", outcome_reason: null, outcome_by: "seller" });
  });

  test("and the assistant re-reading the same messages does not undo it", async () => {
    await db.sql("update conversations set ai_outcome = 'not_bought', ai_outcome_read_up_to = $2 where id = $1", [id, at(0)]);
    assert.equal((await shown()).outcome_by, "seller");
  });

  test("a reading of newer messages replaces an older correction", async () => {
    // The customer came back after the seller marked it: the newer reading is
    // about a conversation the seller has not judged yet.
    await db.sql("update conversations set ai_outcome = 'just_asking', ai_outcome_reason = null, ai_outcome_read_up_to = $2 where id = $1", [id, at(10)]);
    assert.deepEqual(await shown(), { outcome: "just_asking", outcome_reason: null, outcome_by: "ai" });
  });

  test("an outcome outside the four is refused", async () => {
    await assert.rejects(db.sql("update conversations set seller_outcome = 'shipped' where id = $1", [id]));
  });
});

describe("the week the seller sees", () => {
  let db: TestDb;
  let mine: { userId: string; workspaceId: string };
  let theirs: { userId: string; workspaceId: string };

  const add = async (
    who: { workspaceId: string },
    account: string,
    customer: string,
    fields: Record<string, unknown>,
    messages: [("in" | "out"), number][],
  ) => {
    const id = await startConversation(db, who.workspaceId, account, customer);
    for (const [dir, hours] of messages) {
      await addMessage(db, id, who.workspaceId, {
        mid: `${customer}-${hours}-${dir}`,
        direction: dir === "in" ? "inbound" : "outbound",
        text: "x",
        sentAt: at(hours),
      });
    }
    const keys = Object.keys(fields);
    if (keys.length) {
      await db.sql(
        `update conversations set ${keys.map((k, i) => `${k} = $${i + 2}`).join(", ")} where id = $1`,
        [id, ...keys.map((k) => fields[k])],
      );
    }
    return id;
  };

  before(async () => {
    db = await freshDb();
    mine = await createSeller(db, "week@example.test");
    theirs = await createSeller(db, "other@example.test");
    const a = await connectAccount(db, mine.workspaceId, "messenger", "page-week");
    const b = await connectAccount(db, theirs.workspaceId, "messenger", "page-other");

    // T0 is 10:00 UTC, 13:00 in Amman.
    await add(mine, a, "w1", { ai_outcome: "ordered", ai_outcome_read_up_to: at(1), outcome_products: ["فستان أحمر"], outcome_area: "إربد" }, [["in", 0], ["out", 1]]);
    await add(mine, a, "w2", { ai_outcome: "not_bought", ai_outcome_reason: "price", ai_outcome_read_up_to: at(3), outcome_products: ["فستان أحمر", "عطر ورد"] }, [["in", 2], ["out", 3]]);
    await add(mine, a, "w3", { ai_outcome: "not_bought", ai_outcome_reason: "delivery_fee", ai_outcome_read_up_to: at(5), outcome_area: "إربد" }, [["in", 4], ["out", 5]]);
    // The seller corrected this one from "just asking" to an order.
    await add(mine, a, "w4", { ai_outcome: "just_asking", ai_outcome_read_up_to: at(7), seller_outcome: "ordered", seller_outcome_at: at(30) }, [["in", 6], ["out", 7]]);
    // Never answered, and its window has closed.
    await add(mine, a, "w5", {}, [["in", 8]]);
    // Corrected only in its reason, which is still the assistant being wrong.
    await add(mine, a, "w6", { ai_outcome: "not_bought", ai_outcome_reason: "price", ai_outcome_read_up_to: at(9), seller_outcome: "not_bought", seller_outcome_reason: "delivery_fee", seller_outcome_at: at(30) }, [["in", 9]]);
    // Before the week.
    await add(mine, a, "old", { ai_outcome: "ordered", ai_outcome_read_up_to: at(-99) }, [["in", -100]]);
    // Another seller's orders must not appear.
    await add(theirs, b, "t1", { ai_outcome: "ordered", ai_outcome_read_up_to: at(1) }, [["in", 0]]);
  });

  after(async () => {
    await db.close();
  });

  const week = (userId: string) =>
    db.asUser(userId, () => db.sql("select outcome_summary($1, $2) as s", [at(-1), at(48)])).then((r) => r[0].s);

  test("counts the week's conversations by how they ended", async () => {
    const s = await week(mine.userId);
    assert.equal(s.conversations, 6);
    assert.equal(s.ordered, 2, "the seller's correction counts as an order");
    assert.equal(s.not_bought, 3);
    assert.equal(s.just_asking, 0);
    assert.equal(s.open, 1);
  });

  test("says why customers did not buy", async () => {
    assert.deepEqual((await week(mine.userId)).reasons, { price: 1, delivery_fee: 2 });
  });

  test("ranks products by how often they were asked about, with orders", async () => {
    assert.deepEqual((await week(mine.userId)).products, [
      { name: "فستان أحمر", asked: 2, ordered: 1 },
      { name: "عطر ورد", asked: 1, ordered: 0 },
    ]);
  });

  test("names where customers are", async () => {
    assert.deepEqual((await week(mine.userId)).areas, [{ name: "إربد", count: 2 }]);
  });

  test("counts customers whose window closed unanswered", async () => {
    assert.equal((await week(mine.userId)).unanswered, 2);
  });

  test("buckets messages by the hour in Amman", async () => {
    const hours = (await week(mine.userId)).hours as number[];
    assert.equal(hours.length, 24);
    assert.equal(hours[13], 1, "10:00 UTC is 13:00 in Amman");
    assert.equal(hours.reduce((a, b) => a + b, 0), 6);
  });

  test("says how often the assistant was corrected", async () => {
    const s = await week(mine.userId);
    assert.equal(s.read_by_assistant, 5);
    assert.equal(s.corrected, 2, "a changed reason is a correction too");
  });

  test("another seller's conversations are not in it", async () => {
    const s = await week(theirs.userId);
    assert.equal(s.conversations, 1);
    assert.equal(s.ordered, 1);
    assert.deepEqual(s.products, []);
  });
});
