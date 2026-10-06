-- WhatsApp as a third channel.
--
-- connected_accounts.external_id holds the WhatsApp phone number id (what
-- arrives in value.metadata.phone_number_id), and conversations'
-- customer_external_id holds the customer's WhatsApp number. Nothing else in
-- the schema changes: the 24 hour window is WhatsApp's rule too.
alter type platform add value if not exists 'whatsapp';

-- Files customers send on WhatsApp. Meta gives a media id that only works with
-- the account's token, so the webhook downloads each file once and keeps it
-- here, where the app and Meta's own fetch can read it.
--
-- Public read, for the same reason as product-photos and with the same
-- protection: every path carries a random uuid. Messenger's attachment URLs
-- are just as public. Only the service role writes, so there are no policies.
--
-- 50 MB: the Free plan's upload ceiling. WhatsApp allows documents up to
-- 100 MB; one larger than this is stored without a file, as a failed fetch is.
insert into storage.buckets (id, name, public, file_size_limit)
values ('customer-media', 'customer-media', true, 52428800)
on conflict (id) do nothing;
