// Launch hardening: what a seller may write, what only an admin may read, and
// what the service keeps and for how long.

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

describe("launch hardening", () => {
  let db: TestDb;
  let seller: { userId: string; workspaceId: string };
  let admin: { userId: string; workspaceId: string };
  let conversation: string;

  before(async () => {
    db = await freshDb();
    seller = await createSeller(db, "seller@example.test");
    admin = await createSeller(db, "owner@example.test");
    await db.sql(`update auth.users set raw_app_meta_data = '{"rabta_admin": true}' where id = $1`, [admin.userId]);

    const account = await connectAccount(db, seller.workspaceId, "messenger", "page-ops");
    conversation = await startConversation(db, seller.workspaceId, account, "cust-ops");
    await addMessage(db, conversation, seller.workspaceId, {
      mid: "ops-1", direction: "inbound", text: "مرحبا", sentAt: new Date().toISOString(),
    });
  });

  after(async () => {
    await db.close();
  });

  // -- what a seller may write ----------------------------------------------

  test("a seller can do what the app does: read, pause, correct", async () => {
    await db.asUser(seller.userId, () =>
      db.sql(
        `update conversations set unread_count = 0, ai_paused = true,
           seller_outcome = 'ordered', seller_outcome_at = now() where id = $1`,
        [conversation],
      ));
    const [row] = await db.sql("select unread_count, ai_paused, outcome from conversations where id = $1", [conversation]);
    assert.deepEqual(row, { unread_count: 0, ai_paused: true, outcome: "ordered" });
  });

  test("a seller cannot rewrite the fields the service owns", async () => {
    for (const column of ["account_id = account_id", "customer_external_id = 'x'", "ai_state = null", "ai_outcome = 'ordered'", "window_expires_at = now()"]) {
      await assert.rejects(
        db.asUser(seller.userId, () => db.sql(`update conversations set ${column} where id = $1`, [conversation])),
        /permission denied/,
        `a seller could write ${column}`,
      );
    }
  });

  // -- the admin's view ------------------------------------------------------

  test("only an admin is an admin", async () => {
    assert.equal((await db.asUser(seller.userId, () => db.sql("select is_admin() as a")))[0].a, false);
    assert.equal((await db.asUser(admin.userId, () => db.sql("select is_admin() as a")))[0].a, true);
  });

  test("a truthy flag that is not JSON true does not make an admin", async () => {
    await db.sql(`update auth.users set raw_app_meta_data = '{"rabta_admin": "true"}' where id = $1`, [seller.userId]);
    assert.equal((await db.asUser(seller.userId, () => db.sql("select is_admin() as a")))[0].a, false);
    await db.sql(`update auth.users set raw_app_meta_data = '{}' where id = $1`, [seller.userId]);
  });

  test("a seller asking for the overview is refused", async () => {
    await assert.rejects(
      db.asUser(seller.userId, () => db.sql("select admin_overview()")),
      /not an admin/,
    );
  });

  test("the admin sees every seller, with what they have", async () => {
    await db.sql(
      `insert into ai_usage (workspace_id, kind, model, input_tokens, output_tokens, cost_usd)
       values ($1, 'reply', 'claude-sonnet-5', 1000, 100, 0.003)`,
      [seller.workspaceId],
    );
    await db.sql(
      `insert into ops_log (level, source, event, workspace_id) values ('error', 'meta-webhook', 'event_failed', $1)`,
      [seller.workspaceId],
    );

    const [{ o }] = await db.asUser(admin.userId, () => db.sql("select admin_overview() as o"));
    const mine = o.sellers.find((s: { email: string }) => s.email === "seller@example.test");

    assert.equal(o.sellers.length, 2);
    assert.equal(mine.conversations, 1);
    assert.equal(mine.accounts[0].platform, "messenger");
    assert.equal(Number(mine.ai_cost_month), 0.003);
    assert.equal(o.health.errors_24h, 1);
    assert.equal(o.events[0].email, "seller@example.test");
  });

  test("a seller cannot read the logs or the costs directly", async () => {
    for (const table of ["ops_log", "ai_usage", "client_errors"]) {
      await assert.rejects(
        db.asUser(seller.userId, () => db.sql(`select * from ${table}`)),
        /permission denied/,
        `a seller could read ${table}`,
      );
    }
  });

  // -- errors from the app ---------------------------------------------------

  test("a seller can report their own error, and only as themselves", async () => {
    await db.asUser(seller.userId, () =>
      db.sql("insert into client_errors (message, url) values ('boom', '/')"));
    const [row] = await db.sql("select user_id from client_errors where message = 'boom'");
    assert.equal(row.user_id, seller.userId);

    await assert.rejects(
      db.asUser(seller.userId, () =>
        db.sql("insert into client_errors (user_id, message) values ($1, 'framed')", [admin.userId])),
      /row-level security/,
    );
  });

  test("an error report cannot be the size of a novel", async () => {
    await assert.rejects(
      db.asUser(seller.userId, () =>
        db.sql("insert into client_errors (message) values ($1)", ["x".repeat(3000)])),
    );
  });

  // -- keeping what is needed ------------------------------------------------

  test("pruning removes old processed events and keeps the retry buffer", async () => {
    const old = new Date(Date.now() - 40 * 86_400_000).toISOString();
    await db.sql(
      `insert into webhook_events (received_at, payload, signature_valid, processed_at)
       values ($1, '{}', true, $1), ($1, '{}', true, null), (now(), '{}', true, now())`,
      [old],
    );

    const [{ r }] = await db.sql("select prune_old_records() as r");
    const left = await db.sql("select processed_at is null as pending, received_at < now() - interval '30 days' as old from webhook_events");

    assert.equal(r.webhook_events, 1);
    assert.ok(left.some((e) => e.pending && e.old), "deleted an event still waiting to be retried");
    assert.ok(left.some((e) => !e.old), "deleted a recent event");
  });

  test("a seller cannot prune anything", async () => {
    await assert.rejects(
      db.asUser(seller.userId, () => db.sql("select prune_old_records()")),
      /permission denied/,
    );
  });
});
