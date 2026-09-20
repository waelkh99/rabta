-- Phase Two. An AI answers basic customer inquiries — price, availability,
-- basic product facts — from the seller's own catalog, and hands everything
-- else to the seller. See CLAUDE.md for the product shape and DECISIONS.md
-- (19 September 2026) for the decisions behind each piece.
--
-- Deliberately no extensions. tests/helpers/db.ts executes every migration in
-- this directory into PGlite, so a `create extension` line would throw at boot
-- and take all existing tests with it. That is also why the AI runs inside the
-- webhook's existing background task rather than on pg_cron.
--
-- Two things here are worth knowing before changing anything:
--
--   * `with check` is written out on the new policies even though it is
--     redundant. When it is omitted Postgres uses the `using` expression for
--     both, so these policies would behave identically without it — measured,
--     not assumed. It is written anyway so that widening `using` later cannot
--     silently widen what may be WRITTEN as well as what may be read. That is
--     a real distinction the moment the two expressions stop being the same.
--
--   * conversations.ai_last_run_at is a claim, not a log. A conditional update
--     against it is what stops two overlapping runs sending the same sentence
--     to a customer twice, which is the one failure that cannot be repaired
--     afterwards.

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

-- Parallel to message_direction: a closed set, named rather than spelled out
-- at each call site. The client renders an AI reply differently from the
-- seller's own, and the runaway-loop guard counts consecutive 'ai' rows.
create type message_origin as enum ('seller', 'ai');

-- What the AI did with a conversation. Null means it has not looked at it.
create type ai_state as enum ('answered', 'escalated');

-- How freely the AI may answer. 'reserved' sticks to what is literally in the
-- catalog; 'normal' also handles greetings and delivery questions. This is a
-- prompt string selected by a setting, not a learning system.
create type ai_caution as enum ('reserved', 'normal');

-- ---------------------------------------------------------------------------
-- Products
-- ---------------------------------------------------------------------------

-- The catalog exists so the model can answer questions. It is not inventory:
-- no stock counts, no variants, no SKUs, no images. CLAUDE.md still rules
-- those out, and this table should not grow into them without a decision.
create table products (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  name         text not null,
  price        numeric(12, 2),
  description  text,

  -- A boolean, not free text. "Usually available" in a text column is an
  -- invitation for the model to turn a hedge into a promise.
  in_stock     boolean not null default true,

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index products_workspace_idx on products (workspace_id, name);

-- ---------------------------------------------------------------------------
-- AI settings
-- ---------------------------------------------------------------------------

-- One row per workspace, but a MISSING row is meaningful and normal: it means
-- the AI is off. Nothing backfills this and no trigger creates it, so the
-- default state of every existing and future workspace is "AI disabled",
-- which is the way round we want it to fail.
--
-- Only settings the seller is supposed to control live here. Postgres has no
-- column-level row level security, so every column on a client-writable table
-- is client-writable. Anything the seller must not change belongs on a table
-- with no policies — the account_tokens pattern — or must not be stored.
-- That is why there is no token counter here; the monthly ceiling is derived
-- by counting messages with origin = 'ai'.
create table ai_settings (
  workspace_id uuid primary key references workspaces (id) on delete cascade,
  enabled      boolean not null default false,
  caution      ai_caution not null default 'reserved',
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Columns on existing tables
-- ---------------------------------------------------------------------------

-- Who wrote an outbound message. The default covers every row that already
-- exists, all of which were written by the seller.
--
-- It is meaningless on an inbound row — a customer's message reads as
-- origin 'seller', which is nonsense if you go looking. Left that way on
-- purpose: making it nullable would add a case to every read for no gain,
-- since the only code that reads it filters on direction = 'outbound' first.
alter table messages
  add column origin message_origin not null default 'seller';

-- Counting an AI reply is how the monthly ceiling is derived, so it is a
-- partial index rather than a counter that has to be kept in sync.
create index messages_ai_month_idx
  on messages (workspace_id, created_at)
  where origin = 'ai';

alter table conversations
  add column ai_state             ai_state,
  add column ai_escalation_reason text,
  add column ai_last_run_at       timestamptz;

comment on column conversations.ai_last_run_at is
  'A claim, not a log. Set by a conditional update that only matches when it is '
  'null or older than the claim window; zero rows back means another run owns '
  'this conversation. Prevents double-sending to a customer.';

comment on column conversations.ai_state is
  'Null means the AI has not looked at this conversation. Answered and '
  'escalated are both cleared when the seller opens it.';

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table products    enable row level security;
alter table ai_settings enable row level security;

-- One policy each: `for all` covers select, insert, update and delete under a
-- single predicate, matching the shape used for connected_accounts. On why
-- `with check` is spelled out when it is redundant, see the note at the top.
create policy products_owner on products
  for all
  using (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  )
  with check (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  );

create policy ai_settings_owner on ai_settings
  for all
  using (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  )
  with check (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  );

-- conversations_owner_update is deliberately left alone. It was briefly
-- thought to have a gap — `using` with no `with check` — but that is not a
-- gap: when `with check` is omitted Postgres uses the `using` expression for
-- both, so the policy already refuses to leave a row in another workspace.
-- Proven by "a seller cannot move their own conversation into another
-- workspace" in tests/schema.test.ts, which passes with or without a rewrite.
-- Dropping and recreating a working policy on a live table would have been
-- churn and a brief window of risk for no behaviour change.

-- Realtime is deliberately not extended to products or ai_settings. A seller
-- editing their own catalog in one tab does not need live updates, and
-- publication membership is a cost and a surface.
