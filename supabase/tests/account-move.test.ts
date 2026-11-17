// A Page connected from a second shop takes its conversations with it.
// Migration 20261117000001; the bug it fixes is described there.

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

/** What meta-oauth's connect() does: upsert on platform + external_id. */
async function connectFrom(db: TestDb, workspaceId: string, platform: string, externalId: string) {
  const [row] = await db.sql(
    `insert into connected_accounts (workspace_id, platform, external_id, name)
     values ($1, $2, $3, 'Page')
     on conflict (platform, external_id)
     do update set workspace_id = excluded.workspace_id, name = excluded.name
     returning id`,
    [workspaceId, platform, externalId],
  );
  return row.id as string;
}

/** What a shop's inbox shows: the list query joins the account, as data.dart does. */
async function inbox(db: TestDb, userId: string) {
  return db.asUser(userId, () =>
    db.sql(
      `select c.id, c.customer_external_id,
              (select count(*)::int from messages m where m.conversation_id = c.id) as messages
         from conversations c
         join connected_accounts a on a.id = c.account_id
        order by c.customer_external_id`,
    )
  );
}

describe("a Page that changes shop", () => {
  let db: TestDb;
  before(async () => (db = await freshDb()));
  after(async () => await db.close());

  test("its conversations and messages move with it, and the new shop sees them", async () => {
    const a = await createSeller(db, "old-shop@example.test");
    const b = await createSeller(db, "new-shop@example.test");

    const page = await connectFrom(db, a.workspaceId, "messenger", "page_moving");
    const conversation = await startConversation(db, a.workspaceId, page, "customer_1");
    await addMessage(db, conversation, a.workspaceId, {
      mid: "m_before", direction: "inbound", text: "Hello in September", sentAt: "2026-09-26T10:00:00Z",
    });

    // The same Page, connected from shop B.
    const again = await connectFrom(db, b.workspaceId, "messenger", "page_moving");
    assert.equal(again, page, "the account row is the same one, moved");

    const [moved] = await db.sql("select workspace_id from conversations where id = $1", [conversation]);
    assert.equal(moved.workspace_id, b.workspaceId);
    const [message] = await db.sql("select workspace_id from messages where mid = 'm_before'");
    assert.equal(message.workspace_id, b.workspaceId);

    assert.deepEqual(await inbox(db, b.userId), [
      { id: conversation, customer_external_id: "customer_1", messages: 1 },
    ]);
    assert.deepEqual(await inbox(db, a.userId), [], "the old shop keeps nothing of this Page");
  });

  test("the returning customer's next message reaches the new shop — the 17 November case", async () => {
    const a = await createSeller(db, "case-a@example.test");
    const b = await createSeller(db, "case-b@example.test");

    const page = await connectFrom(db, a.workspaceId, "messenger", "page_case");
    const conversation = await startConversation(db, a.workspaceId, page, "owner_psid");
    await addMessage(db, conversation, a.workspaceId, {
      mid: "m_sept", direction: "inbound", text: "test", sentAt: "2026-09-26T10:00:00Z",
    });

    await connectFrom(db, b.workspaceId, "messenger", "page_case");

    // The webhook files a new message under the existing conversation (unique
    // per account and customer) and the account's current workspace.
    const [existing] = await db.sql(
      "select id, workspace_id from conversations where account_id = $1 and customer_external_id = 'owner_psid'",
      [page],
    );
    assert.equal(existing.id, conversation);
    await addMessage(db, existing.id, existing.workspace_id, {
      mid: "m_hello", direction: "inbound", text: "Hello", sentAt: "2026-11-17T19:32:20Z",
    });

    const seen = await inbox(db, b.userId);
    assert.equal(seen.length, 1);
    assert.equal(seen[0].messages, 2, "the new shop sees the history and the new message");
    assert.deepEqual(await inbox(db, a.userId), []);
  });

  test("the old shop's other accounts and conversations are left exactly where they are", async () => {
    const a = await createSeller(db, "keeps-a@example.test");
    const b = await createSeller(db, "keeps-b@example.test");

    const moving = await connectFrom(db, a.workspaceId, "messenger", "page_leaves");
    const staying = await connectAccount(db, a.workspaceId, "instagram", "ig_stays");
    await startConversation(db, a.workspaceId, moving, "c_moves");
    const kept = await startConversation(db, a.workspaceId, staying, "c_stays");
    await addMessage(db, kept, a.workspaceId, {
      mid: "m_stays", direction: "inbound", text: "still here", sentAt: "2026-11-17T10:00:00Z",
    });

    await connectFrom(db, b.workspaceId, "messenger", "page_leaves");

    assert.deepEqual((await inbox(db, a.userId)).map((c) => c.customer_external_id), ["c_stays"]);
    assert.deepEqual((await inbox(db, b.userId)).map((c) => c.customer_external_id), ["c_moves"]);
    const [message] = await db.sql("select workspace_id from messages where mid = 'm_stays'");
    assert.equal(message.workspace_id, a.workspaceId);
  });

  test("reconnecting from the same shop changes nothing", async () => {
    const a = await createSeller(db, "same-shop@example.test");
    const page = await connectFrom(db, a.workspaceId, "instagram", "ig_same");
    const conversation = await startConversation(db, a.workspaceId, page, "c_same");

    await connectFrom(db, a.workspaceId, "instagram", "ig_same");

    const [row] = await db.sql("select workspace_id from conversations where id = $1", [conversation]);
    assert.equal(row.workspace_id, a.workspaceId);
    assert.equal((await inbox(db, a.userId)).length, 1);
  });

  test("a seller still cannot move an account, so cannot pull another shop's conversations", async () => {
    const a = await createSeller(db, "victim@example.test");
    const thief = await createSeller(db, "thief@example.test");
    const page = await connectFrom(db, a.workspaceId, "messenger", "page_victim");
    await startConversation(db, a.workspaceId, page, "c_private");

    await db.asUser(thief.userId, () =>
      db.sql("update connected_accounts set workspace_id = $1 where id = $2", [thief.workspaceId, page])
        .catch(() => [])
    );

    assert.deepEqual(await inbox(db, thief.userId), []);
    assert.equal((await inbox(db, a.userId)).length, 1);
  });
});
