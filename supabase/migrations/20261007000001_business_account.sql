-- The WhatsApp Business Account a number belongs to.
--
-- Meta subscribes the app to the business account, not to the number, so
-- stopping a number's messages means unsubscribing its business account — and
-- DELETE /{phone_number_id}/subscribed_apps is refused (code 100, seen on
-- staging 7 October). Null for Pages and Instagram accounts, which are
-- subscribed directly.
alter table connected_accounts add column business_account_id text;
