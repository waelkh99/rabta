-- "I'll handle this one."
--
-- The shop-wide switch decides whether the assistant answers at all. This
-- decides it for one conversation: a regular customer, a delicate complaint, a
-- sale the seller wants to close themselves. It stays set until the seller
-- turns it back on — it is not cleared by their reply, because the point is
-- that this customer is theirs, not that they are at the desk right now. That
-- case is already the seller-present guard.
--
-- Written by the client through the existing conversations_owner_update
-- policy, and read by the webhook, where it makes the assistant behave exactly
-- as if the shop had it switched off: nothing sent, nothing marked, nothing
-- spent.
alter table conversations
  add column ai_paused boolean not null default false;

comment on column conversations.ai_paused is
  'True when the seller has taken this conversation over from the assistant. '
  'The assistant does nothing here until it is false again.';
