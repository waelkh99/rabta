-- Rabta initial schema.
--
-- Everything hangs off a workspace rather than directly off a user, so that
-- adding team members later is a membership table rather than re-parenting
-- every row. In Phase One a workspace always has exactly one owner.

-- gen_random_uuid() is in Postgres core from version 13, so pgcrypto is not
-- needed here.

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

create type platform as enum ('instagram', 'messenger');
create type message_direction as enum ('inbound', 'outbound');
create type account_status as enum ('active', 'needs_reconnect');

-- ---------------------------------------------------------------------------
-- Workspaces
-- ---------------------------------------------------------------------------

create table workspaces (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references auth.users (id) on delete cascade,
  name       text not null default 'My workspace',
  created_at timestamptz not null default now()
);

create index workspaces_owner_idx on workspaces (owner_id);

-- A workspace is created automatically on signup. Asking a new seller to name
-- a workspace before they can do anything would be a step with no purpose.
create function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.workspaces (owner_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ---------------------------------------------------------------------------
-- Connected accounts
-- ---------------------------------------------------------------------------

create table connected_accounts (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  platform     platform not null,
  external_id  text not null,
  name         text,
  avatar_url   text,
  status       account_status not null default 'active',
  connected_at timestamptz not null default now(),

  -- Load-bearing, not merely tidiness. Incoming webhooks identify the account
  -- only by its Meta id, so that id must map to exactly one workspace or we
  -- cannot know whose inbox a message belongs to.
  unique (platform, external_id)
);

create index connected_accounts_workspace_idx on connected_accounts (workspace_id);

-- Access tokens are keys to a seller's business inbox. This table has RLS
-- enabled and deliberately no policies at all, which denies every client and
-- leaves it readable only by the service role used by Edge Functions.
create table account_tokens (
  account_id   uuid primary key references connected_accounts (id) on delete cascade,
  access_token text not null,
  expires_at   timestamptz,
  updated_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Conversations
-- ---------------------------------------------------------------------------

create table conversations (
  id                   uuid primary key default gen_random_uuid(),
  account_id           uuid not null references connected_accounts (id) on delete cascade,

  -- Denormalised from the account so row level security needs no join.
  workspace_id         uuid not null references workspaces (id) on delete cascade,

  -- Meta's id for the customer. Scoped to the account they wrote to: the same
  -- person messaging two accounts appears here as two unrelated rows, and
  -- there is no supported way to connect them.
  customer_external_id text not null,
  customer_name        text,
  customer_avatar_url  text,

  last_message_at      timestamptz,
  last_message_preview text,
  last_inbound_at      timestamptz,

  -- When the free reply window closes. Stored so the interface can disable the
  -- composer before the seller types, rather than failing afterwards.
  window_expires_at    timestamptz,

  unread_count         integer not null default 0,
  created_at           timestamptz not null default now(),

  unique (account_id, customer_external_id)
);

create index conversations_workspace_recent_idx
  on conversations (workspace_id, last_message_at desc);

-- ---------------------------------------------------------------------------
-- Messages
-- ---------------------------------------------------------------------------

create table messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations (id) on delete cascade,
  workspace_id    uuid not null references workspaces (id) on delete cascade,

  -- Meta's message id. Unique, so redelivered webhooks collide here and
  -- idempotency is enforced by the database rather than by careful code.
  mid             text not null unique,

  direction       message_direction not null,
  text            text,
  attachments     jsonb not null default '[]'::jsonb,

  -- Meta's timestamp, not arrival time. Events can arrive out of order.
  sent_at         timestamptz not null,
  created_at      timestamptz not null default now()
);

create index messages_conversation_idx on messages (conversation_id, sent_at desc);

-- Keep the conversation summary in step with its messages. Done in a trigger
-- so it holds however the row arrived, and cannot drift out of sync.
create function touch_conversation()
returns trigger
language plpgsql
as $$
begin
  update conversations set
    -- Only advance the summary if this message really is the newest one.
    last_message_at      = greatest(coalesce(last_message_at, '-infinity'::timestamptz), new.sent_at),
    last_message_preview = case
                             when new.sent_at >= coalesce(last_message_at, '-infinity'::timestamptz)
                             then new.text
                             else last_message_preview
                           end,

    last_inbound_at      = case
                             when new.direction = 'inbound'
                             then greatest(coalesce(last_inbound_at, '-infinity'::timestamptz), new.sent_at)
                             else last_inbound_at
                           end,

    -- Messenger and Instagram allow free replies for 24 hours after the
    -- customer's last message.
    window_expires_at    = case
                             when new.direction = 'inbound'
                             then greatest(coalesce(window_expires_at, '-infinity'::timestamptz), new.sent_at + interval '24 hours')
                             else window_expires_at
                           end,

    -- An outbound message means the seller has answered, wherever they did it
    -- from. A reply sent from their own Instagram app reaches us as an echo
    -- and clears the unread state here, so Rabta does not show a conversation
    -- as waiting when it has already been handled.
    unread_count         = case
                             when new.direction = 'inbound' then unread_count + 1
                             else 0
                           end
  where id = new.conversation_id;

  return new;
end;
$$;

create trigger messages_touch_conversation
  after insert on messages
  for each row execute function touch_conversation();

-- ---------------------------------------------------------------------------
-- Raw webhook events
-- ---------------------------------------------------------------------------

-- Every payload Meta sends is stored before anything is done with it. This is
-- the retry buffer when processing fails, and the only way to answer "what did
-- Meta actually send?" when behaviour does not match expectations.
create table webhook_events (
  id              bigserial primary key,
  received_at     timestamptz not null default now(),
  object          text,
  payload         jsonb not null,
  signature_valid boolean not null,
  processed_at    timestamptz,
  attempts        integer not null default 0,
  error           text
);

create index webhook_events_pending_idx
  on webhook_events (received_at)
  where processed_at is null;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table workspaces         enable row level security;
alter table connected_accounts enable row level security;
alter table account_tokens     enable row level security;
alter table conversations      enable row level security;
alter table messages           enable row level security;
alter table webhook_events     enable row level security;

-- account_tokens and webhook_events intentionally get no policies. RLS with no
-- policy denies all client access; Edge Functions reach them via the service
-- role, which bypasses RLS.

create policy workspaces_owner on workspaces
  for select using (owner_id = auth.uid());

create policy connected_accounts_owner on connected_accounts
  for select using (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  );

create policy conversations_owner on conversations
  for select using (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  );

-- The client updates conversations only to clear unread state when the seller
-- opens one. Messages are never written by the client; outbound messages are
-- inserted by the send-message function after Meta has accepted them.
create policy conversations_owner_update on conversations
  for update using (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  );

create policy messages_owner on messages
  for select using (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table messages;
alter publication supabase_realtime add table conversations;
