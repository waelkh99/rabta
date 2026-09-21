-- What the assistant did, made visible to the seller.
--
-- Two problems, both of which made the assistant invisible in the inbox:
--
--   * An escalation that spoke to the customer wrote an outbound message, so
--     the conversation's last message was no longer the customer's and it left
--     the waiting group. A customer the assistant explicitly could not help sat
--     under the heading "Answered". That is the exact failure this feature
--     exists to prevent, and it was caused by the fix that stopped the
--     assistant going silent.
--
--   * Nothing ever cleared ai_state. The column comment said it was cleared
--     when the seller opened the conversation; no code anywhere did that, in
--     the client or on the server.
--
-- Clearing happens here, in the trigger, rather than in the client. The seller
-- can answer a customer from Rabta or from Meta's own apps, and the echo of
-- either arrives as an outbound message on this same path — so one rule covers
-- both, and a seller who replies from their phone does not come back to a
-- conversation still flagged as needing them.

-- ---------------------------------------------------------------------------
-- Why the assistant stepped back, in two parts
-- ---------------------------------------------------------------------------

-- ai_escalation_reason already holds free text, and since this migration some
-- of that text is written by the model itself and shown to the seller. That is
-- deliberate: a reason that grows richer as the assistant improves should not
-- need a migration each time it does.
--
-- But the interface cannot localise prose it has never seen, and most
-- escalations never reach the model at all — a closed reply window and a
-- refused send are decided by our own code. So the class of reason travels
-- separately, as a short stable token the client maps to its own Arabic and
-- English. Text rather than an enum: the set will grow, and a client that
-- meets a token it does not know falls back to a general line rather than
-- failing.
alter table conversations
  add column ai_escalation_code text;

comment on column conversations.ai_escalation_code is
  'Which kind of escalation this was, as a stable token the client localises: '
  'window_closed, no_window, ai_streak, seller_present, ceiling, ungrounded, '
  'unusable, not_sent, or assistant when the model itself handed over. An '
  'unrecognised value must read as a general hand-over, never as an error.';

comment on column conversations.ai_escalation_reason is
  'The detail behind ai_escalation_code, in prose. When the code is '
  '"assistant" this is the model''s own words, written in the language of the '
  'conversation and shown to the seller. Otherwise it is our own description, '
  'kept for `npm run assistant` and not shown.';

-- ---------------------------------------------------------------------------
-- The seller answering is what clears it
-- ---------------------------------------------------------------------------

-- Unchanged from 20260917000001 except for the three ai_ columns at the end.
-- Restated in full because `create or replace` takes a whole body, and a
-- trigger this central is better read in one piece than reassembled from two
-- migrations.
--
-- The condition is the seller's own message, not any outbound message. The
-- assistant's replies are outbound too, and clearing on those would erase the
-- mark in the same statement that earned it.
--
-- Out-of-order delivery is deliberately not guarded here, unlike the preview
-- columns above it. A seller's reply that arrives late is still a seller who
-- has dealt with this conversation; refusing to clear the flag because the
-- clock disagrees would leave it waiting forever.
create or replace function touch_conversation()
returns trigger
language plpgsql
as $$
begin
  update conversations set
    last_message_at      = greatest(coalesce(last_message_at, '-infinity'::timestamptz), new.sent_at),
    last_message_preview = case
                             when new.sent_at >= coalesce(last_message_at, '-infinity'::timestamptz)
                             then new.text
                             else last_message_preview
                           end,

    last_message_type    = case
                             when new.sent_at >= coalesce(last_message_at, '-infinity'::timestamptz)
                             then message_content_type_of(new.text, new.attachments)
                             else last_message_type
                           end,

    last_inbound_at      = case
                             when new.direction = 'inbound'
                             then greatest(coalesce(last_inbound_at, '-infinity'::timestamptz), new.sent_at)
                             else last_inbound_at
                           end,

    window_expires_at    = case
                             when new.direction = 'inbound'
                             then greatest(coalesce(window_expires_at, '-infinity'::timestamptz), new.sent_at + interval '24 hours')
                             else window_expires_at
                           end,

    unread_count         = case
                             when new.direction = 'inbound' then unread_count + 1
                             else 0
                           end,

    ai_state             = case
                             when new.direction = 'outbound' and new.origin = 'seller'
                             then null
                             else ai_state
                           end,

    ai_escalation_reason = case
                             when new.direction = 'outbound' and new.origin = 'seller'
                             then null
                             else ai_escalation_reason
                           end,

    ai_escalation_code   = case
                             when new.direction = 'outbound' and new.origin = 'seller'
                             then null
                             else ai_escalation_code
                           end
  where id = new.conversation_id;

  return new;
end;
$$;
