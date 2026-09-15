# Phase One checklist

Everything needed for a seller to manage Instagram and Facebook Messenger
conversations from one place. Nothing beyond that belongs here — see the out of
scope list in `CLAUDE.md`.

A box is ticked only when the thing has been run and seen to work, not when the
code exists. Where something was verified, it says how.

Updated 15 September 2026.

---

## 1. Backend foundation

- [x] Supabase project created and linked
- [x] Schema: workspaces, connected accounts, conversations, messages, tokens,
      raw events
- [x] Workspace created automatically on signup
- [x] Row level security on every table
- [x] Access tokens unreadable by any client
- [x] Conversation summary trigger: unread counts, previews, reply window
- [x] Out-of-order message delivery handled
- [x] Schema applied to the live project

Verified by 46 local tests and 13 checks against the live database, seeding
data first so the security checks proved something.

## 2. Receiving messages

- [x] Verification handshake
- [x] HMAC signature verification over the raw body
- [x] Fails closed when no app secret is configured
- [x] Raw payloads stored before processing
- [x] Fast 200, processing afterwards
- [x] Instagram and Messenger payloads parsed
- [x] Redelivery is idempotent
- [x] Echoes stored as outbound and clear unread state
- [x] Events for unconnected accounts handled without failing
- [x] Deployed, with secrets configured
- [ ] Sweep that retries events which failed processing
- [ ] Token expiry detected and the account flagged for reconnection
- [ ] Attachments: decide stored or fetched on view, then implement

Verified by 19 checks against the deployed endpoint using genuinely signed
requests.

Token expiry matters more than its position here suggests. When a token
expires, messages simply stop arriving and the seller has no way to know — they
think business is quiet.

## 3. Meta platform

The critical path. These run in calendar time, not development time, so delays
here hold up everything else.

- [ ] Understand Meta's use cases model
- [ ] Decide which use case and permissions Phase One needs
- [ ] Register the webhook callback URL
- [ ] Subscribe to the `messages` and `messaging_postbacks` fields
- [ ] Connect a real Page and see a message arrive
- [ ] Connect a real Instagram account and see a message arrive
- [ ] Business verification
- [ ] App review for the messaging permissions

Until the last two are done, only accounts belonging to the app's own
developers can connect. No real seller can use the product.

## 4. Connecting an account

- [ ] Agree the connection flow (proposed in `STATUS.md`)
- [ ] `meta-oauth` function: start the flow, carrying `state`
- [ ] `meta-oauth` callback: exchange the code server-side, store the token
- [ ] "You can close this window" page for the browser
- [ ] Desktop app notices the new account through Realtime
- [ ] Connecting a second account works
- [ ] Disconnecting an account works

## 5. Sending replies

- [ ] `send-message` function
- [ ] Refuses clearly when the reply window has closed
- [ ] Stores the outbound message with the id Meta returns
- [ ] The echo of our own reply creates no duplicate
- [ ] Failures reach the client with a useful reason

## 6. The application

- [ ] Flutter Windows build running
- [ ] Localisation set up, with no hardcoded strings
- [ ] Arabic and English, with right-to-left layout
- [ ] Message bubbles take direction from their own text, not the interface
- [ ] Sign in and sign out
- [ ] Connect an account, from the seller's point of view
- [ ] Conversation list
- [ ] Platform visible per conversation
- [ ] Unread state visible
- [ ] Waiting time visible
- [ ] Open a conversation and read its history
- [ ] Reply
- [ ] Composer reflects the reply window before the seller types
- [ ] New messages arrive live
- [ ] Attachments displayed
- [ ] Local notification and taskbar badge
- [ ] Empty states, loading states, and what happens when offline

Six UI principles were proposed and are not yet agreed. A mockup was offered
and not yet made. Sorting by who has waited longest, rather than newest first,
is a real product decision still open.

## 7. Release

- [ ] Windows installer
- [ ] Code signing certificate, which costs money annually
- [ ] Installing on a machine that has never seen the app
- [ ] How updates reach sellers

Unsigned applications show "Windows protected your PC" on first run. For an
audience being asked to connect their business accounts, that is a trust
problem rather than a cosmetic one.

---

## Decisions still open

- Which Meta app type and use case Phase One needs
- Multiple Instagram accounts or Pages per seller
- Whether Phase One links the same customer across channels — proposed no, and
  close to settled, since Meta's customer ids are scoped to the account
- Western or Eastern Arabic numerals
- Attachment media: stored or fetched on view
- The UI principles and the sorting question above

---

## Done when

A seller can comfortably manage their Instagram and Facebook Messenger
conversations from one place, without switching between separate applications.

That is the only goal for Phase One.
