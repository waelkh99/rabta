# Phase One checklist

Everything needed for a seller to manage Instagram and Facebook Messenger
conversations from one place. Nothing beyond that belongs here — see the out of
scope list in `CLAUDE.md`.

A box is ticked only when the thing has been run and seen to work, not when the
code exists. Where something was verified, it says how.

**The Phase Two checklist is at the end of this file.** Nothing in it is built.

Updated 19 September 2026.

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

Verified by 126 backend tests and 13 checks against the live database, seeding
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
- [x] Customer name and picture fetched from Meta — one Graph call per
      customer, not per message. Proven live: the deployed webhook filled in a
      real name and picture, and a redelivery did not ask again.
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
- [x] Connecting a second account works — the same button, from the Accounts
      screen. The callback upserts and sets the account active again.
- [x] Disconnecting an account works — verified in a browser against a
      throwaway account: it asks first, says the conversations survive, then
      unsubscribes from Meta, deletes the token and marks the account off. The
      two real accounts kept their tokens and the conversation survived.
      Deliberately not a delete: `connected_accounts` cascades to every
      conversation and message the seller has ever had.

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
- [x] The interface can actually send one — a reply typed into the browser
      reached the customer, and Meta echoed it back

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
- [x] Connect an account, from the seller's point of view — a Connect button
      in the interface. A seller with nothing connected sees only that; one
      with accounts finds it under Accounts in the header. Verified in a
      browser: it leaves for Meta's approval page in the same tab, carrying
      the config id and a state signed with the workspace from the seller's
      own session. Completing it needs a real Facebook login.
- [x] Public sign-up turned off — verified 18 September: `/auth/v1/settings`
      reports `disable_signup: true` and a real attempt returns 422
      `signup_disabled`.
- [x] Accounts created by invitation, so a seller sets their own password —
      `npm run invite -- them@example.com`. Walked end to end: the link lands
      on a choose-a-password screen, and the seller can then sign out and sign
      back in with what they chose.
- [x] Inviting from inside the product, for admins only — a screen that
      creates the account and hands back the link. Verified in a browser: an
      admin sees it, a seller does not, and a seller's own token is refused by
      the server with `not_admin` even when the request is made by hand.
- [ ] Custom SMTP, so invitations actually arrive — **deferred deliberately**,
      see `DECISIONS.md`. Supabase's built-in sender is rate limited and not
      for production. Until then the link is handed over rather than emailed,
      which the invite screen says. Close this before the first paying
      customer.
- [ ] Site URL set to the application's origin — still `http://localhost:3000`,
      the Supabase default, which is where any link falls back to
- [ ] Password reset, so a forgotten password is not a support message — the
      screen that a reset link lands on is built and the routing handles
      `type=recovery`; what is missing is the button that sends the email
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
- [x] Reply — typed in the browser, sent, echoed back by Meta. Enter sends,
      Shift+Enter breaks the line, and the box keeps a reply that failed.
- [x] Composer reflects the reply window before the seller types — a countdown
      under the box while it is open, and a plain sentence instead of a box
      once it has closed
- [x] New messages arrive live — proven in a browser: a delivery to the
      webhook moved the conversation into the waiting group, with the unread
      dot, the wait rail and the countdown, without a reload
- [x] Customers are named, not all called "Customer"

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
- [ ] The application's origin added to `_shared/origins.ts` — one list now
      serves both the OAuth return and the CORS check
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

---
---

# Phase Two checklist

The AI that answers customer inquiries the seller has not got to yet. Requested
19 September 2026, planned, and **not started**. See `CLAUDE.md` for the product
shape and `DECISIONS.md` for the settled decisions and their reasoning.

The same rule applies here and is worth restating because this phase is easier
to fake: **a box is ticked only when the thing has been run and seen to work.**
Not when the code exists, not when a test was written, and not when a model
appeared to behave once. Where something was verified, it says how.

## 8. Documentation and tooling

- [x] `CLAUDE.md` records Phase Two, and the out-of-scope lines it lifts
- [x] `DECISIONS.md` records every settled decision with its reasoning
- [x] `CHECKLIST.md` has this section
- [x] `STATUS.md` says Phase Two is planned and not built
- [x] The Edge Functions are typechecked — `npm test` runs `deno check` first,
      about a third of a second warm. Proven to catch a `Store` the fake does
      not implement, which `node --test` had been passing silently. It found
      two real defects in code written before Phase Two

## 9. Catalog

- [x] `products` table, with row level security proven against a second seller
      — 10 tests, and the policy predicate widened to `true` on purpose to
      confirm three of them fail when isolation breaks
- [x] `ai_settings`, defaulting to disabled, unreachable by another seller
- [x] Template download — **UTF-8 with a BOM**, or Arabic names arrive in Excel
      as mojibake and the seller concludes the app is broken. The template also
      reads back into exactly what it shows
- [x] Template import, including Arabic product names, a comma inside a quoted
      description, prices written "25,000" or "١٥٠٠٠" or with a currency
      beside them, Windows line endings, a deleted header row, and columns in a
      different order
- [x] Catalog renders byte-identically across repeated calls — the cache
      depends on it
- [x] Catalog reads and writes on the client, scoped by row level security
- [x] Prices hold fils — three decimal places, because the Jordanian dinar
      divides into 1000 and two would have rounded 12.750 away
- [x] A price written with the dinar beside it still parses — "د.ا" contains a
      dot, which broke the parser until it stopped stripping and started
      extracting

## 9b. The shop

- [x] `shop` and `delivery_zones`, with row level security proven against a
      second seller
- [x] Currency is stored, not assumed, and travels with every price the
      assistant quotes
- [x] Delivery zones with fees, and a free-text note for the rules a list
      cannot hold
- [x] A zone with no fee reads as "depends" rather than free
- [x] Locations, hours and a catch-all field, all free text and all optional
- [x] Everything the shop wrote reaches the model, and the same string is what
      the invented-number guard searches
- [x] Settings save one field at a time — two quick edits used to have the
      second silently undo the first
- [x] The screen driven in a real browser against the live database: zones
      added with and without a fee, Arabic text saved and read back
- [x] Products page: add, edit, delete — its own screen, reached from a side
      menu. Driven in a real browser against the live database: a product typed
      in with an Arabic name and the price written "25,000" saved, came back
      from Postgres, and unlocked the assistant switch
- [x] A side menu naming its destinations, replacing three unlabelled icons.
      Opens from the right in Arabic and the left in English
- [x] The page checked at phone width — reflows to one column, nothing clipped
- [x] The assistant switch writes and reads back, persisting as
      `enabled: true` in the database. The reserved/normal choice beside it is
      gone — see 10b

## 10. The AI reply path

- [x] `messages.origin` and the `conversations` AI columns — and proven that an
      AI reply moves the conversation summary exactly as the seller's own does,
      so the untouched trigger really is unaffected
- [x] The claim UPDATE run twice returns a row, then nothing — and a stale
      claim can be taken again, so a run that dies does not lock a conversation
      out of the AI forever. Confirmed to fail when the claim condition is
      removed
- [x] A customer's follow-up inside the claim window is answered, not
      swallowed. **This failed in production first**: the assistant answered a
      greeting and the next message 36 seconds later was dropped without a
      trace. Two regression tests, one at the SQL level and one through
      autoReply, both confirmed to fail against the old predicate
- [x] The pre-call guards, every branch, with a frozen clock — each guard
      removed on purpose to confirm a test fails without it
- [x] The grounding check: a reply containing a price not in the catalog is
      escalated, not sent. Also catches an invented delivery time, a price off
      by a digit, and Arabic-Indic numerals against a Western-digit catalog
- [x] The model call never throws — network failure, error status, unreadable
      body and garbled JSON are all outcomes
- [x] Over-length replies escalate rather than being rejected by Meta — a
      1,200 character reply on Instagram is held back
- [x] A second run for the same conversation calls the model zero times
- [x] Meta refusing the send after the model ran leaves the thread visible and
      writes no message row
- [x] Wired into the webhook background task, with the burst debounce — a
      customer's three fragments produce one reply, and the runs that wake to
      find a newer message stand down without claiming or spending anything
- [x] A redelivered message is not answered twice, and the echo of the AI's own
      reply is not answered at all
- [x] A workspace with the AI off, or no API key configured, spends nothing and
      marks nothing
- [x] The migration applied to the live project, and row level security proven
      there and not only in the test harness: an anonymous read of `products`
      returns `[]`, and an insert naming a real workspace is refused with
      `42501`
- [x] Deployed. A genuinely signed delivery to the live webhook returned 200,
      stored the Arabic text byte for byte, incremented unread, processed with
      no error, and left `ai_state` and `ai_last_run_at` null — the AI path
      correctly did nothing without a key
- [x] The cross-directory import of `send.ts` actually bundles — the deploy
      uploaded `send-message/send.ts` as part of `meta-webhook`
- [ ] `ANTHROPIC_API_KEY` configured, so the AI actually runs

## 10b. It sells, instead of answering when asked exactly the right thing

- [x] Every dead end now speaks. Mutating the hand-over line off fails five
      tests; the customer used to receive nothing on six separate paths
- [x] Answering and handing over are independent — the model can do both in one
      message, which the old shape could not express. Confirmed to fail when
      handing over is made to skip the send again
- [x] The hand-over line is said once and not on every message after it. The
      count itself is the flag, so `>=` in place of `===` fails two tests
- [x] The streak cap raised from 3 to 8 — three killed the conversation at the
      point the customer was closest to buying
- [x] An attachment-only message reaches the model as `[the customer sent a
      photo]` instead of being refused, and every attachment type Meta might
      send has a word for it
- [x] `assistant_caution` dropped from the schema, the client, the model and
      the tests. `flutter analyze` clean, 86 client tests passing
- [x] **Nine scripted conversations run against the real API**, transcripts
      read: a vague gift shopper, something the shop does not sell, an
      out-of-stock item, a budget under what they asked about, an English
      customer, Arabizi, a photo with no words, haggling, and someone who says
      they will think about it
- [x] Five defects found that way, each fixed and each now carrying a test that
      fails without the fix: an English customer answered in Arabic, Eastern
      Arabic numerals, the address switching gender mid-sentence, an invented
      "the price is fixed", and our own English placeholder deciding the
      language of the reply
- [x] The customer's language is decided by us and stated to the model rather
      than inferred by it — three of three in English against the same large
      Arabic catalog that had failed two of three
- [x] Haiku 4.5 and Sonnet 5 measured against each other on the same nine
      conversations, with real token usage priced per reply. Sonnet costs 8%
      more, not the 100% its rate implies, because Haiku cached nothing at all
      — the prefix sits between Sonnet's 1,024-token minimum and Haiku's 4,096
- [x] Sonnet 5 adopted. Thinking sent as `disabled` explicitly, because
      omitting it runs adaptive on Sonnet — confirmed to fail a test when the
      line is removed, which is exactly what a careless model swap does
- [x] Adaptive thinking measured too and rejected: 4% dearer, replies no better
- [x] The shipped default path called against the real API — model
      `claude-sonnet-5`, `thinking: {"type":"disabled"}`, a grounded reply back
- [ ] Re-run the comparison for a shop with a few hundred products, where the
      prefix clears 4,096 tokens, Haiku starts caching too and the gap returns
      to roughly 2x
- [x] Emoji decided: the safe ones only (🌸 🙏 ✨ 🙂 👋), at most one, at the
      end, and only on a reply with no digit and no question mark in it — a
      proxy for "this reply is not doing work". Asked of the model first and it
      did not comply, so it is enforced in `tidyEmoji` instead
- [x] Emoji are stripped rather than escalated, which is the one place a
      finished reply is edited. Confirmed to fail four tests when the tidy
      drops the safe one too
- [x] Claims with no digits in them are now checked the same way numbers are:
      a price policy, scarcity, a discount, a guarantee or a delivery time may
      appear only if the shop wrote it down or the customer raised it.
      Confirmed to fail when the check is removed, and again when it stops
      consulting what the shop actually wrote
- [x] The claim check measured against nine live conversations: fifteen
      replies, zero held back — no false positives, which was the real risk
- [ ] A fabricated sentence using none of the watched words still gets through.
      The upgrade is a second model call to check the first; not worth its cost
      and latency until a leak that matters is seen
- [x] A pleasantry gets the pleasantry back and nothing else. Reported from a
      real thread: "يغطيك العافية" was answered "نعم، عندنا فستان أحمر. إي مقاس
      بدّك؟". Reproduced against a live model before changing anything
- [x] A greeting no longer draws a list of what the shop sells — that rule was
      added on 20 September against a worry nobody raised, and it answered
      "كيفك؟" with a product list. A test asserts the wording is gone, not
      merely contradicted somewhere else
- [x] Suggesting is gated on the customer having said something, and the
      selling behaviour it gates is confirmed still working: a vague gift
      request, an out-of-stock item and a budget under the asking price all
      still draw a real answer
- [x] "نعم" and the other Modern Standard giveaways named specifically. The
      general dialect rule had been in the prompt since 19 September and the
      real reply opened with "نعم" anyway
- [x] English re-measured against a large all-Arabic shop after Arabic
      pleasantry replies entered the instructions — six of six in English
- [x] The claim check seen holding a real reply: "السعر عنا ثابت حسب ما بعرف",
      an invented price policy with no digits in it
- [x] Price is read out, never negotiated, never refused. Measured on seven
      ways of asking for a better price — all seven give the listed number and
      a gentle hand-over, none refused, none held back by either guard
- [x] No invented price policy in either direction: not "the price is fixed",
      not "there is no discount", and no discount offered by the assistant
- [x] The shop owner is never named or given a gender. It had written "صاحب
      المحل" and "صاحبة المحل" in one conversation; `HANDOVER_LINE` changed to
      "رح نرجعلك بأقرب وقت." to match
- [x] No third party anywhere. It speaks as the shop in the first person; the
      `handOver` flag is described to the model as ours and invisible to the
      customer, including in the JSON schema. A full run contains no "صاحب",
      no "صاحبة", no owner and no manager
- [x] No hedging about what is written down, and no answering a question then
      promising to go and check it
- [x] "حالياً ما في خصم على هالقطعة" rather than "مافي عندي معلومة عن خصم" —
      and the claim check changed to match: a negation is stripped before the
      watched patterns run, so ruling a sale out passes while claiming one
      still fails. Confirmed to fail when the exemption is removed
- [x] The watched list is patterns, not bare words. "ثابت" had caught "شي أنيق
      وثابت" — hard-wearing, about a handbag — and withheld a good reply.
      Confirmed to fail both ways when reverted to the bare word (the first
      attempt at that mutation silently did not apply; redone with a check
      that it had)
- [x] An upsell may not invent product qualities, with an escape hatch so the
      rule does not just push it to a different adjective
- [x] It no longer reasons in front of the customer mid-sentence
- [x] `unusable` carries a snippet of what came back and the webhook logs it.
      It happened once live and did not reproduce in three attempts
- [ ] Invented adjectives still leak occasionally — "وثابت أكتر" survived the
      final run. Not deterministically catchable without false positives that
      cost more than the leak
- [x] **Deployed 20 September, version 13.** Verify handshake returns the
      challenge on the right token and 403 on a wrong one
- [x] `npm run assistant` reads back what the assistant did in production —
      every conversation's `ai_state`, its escalation reason, and the messages
      with who wrote each. The CLI has no `functions logs`, and the rows are
      better evidence anyway
- [x] The customer's name reaches the model. It was in `conversations.
      customer_name` and had never been sent — the strongest signal for how to
      address someone in Arabic, one table away while the model guessed
- [x] Gender decided in a defined order: what the customer says about
      themselves, then their name, then the masculine default. Measured four
      ways against the real shop — a male name, a female name, a handle, and no
      name — all correct
- [x] The name may be used where the model judges it fits, once at most and not
      in every message, first name only, and only when it is plainly a personal
      name. A handle and an empty name both produced replies with no name
- [x] The two cache tests no longer locate the breakpoint by counting back from
      the end of the array — they assert by content instead. Adding a volatile
      block had broken them three times in one day
- [x] Deployed: version 15
- [x] `supabase db push` applied 21 September. The hold was unnecessary: there
      is no hosted client to break — `STATUS.md` says there is no origin to
      serve the site from. One row lost `assistant_caution = 'reserved'`, a
      setting the function had ignored since version 13
- [x] Web client rebuilt, and the bundle confirmed to contain no reference to
      the dropped column
- [x] A gap in a conversation is read from what the customer wrote, not from
      how long it lasted. A question nobody ever answered is answered late
      rather than never — measured on the exact live case, and confirmed not to
      be raised twice once it has been dealt with
- [x] **The six synthetic test rows are deleted from `messages`**, 21
      September. Deleting them in Messenger would not have done it, and that
      was checked rather than assumed: Meta sends a deletion event and
      `parse.ts` skips it, so nothing removes a row already stored. Confirmed
      afterwards that none of them was the newest message in its conversation,
      so the inbox summary and unread counts were untouched. The shop now has
      no voice examples at all until real seller replies accumulate
- [ ] ~~Clear the synthetic test messages out of the seller's own thread.~~
      `aiPrompt` takes the shop's voice examples from outbound messages with
      origin 'seller', and five test replies from 18 September qualify —
      including "نعم، الشحن مجاني داخل المدينة." and one about an iPhone 15 Pro
      priced in dollars. They are teaching the assistant its tone
- [ ] Decide what to do with a question the customer asked before the last
      shop reply and never got an answer to. "شفت عندكم فستان" sat unanswered
      from 19 September, and the pleasantry on 20 September was answered with
      it. The triage now returns the ritual and stops, which is right for the
      pleasantry and leaves the older question unanswered forever
- [ ] Run against a real customer on a real account. Everything above is a
      scripted conversation; the send path itself is still unproven end to end
      (Meta's window has never opened for a real reply — see 10)

## 11. The seller sees what happened

- [x] An AI message is distinguishable from the seller's own at a glance, and
      does not use `accent` — teal, measured at 5.22:1 for its text in light
      and 9.96:1 in dark, and confirmed by reading the rendered pixels in a
      browser rather than by eye
- [x] The distinction does not rest on colour alone — every automatic reply
      also says so in words, in both languages
- [x] Seen working in a real browser against the live database, in Arabic and
      English, at desktop and phone width
- [ ] An AI-answered conversation is visibly marked in the list, and stays
      reviewable
- [ ] Escalated conversations stay in the waiting group with a reason
- [ ] Browser notification and title badge
- [ ] Arabic and English for every new string, Western numerals only
- [ ] Draft on open, for escalated threads

## 12. Proven against reality — **blocked**

None of this can be run yet: there is no Anthropic API key on the machine.
These are not optional, and none of them may be inferred from the code.

- [x] A real Arabic conversation answered in the customer's dialect, not
      Modern Standard Arabic — "اكيد بنوصل إربد، التوصيل 3.5 د.ا"
- [x] Arabizi — Arabic written in Latin letters — answered in proper Arabic
      script, in the same dialect: "2adesh se3r el shanta?" → "الشنطة بـ 18
      دينار ومتوفرة هلق"
- [x] A real message from Facebook answered and delivered to the customer —
      "مرحبا" at 11:01:29, replied at 11:02:09 with a Meta-issued mid, so Meta
      accepted and sent it. The echo came back without duplicating
- [x] Holds a conversation and hands over in the right place — six turns
      carried on the careful setting, handed to the seller on "طيب امتى بيوصل؟"
      because no delivery time is written anywhere
- [x] A greeting is answered with a greeting, not a price list
- [x] Token usage logged per reply, so cache hits and cost are visible without
      waiting for an invoice
- [x] No terms of endearment, against a seller whose every example reply used
      one — 0 of 9 replies, including a bare greeting and a thank-you, which
      are the cases most likely to draw one out
- [x] A customer writing actual English gets English — "The red dress is 25.5
      dinars." This needed the shop.s Arabic example replies to be withheld
      from an English conversation; no wording of the language rule was enough
      on its own
- [x] `cache_read_input_tokens` non-zero on a second call with a prefix over
      4096 tokens — a 220-product shop wrote 12,930 tokens on the first call
      and read all 12,930 back on the second, leaving 37 uncached
- [x] A prefix under 4096 tokens confirmed to write nothing rather than
      charging for a cache entry it did not create — a five-product shop
      reported write 0, read 0 on both calls. This is what justifies marking
      unconditionally instead of measuring the prefix first
- [x] Delivery answered from the zones, and an unpriced zone escalated instead
      of a number being invented
- [x] Haggling escalated; an out-of-stock product answered honestly
- [x] Measured cost: **$0.0013 per reply** on a small shop — about **$2.50 per
      seller per month** at 1,900 replies, against the $7 estimated in
      `DECISIONS.md`. The estimate assumed a much larger prompt than a real
      small shop has
- [x] A real signed delivery reached the deployed webhook, passed every guard,
      called the model, and was escalated when **Meta refused the send with
      `window_closed`** — no message row written for something the customer
      never received. The designed failure path, seen working in production
- [ ] Token expiry on the receiving path, and the seller notification that
      tells them an escalated conversation is waiting

## Phase Two is done when

A seller can go to bed with unanswered customers and wake up to find the easy
ones answered in their own voice, the hard ones waiting with a reason, and
nothing sent that they would be embarrassed by.
