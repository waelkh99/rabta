// Boots a real Postgres in-process (PGlite) and applies the migration, so the
// schema, triggers and security policies are tested rather than assumed.
//
// Supabase provides a few things the migration depends on which a bare
// Postgres does not have. They are recreated here to match Supabase's own
// definitions — in particular the grants, without which a policy test could
// pass merely because permission was denied, which would prove nothing.

import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

import { PGlite } from "@electric-sql/pglite";

const MIGRATION = fileURLToPath(
  new URL("../../migrations/20260914000001_init.sql", import.meta.url),
);

const SUPABASE_SHIM = `
  create schema if not exists auth;

  create table auth.users (
    id    uuid primary key default gen_random_uuid(),
    email text unique
  );

  -- Matches Supabase's definition: the signed-in user id comes from the JWT
  -- claims, which tests set with "set local request.jwt.claims".
  create function auth.uid() returns uuid
  language sql stable
  as $$
    select nullif(current_setting('request.jwt.claims', true)::json->>'sub', '')::uuid
  $$;

  create role anon;
  create role authenticated;
  create role service_role bypassrls;

  create publication supabase_realtime;
`;

// Supabase grants table access to these roles by default and relies on row
// level security to restrict it. Mirroring that is what makes the policy tests
// meaningful.
const SUPABASE_GRANTS = `
  grant usage on schema public to anon, authenticated, service_role;
  grant all on all tables in schema public to anon, authenticated, service_role;
  grant all on all sequences in schema public to anon, authenticated, service_role;
`;

export interface TestDb {
  sql(query: string, params?: unknown[]): Promise<any[]>;
  /** Runs `fn` as a signed-in seller, with row level security applied. */
  asUser<T>(userId: string, fn: () => Promise<T>): Promise<T>;
  close(): Promise<void>;
}

export async function freshDb(): Promise<TestDb> {
  const db = new PGlite();
  await db.waitReady;

  await db.exec(SUPABASE_SHIM);
  await db.exec(await readFile(MIGRATION, "utf8"));
  await db.exec(SUPABASE_GRANTS);

  return {
    async sql(query, params = []) {
      const result = await db.query(query, params);
      return result.rows as any[];
    },

    async asUser(userId, fn) {
      // PGlite connects as superuser, which bypasses row level security.
      // Switching role is what puts the policies in front of the query.
      await db.exec(`
        set role authenticated;
        set request.jwt.claims = '{"sub":"${userId}"}';
      `);

      try {
        return await fn();
      } finally {
        await db.exec("reset role; reset request.jwt.claims;");
      }
    },

    async close() {
      await db.close();
    },
  };
}

/** Creates a seller. The signup trigger gives them a workspace. */
export async function createSeller(db: TestDb, email: string): Promise<{
  userId: string;
  workspaceId: string;
}> {
  const [user] = await db.sql(
    "insert into auth.users (email) values ($1) returning id",
    [email],
  );

  const [workspace] = await db.sql(
    "select id from workspaces where owner_id = $1",
    [user.id],
  );

  return { userId: user.id, workspaceId: workspace.id };
}

export async function connectAccount(
  db: TestDb,
  workspaceId: string,
  platform: "instagram" | "messenger",
  externalId: string,
): Promise<string> {
  const [account] = await db.sql(
    `insert into connected_accounts (workspace_id, platform, external_id, name)
     values ($1, $2, $3, $4) returning id`,
    [workspaceId, platform, externalId, "Test account"],
  );

  return account.id;
}

export async function startConversation(
  db: TestDb,
  workspaceId: string,
  accountId: string,
  customerExternalId: string,
): Promise<string> {
  const [conversation] = await db.sql(
    `insert into conversations (account_id, workspace_id, customer_external_id)
     values ($1, $2, $3) returning id`,
    [accountId, workspaceId, customerExternalId],
  );

  return conversation.id;
}

export async function addMessage(
  db: TestDb,
  conversationId: string,
  workspaceId: string,
  message: {
    mid: string;
    direction: "inbound" | "outbound";
    text?: string | null;
    sentAt: string;
  },
): Promise<void> {
  await db.sql(
    `insert into messages (conversation_id, workspace_id, mid, direction, text, sent_at)
     values ($1, $2, $3, $4, $5, $6)`,
    [
      conversationId,
      workspaceId,
      message.mid,
      message.direction,
      message.text ?? null,
      message.sentAt,
    ],
  );
}
