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
const T0 = new Date("2026-09-14T10:00:00.000Z");
const at = (hours: number) => new Date(T0.getTime() + hours * HOUR).toISOString();

describe("schema", () => {
  let db: TestDb;

  before(async () => {
    db = await freshDb();
  });

  after(async () => {
    await db.close();
  });

  // -------------------------------------------------------------------------

  test("a new seller gets a workspace without being asked to make one", async () => {
    const { userId, workspaceId } = await createSeller(db, "seller@example.test");

    assert.ok(workspaceId);

    const [workspace] = await db.sql("select owner_id, name from workspaces where id = $1", [
      workspaceId,
    ]);
    assert.equal(workspace.owner_id, userId);
    assert.equal(workspace.name, "My workspace");
  });

  test("the same Meta account cannot be connected twice", async () => {
    // Load-bearing: incoming webhooks identify an account only by its Meta id,
    // so a duplicate would make the destination workspace ambiguous.
    const a = await createSeller(db, "dup-a@example.test");
    const b = await createSeller(db, "dup-b@example.test");

    await connectAccount(db, a.workspaceId, "messenger", "page_shared");

    await assert.rejects(
      () => connectAccount(db, b.workspaceId, "messenger", "page_shared"),
      /duplicate key|unique/i,
    );
  });

  test("the same id on two platforms is two different accounts", async () => {
    const seller = await createSeller(db, "two-platforms@example.test");

    await connectAccount(db, seller.workspaceId, "messenger", "same_id");
    await connectAccount(db, seller.workspaceId, "instagram", "same_id");

    const rows = await db.sql(
      "select platform from connected_accounts where external_id = 'same_id'",
    );
    assert.equal(rows.length, 2);
  });

  test("a redelivered message is refused by the database", async () => {
    // Idempotency must not depend on the code remembering to check.
    const seller = await createSeller(db, "dedupe@example.test");
    const account = await connectAccount(db, seller.workspaceId, "messenger", "page_dedupe");
    const conversation = await startConversation(db, seller.workspaceId, account, "cust_1");

    await addMessage(db, conversation, seller.workspaceId, {
      mid: "m_once",
      direction: "inbound",
      text: "hello",
      sentAt: at(0),
    });

    await assert.rejects(
      () =>
        addMessage(db, conversation, seller.workspaceId, {
          mid: "m_once",
          direction: "inbound",
          text: "hello",
          sentAt: at(0),
        }),
      /duplicate key|unique/i,
    );
  });

  test("one customer cannot open two conversations on the same account", async () => {
    const seller = await createSeller(db, "one-conv@example.test");
    const account = await connectAccount(db, seller.workspaceId, "messenger", "page_oneconv");

    await startConversation(db, seller.workspaceId, account, "cust_x");

    await assert.rejects(
      () => startConversation(db, seller.workspaceId, account, "cust_x"),
      /duplicate key|unique/i,
    );
  });
});

// ---------------------------------------------------------------------------

describe("last message type", () => {
  // A photo-only message has no text, so the conversation preview was null and
  // the inbox showed a blank row. The type is recorded so the client can render
  // a localized label without the database holding a user-facing string.
  let db: TestDb;
  let workspaceId: string;
  let conversationId: string;

  before(async () => {
    db = await freshDb();
    const seller = await createSeller(db, "lastType@example.test");
    workspaceId = seller.workspaceId;
    const account = await connectAccount(db, workspaceId, "messenger", "page_type");
    conversationId = await startConversation(db, workspaceId, account, "cust_type");
  });

  after(async () => {
    await db.close();
  });

  const summary = async () => {
    const [row] = await db.sql(
      `select last_message_preview, last_message_type
       from conversations where id = $1`,
      [conversationId],
    );
    return row;
  };

  const image = [{ type: "image", payload: { url: "https://scontent.xx.fbcdn.net/x.png" } }];

  test("a text message is typed as text", async () => {
    await addMessage(db, conversationId, workspaceId, {
      mid: "ty_1",
      direction: "inbound",
      text: "Do you have this in blue?",
      sentAt: at(0),
    });

    const row = await summary();
    assert.equal(row.last_message_type, "text");
    assert.equal(row.last_message_preview, "Do you have this in blue?");
  });

  test("a photo-only message is typed as image, and the preview stays empty", async () => {
    await addMessage(db, conversationId, workspaceId, {
      mid: "ty_2",
      direction: "inbound",
      attachments: image,
      sentAt: at(1),
    });

    const row = await summary();

    // This is the defect. Before the type column existed the row had a null
    // preview and nothing else, so the inbox could only render a blank line.
    assert.equal(row.last_message_preview, null);
    assert.equal(row.last_message_type, "image");
  });

  test("text sent with an attachment previews as text", async () => {
    await addMessage(db, conversationId, workspaceId, {
      mid: "ty_3",
      direction: "inbound",
      text: "Like this one",
      attachments: image,
      sentAt: at(2),
    });

    const row = await summary();
    assert.equal(row.last_message_type, "text");
    assert.equal(row.last_message_preview, "Like this one");
  });

  test("an attachment type Meta has not told us about is stored as other", async () => {
    await addMessage(db, conversationId, workspaceId, {
      mid: "ty_4",
      direction: "inbound",
      attachments: [{ type: "reel_clip_from_the_future", payload: {} }],
      sentAt: at(3),
    });

    const row = await summary();

    // It must not fail the insert and must not come back blank either.
    assert.equal(row.last_message_type, "other");
  });

  test("a late older message does not overwrite the newer type", async () => {
    await addMessage(db, conversationId, workspaceId, {
      mid: "ty_5",
      direction: "inbound",
      text: "sent earlier, delivered later",
      sentAt: at(1),
    });

    const row = await summary();

    // Guarded by the same out-of-order check as the preview.
    assert.equal(row.last_message_type, "other");
  });

  test("an audio message is typed as audio", async () => {
    await addMessage(db, conversationId, workspaceId, {
      mid: "ty_6",
      direction: "inbound",
      attachments: [{ type: "audio", payload: { url: "https://scontent.xx.fbcdn.net/a.mp4" } }],
      sentAt: at(4),
    });

    const row = await summary();
    assert.equal(row.last_message_type, "audio");
  });
});

describe("conversation summary trigger", () => {
  let db: TestDb;
  let workspaceId: string;
  let conversationId: string;

  before(async () => {
    db = await freshDb();
    const seller = await createSeller(db, "trigger@example.test");
    workspaceId = seller.workspaceId;
    const account = await connectAccount(db, workspaceId, "messenger", "page_trigger");
    conversationId = await startConversation(db, workspaceId, account, "cust_trigger");
  });

  after(async () => {
    await db.close();
  });

  const summary = async () => {
    const [row] = await db.sql(
      `select unread_count, last_message_at, last_message_preview,
              last_inbound_at, window_expires_at
       from conversations where id = $1`,
      [conversationId],
    );
    return row;
  };

  test("an inbound message opens a 24 hour reply window", async () => {
    await addMessage(db, conversationId, workspaceId, {
      mid: "t_1",
      direction: "inbound",
      text: "Do you have this in blue?",
      sentAt: at(0),
    });

    const row = await summary();

    assert.equal(row.unread_count, 1);
    assert.equal(row.last_message_preview, "Do you have this in blue?");
    assert.equal(new Date(row.last_message_at).toISOString(), at(0));
    assert.equal(new Date(row.window_expires_at).toISOString(), at(24));
  });

  test("a second inbound message counts as another unread", async () => {
    await addMessage(db, conversationId, workspaceId, {
      mid: "t_2",
      direction: "inbound",
      text: "Still there?",
      sentAt: at(1),
    });

    const row = await summary();

    assert.equal(row.unread_count, 2);
    assert.equal(row.last_message_preview, "Still there?");
    // The window runs from the newest customer message, not the first.
    assert.equal(new Date(row.window_expires_at).toISOString(), at(25));
  });

  test("a reply clears the unread count", async () => {
    await addMessage(db, conversationId, workspaceId, {
      mid: "t_3",
      direction: "outbound",
      text: "Yes, in stock",
      sentAt: at(2),
    });

    const row = await summary();

    assert.equal(row.unread_count, 0);
    assert.equal(row.last_message_preview, "Yes, in stock");
  });

  test("a reply does not extend the reply window", async () => {
    // Only the customer writing to us reopens the window. Believing otherwise
    // would let the interface offer a composer that Meta then refuses.
    const row = await summary();

    assert.equal(new Date(row.window_expires_at).toISOString(), at(25));
    assert.equal(new Date(row.last_inbound_at).toISOString(), at(1));
  });

  test("a late-arriving older message does not overwrite the summary", async () => {
    // Events can arrive out of order. An old message must not roll the
    // conversation preview backwards to something the seller already handled.
    await addMessage(db, conversationId, workspaceId, {
      mid: "t_late",
      direction: "inbound",
      text: "(sent earlier, arrived late)",
      sentAt: at(0.5),
    });

    const row = await summary();

    assert.equal(row.last_message_preview, "Yes, in stock");
    assert.equal(new Date(row.last_message_at).toISOString(), at(2));
    // It is still a message the seller has not read.
    assert.equal(row.unread_count, 1);
    // And it must not shorten a window that a newer message already extended.
    assert.equal(new Date(row.window_expires_at).toISOString(), at(25));
  });
});

// ---------------------------------------------------------------------------

describe("row level security", () => {
  let db: TestDb;
  let alice: { userId: string; workspaceId: string };
  let bob: { userId: string; workspaceId: string };
  let aliceConversation: string;

  before(async () => {
    db = await freshDb();

    alice = await createSeller(db, "alice@example.test");
    bob = await createSeller(db, "bob@example.test");

    const account = await connectAccount(db, alice.workspaceId, "messenger", "alice_page");
    aliceConversation = await startConversation(db, alice.workspaceId, account, "cust_alice");

    await addMessage(db, aliceConversation, alice.workspaceId, {
      mid: "rls_1",
      direction: "inbound",
      text: "private customer enquiry",
      sentAt: at(0),
    });

    await db.sql(
      "insert into account_tokens (account_id, access_token) values ($1, $2)",
      [account, "super-secret-page-token"],
    );

    await db.sql(
      "insert into webhook_events (payload, signature_valid) values ('{}'::jsonb, true)",
    );
  });

  after(async () => {
    await db.close();
  });

  test("a seller sees their own conversations and messages", async () => {
    await db.asUser(alice.userId, async () => {
      const conversations = await db.sql("select id from conversations");
      const messages = await db.sql("select text from messages");

      assert.equal(conversations.length, 1);
      assert.equal(messages.length, 1);
      assert.equal(messages[0].text, "private customer enquiry");
    });
  });

  test("a seller cannot see another seller's conversations or messages", async () => {
    // The central guarantee of a multi-tenant inbox.
    await db.asUser(bob.userId, async () => {
      assert.deepEqual(await db.sql("select id from conversations"), []);
      assert.deepEqual(await db.sql("select id from messages"), []);
      assert.deepEqual(await db.sql("select id from connected_accounts"), []);
    });
  });

  test("a seller sees their own workspace and no one else's", async () => {
    await db.asUser(bob.userId, async () => {
      const rows = await db.sql("select id from workspaces");

      assert.deepEqual(rows.map((r) => r.id), [bob.workspaceId]);
    });
  });

  test("naming another seller's conversation directly still returns nothing", async () => {
    await db.asUser(bob.userId, async () => {
      const rows = await db.sql("select id from conversations where id = $1", [
        aliceConversation,
      ]);
      assert.deepEqual(rows, []);
    });
  });

  test("a seller cannot alter another seller's conversation", async () => {
    await db.asUser(bob.userId, async () => {
      await db.sql("update conversations set unread_count = 0 where id = $1", [
        aliceConversation,
      ]);
    });

    const [row] = await db.sql("select unread_count from conversations where id = $1", [
      aliceConversation,
    ]);
    assert.equal(row.unread_count, 1);
  });

  test("a seller can clear their own unread count", async () => {
    await db.asUser(alice.userId, async () => {
      await db.sql("update conversations set unread_count = 0 where id = $1", [
        aliceConversation,
      ]);
    });

    const [row] = await db.sql("select unread_count from conversations where id = $1", [
      aliceConversation,
    ]);
    assert.equal(row.unread_count, 0);
  });

  test("no signed-in seller can read access tokens", async () => {
    // These are keys to a business inbox. They must never be reachable from a
    // client, including the account's own owner.
    for (const user of [alice, bob]) {
      await db.asUser(user.userId, async () => {
        assert.deepEqual(await db.sql("select access_token from account_tokens"), []);
      });
    }
  });

  test("no signed-in seller can read raw webhook payloads", async () => {
    await db.asUser(alice.userId, async () => {
      assert.deepEqual(await db.sql("select id from webhook_events"), []);
    });
  });

  test("a seller cannot write messages directly", async () => {
    // Outbound messages are only ever inserted after Meta has accepted them.
    await db.asUser(alice.userId, async () => {
      await assert.rejects(
        () =>
          db.sql(
            `insert into messages (conversation_id, workspace_id, mid, direction, text, sent_at)
             values ($1, $2, 'forged', 'outbound', 'fake', now())`,
            [aliceConversation, alice.workspaceId],
          ),
        /row-level security/i,
      );
    });
  });

  test("a seller cannot connect an account to someone else's workspace", async () => {
    await db.asUser(bob.userId, async () => {
      await assert.rejects(
        () =>
          db.sql(
            `insert into connected_accounts (workspace_id, platform, external_id)
             values ($1, 'messenger', 'stolen_page')`,
            [alice.workspaceId],
          ),
        /row-level security/i,
      );
    });
  });
});

// ---------------------------------------------------------------------------
// Phase Two. The catalog is the first thing in this product a client may write
// rather than only read, so these are the first policies that have to hold
// against insert, update and delete and not just select.
// ---------------------------------------------------------------------------

describe("catalog and AI settings", () => {
  let db: TestDb;
  let alice: { userId: string; workspaceId: string };
  let bob: { userId: string; workspaceId: string };
  let aliceProduct: string;

  before(async () => {
    db = await freshDb();

    alice = await createSeller(db, "catalog-alice@example.test");
    bob = await createSeller(db, "catalog-bob@example.test");

    const [product] = await db.sql(
      `insert into products (workspace_id, name, price)
       values ($1, 'فستان أحمر', 25000) returning id`,
      [alice.workspaceId],
    );
    aliceProduct = product.id;
  });

  after(async () => {
    await db.close();
  });

  test("a seller reads their own catalog", async () => {
    await db.asUser(alice.userId, async () => {
      const rows = await db.sql("select name, price, in_stock from products");
      assert.equal(rows.length, 1);
      assert.equal(rows[0].name, "فستان أحمر");
      // Stock defaults to true: a product someone bothered to add is for sale
      // until they say otherwise.
      assert.equal(rows[0].in_stock, true);
    });
  });

  test("a seller cannot read another seller's catalog", async () => {
    // A catalog is commercially sensitive on its own — it is their pricing.
    await db.asUser(bob.userId, async () => {
      const rows = await db.sql("select id from products");
      assert.equal(rows.length, 0);
    });
  });

  test("naming another seller's product directly still returns nothing", async () => {
    await db.asUser(bob.userId, async () => {
      const rows = await db.sql("select id from products where id = $1", [aliceProduct]);
      assert.equal(rows.length, 0);
    });
  });

  test("a seller cannot add a product to someone else's catalog", async () => {
    // Bob writing into Alice's catalog would put his prices in front of her
    // customers, since the AI quotes the catalog verbatim.
    await db.asUser(bob.userId, async () => {
      await assert.rejects(
        () =>
          db.sql("insert into products (workspace_id, name) values ($1, 'planted')", [
            alice.workspaceId,
          ]),
        /row-level security/i,
      );
    });
  });

  test("a seller cannot move their own product into another workspace", async () => {
    // The row an update LEAVES BEHIND is checked, not just the row it started
    // from — so a product cannot be walked across into another catalog.
    const [own] = await db.sql(
      "insert into products (workspace_id, name) values ($1, 'bob thing') returning id",
      [bob.workspaceId],
    );

    await db.asUser(bob.userId, async () => {
      await assert.rejects(
        () =>
          db.sql("update products set workspace_id = $1 where id = $2", [
            alice.workspaceId,
            own.id,
          ]),
        /row-level security/i,
      );
    });
  });

  test("a seller cannot delete another seller's product", async () => {
    await db.asUser(bob.userId, async () => {
      await db.sql("delete from products where id = $1", [aliceProduct]);
    });

    const rows = await db.sql("select id from products where id = $1", [aliceProduct]);
    assert.equal(rows.length, 1, "Alice's product survived Bob's delete");
  });

  test("a seller cannot move their own conversation into another workspace", async () => {
    // conversations_owner_update was briefly suspected of allowing this,
    // because it has `using` and no `with check`. It does not: Postgres uses
    // the `using` expression for both when `with check` is omitted. This test
    // exists to hold that true rather than to record a fix.
    const account = await connectAccount(db, bob.workspaceId, "messenger", "bob_page_wc");
    const conversation = await startConversation(db, bob.workspaceId, account, "cust_bob_wc");

    await db.asUser(bob.userId, async () => {
      await assert.rejects(
        () =>
          db.sql("update conversations set workspace_id = $1 where id = $2", [
            alice.workspaceId,
            conversation,
          ]),
        /row-level security/i,
      );
    });
  });

  test("a workspace has no shop row until someone makes one", async () => {
    // A missing row means the assistant is off. Nothing backfills or
    // auto-creates it, so every workspace that already exists is disabled by
    // default — the way round we want this to fail.
    const rows = await db.sql("select workspace_id from shop where workspace_id = $1", [
      alice.workspaceId,
    ]);
    assert.equal(rows.length, 0);
  });

  test("a shop starts with the assistant off and priced in dinars", async () => {
    await db.asUser(alice.userId, async () => {
      await db.sql("insert into shop (workspace_id) values ($1)", [alice.workspaceId]);

      const [shop] = await db.sql(
        "select assistant_enabled, currency from shop where workspace_id = $1",
        [alice.workspaceId],
      );
      assert.equal(shop.assistant_enabled, false);

      // Stored rather than assumed: an assistant answering "25.500" with no
      // unit, or the wrong one, is the same problem as an invented price. The
      // product mainly serves Jordan, so the dinar is the default.
      assert.equal(shop.currency, "د.ا");
    });
  });

  test("a seller cannot switch on the assistant for another workspace", async () => {
    await db.asUser(bob.userId, async () => {
      await assert.rejects(
        () =>
          db.sql("insert into shop (workspace_id, assistant_enabled) values ($1, true)", [
            alice.workspaceId,
          ]),
        /row-level security/i,
      );
    });
  });

  test("a seller cannot read or change another shop's delivery fees", async () => {
    // Delivery pricing is commercially sensitive in the same way a catalog is.
    await db.sql(
      "insert into delivery_zones (workspace_id, name, fee) values ($1, 'بغداد', 5000)",
      [alice.workspaceId],
    );

    await db.asUser(bob.userId, async () => {
      assert.equal((await db.sql("select id from delivery_zones")).length, 0);

      await assert.rejects(
        () =>
          db.sql(
            "insert into delivery_zones (workspace_id, name, fee) values ($1, 'planted', 1)",
            [alice.workspaceId],
          ),
        /row-level security/i,
      );
    });

    await db.asUser(alice.userId, async () => {
      const zones = await db.sql("select name from delivery_zones");
      assert.equal(zones.length, 1);
      assert.equal(zones[0].name, "بغداد");
    });
  });

  test("a delivery zone may have no fee, which is not the same as free", async () => {
    // "We deliver there, the price depends" is a truthful answer. Requiring a
    // number would make the seller invent one and the assistant repeat it.
    await db.sql("insert into delivery_zones (workspace_id, name) values ($1, 'أربيل')", [
      alice.workspaceId,
    ]);

    const [zone] = await db.sql("select fee from delivery_zones where name = 'أربيل'");
    assert.equal(zone.fee, null);
  });
});

// ---------------------------------------------------------------------------
// The claim. Sending the same sentence to a customer twice cannot be repaired
// afterwards, so overlapping runs are settled in the database rather than by
// hoping two Edge Function invocations never overlap.
// ---------------------------------------------------------------------------

describe("the AI claim", () => {
  let db: TestDb;
  let seller: { userId: string; workspaceId: string };
  let conversation: string;

  // The statement the function runs. Zero rows back means someone else owns
  // this conversation.
  const CLAIM = `update conversations set ai_last_run_at = now()
                  where id = $1
                    and (ai_last_run_at is null
                         or ai_last_run_at < now() - interval '2 minutes')
                returning id`;

  before(async () => {
    db = await freshDb();
    seller = await createSeller(db, "claim@example.test");
    const account = await connectAccount(db, seller.workspaceId, "instagram", "claim_acct");
    conversation = await startConversation(db, seller.workspaceId, account, "cust_claim");
  });

  after(async () => {
    await db.close();
  });

  test("the first run claims the conversation", async () => {
    const claimed = await db.sql(CLAIM, [conversation]);
    assert.equal(claimed.length, 1);
  });

  test("a second run gets nothing while the first still holds it", async () => {
    const claimed = await db.sql(CLAIM, [conversation]);
    assert.equal(claimed.length, 0, "two runs both believed they owned the conversation");
  });

  test("a message that arrived after the last run can be claimed", async () => {
    // The bug this replaces: the claim only asked whether a run had happened
    // recently, so a customer's follow-up inside the window was dropped
    // without a trace. Seen in production — a message 36 seconds after a reply
    // was never answered.
    //
    // The question is whether THIS message has been considered, and a run that
    // started before it arrived cannot have considered it.
    const justRan = new Date();
    await db.sql("update conversations set ai_last_run_at = $1 where id = $2", [
      justRan.toISOString(),
      conversation,
    ]);

    const followUp = new Date(justRan.getTime() + 30_000).toISOString();

    const claimed = await db.sql(
      `update conversations set ai_last_run_at = now()
        where id = $1
          and (ai_last_run_at is null
               or ai_last_run_at < now() - interval '2 minutes'
               or ai_last_run_at < $2)
      returning id`,
      [conversation, followUp],
    );

    assert.equal(claimed.length, 1, "a follow-up must not be swallowed");
  });

  test("two runs for the same message still cannot both claim it", async () => {
    // The other half: allowing follow-ups must not reopen the double-send the
    // claim exists to prevent.
    const arrived = new Date().toISOString();

    const claim = () =>
      db.sql(
        `update conversations set ai_last_run_at = now()
          where id = $1
            and (ai_last_run_at is null
                 or ai_last_run_at < now() - interval '2 minutes'
                 or ai_last_run_at < $2)
        returning id`,
        [conversation, arrived],
      );

    await db.sql("update conversations set ai_last_run_at = null where id = $1", [
      conversation,
    ]);

    assert.equal((await claim()).length, 1, "the first run takes it");
    assert.equal((await claim()).length, 0, "the second finds it taken");
  });

  test("a stale claim can be taken again", async () => {
    // Otherwise an invocation that died mid-run would lock the conversation
    // out of the AI forever, and the seller would never know why.
    await db.sql(
      "update conversations set ai_last_run_at = now() - interval '5 minutes' where id = $1",
      [conversation],
    );

    const claimed = await db.sql(CLAIM, [conversation]);
    assert.equal(claimed.length, 1);
  });

  test("an AI reply behaves exactly like the seller's own in the summary", async () => {
    // The new origin column must change no existing behaviour. The trigger is
    // on the hottest path in the product and is deliberately untouched.
    await addMessage(db, conversation, seller.workspaceId, {
      mid: "claim_in_1",
      direction: "inbound",
      text: "بكم؟",
      sentAt: at(0),
    });

    const [afterInbound] = await db.sql(
      "select unread_count from conversations where id = $1",
      [conversation],
    );
    assert.equal(afterInbound.unread_count, 1);

    await db.sql(
      `insert into messages (conversation_id, workspace_id, mid, direction, text, sent_at, origin)
       values ($1, $2, 'claim_ai_1', 'outbound', '25000 دينار', $3, 'ai')`,
      [conversation, seller.workspaceId, at(1)],
    );

    const [afterReply] = await db.sql(
      `select unread_count, last_message_preview, last_message_at, last_inbound_at
         from conversations where id = $1`,
      [conversation],
    );
    assert.equal(afterReply.unread_count, 0, "an AI reply must clear unread like any other");
    assert.equal(afterReply.last_message_preview, "25000 دينار");
    assert.ok(
      afterReply.last_message_at > afterReply.last_inbound_at,
      "the conversation must leave the waiting group, which these two decide",
    );
  });

  test("a seller's own message is recorded as theirs without being asked", async () => {
    await addMessage(db, conversation, seller.workspaceId, {
      mid: "claim_seller_1",
      direction: "outbound",
      text: "شكرا",
      sentAt: at(2),
    });

    const [row] = await db.sql("select origin from messages where mid = 'claim_seller_1'");
    assert.equal(row.origin, "seller", "existing insert paths must keep producing seller rows");
  });
});
