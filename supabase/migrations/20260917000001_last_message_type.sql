-- A message carrying only an attachment has no text, so the conversation
-- summary had nothing to show and the inbox rendered a blank row. Customers in
-- social commerce send pictures of what they want, so this is a primary path
-- rather than an edge case.
--
-- The fix records what KIND of thing the last message was and lets the client
-- render the label. Writing 'Photo' into the trigger would put a user-facing
-- English string in the database, which contradicts the decision that there are
-- no hardcoded user-facing strings anywhere — the interface is Arabic and
-- English, and the database should not pick one.
--
-- Deriving this client-side instead would mean joining messages onto every
-- conversation list query, which is the hottest read in the product. One column
-- maintained by the same trigger that already maintains the rest of the summary
-- keeps that query a single read.

create type message_content_type as enum (
  'text', 'image', 'video', 'audio', 'file', 'share', 'other'
);

alter table conversations
  add column last_message_type message_content_type;

-- Shared by the trigger and the backfill so the two cannot disagree.
create function message_content_type_of(p_text text, p_attachments jsonb)
returns message_content_type
language sql
immutable
as $$
  select case
    -- A message with both text and an attachment previews as its text, so it
    -- is a text message as far as the list is concerned.
    when p_text is not null and p_text <> '' then 'text'::message_content_type
    when jsonb_typeof(p_attachments) = 'array' and jsonb_array_length(p_attachments) > 0 then
      case p_attachments -> 0 ->> 'type'
        when 'image' then 'image'::message_content_type
        when 'video' then 'video'::message_content_type
        when 'audio' then 'audio'::message_content_type
        when 'file'  then 'file'::message_content_type
        when 'share' then 'share'::message_content_type
        -- Meta adds attachment types without warning. An unknown one must not
        -- fail the insert, and must not render as blank either.
        else 'other'::message_content_type
      end
    else 'other'::message_content_type
  end;
$$;

-- Existing conversations get the type of their newest message.
update conversations c
set last_message_type = message_content_type_of(m.text, m.attachments)
from (
  select distinct on (conversation_id) conversation_id, text, attachments
  from messages
  order by conversation_id, sent_at desc
) m
where m.conversation_id = c.id;

-- Replaces the function from the initial migration. The only change is the
-- new column; it is guarded by the same out-of-order check as the preview, so
-- a late-arriving older message cannot overwrite a newer summary.
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
                           end
  where id = new.conversation_id;

  return new;
end;
$$;
