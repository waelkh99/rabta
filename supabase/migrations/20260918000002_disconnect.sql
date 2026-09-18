-- Disconnecting an account must not delete the conversations.
--
-- `connected_accounts` is the parent of conversations, which is the parent of
-- messages, both `on delete cascade`. So removing the row would take every
-- conversation and every message with it — a seller who disconnects to stop
-- new messages arriving would silently lose the history of every customer they
-- have ever spoken to, with no warning and no way back.
--
-- A third status instead. The account stays, its history stays readable, and
-- what actually goes is the stored token and the webhook subscription.

alter type account_status add value if not exists 'disconnected';

comment on column connected_accounts.status is
  'active: messages arrive. needs_reconnect: the token expired and messages '
  'have silently stopped. disconnected: the seller turned it off, the token is '
  'deleted and Meta is unsubscribed, but the history stays.';
