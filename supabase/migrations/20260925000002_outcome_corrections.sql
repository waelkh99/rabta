-- A changed reason is a correction too.
--
-- outcome_summary counted a correction only when the seller changed the
-- outcome itself. Seen in a browser: the assistant read "didn't buy: price",
-- the seller changed it to "didn't buy: delivery fee", and the view said
-- they had corrected nothing. The reason is the part of the reading the
-- seller acts on, so getting it wrong is the assistant being wrong.
--
-- The rest of the function is unchanged; restated whole because `create or
-- replace` takes a whole body.

create or replace function outcome_summary(p_from timestamptz, p_to timestamptz)
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

    'unanswered', (
      select count(*) from conversations c
      where c.window_expires_at >= p_from
        and c.window_expires_at < least(p_to, now())
        and c.last_message_at <= c.last_inbound_at
    ),

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

    'read_by_assistant', (select count(*) from active where ai_outcome is not null),
    'corrected', (
      select count(*) from active
      where outcome_by = 'seller' and ai_outcome is not null
        and (
          seller_outcome is distinct from ai_outcome
          or (seller_outcome = 'not_bought'
              and coalesce(seller_outcome_reason, 'unknown') is distinct from coalesce(ai_outcome_reason, 'unknown'))
        )
    )
  );
$$;
