-- The other half of 20260926000001's policy rewrite.
--
-- These five policies spell out `with check` as well as `using` (see the note
-- at the top of 20260919000001_ai.sql for why). The earlier migration rewrote
-- only `using`, and the advisor still flagged the raw auth.uid() left in the
-- check. Same rule, evaluated once per statement instead of once per row.
alter policy products_owner on products
  with check (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy shop_owner on shop
  with check (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy delivery_zones_owner on delivery_zones
  with check (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy categories_owner on categories
  with check (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));
alter policy offers_owner on offers
  with check (workspace_id in (select id from workspaces where owner_id = (select auth.uid())));

-- Deleting a seller cascades through these; without an index each delete
-- scans the table.
create index client_errors_user_idx on client_errors (user_id);
create index ops_log_workspace_idx on ops_log (workspace_id);
