-- The facts about a shop that are not products.
--
-- A catalog answers "how much is the red dress". It cannot answer "how much is
-- delivery to Basra", "do you deliver to Erbil", "are you open now" or "where
-- are you" — and those are asked as often as anything about a product. Without
-- them the assistant hands back most of a normal conversation, which reads as
-- broken rather than careful.
--
-- `ai_settings` is folded into `shop` here rather than left beside it. Both
-- were one row per workspace, and two settings tables means two queries, two
-- policies and a standing question about which one a new setting belongs in.
-- Done now because the only data in it is a single test row; it would not be
-- worth the churn later.
--
-- Currency is stored, not assumed. The product mainly serves Jordan, where
-- prices are in dinars, but some sellers quote in dollars — and an assistant
-- that answers "25" with no unit, or the wrong one, is the same problem as an
-- invented price.
--
-- Prices also gain a third decimal place here. The Jordanian dinar divides
-- into 1000 fils, so 12.750 is an ordinary price and the two decimal places
-- the catalog started with would have silently rounded it to 12.75. That is
-- the kind of defect nobody notices until a customer is quoted the wrong
-- number.

-- ---------------------------------------------------------------------------
-- The shop
-- ---------------------------------------------------------------------------

create table shop (
  workspace_id uuid primary key references workspaces (id) on delete cascade,

  -- Written as the seller writes it, and repeated back to the customer the
  -- same way. Not a currency code: nobody says "JOD" to a customer.
  currency text not null default 'د.ا',

  -- The delivery rules that do not fit a list of zones: free over a certain
  -- amount, same day inside the city, a surcharge for cash on delivery.
  delivery_note text,

  -- Where the shop is, for "where are you" and "can I collect it". Free text
  -- and multi-line, because a shop with two branches has two addresses and a
  -- shop with none has a neighbourhood it meets people in.
  locations text,

  -- Free text rather than a row per weekday. Real hours are "السبت إلى الخميس
  -- ١٠ص-٨م، الجمعة مغلق", and a structured editor for that is a lot of screen
  -- for something the assistant reads as a sentence anyway.
  hours text,

  -- Everything else the seller thinks the assistant should know: how to order,
  -- whether they take cash on delivery, return policy, that the blue one runs
  -- small. Deliberately open — no shop is the same shape as the next, and a
  -- field per fact would be a form nobody finishes.
  --
  -- It goes into the prompt as written, so it is also the escape hatch when
  -- the assistant keeps getting something wrong.
  about text,

  -- Moved from ai_settings, which this table replaces.
  assistant_enabled boolean not null default false,
  assistant_caution ai_caution not null default 'reserved',

  updated_at timestamptz not null default now()
);

-- Carries over whatever ai_settings held, so nobody's assistant silently
-- switches itself off.
insert into shop (workspace_id, assistant_enabled, assistant_caution)
select workspace_id, enabled, caution from ai_settings
on conflict (workspace_id) do nothing;

drop table ai_settings;

-- ---------------------------------------------------------------------------
-- Where the shop delivers, and for how much
-- ---------------------------------------------------------------------------

-- A list rather than a paragraph, because "how much to Basra" deserves an
-- exact answer rather than an interpretation of prose. The paragraph still
-- exists, above, for the rules a list cannot hold.
--
-- A zone with no fee is meaningful: it says the shop covers that place but
-- the price depends, which is a truthful answer and better than inventing one.
create table delivery_zones (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  name         text not null,
  fee          numeric(12, 3),
  created_at   timestamptz not null default now()
);

create index delivery_zones_workspace_idx on delivery_zones (workspace_id, name);

-- Fils. See the note at the top: 12.750 is an ordinary price in Jordan, and
-- two decimal places would round it away. Widening the scale keeps every value
-- already stored.
alter table products alter column price type numeric(12, 3);

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table shop            enable row level security;
alter table delivery_zones  enable row level security;

-- Same shape as products: one policy covering select, insert, update and
-- delete, with `with check` written out so that widening `using` later cannot
-- quietly widen what may be written.
create policy shop_owner on shop
  for all
  using (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  )
  with check (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  );

create policy delivery_zones_owner on delivery_zones
  for all
  using (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  )
  with check (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  );
