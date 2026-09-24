-- How each conversation ended. See CLAUDE.md, "How conversations end".
--
-- The assistant reads a conversation once it has settled and says how it
-- ended; the seller can correct it with one tap. The two are kept apart —
-- ai_outcome is what the assistant said, seller_outcome what the seller said —
-- so a later reading never overwrites a correction, and so the view can say
-- honestly how often the assistant had to be corrected.

alter table conversations
  -- What the assistant read.
  add column ai_outcome text
    check (ai_outcome in ('ordered', 'not_bought', 'just_asking', 'undecided')),
  add column ai_outcome_reason text,
  add column outcome_products text[] not null default '{}',
  add column outcome_area text,
  add column outcome_topics text[] not null default '{}',
  add column outcome_evidence text,

  -- The newest message the reading covered. A conversation is read again only
  -- once something newer arrives, which is also what lets a customer who comes
  -- back and orders replace an earlier "didn't buy".
  add column ai_outcome_read_up_to timestamptz,

  -- Held while a reading is in progress, so two deliveries arriving together
  -- do not both pay to read the same conversation. Stale after ten minutes.
  add column outcome_claimed_at timestamptz,

  -- What the seller said, when they corrected it.
  add column seller_outcome text
    check (seller_outcome in ('ordered', 'not_bought', 'just_asking', 'undecided')),
  add column seller_outcome_reason text,
  add column seller_outcome_at timestamptz;

-- The one rule for which label is shown, in the database so the row, the
-- thread and the weekly view cannot disagree about it.
--
-- The seller wins for the conversation as it stood when they corrected it.
-- Once the customer writes again and the assistant reads the new messages,
-- the newer reading is shown: a "didn't buy" the seller set on Monday should
-- not hide the order the same customer placed on Thursday.
alter table conversations
  add column outcome_by text generated always as (
    case
      when seller_outcome is not null
        and (ai_outcome_read_up_to is null or seller_outcome_at >= ai_outcome_read_up_to)
        then 'seller'
      when ai_outcome is not null then 'ai'
    end
  ) stored,
  add column outcome text generated always as (
    case
      when seller_outcome is not null
        and (ai_outcome_read_up_to is null or seller_outcome_at >= ai_outcome_read_up_to)
        then seller_outcome
      else ai_outcome
    end
  ) stored,
  add column outcome_reason text generated always as (
    case
      when seller_outcome is not null
        and (ai_outcome_read_up_to is null or seller_outcome_at >= ai_outcome_read_up_to)
        then seller_outcome_reason
      else ai_outcome_reason
    end
  ) stored;

comment on column conversations.outcome is
  'How the conversation ended, as shown: the seller''s correction while it is '
  'current, otherwise the assistant''s reading. ordered, not_bought, '
  'just_asking, or undecided (shown as no mark).';

-- ---------------------------------------------------------------------------
-- Picking conversations to read
-- ---------------------------------------------------------------------------

-- Settled conversations nobody has read since their last message, claimed in
-- one statement so concurrent callers take different rows. Returns the
-- newest message time each reading will cover.
--
-- Only accounts still receiving: a disconnected account's conversations are
-- history, and reading them costs money for nobody.
create function claim_outcomes_due(
  p_now timestamptz,
  p_settle interval,
  p_limit int
)
returns table (id uuid, workspace_id uuid, read_up_to timestamptz)
language sql
security definer set search_path = public
as $$
  with due as (
    select c.id
    from conversations c
    join connected_accounts a on a.id = c.account_id and a.status = 'active'
    where c.last_inbound_at is not null
      and c.last_message_at < p_now - p_settle
      and (c.ai_outcome_read_up_to is null or c.ai_outcome_read_up_to < c.last_message_at)
      and (c.outcome_claimed_at is null or c.outcome_claimed_at < p_now - interval '10 minutes')
    order by c.last_message_at
    limit p_limit
    for update of c skip locked
  )
  update conversations c
  set outcome_claimed_at = p_now
  from due
  where c.id = due.id
  returning c.id, c.workspace_id, c.last_message_at;
$$;

-- Only the webhook reads conversations, with the service role.
revoke execute on function claim_outcomes_due(timestamptz, interval, int) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- The week, for the seller
-- ---------------------------------------------------------------------------

-- Everything the "this week" view shows, in one call. Security invoker, so
-- row level security scopes it to the signed-in seller's own conversations
-- exactly as every other read is scoped.
--
-- A conversation belongs to the period when the customer wrote in it during
-- the period.
create function outcome_summary(p_from timestamptz, p_to timestamptz)
returns jsonb
language sql
stable
security invoker set search_path = public
as $$
  with active as (
    select c.*
    from conversations c
    where exists (
      select 1 from messages m
      where m.conversation_id = c.id
        and m.direction = 'inbound'
        and m.sent_at >= p_from and m.sent_at < p_to
    )
  )
  select jsonb_build_object(
    'conversations', (select count(*) from active),
    'ordered', (select count(*) from active where outcome = 'ordered'),
    'not_bought', (select count(*) from active where outcome = 'not_bought'),
    'just_asking', (select count(*) from active where outcome = 'just_asking'),
    'open', (select count(*) from active where outcome is null or outcome = 'undecided'),

    'reasons', coalesce((
      select jsonb_object_agg(reason, n)
      from (
        select coalesce(outcome_reason, 'unknown') as reason, count(*) as n
        from active where outcome = 'not_bought'
        group by 1
      ) r
    ), '{}'::jsonb),

    -- Most asked about, and how many of those conversations became orders.
    'products', coalesce((
      select jsonb_agg(jsonb_build_object('name', name, 'asked', asked, 'ordered', ordered)
                       order by asked desc, name)
      from (
        select p as name,
               count(*) as asked,
               count(*) filter (where outcome = 'ordered') as ordered
        from active, unnest(outcome_products) as p
        group by p
        order by asked desc, p
        limit 5
      ) x
    ), '[]'::jsonb),

    'areas', coalesce((
      select jsonb_agg(jsonb_build_object('name', outcome_area, 'count', n) order by n desc, outcome_area)
      from (
        select outcome_area, count(*) as n
        from active where outcome_area is not null
        group by 1 order by n desc, outcome_area limit 5
      ) a
    ), '[]'::jsonb),

    -- Customers whose reply window closed in the period with their last
    -- message never answered: lost to silence, whatever the assistant read.
    'unanswered', (
      select count(*) from conversations c
      where c.window_expires_at >= p_from
        and c.window_expires_at < least(p_to, now())
        and c.last_message_at <= c.last_inbound_at
    ),

    -- When customers write, by hour in Amman: 24 counts, midnight first.
    'hours', (
      select jsonb_agg(coalesce(h.n, 0) order by s.hour)
      from generate_series(0, 23) as s(hour)
      left join (
        select extract(hour from m.sent_at at time zone 'Asia/Amman')::int as hour, count(*) as n
        from messages m
        where m.direction = 'inbound' and m.sent_at >= p_from and m.sent_at < p_to
        group by 1
      ) h on h.hour = s.hour
    ),

    -- How often the seller had to correct the assistant.
    'read_by_assistant', (select count(*) from active where ai_outcome is not null),
    'corrected', (
      select count(*) from active
      where outcome_by = 'seller' and ai_outcome is not null and seller_outcome <> ai_outcome
    )
  );
$$;

grant execute on function outcome_summary(timestamptz, timestamptz) to authenticated;
