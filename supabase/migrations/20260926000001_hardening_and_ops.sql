-- Getting ready to run with real sellers: tighter permissions, and a record of
-- what the service is doing that an admin can read from inside the app.
--
-- Found by a launch-readiness review on 25 September 2026: Supabase's own
-- advisors against the live project, and a read of every policy.

-- ---------------------------------------------------------------------------
-- A seller writes only the conversation fields the app writes
-- ---------------------------------------------------------------------------

-- conversations_owner_update let a seller change any column of their own
-- conversations: which account it belongs to, the customer's id, the
-- assistant's own state. Nothing reached another seller — send-message reads
-- the account through the seller's own row level security — but a client has
-- no business writing any of it. These five are everything lib/data.dart
-- writes: opening a thread, the pause switch, and correcting an outcome.
revoke update on conversations from anon, authenticated;
grant update (unread_count, ai_paused, seller_outcome, seller_outcome_reason, seller_outcome_at)
  on conversations to authenticated;

-- ---------------------------------------------------------------------------
-- Advisor findings
-- ---------------------------------------------------------------------------

-- A function without a fixed search_path resolves names through whatever path
-- the caller set.
alter function message_content_type_of(text, jsonb) set search_path = public;
alter function touch_conversation() set search_path = public;

-- A trigger function, reachable as /rest/v1/rpc/handle_new_user because
-- functions are executable by everyone by default. Postgres refuses to run a
-- trigger function outside a trigger, so this was never exploitable; it is
-- closed so the advisor stops saying so and nobody has to reason about it.
revoke execute on function handle_new_user() from public, anon, authenticated;

-- auth.uid() inside a policy is re-evaluated for every row. Wrapped in a
-- select, Postgres evaluates it once per query. Same rules, same tests.
alter policy workspaces_owner on workspaces using (owner_id = (select auth.uid()));
alter policy connected_accounts_owner on connected_accounts
  using (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy conversations_owner on conversations
  using (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy conversations_owner_update on conversations
  using (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy messages_owner on messages
  using (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy products_owner on products
  using (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy shop_owner on shop
  using (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy delivery_zones_owner on delivery_zones
  using (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy categories_owner on categories
  using (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy offers_owner on offers
  using (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));

-- ---------------------------------------------------------------------------
-- What the service did, kept where an admin can read it
-- ---------------------------------------------------------------------------

-- Function logs live in the Supabase dashboard for a day or a week and cannot
-- be searched by seller. The events that matter — a failure, a dead token, an
-- account connected — are written here as well, one row each.
create table ops_log (
  id           bigserial primary key,
  at           timestamptz not null default now(),
  level        text not null check (level in ('info', 'warn', 'error')),
  source       text not null,
  event        text not null,
  workspace_id uuid references workspaces (id) on delete set null,
  detail       jsonb not null default '{}'::jsonb
);

create index ops_log_at_idx on ops_log (at desc);

-- What each model call cost, so a seller's month can be priced without an
-- invoice, and so a cache that stopped working shows up as a number.
create table ai_usage (
  id            bigserial primary key,
  at            timestamptz not null default now(),
  workspace_id  uuid references workspaces (id) on delete cascade,
  kind          text not null check (kind in ('reply', 'outcome')),
  model         text not null,
  input_tokens  int not null default 0,
  output_tokens int not null default 0,
  cache_read    int not null default 0,
  cache_write   int not null default 0,
  cost_usd      numeric(12, 6) not null default 0
);

create index ai_usage_workspace_at_idx on ai_usage (workspace_id, at desc);

-- Errors the app hit on a seller's screen. Written by the seller's own
-- session and readable by nobody but an admin. Lengths are capped so a loop
-- cannot fill the table with megabytes.
create table client_errors (
  id          bigserial primary key,
  at          timestamptz not null default now(),
  user_id     uuid default auth.uid() references auth.users (id) on delete cascade,
  message     text not null check (length(message) <= 2000),
  stack       text check (length(stack) <= 8000),
  url         text check (length(url) <= 500),
  app_version text check (length(app_version) <= 50)
);

create index client_errors_at_idx on client_errors (at desc);

alter table ops_log enable row level security;
alter table ai_usage enable row level security;
alter table client_errors enable row level security;

-- ops_log and ai_usage get no policies: only the service role writes them, and
-- admins read them through admin_overview below.
create policy client_errors_insert on client_errors
  for insert to authenticated
  with check (user_id = (select auth.uid()));

revoke all on ops_log, ai_usage from anon, authenticated;
revoke all on client_errors from anon;
revoke select, update, delete on client_errors from authenticated;

-- ---------------------------------------------------------------------------
-- Keeping what is needed, and no more
-- ---------------------------------------------------------------------------

-- Raw payloads carry customers' messages. Once processed, the message itself
-- is in `messages`; the payload is only evidence for debugging, and a month is
-- plenty for that. Unprocessed events are never pruned — they are the retry
-- buffer.
create index webhook_events_received_idx on webhook_events (received_at);

create function prune_old_records(p_now timestamptz default now())
returns jsonb
language sql
security definer set search_path = public
as $$
  with events as (
    delete from webhook_events
    where processed_at is not null and received_at < p_now - interval '30 days'
    returning 1
  ), logs as (
    delete from ops_log where at < p_now - interval '90 days' returning 1
  ), errors as (
    delete from client_errors where at < p_now - interval '90 days' returning 1
  )
  select jsonb_build_object(
    'webhook_events', (select count(*) from events),
    'ops_log', (select count(*) from logs),
    'client_errors', (select count(*) from errors)
  );
$$;

revoke execute on function prune_old_records(timestamptz) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The admin's view
-- ---------------------------------------------------------------------------

-- Whether the signed-in user is one of us. Read from auth.users rather than
-- from the token, so a flag granted or revoked takes effect at once rather
-- than when the token next refreshes — the same rule admin-invite follows.
-- Strictly JSON true, as isAdmin() is in admin.ts.
create function is_admin()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select coalesce(
    (select raw_app_meta_data -> 'rabta_admin' = 'true'::jsonb
     from auth.users where id = auth.uid()),
    false
  );
$$;

revoke execute on function is_admin() from public, anon;
grant execute on function is_admin() to authenticated;

-- Everything the admin screen shows, in one call, across every seller. Refuses
-- anyone who is not an admin: security definer is what lets it read past row
-- level security, so the check is the whole of its protection.
create function admin_overview(p_now timestamptz default now())
returns jsonb
language plpgsql
stable
security definer set search_path = public
as $$
declare
  month_start timestamptz := date_trunc('month', p_now);
begin
  if not is_admin() then
    raise exception 'not an admin' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'generated_at', p_now,

    'health', jsonb_build_object(
      'last_delivery_at', (select max(received_at) from webhook_events),
      'unprocessed', (select count(*) from webhook_events where processed_at is null),
      'failing', (select count(*) from webhook_events where processed_at is null and error is not null),
      'stuck', (select count(*) from webhook_events where processed_at is null and attempts >= 5),
      'accounts_need_reconnect', (select count(*) from connected_accounts where status = 'needs_reconnect'),
      'errors_24h', (select count(*) from ops_log where level = 'error' and at > p_now - interval '24 hours'),
      'warnings_24h', (select count(*) from ops_log where level = 'warn' and at > p_now - interval '24 hours'),
      'client_errors_24h', (select count(*) from client_errors where at > p_now - interval '24 hours'),
      'ai_cost_month', (select coalesce(sum(cost_usd), 0) from ai_usage where at >= month_start),
      'ai_calls_month', (select count(*) from ai_usage where at >= month_start)
    ),

    'sellers', coalesce((
      select jsonb_agg(s order by s->>'last_message_at' desc nulls last)
      from (
        select jsonb_build_object(
          'workspace_id', w.id,
          'email', u.email,
          'admin', u.raw_app_meta_data -> 'rabta_admin' = 'true'::jsonb,
          'created_at', w.created_at,
          'last_sign_in_at', u.last_sign_in_at,
          'accounts', coalesce((
            select jsonb_agg(jsonb_build_object('platform', a.platform, 'name', a.name, 'status', a.status))
            from connected_accounts a where a.workspace_id = w.id
          ), '[]'::jsonb),
          'conversations', (select count(*) from conversations c where c.workspace_id = w.id),
          'messages_7d', (select count(*) from messages m where m.workspace_id = w.id and m.sent_at > p_now - interval '7 days'),
          'last_message_at', (select max(c.last_message_at) from conversations c where c.workspace_id = w.id),
          'products', (select count(*) from products p where p.workspace_id = w.id),
          'assistant_on', coalesce((select sh.assistant_enabled from shop sh where sh.workspace_id = w.id), false),
          'ai_replies_month', (select count(*) from messages m where m.workspace_id = w.id and m.origin = 'ai' and m.created_at >= month_start),
          'ai_cost_month', (select coalesce(sum(cost_usd), 0) from ai_usage g where g.workspace_id = w.id and g.at >= month_start),
          'handed_over', (select count(*) from conversations c where c.workspace_id = w.id and c.ai_state = 'escalated'),
          'ordered_month', (select count(*) from conversations c where c.workspace_id = w.id and c.outcome = 'ordered' and c.last_message_at >= month_start)
        ) as s
        from workspaces w
        join auth.users u on u.id = w.owner_id
      ) x
    ), '[]'::jsonb),

    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'at', l.at, 'level', l.level, 'source', l.source, 'event', l.event,
        'email', (select u.email from workspaces w join auth.users u on u.id = w.owner_id where w.id = l.workspace_id),
        'detail', l.detail
      ) order by l.at desc)
      from (select * from ops_log order by at desc limit 60) l
    ), '[]'::jsonb),

    'client_errors', coalesce((
      select jsonb_agg(jsonb_build_object(
        'at', e.at, 'message', e.message, 'url', e.url, 'app_version', e.app_version,
        'email', (select u.email from auth.users u where u.id = e.user_id)
      ) order by e.at desc)
      from (select * from client_errors order by at desc limit 30) e
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function admin_overview(timestamptz) from public, anon;
grant execute on function admin_overview(timestamptz) to authenticated;
