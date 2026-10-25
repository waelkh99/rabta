// Plans: every workspace has one, a seller can read it and cannot change it,
// and only an admin can move a seller between them.

import { strict as assert } from "node:assert";
import { after, before, describe, test } from "node:test";

import { createSeller, freshDb, type TestDb } from "./helpers/db.ts";

describe("plans", () => {
  let db: TestDb;
  let seller: { userId: string; workspaceId: string };
  let admin: { userId: string; workspaceId: string };

  const planOf = async (workspaceId: string) =>
    (await db.sql("select plan from workspaces where id = $1", [workspaceId]))[0].plan;

  before(async () => {
    db = await freshDb();
    seller = await createSeller(db, "seller@example.test");
    admin = await createSeller(db, "owner@example.test");
    await db.sql(`update auth.users set raw_app_meta_data = '{"rabta_admin": true}' where id = $1`, [admin.userId]);
  });

  after(async () => {
    await db.close();
  });

  test("a new workspace starts on Basic", async () => {
    assert.equal(await planOf(seller.workspaceId), "basic");
  });

  test("a seller can read their plan and what each plan includes", async () => {
    await db.asUser(seller.userId, async () => {
      const [mine] = await db.sql("select w.plan, p.replies_per_month from workspaces w join plans p on p.id = w.plan");
      assert.deepEqual(mine, { plan: "basic", replies_per_month: 1000 });

      const all = await db.sql("select id, replies_per_month from plans order by replies_per_month");
      assert.deepEqual(all, [
        { id: "basic", replies_per_month: 1000 },
        { id: "ultimate", replies_per_month: 5000 },
      ]);
    });
  });

  test("a seller cannot move themselves to another plan", async () => {
    // No update policy on workspaces: the row is filtered out, nothing changes.
    await db.asUser(seller.userId, () =>
      db.sql("update workspaces set plan = 'ultimate' where id = $1", [seller.workspaceId]));
    assert.equal(await planOf(seller.workspaceId), "basic");
  });

  test("a seller cannot raise a plan's limit", async () => {
    await assert.rejects(
      db.asUser(seller.userId, () => db.sql("update plans set replies_per_month = 999999")),
      /permission denied/,
    );
    await assert.rejects(
      db.asUser(seller.userId, () => db.sql("insert into plans values ('mine', 999999)")),
      /permission denied/,
    );
  });

  test("a seller cannot use the admin's door either", async () => {
    await assert.rejects(
      db.asUser(seller.userId, () => db.sql("select admin_set_plan($1, 'ultimate')", [seller.workspaceId])),
      /not an admin/,
    );
    assert.equal(await planOf(seller.workspaceId), "basic");
  });

  test("an admin moves a seller between plans, and the overview shows it", async () => {
    await db.asUser(admin.userId, () => db.sql("select admin_set_plan($1, 'ultimate')", [seller.workspaceId]));
    assert.equal(await planOf(seller.workspaceId), "ultimate");

    const [{ o }] = await db.asUser(admin.userId, () => db.sql("select admin_overview() as o"));
    const mine = o.sellers.find((s: { email: string }) => s.email === "seller@example.test");
    assert.equal(mine.plan, "ultimate");
    assert.equal(mine.replies_limit, 5000);
  });

  test("a plan that does not exist is refused", async () => {
    await assert.rejects(
      db.asUser(admin.userId, () => db.sql("select admin_set_plan($1, 'platinum')", [seller.workspaceId])),
      /foreign key/,
    );
  });

  test("reading a guide is priced like any other model call", async () => {
    await db.sql(
      `insert into ai_usage (workspace_id, kind, model, cost_usd) values ($1, 'guide', 'claude-sonnet-5', 0.004)`,
      [seller.workspaceId],
    );
    await assert.rejects(
      db.sql(`insert into ai_usage (workspace_id, kind, model) values ($1, 'other', 'm')`, [seller.workspaceId]),
      /check constraint/,
    );
  });

  test("a guide longer than the limit is refused by the table itself", async () => {
    await db.sql("insert into shop (workspace_id, guide) values ($1, $2)", [seller.workspaceId, "a".repeat(4000)]);
    await assert.rejects(
      db.sql("update shop set guide = $2 where workspace_id = $1", [seller.workspaceId, "a".repeat(4001)]),
      /check constraint/,
    );
  });
});
