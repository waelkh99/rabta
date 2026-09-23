-- Offers: the sales and discounts section, promised since 20 September.
--
-- Asked for by the product owner on 22 September 2026. Three kinds, chosen
-- from what small shops selling through Instagram in Jordan actually run:
--
--   percent  — خصم 20%
--   amount   — 5 دنانير خصم
--   buy_get  — اشتري 2 والثالثة مجاناً
--
-- Each covers the whole shop, some categories, or some products, and may have
-- a start and an end date. Promo codes were offered and declined. A seasonal
-- sale — Ramadan, Eid, White Friday — is any of these with a name and dates.
--
-- The assistant never works out a sale price itself. The grounding check
-- refuses any number the shop did not write down, so a price the model
-- calculated would be refused on the way out. The price is calculated in code
-- (`salePrice` in ai.ts) and written into what the model reads.

create type offer_kind as enum ('percent', 'amount', 'buy_get');

create table offers (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,

  -- Optional, and what the customer is told: "عرض العيد". Without one the
  -- offer is described by what it does.
  name         text,

  kind         offer_kind not null,

  -- The percentage for percent, the amount off for amount. Fils, like prices.
  value        numeric(12, 3),

  -- For buy_get: buy this many, get this many more free.
  buy          int,
  get          int,

  -- Both empty means the whole shop. Ids rather than join tables: an offer is
  -- only ever read whole, with its targets, and never queried by target.
  --
  -- ponytail: no foreign key on an array element. A deleted product's id
  -- stays here and simply stops matching anything. Move to join tables if
  -- that is ever more than untidy.
  category_ids uuid[] not null default '{}',
  product_ids  uuid[] not null default '{}',

  -- Dates, not times, and inclusive: "until the 30th" means the 30th is in.
  -- Read in Amman time — see salePrice. Null at either end is open.
  starts_on    date,
  ends_on      date,

  enabled      boolean not null default true,

  created_at   timestamptz not null default now(),

  -- Coalesced to false because a check that evaluates to null passes: an
  -- amount offer with no amount would otherwise be stored, since null > 0 is
  -- null rather than false. The test for exactly that failed first.
  constraint offers_value check (
    coalesce(
      case kind
        when 'percent' then value > 0 and value < 100 and buy is null and get is null
        when 'amount'  then value > 0 and buy is null and get is null
        when 'buy_get' then value is null and buy >= 1 and get >= 1
      end,
      false
    )
  ),

  constraint offers_dates check (starts_on is null or ends_on is null or starts_on <= ends_on)
);

create index offers_workspace_idx on offers (workspace_id);

alter table offers enable row level security;

create policy offers_owner on offers
  for all
  using (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  )
  with check (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  );
