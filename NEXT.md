# Next — new name and WhatsApp

Started 6 October 2026. Spans many sessions: **read this first, tick items as
they finish, and add a dated line under "Log" at the end of each session.**
Big-company features are deliberately not here; the owner will report back
after meeting the buyers.

## Status

- [x] Step 0 — plan in the repo, pointed to from CLAUDE.md
- [ ] A — naming brief (candidates, checks run, top 3)
- [ ] A — owner picks a name
- [ ] A — rename what users see, new domain
- [ ] B — owner adds WhatsApp product to the Meta app, hands back phone_number_id, WABA id, system-user token
- [ ] B1 — migration, parse, send, media, UI three-way switches, prompts (unit-tested)
- [ ] B1 — connect-whatsapp script, end to end on staging with the test number
- [ ] B1 — seen in Playwright (both languages, both widths)
- [ ] B2 — Embedded Signup + "Connect WhatsApp" button
- [ ] Owner decision — production access route (buyer owns the Meta app, or register a business)
- [ ] Docs — DECISIONS.md, CLAUDE.md, CHECKLIST.md, LAUNCH.md header

## Log

- 2026-10-06 — plan written and approved.

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
- `lib/wordmark.dart` and the title in `lib/main.dart`;
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

- `DECISIONS.md`: amend the 14 Sept WhatsApp entry (Coexistence now exists) and note the change.
- `CLAUDE.md`: add a WhatsApp section and take WhatsApp off Future Vision.
- `CHECKLIST.md`: add a section for B1 and B2.
- `LAUNCH.md`: the header no longer says "paused".

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
