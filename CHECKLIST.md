# Phase One checklist

Everything needed for a seller to manage Instagram and Facebook Messenger
conversations from one place. Nothing beyond that belongs here — see the out of
scope list in `CLAUDE.md`.

A box is ticked only when the thing has been run and seen to work, not when the
code exists. Where something was verified, it says how.

Updated 18 September 2026.

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

- [x] Understand Meta's use cases model
- [x] Decide which use case and permissions Phase One needs — Facebook Login
      for Business, Instagram reached through the linked Page. `DECISIONS.md`.
- [x] Register the webhook callback URL — against both the Page and Instagram
      objects, same verify token
- [x] Subscribe to the `messages` and `messaging_postbacks` fields
- [x] Connect a real Page and see a message arrive — 15 September, end to end
- [ ] Connect a real Instagram account and see a message arrive
- [ ] Business verification
- [ ] App review for the messaging permissions

Until the last two are done, only accounts belonging to the app's own
developers can connect. No real seller can use the product.

## 4. Connecting an account

- [x] Agree the connection flow — settled 17 September, and made much simpler
      by the move to a web application. See `STATUS.md`.
- [x] `meta-oauth` function: start the flow, carrying `state`
- [x] `meta-oauth` callback: exchange the code server-side, store the token
- [x] `/me/subscribed_apps` called once the token is stored
- [x] Return origin validated against an allowlist before redirecting back —
      18 September. The state carries an index into the allowlist rather than
      an origin, so a destination cannot be expressed at all. Proven against
      the deployed function: a state signed with the real app secret naming
      index 1 or 99 is rejected, while index 0 passes.
- [ ] Browser lands back in the application, signed in and carrying on — the
      redirect is written and deployed; not yet run through a real Meta login
- [ ] Connecting a second account works
- [ ] Disconnecting an account works

The allowlist item was not housekeeping. `meta-oauth` redirects the browser
after handling an access token, and a destination taken from the request would
make it an open redirect on the most sensitive endpoint we have. It is closed:
the destination is looked up, never read.

## 5. Sending replies

- [x] `send-message` function — deployed 18 September, and a real reply sent
      to the test Page's customer and accepted by Meta
- [x] Refuses clearly when the reply window has closed — proven live against
      the deployed function: a conversation whose window closed seven days ago
      is refused `window_closed`, and one where the customer has never written
      is refused `no_window`, which is a different thing and says so
- [x] Stores the outbound message with the id Meta returns
- [x] The echo of our own reply creates no duplicate — both echoes arrived
      from Meta and were processed, and the messages table still holds each
      reply once. The unique `mid` and the webhook's existing
      `ignoreDuplicates` do it; no new code was needed.
- [x] Failures reach the client with a useful reason — as a code, never a
      sentence, so the interface picks the language. `empty`, `too_long`,
      `window_closed`, `no_window`, `not_found`, `disconnected`, `rejected`,
      `unreachable`.
- [ ] The interface can actually send one — the composer is still a notice

Arabic was verified through the whole path: a reply of
`مرحبا، سعر iPhone 15 Pro هو 1200 دولار؟` was sent, and Meta's echo of it came
back byte for byte, Arabic question mark and Western digits intact.

An expired access token is recorded on the account as `needs_reconnect` when
Meta reports code 190, which is the only warning a seller would otherwise get
that their inbox has gone quiet for a reason. That covers the sending path
only; the receiving path in section 2 is still uncovered.

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
- [ ] Almarai loading in Flutter web, subset to weights 300 and 700 only —
      it renders, but through `google_fonts`, which fetches from Google's CDN
      at runtime. That is neither bundled nor subset: it is a third-party
      request on every cold load, and the Arabic interface shows a fallback
      face until it lands. Not the same thing as done.
- [x] Localisation set up, with no hardcoded strings — Arabic is the source
      file, English the translation. A test scans the Arabic file for Eastern
      numerals, which caught one two spot-checks had missed.
- [x] Arabic and English, with right-to-left layout — verified in a browser in
      both languages, at desktop and phone width
- [x] Message bubbles take direction from their own text, not the interface
- [x] Sign in and sign out
- [ ] Connect an account, from the seller's point of view — still a URL pasted
      by hand with the workspace id in it
- [x] Two-pane layout: conversation list beside the open conversation
- [x] Conversation list: awaiting a reply first, longest wait at the top, then
      answered conversations newest first
- [x] The divider between the two groups says what it means in plain language
      — and is hidden when either group is empty, because a heading with
      nothing under it reads as a section that failed to load
- [ ] Index on `(workspace_id, last_inbound_at)` for the list query
- [x] Platform visible per conversation, as a mark rather than interface tinting
- [x] Unread state visible
- [x] Waiting time visible — the wait rail, and a countdown on the composer
- [x] Open a conversation and read its history
- [ ] Reply
- [x] Composer reflects the reply window before the seller types — it states
      the window and says replying is not built, rather than offering a box
      that would fail
- [ ] New messages arrive live
- [x] Attachments displayed — verified against the real image delivered by Meta
- [ ] In-page notification and title badge while the tab is open
- [ ] Empty states, loading states, and what happens when offline — the first
      two are built and seen; offline is not handled at all
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
