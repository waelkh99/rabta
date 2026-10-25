-- Plans, and the seller's guide for the assistant. Asked for on 26 October 2026.
--
-- Plans
-- -----
-- Two to start, Basic and Ultimate, differing only in how many assistant
-- replies a month they include. The number is counted, not stored: the same
-- count of `messages where origin = 'ai'` the fixed 2,000 ceiling used, so
-- there is still no counter to drift (docs/DECISIONS.md, 19 September).
--
-- The limits live in a table rather than in code so they can be changed with
-- one update and no deploy. Every seller can read every plan — there is
-- nothing secret in a name and a number — and nobody but the service role can
-- write one.
--
-- The plan sits on `workspaces`, which has a select policy and nothing else,
-- so a seller can read their plan and cannot change it. Admins change it
-- through admin_set_plan below. There is no payment: buyers are invoiced
-- directly, and payments are out of scope.

create table plans (
  id                text primary key,
  replies_per_month int  not null check (replies_per_month >= 0)
);

-- Measured on Sonnet 5: about $0.0037 a reply (docs/DECISIONS.md). Basic is
-- roughly $4 of model a month at its limit, Ultimate roughly $18.
insert into plans (id, replies_per_month) values
  ('basic', 1000),
  ('ultimate', 5000);

alter table plans enable row level security;

create policy plans_read on plans
  for select to authenticated using (true);

revoke insert, update, delete on plans from anon, authenticated;

-- Every workspace, existing and new, starts on Basic.
alter table workspaces
  add column plan text not null default 'basic' references plans (id);

create function admin_set_plan(p_workspace uuid, p_plan text)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  if not is_admin() then
    raise exception 'not an admin' using errcode = '42501';
  end if;

  update workspaces set plan = p_plan where id = p_workspace;
end;
$$;

revoke execute on function admin_set_plan(uuid, text) from public, anon;
grant execute on function admin_set_plan(uuid, text) to authenticated;

-- The admin screen shows each seller's plan and its limit next to the replies
-- already counted there. Otherwise unchanged from 20260926000001.
create or replace function admin_overview(p_now timestamptz default now())
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
          'plan', w.plan,
          'replies_limit', (select p.replies_per_month from plans p where p.id = w.plan),
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

-- The guide
-- ---------
-- What the seller writes, in their own words, about how the assistant should
-- run a conversation — "always ask which size first", "anyone asking for a
-- discount goes to me". `guide` is the source; `guide_steps` is the model's
-- reading of it, drawn back to the seller as a diagram so they can see it was
-- understood. Both go to the assistant. Written together by the `guide`
-- function, so they cannot drift apart.

alter table shop
  add column guide text check (length(guide) <= 4000),
  add column guide_steps jsonb;

-- Reading the guide is a model call too, and is priced with the rest.
alter table ai_usage drop constraint ai_usage_kind_check;
alter table ai_usage add constraint ai_usage_kind_check
  check (kind in ('reply', 'outcome', 'guide'));
