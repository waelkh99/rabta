-- Photos and categories for the catalog.
--
-- Asked for by the product owner on 22 September 2026. The catalog held a
-- name, a price, one line of description and an in-stock flag, and that was
-- thin: a seller has more to say about what they sell, and a customer asks to
-- see it far more often than they ask what it is made of.
--
-- Deliberately not here: sizes, colours, variants, stock counts. The product
-- owner asked for the easiest thing for the seller "even if it puts extra load
-- on the agent" — sizes and colours are written in the description, in the
-- seller's own words, and the assistant reads them.

-- ---------------------------------------------------------------------------
-- Categories
-- ---------------------------------------------------------------------------

-- A table rather than a text column on the product, so that renaming a
-- category cannot silently detach the offers that target it. Offers point at
-- a category by id; a name typed slightly differently on two products would
-- otherwise be two categories and half an offer.
create table categories (
  id           uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references workspaces (id) on delete cascade,
  name         text not null check (length(trim(name)) > 0),
  created_at   timestamptz not null default now()
);

-- Case-insensitive, because "Dresses" and "dresses" are one category to a
-- seller. Also what lets the client find-or-create by name.
create unique index categories_workspace_name_idx
  on categories (workspace_id, lower(trim(name)));

-- Set null rather than cascade: deleting a category must never delete the
-- products in it.
alter table products
  add column category_id uuid references categories (id) on delete set null;

-- Storage paths inside the product-photos bucket, in the order the seller put
-- them. The first is the cover — the one the assistant sends.
--
-- An array rather than a table: they are only ever read with the product,
-- always in order, and never queried on their own. Five is plenty for a
-- product in a DM shop, and a cap stops a runaway upload loop filling storage.
alter table products
  add column photos text[] not null default '{}'
  check (cardinality(photos) <= 5);

create index products_category_idx on products (category_id);

-- The seller's own code for a product — "FS-101". Asked for by the product
-- owner on 22 September 2026, so that importing a sheet a second time updates
-- the products it added the first time. Names were rejected for that: a shop
-- writes the same product in Arabic in one place and English in another, and
-- matching on them would update the wrong thing or nothing.
--
-- Not a SKU in the sense CLAUDE.md rules out: nothing hangs off it, no stock,
-- no variants. It is a label the seller already uses — on their Instagram
-- posts as often as in their sheet — so the assistant reads it too.
alter table products
  add column code text check (code is null or length(trim(code)) > 0);

-- Unique within a shop, ignoring case and surrounding space: "fs-101" and
-- "FS-101 " are one code to a seller. Partial, because most products have none.
-- Every product has one, so a sheet can always be matched back. Products that
-- exist before this migration are numbered in the order they were added, the
-- same shape the client gives new ones: P-001, P-002. Asked for by the product
-- owner: "if the seller doesn't have it on first import we can generate an Id".
update products p
set code = 'P-' || lpad(r.n::text, 3, '0')
from (
  select id, row_number() over (partition by workspace_id order by created_at, id) as n
  from products
) r
where p.id = r.id and p.code is null;

create unique index products_code_idx
  on products (workspace_id, lower(trim(code)))
  where code is not null;

alter table categories enable row level security;

create policy categories_owner on categories
  for all
  using (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  )
  with check (
    workspace_id in (select id from workspaces where owner_id = auth.uid())
  );

-- ---------------------------------------------------------------------------
-- The photos themselves
-- ---------------------------------------------------------------------------

-- Public read. Meta fetches the URL itself to deliver an image to a customer,
-- and cannot present our credentials; a signed URL would expire under a
-- message that is meant to stay in the customer's thread. These are the
-- photos a seller posts publicly on Instagram anyway, and every path carries
-- a random uuid, so there is nothing to enumerate.
--
-- Only JPEG, and at most 2 MB: the client re-encodes every photo to a 1600px
-- JPEG before it uploads, so anything else did not come from the client.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-photos', 'product-photos', true, 2097152, array['image/jpeg'])
on conflict (id) do nothing;

-- Writing is scoped by the first folder of the path, which is the workspace
-- id: `{workspace_id}/{uuid}.jpg`. A seller can put files in their own folder
-- and nowhere else, and can remove only their own.
create policy product_photos_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'product-photos'
    and (storage.foldername(name))[1] in (
      select id::text from workspaces where owner_id = auth.uid()
    )
  );

-- Removing goes through a select first on Supabase's side, so the owner needs
-- to be able to see their own objects as well as delete them.
create policy product_photos_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'product-photos'
    and (storage.foldername(name))[1] in (
      select id::text from workspaces where owner_id = auth.uid()
    )
  );

create policy product_photos_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'product-photos'
    and (storage.foldername(name))[1] in (
      select id::text from workspaces where owner_id = auth.uid()
    )
  );
