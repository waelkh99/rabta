-- A connected account's conversations go where the account goes.
--
-- Connecting a Page from a second shop moves its connected_accounts row (the
-- upsert in meta-oauth is on platform + external_id), but its conversations
-- and messages kept the old workspace_id. A returning customer's message was
-- then added to that old conversation — conversations are unique per account
-- and customer — and neither shop could see it: the inbox list and
-- send-message both read the account under row level security, which the old
-- shop no longer passes and the new shop never did for the conversation.
-- Found 17 November 2026, when the owner's own Messenger "Hello" vanished
-- after Rabta App was connected to the demo shop.
--
-- Decided by the owner the same day: the conversations move with the Page, as
-- they do in Meta's own Page inbox, where whoever manages the Page sees its
-- whole history.
--
-- A trigger rather than code in meta-oauth, so it holds however the account
-- changes shop (the Connect button, the WhatsApp script, anything later) and
-- in the same transaction as the move. Sellers cannot change an account's
-- workspace — connected_accounts has no update policy — so this runs only for
-- the service role. It must not be `security definer`: running with the
-- caller's rights, even a seller who somehow could move an account could not
-- move another shop's conversations with it. tests/account-move.test.ts fails
-- if both of those protections are lost.
--
-- Not moved, on purpose: ai_usage stays with the shop that used those replies,
-- and ops_log stays where it was written.

create function move_account_conversations()
returns trigger
language plpgsql
as $$
begin
  update conversations
     set workspace_id = new.workspace_id
   where account_id = new.id
     and workspace_id is distinct from new.workspace_id;

  update messages
     set workspace_id = new.workspace_id
   where conversation_id in (select id from conversations where account_id = new.id)
     and workspace_id is distinct from new.workspace_id;

  return new;
end;
$$;

create trigger connected_accounts_move_conversations
  after update of workspace_id on connected_accounts
  for each row
  when (old.workspace_id is distinct from new.workspace_id)
  execute function move_account_conversations();
