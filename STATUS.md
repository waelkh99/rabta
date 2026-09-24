# Where we are

Updated 25 September 2026.

What is built, what is live, and what comes next. `CLAUDE.md` holds the product
direction, `DECISIONS.md` the settled decisions and why, `CHECKLIST.md` the
progress, and `WEBHOOKS.md` the webhook service specification.

**In one paragraph.** Phase One is functionally complete as a product: a seller
signs in, connects their Meta accounts, reads their Instagram and Messenger
conversations in one inbox, and replies — with messages arriving live and
customers named. What is left is mostly not code. The Meta app is still in
development mode, so nobody outside its own roles can connect at all, and
Instagram has never been verified against a real delivery. There is nowhere to
host the site yet. Those are the critical path. **Phase Two — an AI that
answers basic inquiries from the seller's catalog — was requested on
19 September and is live on the test account: a real customer message has been
answered and delivered. As of 22 September the seller can also see what it did:
the inbox marks what the assistant answered and what it handed back, the
details pane carries the assistant's own reason in its own words, and the tab
title and a system notification say when something needs them. On
22–23 September products gained photos, codes, categories and spreadsheet
import; offers got their own screen; the assistant sends product photos,
recognises a customer's screenshot, and understands offers written in the
seller's own words. A hand-over is now impossible to miss, and there is no
longer any limit on how many times in a row the assistant answers.**

---

## Live right now

Supabase project `xejtffbpfguwvybrwqqj`. Eighteen migrations applied, four Edge
Functions deployed.

| Function | What it does | Auth |
|---|---|---|
| `meta-webhook` | receives deliveries from Meta | HMAC signature, no JWT |
| `meta-oauth` | `/start`, `/callback`, `/disconnect`, `/check` | seller's JWT, except the callback |
| `send-message` | sends a reply | seller's JWT |
| `admin-invite` | creates an account | seller's JWT, admins only |

```
https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-webhook
https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-oauth/callback
```

The second is the **OAuth redirect** registered in the Meta dashboard. The
webhook callback is registered separately, under the Webhooks configuration,
against both the **Page** and **Instagram** objects with the same verify token.

`META_APP_SECRET` and `META_VERIFY_TOKEN` are set on the functions. Public
sign-up is off: `/auth/v1/settings` reports `disable_signup: true`.

**475 backend tests** (`cd supabase && npm test`, which typechecks every Edge
Function with `deno check` first; about ten seconds, no Docker and no network)
and **247 client tests** (`flutter test`). Each new piece of
logic is shown to fail when deliberately broken rather than assumed to be
covered.

---

## What works, end to end

Everything here has been run against the live project and seen to work, not
inferred from the code.

**Messages arrive.** Signature verified over the raw bytes, the raw payload
stored before anything is done with it, a fast 200 and processing afterwards.
Redelivery is idempotent. Echoes of the seller's own replies are stored as
outbound and clear the unread state. Four real deliveries are captured as
fixtures in `tests/parse.test.ts` with their ids untouched.

**Accounts connect.** The seller presses Connect, approves on Meta's screen,
and the callback exchanges the code, stores the token, subscribes the account
to the webhook and sends the browser back. Turning an account off stops new
messages without deleting its history.

**Replies send.** A reply typed in the browser reaches the customer, and Meta's
echo of it comes back and does not appear twice. Arabic survives the round trip
byte for byte, including U+061F and Western digits inside a right-to-left
sentence.

**The inbox updates live.** Realtime is used as a signal, never as a source of
data: on any change the list is read again through the ordinary query, so
everything on screen has passed row level security exactly as it would on a
reload.

**Customers have names and faces.** Meta sends only an opaque id with a
message, so the profile is fetched once per customer rather than once per
message.

**Accounts are created by invitation.** There is no public sign-up. An admin
invites someone; they choose their own password from the link, so it is never
ours and never travels through a chat.

**The interface.** Sign-in, the two-group conversation list with search, the
thread, the composer, the details pane, the accounts screen, the invite
screen, the products, offers and shop screens, and Results. In the thread
header: how the conversation ended, and the switch that takes it over from the
assistant. Arabic and
English throughout, Arabic as the source language and the fallback. Verified in
a browser in both languages, at desktop and phone width.

---

## Not built, and known gaps

- **Publishing the Meta app.** It is in development mode, so Meta only delivers
  from accounts holding a role on it. **This blocks everything else**: no real
  seller can connect, and Instagram cannot be verified. Calendar time.
- **Hosting.** There is no origin to serve the site from. Once there is one it
  goes in `supabase/functions/_shared/origins.ts`, the single list serving both
  the OAuth return and the CORS checks.
- **Site URL is still `http://localhost:3000`**, the Supabase default. Any auth
  link whose redirect is not on the allowlist falls back to it.
- **Custom SMTP — deferred deliberately.** Supabase's built-in sender is rate
  limited and not for production, so invitations can fail to arrive exactly
  when someone is waiting. Until then the invite screen hands over a link
  rather than emailing it, and says so. **Close this before the first paying
  customer.**
- **Sending a password reset** — a *forgotten* password, which is a different
  thing from changing one. A seller who is signed in can change theirs on the
  shop screen since 22 September, and that needs no email. A seller who cannot
  get in needs a link sent to them: the screen it lands on is built and the
  routing handles `type=recovery`, but the button that sends the email is not,
  and is useless until SMTP exists.
- **Attachments are shown from Meta's URLs**, which expire after about 30 days.
  Whether to copy them into storage is still open.
- **The font is fetched, not bundled.** Almarai renders through `google_fonts`,
  which pulls from Google's CDN at runtime, so every cold load makes a
  third-party request and shows a fallback face until it lands.
- **Notifications reach an open tab only.** Inside it a hand-over is loud
  since 23 September — a red pill on the row, a red banner in the thread, and
  a bell counting them. A background tab is covered; a
  closed browser is not, and on an iPhone a Safari tab cannot show one at all
  until the seller adds Rabta to their home screen. `DECISIONS.md`, "Telling
  the seller something happened", has the whole picture.
- **Instagram, verified against a real delivery.** See below.

---

## What needs you, not code

**All of it is in `LAUNCH.md`**, in order, with why each matters and what to
hand back. In short: a production Supabase project on Pro in Frankfurt (the
current one is in Tokyo with no backups), a domain and hosting, SMTP, filling
in and reviewing the privacy and data-deletion pages, Meta business
verification and App Review, a spend-limited Anthropic key, and a pilot.

## Running the service: the Admin screen

Since 25 September 2026 the owner runs the service from inside the app, not a
terminal. **Menu → Admin** (admins only, enforced in the database by
`is_admin()` / `admin_overview()`) shows:

- **Health** — last delivery from Meta, messages not yet processed, failing and
  given-up events, accounts needing reconnection, errors and warnings in the
  last 24 hours, errors on sellers' screens, and the assistant's cost and calls
  this month. Green when nothing needs attention, red with a list when it does.
- **Every seller** — email, admin badge, connected accounts and their status,
  conversations, messages this week, last message and sign-in, products,
  assistant on/off, assistant replies and cost this month, hand-overs waiting,
  orders this month.
- **Recent events** from `ops_log` and **errors on sellers' screens** from
  `client_errors`.
- **Invite a seller** from its top bar.

Where it comes from: every function writes important events to `ops_log`
(`functions/_shared/log.ts`), every model call's tokens and cost to `ai_usage`,
and the app reports uncaught errors to `client_errors` (`lib/reporting.dart`).
Processed raw deliveries are pruned after 30 days and logs after 90
(`prune_old_records`, run after each delivery).

An admin with no connected accounts of their own lands on this screen instead
of the inbox, with the language, sign-out and a link to Accounts.

**Admins:** `wal.kh.saleh99@gmail.com` (the product owner) only. Grant or
revoke with `npm run admin -- email [--revoke]`. A forgotten password, until
SMTP exists: `npm run signin -- email --password` prints a choose-a-password
link.

Supabase advisors on the live project are clean except three, all expected:
`is_admin` and `admin_overview` are callable by signed-in users (each refuses
non-admins inside, tested and proven live), and leaked-password protection
needs the Pro plan.

---

## Test data in the live database

Deliberately kept, so a message sent to the test Page flows straight through
without setting anything up again.

- auth user `webhook-test@rabta.local`, password `rabta-dev-2026`. Written down
  because it is otherwise unrecoverable, and because it owns nothing but this
  test data.

  **It must never be an admin.** That password is in this repository and in its
  history, so an admin flag on it would hand account creation to anyone who can
  read the repo. It was briefly an admin on 18 September while the invite
  screen was tested, and was revoked afterwards. There are currently **no
  admins**. Grant one to a real account whose password is not written down
  here: `npm run admin -- you@example.com`.

- its workspace, `0c839c31-4a49-485b-a9f9-b2e4af479b8b`
- `connected_accounts` for the Facebook Page `1427711713749572` ("Rabta App")
  and the Instagram account `17841401424316998` (`djangus_w`), both connected
  through `meta-oauth` and both active
- one product (`فستان أحمر`, 25.500), a `shop` row with the assistant
  **enabled**, `price_stance` at its default `notify`, a delivery note and an
  address, and two delivery zones (عمّان 2.500, العقبة with no fee). The
  `assistant_caution` setting this used to mention was dropped from the schema
  on 21 September. **Not inert:** `ANTHROPIC_API_KEY` is set on the functions,
  so this workspace answers messages sent to the test Page
- one conversation with the customer `28847995138118550` ("Wael K. Saleh"), its
  messages, and the raw events behind them. Read live by the outcome reader on
  24 September as "didn't buy, never answered", which is right
- **dummy catalog, seeded 23 September:** ten products with codes `T-001` to
  `T-010`, photos, four categories (فساتين، حقائب، عطور، إكسسوارات) and four
  offers. The assistant answers from it, so a message to the test Page gets
  real prices, photos and offers. Remove it with
  `cd supabase && npm run seed-demo -- remove`, which deletes the `T-`
  products, their photos, the four offers and any category left empty. The
  original `فستان أحمر` (`P-001`) is not touched
- a second seller, **`playwright-seller@example.test`**, workspace
  `b7e924a6-0f36-49ef-9cc7-9643a44a1ba8`, used to drive the screens in
  Playwright without touching the Page's own shop. No password; sign in with
  `cd supabase && npm run signin -- playwright-seller@example.test` and open
  the link it prints (`npm run invite` refuses an account that already
  exists). It holds eight products, four offers and a fake conversation with
  "سارة" whose photo links now fail to load; the outcome reader has marked it
  "didn't buy". Its Instagram account `playwright-placeholder-not-a-meta-id`
  is fake but **active**, so the outcome reader does read its conversations —
  a fraction of a cent each. Nothing from Meta reaches it

None of it is real seller data. Clear it whenever it stops being useful — but
removing a `connected_accounts` row sends later deliveries back to being stored
and skipped as `unknown-account`.

---

## What Meta does that its documentation does not say

All found by running the real flow. Each one would have shipped as a bug.

**`/me/accounts` returns an empty array under Facebook Login for Business**,
even when the Page was explicitly granted. `debug_token` on the same token
reports the Page id under `granular_scopes.target_ids` for every `pages_*`
scope. The documented way to list a seller's Pages therefore says they have
none, which is indistinguishable from a seller who genuinely has none.
`meta-oauth` reads the granted ids from `debug_token` instead.

**`instagram_business_account` on a Page requires `instagram_basic`.** Without
it the field is simply absent rather than erroring, so the documented way to
find a seller's Instagram account silently returns nothing. The Instagram ids
are in `granular_scopes` too.

**Graph API Explorer can no longer issue Page tokens for this app.** Explorer
sends no `config_id`, so the login falls through to an ordinary user login with
no asset-selection step and returns a user token every time. Not a
misconfiguration — the OAuth flow is now the only way to obtain a Page token.

**Subscribing fields in the dashboard is not enough.** Each account must also
be subscribed through `POST /{id}/subscribed_apps`, which needs
`pages_manage_metadata`. Miss it and the webhook verifies cleanly and then
never fires. `meta-oauth` does it immediately after the token exchange.

**The "Authorize callback URL" field is the OAuth redirect, not the webhook
callback.** Putting the webhook URL there looks correct and silently does
nothing.

**The "Native or desktop app?" toggle stays off.** It tells Meta the client
cannot keep a secret; ours never sees one.

**Profile picture and attachment URLs last about 30 days** and are fetchable
with no access token. Measured 15 and 18 September.

**Facebook Login for Business configuration id: `1063344539629710`.** Not a
secret — it appears in the login URL the browser is sent to. Without a
`config_id` the dialog has no asset-selection step at all.

---

## Instagram: configured, not verified

Everything checkable is correct, and **no Instagram message has ever reached
the webhook.**

Confirmed: the account is Professional and linked; Meta reports
`instagram_business_account` as `17841401424316998` on the Page; it was granted
on the asset screen and is stored with its token; the Page's subscription is
`messages, messaging_postbacks, message_echoes`; **Connected tools → Allow
access to messages** is on in the Instagram app — account-side, off by default,
invisible from the app dashboard, and something a seller will have to be walked
through; direct messages reach the Page's inbox in Meta Business Suite; and the
function handles `object: "instagram"` end to end, proven by replaying a signed
delivery on 17 September.

The blocker is development mode. Meta only delivers from accounts holding a
role on the app, and Instagram has no role that fits: the Instagram Tester role
resolves against a Facebook-linked identity, and a standalone Instagram account
has none, so Meta rejects it with "does not resolve to a valid user id".

**The first thing to check once the app is published**, before anything is
built on top:

```
entry.id == 17841401424316998   the Instagram account id, which is what we store
entry.id == 1427711713749572    the Page id, which would mean every Instagram
                                message is stored and then skipped as
                                belonging to an unknown account
```

Meta's documentation says the first. Nothing has confirmed it for this app.

---

## Phase Two: the backend is live, the screens are not

Requested by the product owner on 19 September 2026, after Phase One was
functionally complete. An AI answers basic customer inquiries — price,
availability, basic product facts — from the seller's own product catalog, and
escalates everything else to the seller. The goal is that no customer inquiry
goes unanswered.

**Live now, and answering real customers.** The migrations are applied
(`products`, `shop`, `delivery_zones`, `messages.origin`, the `conversations`
AI columns) and `meta-webhook` is deployed at **version 16**. Both
`ANTHROPIC_API_KEY` and `ANTHROPIC_WORKSPACE_ID` are set on the functions, so
the assistant is on and has answered genuine messages.

**The model is `claude-sonnet-5`**, with `thinking` sent as `disabled`
explicitly — omitting it runs adaptive thinking on Sonnet, which a bare model
swap would have started paying for silently. Measured at roughly **$4-7 per
seller per month** at 1,900 replies, against Haiku 4.5's $6.44: the sticker
price is 2x and the bill is not, because Sonnet caches a prefix from 1,024
tokens and Haiku only from 4,096, so a real small shop's prompt cached nothing
at all on Haiku.

**The assistant was rewritten on 20 September**, after the product owner's
verdict that it was "a robotic answering machine". It now sells rather than
answering only exact questions, never goes silent, reads what kind of message
it is before replying, states prices without negotiating or hedging, addresses
the customer in the right Arabic gender, and may use their first name. Every
step of that is in `DECISIONS.md` with what was measured against the live
model, including what it got wrong on the way.

**Every migration is applied**, including `20260920000001_assistant.sql`, which
drops `shop.assistant_caution` — a setting the function had ignored since
version 13. It was held back for a day in case a deployed web build still
selected that column; there is no deployed web build, which this document has
said all along under Hosting. The client was rebuilt and its bundle confirmed
free of any reference to the dropped column.

Verified against the live project rather than inferred: an anonymous read of
`products` returns `[]` and an anonymous insert naming a real workspace is
refused with `42501`; a genuinely signed delivery returned 200, stored its
Arabic byte for byte, incremented unread, processed with no error, and left the
AI columns null.

**Built and seen working in a browser:** the products screen and a separate
shop screen — currency, delivery zones and rules, locations, hours and a
catch-all field — both reached from a side menu that replaced three unlabelled
header icons; the catalog paste import; and the teal treatment that tells an
assistant message from the seller's own.

**Built on 21 and 22 September, and seen in a browser rather than inferred.**
Under a rule added to `CLAUDE.md` on 21 September, nothing that affects the
interface is ticked on unit tests alone: it is driven with Playwright in both
languages and at desktop and phone width, and looked at.

- **An escalated conversation stays in the waiting group, with a reason.** This
  closed a live defect rather than adding a feature. The assistant usually
  speaks when it hands a conversation back, and that line is an outbound
  message — so the conversation's last message was no longer the customer's and
  it filed itself under "Answered". A customer the assistant had explicitly
  said it could not help sat in the group the seller had finished reading.
- **Nothing cleared `ai_state`.** The column comment had claimed since
  19 September that it was cleared when the seller opened the conversation. No
  code anywhere did that. It is now cleared in the `touch_conversation`
  trigger, on the seller's own outbound message — so a reply typed in Messenger
  clears it too, which a client-side write would not have.
- **The reason is the assistant's own sentence** where the assistant is the one
  who handed over, written in the language of the conversation and shown as
  written. Every other escalation carries a short code the interface localises.
  The row says what happened; the details pane says why.
- **The tab title counts** — `(3) Rabta` — and a **system notification** fires
  when a customer writes or the assistant hands a conversation back, with a
  switch in the menu that goes both ways.

**Built 24 September, seen in a browser:** opening a conversation marks it
read; search; a banner when an account stops receiving (found by
`meta-oauth/check` as the inbox opens); a retry for events that failed
processing; a per-conversation "I'll handle this one" switch; and a card that
saves the seller's answer to a hand-over into the shop's information.
`DECISIONS.md` has the reasoning. Draft-on-open stays dropped.

**Built 24–25 September, seen in a browser: how conversations end.** Each
settled conversation is read by the assistant as ordered, didn't buy (with a
reason), or just asking; the seller corrects it from the thread header; a
Results screen shows the last seven days. See `CHECKLIST.md` section 13.

**How to see what it did.** The Supabase CLI has no `functions logs`, and the
rows are better evidence anyway. From `supabase/`: `npm run assistant` for what
the assistant did and why, `npm run catalog` for everything it is allowed to
know — the answer to "did it make that up?" — and `npm run replay` to replay a
conversation against the real catalog and the real voice examples without
sending anything to Meta. `npm run live` runs nine scripted Jordanian
conversations against the real model and prices each reply; it costs money,
which is why it is not part of `npm test`.

**The shop currently has no voice examples at all.** The six it had been
learning from were synthetic test replies left in the seller's own thread —
"test 33", an iPhone priced in dollars, a row of question marks — and they were
deleted from `messages` on 21 September. Deleting them in Messenger would not
have done it: Meta sends a deletion event and `parse.ts` skips it, so nothing
removes a row already stored. Until real seller replies accumulate, the
assistant writes from its instructions alone.

**One customer question is still unanswered on purpose.** "شفت عندكم فستان",
asked on 19 September, was never replied to. Since version 16 that is handled
rather than lost: the next time that customer writes, the assistant answers
whatever they say and adds one short line picking the old question up, then
never raises it again. The live thread is the test case for it.

**The test workspace now has the assistant switched on**, with one product in
it, plus a shop with delivery zones and an address. Nothing happens while there is no API key — a
missing key means the AI is off — but the moment one is set on the functions,
that workspace will start answering messages sent to the test Page. That is
what we want for the first real test; it is written down so it is not a
surprise.

`CLAUDE.md` describes the product shape, `DECISIONS.md` holds the settled
decisions with their reasoning, and `CHECKLIST.md` sections 8–12 track it.

The decisions most easily lost, repeated here because they cost money or
correctness:

- **`claude-sonnet-5`**, with `thinking` sent as `disabled` explicitly.
  Measured at about $0.0013 a reply on a real small shop. Haiku 4.5 was
  replaced on 20 September: its sticker price is half, its bill is not, because
  a small shop's prompt sits between Sonnet's 1,024-token cache minimum and
  Haiku's 4,096 and so cached nothing at all on Haiku.
- **The cache marker is always set, with the 1-hour TTL** — not the 5-minute
  default. Below the model's minimum cacheable prefix it is a free no-op, so
  there is no length check. Without caching at all, a seller with a large catalog costs
  $21/month and the subscription price stops working. Watch
  `cache_read_input_tokens`: zero across repeated calls means the prefix is
  being invalidated and the bill will look like that $21.
- **No pg_cron and no pg_net.** A `create extension` line in a migration kills
  all 126 existing tests, because the PGlite harness executes every migration.
- **A conditional UPDATE is the concurrency guard**, because double-sending the
  same sentence to a customer cannot be repaired afterwards.

**The assistant is armed and measured.** `ANTHROPIC_API_KEY` and
`ANTHROPIC_WORKSPACE_ID` are set on the functions. The key is
organisation-level rather than workspace-scoped, which is why the workspace has
to be named on every request; a scoped key would not need it.

Measured against the real API, not estimated:

- **Jordanian dialect holds on Haiku 4.5.** "اكيد بنوصل إربد، التوصيل 3.5 د.ا",
  not Modern Standard Arabic. The model tier is no longer a hypothesis.
- **Arabizi is mirrored** — "2adesh se3r el shanta?" is answered in Latin
  letters. This failed on the first run and needed the case named explicitly
  with a worked example.
- **Caching works, and the unconditional marker is free.** A 220-product shop
  wrote 12,930 tokens then read all of them back; a five-product shop wrote and
  read nothing at all.
- **Cost is about $0.0013 a reply**, roughly **$2.50 per seller per month** at
  1,900 replies — well under the $7 estimated, because a real small shop's
  prompt is far smaller than the estimate assumed.

**A real customer message has been answered end to end.** "مرحبا" arrived from
Facebook at 11:01:29 and the assistant replied at 11:02:09 — 40 seconds, the
debounce plus processing — with a Meta-issued message id, meaning Meta accepted
and delivered it. The echo came back without duplicating.

It holds a conversation rather than answering one question and stopping: six
turns carried on the careful setting, then handed to the seller on "طيب امتى
بيوصل؟" because no delivery time is written down anywhere. A greeting gets a
greeting.

**Built 22–23 September, seen in a browser and against the real model.**

- **Products:** up to five photos each (shrunk in the browser, stored in the
  public `product-photos` bucket with a 320px thumbnail), a product code
  generated as `P-001` when the seller has none, optional categories that can
  be renamed and deleted, and a free-text details box for sizes and colours.
  Import reads the seller's own sheet (.xlsx or .csv, whatever the headers)
  and updates by code, never by name; the catalog downloads as a sheet.
- **Offers (العروض):** percentage, amount, buy X get Y, or written in the
  seller's own words; whole shop, categories or products; optional dates.
  Sale prices are computed in code in both TypeScript and Dart from one shared
  fixture, never by the model. The assistant mentions an offer only when the
  customer is interested, once, and never pushes.
- **Photos to and from customers:** the assistant sends a product's photo
  after its text, and hands over with `no_photo` naming the product when asked
  for one that does not exist. A screenshot from a customer is matched against
  the thumbnails. Seen arriving on the product owner's phone on 23 September.
- **No limit on replies in a row.** The streak cap stopped a live customer and
  was removed; the monthly ceiling is the only count left.
- **Hand-overs are loud:** red pill and ground on the row, first in the
  waiting group, a red banner in the thread at every width, and a bell with a
  count and a list.

`meta-webhook` has been redeployed with all of it.

**Unverified and potentially blocking:** Meta's disclosure requirements for
automated experiences have not been checked against current policy.

---

## Next

1. Business verification and App Review, then publish the app.
2. Capture a real Instagram delivery and check `entry.id` against the value
   stored for the account.
3. Decide where the site is hosted, add that origin to
   `functions/_shared/origins.ts`, and set Site URL to match. This also
   unblocks Web Push, which needs a real HTTPS origin.
4. Custom SMTP, then the button that emails a forgotten-password link. Changing
   a password while signed in already works and needs none of this.

Nothing above is code, and nothing in Phase Two is waiting on code. The
product-side work that is genuinely next, in the order it makes sense:

5. ~~**The sales and discounts section.**~~ **Done 22–23 September** — the
   offers screen, structured and in the seller's own words. See `CHECKLIST.md`.
6. ~~**Expanding what a product can say.**~~ **Done 22–23 September** —
   photos, codes, categories, a details box, spreadsheet import and download.
7. **Web Push**, once there is hosting — the only way a hand-over reaches a
   seller whose browser is closed, which is the 11pm case Phase Two exists for.
8. **The screenshot quirk.** With no match for a customer's screenshot, the
   model offers the nearest item even when it is out of stock. Truthful, not
   ideal.
9. **Watch the first real week of outcomes.** Accuracy was measured on 32
   scripted conversations and one real one. The Results screen says how often
   the seller corrected the assistant; that number, on a real shop, is the
   measurement that counts.
10. **Decide what `notify` should mean.** It currently does what the assistant
   already did — answers, marks, hands over. Left open deliberately until
   there is a real case to watch.

---

## Open questions

Carried from `DECISIONS.md`:

- Can one seller connect more than one Instagram account or Page?
- Does Phase One link the same customer across channels? Proposed no, and close
  to settled: Meta's customer ids are scoped to the account they wrote to, so
  there is no supported way to connect them.
- Attachment media: stored or fetched on view.
- Where the site is hosted, and on what domain.
- How a conversation near the end of its reply window is marked in the list.

Phase Two:

- What Meta requires us to disclose about automated replies. Unchecked, and the
  one question that could block the feature outright.
- ~~How an AI-sent message is shown in the thread.~~ **Settled.** Teal, never
  `accent`, and it says "automatic reply" in words as well — colour is not the
  only signal.
- Whether a fact can leak out of a seller's own past reply. One did: a delivery
  time was lifted from an exemplar and sent as a promise. It carries no digits,
  so the grounding check cannot see it.
- ~~Whether escalation should cover a customer who is clearly upset.~~
  **Settled 20 September: yes**, and it costs nothing now that handing over no
  longer means silence.
- ~~Whether the details pane should appear below 1180px.~~ **Settled
  22 September:** it does not, and the same card is shown at the top of the
  thread instead whenever the pane is not on screen. The pane keeps its
  breakpoint, so the thread is never squeezed to buy room for one card.
- ~~Whether a pricing setting should let the seller choose between the
  assistant handing price negotiation back and it holding the listed price as
  final.~~ **Built 22 September** as two named modes, strict and notify, and
  measured both ways against the real model. Sales and discounts, the other
  half `CLAUDE.md` promised, is still open — and when it lands the assistant
  reads it the same way, so the stance keeps deciding only what happens after
  it has said what it knows.
- What "notify" should mean in practice. It currently marks the conversation
  and hands it to the seller, which is what the assistant already did. Whether
  that is the right shape is a question about how the case actually goes in a
  real shop, and is deliberately left until there is one to watch.
