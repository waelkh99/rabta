# Phase One checklist

Everything needed for a seller to manage Instagram and Facebook Messenger
conversations from one place. Nothing beyond that belongs here — see the out of
scope list in `CLAUDE.md`.

A box is ticked only when the thing has been run and seen to work, not when the
code exists. Where something was verified, it says how.

Updated 17 September 2026.

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

Verified by 56 local tests and 13 checks against the live database, seeding
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
- [x] A message with no text no longer renders as a blank row —
      `last_message_type` on `conversations`, set by the trigger, client renders
      the label. Six tests, each shown to fail against the old trigger.
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

- [x] Agree the connection flow — settled 17 September, and made much simpler
      by the move to a web application. See `STATUS.md`.
- [ ] `meta-oauth` function: start the flow, carrying `state`
- [ ] `meta-oauth` callback: exchange the code server-side, store the token
- [ ] `/me/subscribed_apps` called once the token is stored
- [ ] Return origin validated against an allowlist before redirecting back
- [ ] Browser lands back in the application, signed in and carrying on
- [ ] Connecting a second account works
- [ ] Disconnecting an account works

The allowlist item is not housekeeping. `meta-oauth` redirects the browser
after handling an access token, and a destination taken from the request makes
it an open redirect on the most sensitive endpoint we have.

## 5. Sending replies

- [ ] `send-message` function
- [ ] Refuses clearly when the reply window has closed
- [ ] Stores the outbound message with the id Meta returns
- [ ] The echo of our own reply creates no duplicate
- [ ] Failures reach the client with a useful reason

## 6. The application

- [x] Flutter web build running — `flutter build web --release` verified on
      17 September with Flutter 3.47.4. Toolchain only; there is no interface.
- [x] Arabic and right-to-left proven on the web renderer — shaping, bidi,
      U+061F, Eastern numerals and per-message direction all rendered correctly
      in Chrome on 17 September, using the real Arabic message from the
      fixtures. Static render only; typing, selection and screen readers are
      not covered.
- [x] An Arabic font with proper glyphs chosen — Almarai, covering Arabic and
      Latin from one family, at 300 for previews and 700 for names. Picked on
      measured width against Cairo and Alexandria, not on style.
- [ ] Almarai loading in Flutter web, subset to weights 300 and 700 only
- [ ] Localisation set up, with no hardcoded strings
- [ ] Arabic and English, with right-to-left layout
- [x] Message bubbles take direction from their own text, not the interface
- [ ] Sign in and sign out
- [ ] Connect an account, from the seller's point of view
- [x] Two-pane layout: conversation list beside the open conversation
- [x] Conversation list: awaiting a reply first, longest wait at the top, then
      answered conversations newest first
- [ ] The divider between the two groups says what it means in plain language
- [ ] Index on `(workspace_id, last_inbound_at)` for the list query
- [x] Platform visible per conversation, as a mark rather than interface tinting
- [ ] Unread state visible
- [ ] Waiting time visible
- [ ] Open a conversation and read its history
- [ ] Reply
- [ ] Composer reflects the reply window before the seller types
- [ ] New messages arrive live
- [ ] Attachments displayed
- [ ] In-page notification and title badge while the tab is open
- [ ] Empty states, loading states, and what happens when offline
- [ ] First load is measured again once there is a real interface

Layout, sort order, typeface and numerals were settled on 17 September — see
`DECISIONS.md`. Six interface principles and a palette are proposed in
`STATUS.md` and not yet agreed. No mockup has been made.

## 7. Release

- [ ] Somewhere to host the built site, and a domain
- [ ] The application's origin added to the `meta-oauth` allowlist
- [ ] Opening the deployed site on a machine that has never seen it
- [ ] How a new version reaches sellers

Shipping a website removed the installer, the code signing certificate and the
"Windows protected your PC" warning from Phase One entirely. What is left is
hosting, which is smaller work than what it replaced. Updates become a deploy,
though a seller with the tab open still needs to reload to get one.

---

## Decisions still open

- Which Meta app type and use case Phase One needs
- Multiple Instagram accounts or Pages per seller
- Whether Phase One links the same customer across channels — proposed no, and
  close to settled, since Meta's customer ids are scoped to the account
- Attachment media: stored or fetched on view
- Where the site is hosted, and on what domain
- The six interface principles and the palette proposed in `STATUS.md`

---

## Done when

A seller can comfortably manage their Instagram and Facebook Messenger
conversations from one place, without switching between separate applications.

That is the only goal for Phase One.
