# Next — new name and WhatsApp

Started 6 October 2026. Spans many sessions: **read this first, tick items as
they finish, and add a dated line under "Log" at the end of each session.**
Big-company features are deliberately not here; the owner will report back
after meeting the buyers.

## Next session — start here

**Where things stand (16 November):** production runs HEAD at
https://inboxara.app, functions and web both deployed. WhatsApp's App Review
(Tech Provider) is **approved** and "Connect WhatsApp" is live; a real number
end to end was skipped by the owner — watch the first seller's. **All three
webhooks now point at production** (Messenger and Instagram moved 16 Nov).
The first real Instagram DM arrived and was answered on 16 Nov.

**Waiting on Meta — the Instagram/Messenger App Review, submitted 17 November**
(seven permissions; WhatsApp's two renewed alongside; "most within 20 days").
What was sent is in `docs/APP-REVIEW-MESSAGING.md`. If Meta asks a question or
rejects, read it with the owner before replying. Likeliest question: a tester
account — the owner chose not to give one (a second personal Facebook account
in their own name was refused and would break Facebook's one-account rule);
the texts offer to add the reviewer's own account as a Tester.

**After the decision, in order:**
1. ~~Build fix (a)~~ **Built 17 Nov:** migration
   `20261117000001_account_moves_conversations.sql` (a trigger), 5 tests in
   `tests/account-move.test.ts` shown failing without it; 540 backend pass.
   **Not yet pushed** to staging or production — `supabase db push`, owner runs.
2. Remove "Manage comments" (`instagram_manage_comments`) from login
   configuration 1063344539629710 — it still appears on Meta's permission
   screen though it is not used or requested.
3. Change the demo shop's password (it went to Meta's reviewers) and its
   `demo@rabta.chat` login.
4. On approval: a DM from an account with no role on the app, end to end.

**Supabase free plan pauses idle projects** (owner had to restore them, 17 Nov).
`.github/workflows/keep-alive.yml` asks both projects for a row once a day and
fails — GitHub emails — if either does not answer. Secrets added by the owner
and the first run passed for both projects (17 Nov, run 44173056651). The repo is public, so GitHub turns the schedule
off after 60 days without commits; Supabase Pro (no pausing, daily backups) is
the real fix, the owner's call.

Production working notes for a session: `RABTA_ENV=prod npm run events --
instagram` shows deliveries; production deploys are run by the owner (the
command line needs `SUPABASE_ACCESS_TOKEN` from `.env.prod`); the browser
for Playwright is headed, and the owner signs in to it.

**Can be done meanwhile, owner decides the order:**
- **Second App Review — Instagram and Messenger:** corrected 16 Nov against
  Meta's Messenger Platform overview — the Facebook Login route (DECISIONS,
  15 Sept) needs `pages_show_list`, `pages_manage_metadata`, `pages_messaging`,
  `pages_read_engagement`, `business_management` (a dependency of
  `pages_messaging`, to be said so in the review), `instagram_basic`,
  `instagram_manage_messages`. The `instagram_business_*` names that stood here
  are Instagram Login's, which this app does not use. Webhook moved and unused
  permissions removed (16 Nov); `ads_management` stays, required by the use
  case — never submit it.
- **2FA** for the business portfolio's admins.
- ~~Two pending invitations with full access to the business portfolio, to
  `@tmpbox.net` addresses.~~ Revoked by the owner, 16 Nov.
- Smaller: the demo login is still `demo@rabta.chat`; no Terms of Service page
  (the field was cleared); production backups wait for the first customer
  (owner, 28 Oct); `docs/name-options.pdf` and `docs/hub-name-options.pdf` are
  untracked.

The items below are the history behind this.

1. **Blocked — the "Connect WhatsApp" button cannot work yet** (found
   11 October). Meta's Embedded Signup docs: "You must already be a Solution
   Partner or Tech Provider" — so the "WhatsApp Embedded Signup" login
   variation does not appear in this app's Configurations. Tech Provider needs
   Business Verification: the same blocker as Instagram. Also, Embedded Signup
   v4 launches only through the JavaScript SDK (`FB.login` with the
   config_id); the redirect flow built on 7 October would need reworking when
   this unblocks. Hidden at the owner's request (11 October): `_whatsappSignup = false`
   in `lib/pages/accounts_page.dart`; flip it back when this unblocks. The
   server path (`meta-oauth/start?kind=whatsapp`) stays deployed.
   - On the buyer-owns-the-app route the button is not needed: their numbers
     are connected once, as the test number was (`npm run connect-whatsapp`).
2. (Kept for when it unblocks) Configuration: Facebook Login for Business →
   Configurations → Create configuration (or "Create from template" → WhatsApp
   Embedded Signup), variation WhatsApp Embedded Signup; then
   `supabase secrets set META_WHATSAPP_CONFIG_ID=<id>` and test. A brand-new
   number also needs `POST /{phone}/register` with a PIN — a product decision.
3. **Then Track A — the naming brief.** Nothing done yet.
4. **Decided 20–21 October: route (b), register a business.** Registered as
   مؤسسة وائل خالد صالح للبرمجة الحاسوبية (no. 625413, 20/10/2026); Meta
   Business Verification submitted 21 October, "In review" (about two working
   days). When it passes: Access Verification, then App Review (LAUNCH.md
   step 5), then item 2 above. Settle the new name before App Review.
   Buyer-meeting outcomes will change priorities; ask before building
   anything for bigger companies.

Working notes: staging is `xejtffbpfguwvybrwqqj` (the CLI is linked to it);
WhatsApp test values are in `supabase/.env` (`WHATSAPP_*`);
`npm run events -- whatsapp_business_account` shows WhatsApp deliveries;
`ops_log` is where the functions write what they refused. Driving the app in
Playwright: `flutter build web --dart-define-from-file=env.json`, serve
`build/web` on port 5353, `npm run signin -- <email>` for a link, then click
the "Enable accessibility" placeholder (Flutter's canvas has no DOM until
then). After resizing the browser, wait a few seconds before a screenshot.

## Status

- [x] Step 0 — plan in the repo, pointed to from CLAUDE.md
- [x] A — naming brief: superseded, the owner chose Inboxara (26 Oct); options PDFs from 11 Oct
- [x] A — owner picks a name: **Inboxara** (26 Oct)
- [x] A — rename what users see (26 Oct; seen in Playwright) — domain, icon and support mailbox wait on the owner
- [x] B — owner added WhatsApp to the Meta app; test number +1 555-633-5647, IDs and a never-expiring system-user token in `supabase/.env` (checked against Graph 6 Oct); staging webhook verified for WhatsApp
- [x] B1 — migration, parse, send, media, UI three-way switches, prompts (unit-tested)
- [x] B1 — connect-whatsapp script, end to end on staging with the test number (receive, reply, photo, stop, reconnect)
- [x] B1 — seen in Playwright (both languages, both widths)
- [x] B2 — "Connect WhatsApp" button built and deployed to staging (Embedded Signup via the OAuth dialog, same callback, `business_account_id` stored) — **seen** reaching the server, which answers `not_configured`
- [ ] B2 — end to end: **blocked** on Tech Provider status (Business Verification), found 11 Oct; button hidden meanwhile (11 Oct)
- [x] Owner decision — production access route: (b), business registered 20 Oct, Meta Business Verification submitted 21 Oct
- [x] Docs — docs/DECISIONS.md, CLAUDE.md, docs/CHECKLIST.md (section 15), docs/LAUNCH.md header — 7 Oct

## Log

- 2026-10-06 — plan written and approved.
- 2026-10-06 — B1 started: `parse.ts` reads WhatsApp messages, media (by id),
  and Coexistence echoes; 5 tests. Not yet: migration, media download,
  profile name, send, UI, prompts. Inbound WhatsApp would currently fail at
  `findAccount` (enum lacks 'whatsapp') — harmless until a number is subscribed.
- 2026-10-06 — repo reorganized at the owner's request: docs into `docs/`,
  `lib/` into `pages/`, `widgets/`, `services/`. Imports rewritten; analyzer
  clean, 266 Flutter + 480 backend tests pass, `flutter build web` compiles.

---

## Context

Rabta was paused on 27 Sept because Instagram needs Meta Business Verification. There are now
potential buyers, so work resumes. Two tracks run in parallel. Big-company features wait until the
owner reports back from the buyer meetings.

1. **A new name.** People say "Rabta" doesn't sound like a product. The owner prefers a name that
   says what the app does, even if it's plain.
2. **WhatsApp** as a third channel.

Two facts from research change the picture:

- **The 14 Sept reason for deferring WhatsApp is out of date.** Meta's *Coexistence* (2025) lets one
  number run on the WhatsApp Business app and the Cloud API at the same time, with up to 6 months
  of chat history synced. Sellers no longer have to give up the app.
- **WhatsApp has the same blocker Instagram had.** To connect *other companies'* numbers, Rabta has
  to be a Meta **Tech Provider**, which means Business Verification, then App Review, then Access
  Verification. Coexistence also only works through a Tech Provider.
  - Building and testing on Meta's free **test number** in development mode needs none of that.

CLAUDE.md already calls the AI work "Phase Two". This work goes in a new section rather than
renaming Phase Two.

---

## Track A — Name research (no code until a name is chosen)

The deliverable is a short naming brief, published as a doc the owner can share. It contains:

- **Criteria:** the name
  - says what it does (inbox / customers / replies);
  - works when said aloud in Arabic and in English;
  - is easy to spell after hearing it;
  - has no unfortunate meaning in Levantine Arabic;
  - doesn't sound like a small-shop tool.
- **15–25 candidates** in three groups:
  - descriptive (the owner's preference);
  - Arabic words that read well in Latin letters;
  - compound or short names.
- **Checks actually run on each shortlisted name:**
  - `.com`, `.app` and `.chat` availability;
  - products with the same name in the same space;
  - the Jordan trademark registry, where it can be searched online;
  - App Store and Play Store collisions;
  - free Instagram and Facebook handles.
- **A top 3**, with a recommendation and the reasoning behind it.

### After a name is chosen (a separate step)

Rename only what users see:

- about 6–9 l10n strings per language;
- `lib/widgets/wordmark.dart` and the title in `lib/main.dart`;
- `web/index.html`, `web/manifest.json`, `web/privacy.html`, `web/data-deletion.html`;
- `supabase/scripts/email-templates.mjs` and `web/alerts_sw.js`;
- the OAuth error text in `meta-oauth/index.ts`;
- the new domain: `_shared/origins.ts`, the Cloudflare project, and the Supabase Site URL and SMTP;
- the Meta app's display name and policy URLs.

**Not renamed:** package names, `RabtaColors`, `rabta_admin` and the Supabase project. Users never
see them, and renaming them only adds risk.

---

## Track B — WhatsApp, built on a Meta test number

**Owner setup (about 15 minutes):** add the "WhatsApp" product to the existing Meta app. That gives
a test number, a temporary token and a WABA id. Hand back:

- the phone_number_id;
- the WABA id;
- a permanent system-user token.

### B1. Receive and reply (the core)

- **Migration:** `alter type platform add value 'whatsapp'`.
  - `connected_accounts.external_id` holds the `phone_number_id`.
  - `customer_external_id` holds the `wa_id`, which is the customer's phone number.
- **`meta-webhook/parse.ts`:** a new branch for `object: "whatsapp_business_account"`, mapped to the
  same parsed-message type so `process.ts` stays unchanged. How the payload differs from Messenger:
  - messages sit in `entry[].changes[].value`, with `metadata.phone_number_id`,
    `contacts[].profile.name` and `messages[]`;
  - timestamps are in seconds, not milliseconds;
  - `type` can be text, image, video, audio, document, sticker or location;
  - `statuses[]` is ignored for now.
  - This replaces the existing "skip whatsapp" test (`supabase/tests/parse.test.ts:174`).
- **Customer name:** taken from `contacts[].profile.name`. WhatsApp has no profile API, so for
  WhatsApp `profile.ts` returns the name from the payload.
- **Media:** WhatsApp sends a media *id*, not a URL, and downloading it needs the token. The webhook
  calls `GET /{media-id}` for the URL, fetches the file, and stores it in the Supabase storage
  bucket the app already uses.
- **`send-message/send.ts`:**
  - `sendRequest` gains the WhatsApp request shape: `POST /{phone_number_id}/messages` with
    `{messaging_product:"whatsapp", to, type:"text", text:{body}}`, or
    `{type:"image", image:{link}}` for an image;
  - `TEXT_LIMIT.whatsapp = 4096`;
  - `refusalFor` maps WhatsApp's window error (131047) to `window_closed`.
- **24h window:** WhatsApp has the same rule, so the DB trigger already handles it.
- **Templates are not built.** WhatsApp only allows messages outside the 24h window as paid,
  pre-approved templates.
- **Fix the binary fallbacks** that would silently show WhatsApp as Messenger. Each one becomes a
  three-way switch:
  - `platform_icon.dart`, which also needs a WhatsApp painter;
  - `theme.dart`: `platform()` and the colour fields;
  - `strings.dart`: `platformName()`;
  - the default in `data.dart:182`;
  - `profile.ts`.
  - `platformWhatsApp` is added to both arb files.
- **AI prompts:** the platform names in `ai.ts:679` and `outcome.ts:62` either list all three or
  are dropped.
- **Connecting the test number:** a script, `supabase/scripts/connect-whatsapp.mjs`, inserts the
  `connected_accounts` and `account_tokens` rows and subscribes the app to the WABA. The spike
  needs no UI for this.

### B2. Self-connect through Embedded Signup (after B1 works)

- A second Facebook Login for Business config, with the WhatsApp scopes.
- A new `meta-oauth` route, `start-whatsapp`. Its callback:
  - receives `waba_id` and `phone_number_id`;
  - exchanges the code;
  - calls `POST /{waba}/subscribed_apps`.
- With Coexistence, it also subscribes to `smb_message_echoes` and history, so replies the seller
  sends from their phone appear in Rabta as echoes.
- The Accounts page gets a "Connect WhatsApp" button next to "Connect with Meta".
- In development mode this only works for people with a role on the app. Production use waits on
  the decision below.

---

## Decision the owner needs to make (raise it, don't block on it)

**The production access route for WhatsApp and Instagram:**

- **(a) The buyer owns the Meta app.** Their verified business creates it, and we deploy for them.
- **(b) The owner registers a business**, and Rabta becomes a Tech Provider.

B1 doesn't depend on this.

## Docs to update when building

- `docs/DECISIONS.md`: amend the 14 Sept WhatsApp entry (Coexistence now exists) and note the change.
- `CLAUDE.md`: add a WhatsApp section and take WhatsApp off Future Vision.
- `docs/CHECKLIST.md`: add a section for B1 and B2.
- `docs/LAUNCH.md`: the header no longer says "paused".

## Verification

**Unit tests**, each shown failing against the old code first:

- `cd supabase; npm test`:
  - new `parse.test.ts` cases built from real WhatsApp payloads: text, image, an unknown type, and
    statuses only;
  - `send.test.ts`: the WhatsApp request shape and the 131047 refusal;
  - `profile.test.ts`.
- `flutter test` covers the three-way platform switches.

**End to end**, deployed to staging:

1. Message the test number from a real phone.
2. The conversation appears with the WhatsApp badge and the customer's name.
3. A photo sent from the phone renders.
4. A reply sent from Rabta arrives on the phone.
5. The AI answers a price question from the demo catalog (`npm run replay`).

**Playwright** (standing rule):

- the inbox row, conversation view and details panel for a WhatsApp conversation, and the Accounts
  page;
- in Arabic and English, at desktop and phone width.

**Naming brief:** every availability claim comes from a check that was actually run, with its
source linked.
- 2026-10-06 — B1 code done, not deployed: migration `20261006000001_whatsapp.sql`
  (enum value + public `customer-media` bucket), WhatsApp send shape and
  131047, media downloaded with the token into `customer-media`, name from the
  payload, three-way platform switches + WhatsApp mark + strings, prompts name
  WhatsApp, `npm run connect-whatsapp -- <email>`. 488 backend + 270 Flutter
  tests pass; each new test shown failing first. Deploy to staging was held for
  the owner's permission: `supabase db push`, then
  `supabase functions deploy meta-webhook send-message`, then the connect script.
- 2026-10-07 — Deployed to staging (db push, meta-webhook + send-message,
  connect script for wal.kh.saleh99@gmail.com). A real WhatsApp message from
  the owner's phone arrived, stored as a WhatsApp conversation named "Wael",
  window open. Seen in Playwright: inbox row, thread, details pane, in English
  and Arabic at 1366 and at 390 wide. Not yet seen: a photo, a reply sent from
  Rabta, the Accounts page. Note: `npm run events` needs
  `-- whatsapp_business_account` to show WhatsApp deliveries.
- 2026-10-07 — A reply sent from Rabta arrived on the owner's phone. Platform
  marks replaced at the owner's request: the hand-drawn painters became the
  brands' own glyphs (Simple Icons, CC0) through flutter_svg; details pane
  centres the mark on its value. Seen in Playwright: WhatsApp in the list,
  thread and details, English and Arabic, 1366 and 390; Instagram and
  Messenger on the sign-in page. Still not seen: a customer photo, the
  Accounts page.
- 2026-10-07 — A customer photo arrived, was downloaded into `customer-media`
  and stored with its URL, but the bubble showed only the caption: it drew
  text OR attachment, and WhatsApp puts a caption on the photo's own message.
  Fixed (`MessageBody` shows the photo, then the caption); widget test shown
  failing with the old branch. Seen in Playwright, English desktop and Arabic
  phone. Still not seen: the Accounts page.
- 2026-10-07 — Stopping a link: the owner asked that a stopped link leave the
  Accounts page. It now does (only there — the inbox still counts it, so
  stopping every link does not swap the past for the first-run screen). Found
  on the way: Meta refuses `DELETE /{phone_number_id}/subscribed_apps`
  (code 100), so a stopped WhatsApp number kept receiving; the webhook's
  `findAccount` now skips disconnected accounts. Cycle tested on staging:
  stop in the app → row gone → a message sent was delivered (event 62) and
  ignored → reconnect script → row back, receiving. Unsubscribing the WABA
  properly needs its id stored, which B2 will do.
- 2026-10-07 — Accounts page seen in Arabic (desktop). B1 is done.
- 2026-10-07 — Account names keep their own direction (the test number read
  "(+1555-…" in Arabic). "Connect WhatsApp" button: `meta-oauth/start?kind=
  whatsapp` opens the WhatsApp config; the callback connects every number of
  every granted business account and subscribes it; Stop unsubscribes the
  business account when it is the last running number on it. New
  `assets.ts` + 4 tests (shown failing without the WhatsApp branch);
  migration `20261007000001_business_account.sql` pushed to staging;
  connect script backfilled the test number. Seen: Accounts page in Arabic
  desktop and English phone with both buttons; pressing Connect WhatsApp
  reaches the server (503 `not_configured`) and shows the failure message.
  271 Flutter + 492 backend tests pass. Session ended here.
- 2026-10-11 — The owner found no WhatsApp option in Configurations. Cause:
  Embedded Signup requires Tech Provider status (Meta's implementation docs),
  and v4 is JS-SDK only. B2 blocked with the production decision; proposed
  hiding the button. Docs: developers.facebook.com/docs/whatsapp/embedded-signup/implementation
- 2026-10-11 — Owner agreed: "Connect WhatsApp" hidden behind
  `_whatsappSignup = false`. Seen in Playwright: Accounts page shows only
  "Connect with Meta", English and Arabic, 1366 and 390. 271 Flutter tests pass.
- 2026-10-11 — Track A: owner asked for a PDF of names with objective pros
  and cons, no recommendation: `docs/name-options.pdf` (30 names). Checked:
  .com/.app/.chat by registry RDAP, App Store (JO+US) and Play, web search
  for same-space products. Ruled out by same-space products: Jawab, Wared,
  Mersal, ReplyDesk, Replyo; near: Radd (Radad AI), Zboon (Zbooni, Jordan).
  Not checked: Instagram/Facebook handles (sign-in wall), Jordan trademark
  register (no public online search found). Owner picks next.
- 2026-10-11 — Owner likes "Hub": `docs/hub-name-options.pdf` (18 names, same
  checks). Same-space conflicts: ChatHub, ConvoHub, MessageHub, JawabHub.
  None found: InboxHub, DMHub, HiwarHub, AhlanHub, Mehwar (Arabic for hub).
- 2026-10-11 — "MetaHub" checked and advised against: Meta's trademark page
  forbids using "Meta" as part of a company/product/domain name without
  permission, and the product needs Meta's App Review. All three domains taken.
- 2026-10-21 — Route (b) taken: business registered (مؤسسة وائل خالد صالح
  للبرمجة الحاسوبية, commercial registration 625413). Meta Business
  Verification submitted with use case "App requires access to permissions on
  Meta for Developers"; Arabic legal name accepted; "In review". Privacy page
  now names the registered business and address (both languages; seen in
  Playwright, Arabic at desktop, English at 390).
- 2026-10-21 — Meta rejected the phone proof (+962786548768): certificate
  "isn't an accepted type" (likely the skewed photo / Arabic-only text).
  Resubmitted as a clean PDF scan. If rejected again: an English copy of the
  certificate from MoITS, or a translation page, then a business bank letter
  showing the legal name and phone. Not a personal phone bill (wrong name).
- 2026-10-21 — Signed-out screens link "Privacy policy · Data deletion"
  (Arabic opens the pages' #ar half); test shown failing without the
  phone-width links; 272 tests pass. **Deployed to production** together with
  the privacy page, built from `bfb1ee3` (the 27 Sept production code) plus
  only these two changes, because production's database lacks the WhatsApp
  migrations: `tool\deploy.ps1` from HEAD would ship code that expects them.
  Seen live on rabta.chat: English at 1366, Arabic at 390, both links open
  their pages. Next production deploy must either be the same kind of
  patch or come with `supabase db push` to production first.
- 2026-10-22 — Criteria changed with the owner: the name no longer has to
  describe the product (feedback: Arabic words too formal, "inbox"/"DM" too
  narrow); no Levantine words; short .com is unaffordable, so .app/.chat/
  get…com matter. Owner likes **Nexira** (Latin nexus). Rechecked 22 Oct:
  nexira.chat, getnexira.com, usenexira.com free; nexira.com is Nexira SAS
  (French acacia-gum company, est. 1895); nexira.app registered Jan 2026.
  No software product named Nexira found. Not yet: name confirmed, domains
  bought, Jordan trademark search, Instagram/Facebook handles.
- 2026-10-22 — More Nexira-style names checked (Latin/Greek root + -ira).
  Clean on .app/.chat/get…com with no apps: Fonira (phōnē, voice),
  Kentira, Junira, Socira, Sermira. Closest in sound: Lexira (.chat and
  getlexira.com only). Owner to choose.
- 2026-10-22 — Owner rejected the made-up names (not catchy) and chose two
  styles: Arabic-rooted brand (Careem, Talabat) and two-word blend (HubSpot).
  Single everyday Arabic words are all taken by regional apps (Hader, Lahza,
  Tamam, Fawran, Mawjood; Rasayel is a WhatsApp inbox). Blends with every
  domain free incl. .com on 22 Oct: DallaHub, HaderHub, AhlanHub, RaddHub.
  Recommended DallaHub. Finjan is a Jordanian café-ordering app.
- 2026-10-22 — Owner's brief sharpened: professional (buyers are companies),
  open/uncrowded, not cliché; either fully abstract or fully literal.
  Real English words all taken. Abstract and open (.ai/.io/.app/…hq.com
  free, no apps, no company found): Teldan, Kerran, Kinsel, Kendel.
  Literal: CustomerThread and CustomerHall free on every domain incl .com;
  CustomerLine/Deck/Wire free except .com. Corran dropped (sounds like قرآن).
- 2026-10-22 — Owner likes **Kendel**. Checked: kendel.ai/.io/.app/.chat,
  kendelhq.com, getkendel.com, usekendel.com free; kendel.com listed for
  sale (registered 1999, price on request); kendel.co taken. Only app:
  "Kendel Driver" (Business, Afom bokre). No company using the name found
  (near: Kendox, Kendle — both document/retail software). Flagged: in
  Arabic script it is written like Kindle (كيندل). Not yet: owner's final
  call, domains bought, handles, Jordan trademark search.
- 2026-10-22 — Three more in Kendel's style, all free on .ai/.io/.app and
  …hq.com, no company found: Kenzel (.com unused), Tenzel (.com held by a
  premium-domain broker), Kentel (.com unused; one food app). Kestel also
  open (Turkish town; kestel.com a photo site).
- 2026-10-22 — Final four for the owner: Kendel, Teldan, Sorran,
  CustomerLine (all checked today). Recommended Teldan: one obvious way to
  say it in both languages. Owner to pick one.
- 2026-10-22 — CustomerLine shortened: "Cus-/Cust-" ruled out (sounds like a
  vulgar Arabic word). CXLine, LineCX, CustomerLine, BuyerLine, SaleLine all
  free on .ai/.io/.app/…hq.com (not .com), no apps, no product found.
  Recommended CXLine.
- 2026-10-26 — Owner: name settled as **Inboxara**; Meta Business
  Verification passed. Next per item 4: Access Verification, then App Review
  (rename first — App Review should see the final name). New work asked for:
  AI usage limits and plans; a seller-written workflow for the assistant,
  shown back as a diagram. Proposal and open questions sent to the owner;
  nothing built yet.
- 2026-10-26 — Renamed to Inboxara (strings, wordmark, web pages, emails,
  OAuth text); seen in Playwright, Arabic at 390 and 1366, English at 1366.
  Built plans (Basic 1,000 / Ultimate 5,000 replies) and the assistant guide
  (`guide` function, diagram page, `renderFacts`). 513 backend + 278 Flutter
  tests pass, new ones shown failing first. Not deployed, not seen: the
  Anthropic key is revoked everywhere we hold it, and staging deploy waits
  on the owner.
- 2026-10-26 — Owner put a new Anthropic key in `supabase/.env.local`
  (works; `.env` still holds the dead one). `npm run guide-eval` passed 12/12
  against the real model. Staging's secret is still the dead key.
- 2026-10-26 — With the owner's go-ahead: new Anthropic key on staging,
  migration pushed, `guide` and `meta-webhook` deployed. Seen on staging: the
  meter, an Arabic guide saved and drawn (English 1366, Arabic 390). Replay:
  guide followed for greeting and order details + hand-over; fixed a leak
  ("بحولك"); "ask before telling" ordering still not kept (owner to decide).
  **Production's key is dead too** (`6165252a…`, the old `.env.local` one);
  setting it was refused by the permission system — owner to run it.
  Admin plan switch unseen.
- 2026-10-26 — Owner set the new Anthropic key on production; digest checked
  (`a47116f1…`, matches `.env.prod`). Production's last AI reply was
  26 September and no AI call has been attempted since, so the dead key
  cost no customer an answer.
- 2026-10-26 — Owner: the guide gets priority. Guided shops now get thinking
  and a last reminder; order kept 7/7 in replay, narration once in 7.
  Deployed `meta-webhook` to staging. Production not deployed.
- 2026-10-26 — Guide page now says the seller's guide comes first, and the
  three things it cannot override. Widget test shown failing without it;
  seen in Playwright, Arabic at 390, English at 1366. Web app is not
  deployed anywhere yet (staging is served locally for Playwright).
- 2026-10-26 — The owner meant a writing tip, not the priority note: the
  guide page now says to write steps plainly and spell out what matters.
  Measured first: the plain "ask their size first" stopped the narration
  (0/8) but the assistant then said "available" 8/8 — it does what is
  written, nothing implied — so the tip says exactly that, not "plain
  wording works better". Seen in Arabic at 390. Open: on the guide page the
  text field's accessible name is the whole page (seen in the Playwright
  tree); an explicit Semantics label did not change it, so it was removed.
- 2026-10-28 — WhatsApp signup reworked to the JavaScript SDK. Owner decided:
  Coexistence without history, Inboxara sets a random PIN for new numbers, no
  templates. `meta-oauth/whatsapp` takes the code + session info, connects only
  granted business accounts, registers or starts the 24-hour sync; the old
  redirect branch is gone. Button behind `--dart-define=WHATSAPP_SIGNUP=true`.
  518 backend + 279 Flutter tests pass, new ones shown failing first. Seen in
  Playwright with Meta stood in for (English 1366, Arabic 390); "Connect with
  Meta" still reaches Facebook. `FB.login` refuses http pages, so the real
  window needs https. Not deployed: `meta-oauth` to staging waits on the owner.
- 2026-10-28 — Owner: start Access Verification right after the domain. Domains
  checked by registry RDAP: inboxara.com taken (registered 30 Jul 2025 at
  name.com, no site answering); inboxara.app/.ai/.io/.chat/.co,
  getinboxara.com, inboxarahq.com, useinboxara.com free. Owner to buy one.
- 2026-10-28 — inboxara.app bought (Cloudflare). Owner did: Pages custom
  domain (serves the 21 Oct production build, still titled "Rabta"), Email
  Routing support@inboxara.app → rabtaappsupport@gmail.com, Resend domain,
  Supabase production Site URL/redirects/SMTP sender. Checked by DNS: MX,
  SPF, Resend DKIM and send records match rabta.chat; **`_dmarc` TXT missing**.
  Code: inboxara.app first in `origins.ts` (test shown failing without it),
  email footer, legal pages now say support@inboxara.app (seen: English 1366,
  Arabic 390). None of it live until the production deploy.
- 2026-10-28 — **Production deployed from HEAD** (owner's go-ahead). One-off
  dump first: `C:\Users\User\Documents\inboxara-backups\prod-before-2026-10-28-deploy.dump`
  (pg_dump 18 via scoop; database only, storage files not included). Then
  `db push` of the three missing migrations (6, 7, 26 Oct), all five
  functions, email templates, `tool\deploy.ps1`. `.env.prod` APP_URL is now
  https://inboxara.app. Checked: webhook verify 403 on a wrong token, oauth
  callback 400 without state, send-message answers CORS for inboxara.app.
  Seen on inboxara.app: admin page with plans (English 1366), demo shop inbox,
  conversation, shop and guide pages (Arabic 390, English 1366), privacy page
  with WhatsApp and support@inboxara.app. Not done: the Meta webhook still
  points at staging, and the Meta app's domain/policy URLs still name
  rabta.chat — owner's dashboard steps, next.
- 2026-10-28 — **Access Verification no longer exists** (Meta's page: "no longer
  required"). Tech Provider = Business Verification (approved) + App Review for
  advanced `whatsapp_business_messaging` and `whatsapp_business_management`,
  from Use cases → WhatsApp → Customize → Tech Provider onboarding. The "In
  review" there is the owner's unsent draft. WhatsApp webhook moved to
  production (Messenger/Instagram still on staging); test number connected to
  the demo shop on production (`WHATSAPP_*` copied into `.env.prod`). A message
  from the owner's phone was answered by the assistant with the bag's photo on
  production. Videos recorded and checked frame by frame (Desktop,
  recording-1.mp4 send/receive 38 s, recording-2.mp4 template 95 s). Meta app
  Basic settings: inboxara.app domain, policy URLs, support email, icon,
  category; display name → Inboxara; ToS URL (was facebook.com) cleared;
  Website platform added; JS SDK domain inboxara.app. Next: owner turns on
  "Login with the JavaScript SDK", fills the review form (texts given in
  chat), I check it, owner submits.
- 2026-10-28 — **WhatsApp App Review submitted** (Tech Provider): only
  `whatsapp_business_messaging` and `whatsapp_business_management`; the other
  14 permissions in the old draft were removed from this submission (not from
  the app) and go in a second review for Instagram/Messenger. Data handling:
  processors Supabase (Germany, US) and Anthropic (US), controller the
  registered business, Jordan; no national security requests; all four
  authority-request practices ticked, written down in `docs/AUTHORITY-REQUESTS.md`.
  When approved: the reminder above (config, webhook fields, WHATSAPP_SIGNUP,
  https test), then the real-number end-to-end test.
- 2026-11-14 — PC reset; toolchain reinstalled (Flutter 3.50 at C:\src\flutter,
  Node 24, Deno, Supabase CLI, Python, gh; Playwright MCP). 519 backend + 279
  Flutter tests pass; `flutter analyze` only shows deprecation notices from
  Flutter 3.47's Material split. `pubspec.lock` moved with the SDK.
- 2026-11-16 — **WhatsApp App Review approved.** Owner created the Embedded
  Signup configuration (1847339703121125), set it on production as
  `META_WHATSAPP_CONFIG_ID`, ticked the four webhook fields, and deployed;
  `env.prod.json` now carries `"WHATSAPP_SIGNUP": true` so every production
  build shows the button. Live bundle checked byte-identical to the local
  build. Seen on inboxara.app (demo shop): "Connect WhatsApp" beside "Connect
  with Meta", English 1280 and Arabic 390; pressing it opens Meta's real
  dialog with this config_id and `whatsapp_business_app_onboarding` — closed
  at Facebook's login, nothing connected. Also seen: the demo shop's old
  "Rabta App" (Messenger) and "djangus_w" (Instagram) show Disconnected, which
  is what raises the inbox's red banner. Next: step 4, real numbers end to end.
- 2026-11-16 — **Step 4 skipped by the owner** (no spare number; not using
  their own). Unproven against Meta: the `meta-oauth/whatsapp` callback with a
  real code, registering a new number with a PIN, Coexistence echoes and the
  24-hour sync, and disconnecting. Watch the first real seller's connection
  (`ops_log`, `npm run events -- whatsapp_business_account`). Moving on to the
  Instagram/Messenger App Review.
- 2026-11-16 — Instagram/Messenger review prep. Owner: unused permissions
  removed (`ads_management` stays in the use case, required by it, and is not
  in login config 1063344539629710 nor to be submitted); Page and Instagram
  webhooks moved to production; Rabta App Page + djangus_w reconnected on the
  production demo shop. `instagram_basic` is in the config: the username came
  through the Page field. **Bug found:** one reconnect hit Meta's transient
  `subscribed_apps` error (code 2) and the seller was still sent back as
  connected, with nothing ever going to arrive. Fixed, not deployed:
  `meta-oauth/subscribe.ts` retries a transient answer once, and a Page still
  unsubscribed gets a page in the app's design (Arabic then English, a way
  back) instead of the redirect. 10 tests, shown failing against no retry,
  retry-everything and no escaping; 529 backend pass. Page seen in Playwright
  at 1280 and 390, light and dark. Deploy: `supabase functions deploy
  meta-oauth` to staging, then production — owner runs it.
- 2026-11-16 — Webhooks proven on production with Meta's dashboard "Test"
  deliveries: #18 (page) and #19 (instagram), signature ok, processed. Real
  Instagram DMs from accounts with no role on the app did not arrive —
  expected before App Review (27 Sept entry). Adding an Instagram Tester needs
  the sender to have a Facebook developer account; owner skipped it. **Still
  unproven: a real Instagram DM end to end.** Send one from any account the
  day the review passes. Messenger not tested today.
- 2026-11-16 — Submission drafted: `docs/APP-REVIEW-MESSAGING.md` (the seven
  permissions, two recordings, reviewer instructions). The Instagram recording
  still needs a sender with a role (an Instagram Tester).
- 2026-11-16 — **First real Instagram DM end to end** (event #20): a new
  Instagram account linked in Accounts Center to the owner's Facebook (which
  has the app through the business) — no Tester role needed; the Instagram
  Testers role failed ("does not resolve", Basic Display is gone). Stored with
  the customer's name, the assistant answered, the reply reached Instagram.
  **Bug:** its echo was stored a second time as the seller's — the Send API
  returns `new_ig_dm_item:…` and the echo carries `ig_dm_item:…` (Meta's
  escaped base64). Fixed, not deployed: `_shared/mid.ts` stores one decoded
  spelling from both `readSendResult` and `parse.ts`; 6 tests from the real ids,
  shown failing; 535 backend pass. The duplicate row in the demo shop's
  "Wael khaled" conversation is still there.
- 2026-11-16 — **"Sort by"** in the inbox, at the owner's request: Needs a reply
  (default, the two groups), Newest first, Unread first, Oldest first;
  remembered per browser. In "Needs a reply" a closed reply window now goes
  after every answerable conversation (the owner saw a new message land under
  seven-week-old closed ones). 7 tests shown failing; 286 Flutter pass. Seen in
  Playwright on production's demo shop, built locally: every option in
  English at 1280, the menu and Oldest first in Arabic at 390, the choice
  surviving a reload. Not seen: the closed-window rule with an open
  conversation present (all of the demo shop's waiting ones are closed) —
  look when the next message arrives. Not deployed.
- 2026-11-16 — Deployed (meta-webhook, send-message, meta-oauth, web). Checked
  on production: a new DM (#22) stored under the decoded id, the assistant's
  reply stored once, its echo (#23) recognised as a duplicate; the row shows
  "The assistant answered" again. Duplicate row from #21 deleted. **Found:**
  inboxara.app serves the `.js` files with `max-age=14400` although
  `web/_headers` says `no-cache` (rabta.pages.dev sends `no-cache`): the
  zone's Browser Cache TTL overrides it, so a seller keeps the old build for
  up to 4 hours after a deploy. Owner: Cloudflare → inboxara.app → Caching →
  Configuration → Browser Cache TTL → "Respect Existing Headers".
  **Done by the owner the same day;** checked: every file, plain and
  cache-busted, now `no-cache`.
- 2026-11-17 — Recording for App Review. **Bug found:** a Page connected from a
  second shop takes its `connected_accounts` row with it (upsert on
  platform+external_id) but its conversations keep the old `workspace_id`, and
  a returning customer's message is added to that old conversation (unique
  account_id+customer_external_id) — invisible to both shops (the list and
  send-message both inner-join the account under RLS). Seen with the owner's
  own Messenger "Hello" (event #28) landing in "My workspace" after Rabta App
  moved to the demo shop. That conversation deleted; no other mismatches on
  production (12 checked). **Owner decided (a):** a Page's conversations and
  their messages move with it to the shop that connects it — as in Meta's own
  Page inbox. To build after the review: in `meta-oauth` `connect()`, when the
  account's workspace changes, move its conversations and messages; tests;
  DECISIONS entry.
- 2026-11-17 — **Instagram/Messenger App Review submitted.** Videos (owner's
  Desktop, checked frame by frame): "Review - Connecting" (42 s: Edit settings
  → Page → Instagram account → permission list → Accounts "Receiving
  messages"), "Review - Instagram (connect + messaging)" (84 s) and "Review -
  Messenger (connect + messaging)" (88 s) — Meta's form asks the messaging
  videos to show the business granting access too. Reviewer login: the demo
  shop. No tester account (owner's decision). Data handling as declared for
  WhatsApp. Seen on the way: the closed-window order live (a new DM at the top
  of "Waiting for a reply"), Messenger end to end on production with the
  customer's name and photo.
