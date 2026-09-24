// Boots a real Postgres in-process (PGlite) and applies the migration, so the
// schema, triggers and security policies are tested rather than assumed.
//
// Supabase provides a few things the migration depends on which a bare
// Postgres does not have. They are recreated here to match Supabase's own
// definitions — in particular the grants, without which a policy test could
// pass merely because permission was denied, which would prove nothing.

import { readdir, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";

import { PGlite } from "@electric-sql/pglite";

const MIGRATIONS_DIR = new URL("../../migrations/", import.meta.url);

// Every migration, in filename order — the same order `supabase db push`
// applies them. Reading the directory rather than naming one file means a new
// migration is covered by the suite the moment it is added, instead of
// silently going untested.
async function migrations(): Promise<string[]> {
  const names = (await readdir(fileURLToPath(MIGRATIONS_DIR)))
    .filter((name) => name.endsWith(".sql"))
    .sort();

  return Promise.all(
    names.map((name) => readFile(fileURLToPath(new URL(name, MIGRATIONS_DIR)), "utf8")),
  );
}

const SUPABASE_SHIM = `
  create schema if not exists auth;

  create table auth.users (
    id                 uuid primary key default gen_random_uuid(),
    email              text unique,
    raw_app_meta_data  jsonb not null default '{}'::jsonb,
    last_sign_in_at    timestamptz
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

  -- Storage, reduced to what a migration touches: the bucket row, the objects
  -- table the policies sit on, and foldername as Supabase defines it — every
  -- path segment but the last. Row level security is on, as it is there, so a
  -- policy test proves the policy rather than an open table.
  create schema storage;

  create table storage.buckets (
    id                 text primary key,
    name               text not null,
    public             boolean default false,
    file_size_limit    bigint,
    allowed_mime_types text[]
  );

  create table storage.objects (
    id        uuid primary key default gen_random_uuid(),
    bucket_id text references storage.buckets (id),
    name      text,
    owner     uuid
  );

  alter table storage.objects enable row level security;

  create function storage.foldername(name text) returns text[]
  language plpgsql immutable
  as $$
  declare
    _parts text[];
  begin
    select string_to_array(name, '/') into _parts;
    return _parts[1:array_length(_parts, 1) - 1];
  end
  $$;
`;

// Supabase grants table access to these roles by default and relies on row
// level security to restrict it. Mirroring that is what makes the policy tests
// meaningful.
const SUPABASE_GRANTS = `
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
  grant usage on schema public to anon, authenticated, service_role;
  grant all on all tables in schema public to anon, authenticated, service_role;
  grant all on all sequences in schema public to anon, authenticated, service_role;
  grant usage on schema storage to anon, authenticated, service_role;
  grant all on all tables in schema storage to anon, authenticated, service_role;
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

  // Grants first, as Supabase does: its default privileges give these roles
  // every new table, and a migration that revokes something runs after that.
  // Granting after the migrations instead silently undid every revoke in them.
  await db.exec(SUPABASE_SHIM);
  await db.exec(SUPABASE_GRANTS);
  for (const sql of await migrations()) await db.exec(sql);

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
    /** Meta's shape: [{ type: "image", payload: { url } }]. */
    attachments?: unknown[];
    sentAt: string;
  },
): Promise<void> {
  await db.sql(
    `insert into messages (conversation_id, workspace_id, mid, direction, text, attachments, sent_at)
     values ($1, $2, $3, $4, $5, $6, $7)`,
    [
      conversationId,
      workspaceId,
      message.mid,
      message.direction,
      message.text ?? null,
      JSON.stringify(message.attachments ?? []),
      message.sentAt,
    ],
  );
}
