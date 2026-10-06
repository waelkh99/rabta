# Launch checklist — the steps that need you

> **Resumed 6 October 2026** for potential buyers — current work is in
> `NEXT.md`. The note below is kept for its reasoning, which still holds for
> Instagram and now for WhatsApp too.
>
> **Paused 27 September 2026, by the product owner's decision.** Instagram
> messages from real customers need Meta App Review for
> `instagram_manage_messages`, which needs Business Verification, which needs a
> registered business. The owner will not register one for an unproven product
> (and Sanad does not offer trade-name registration). See "Where it was left"
> at the end, and DECISIONS.md, 27 September.

Written 25 September 2026, after a launch-readiness review. Everything that
could be done in code is done (see "Done from the code side" at the end). What
is left needs an account, a payment, a legal decision or a person — so it is
yours. Work down the list; each step says why it matters and what to hand back
so the code side can finish it.

Readiness at the time of writing: **about 6.5 / 10** for a public launch —
product and security are strong; hosting, backups, legal pages and Meta review
are what is missing. Items 1–5 are blockers.

---

## 0. Your admin account — done 25 September 2026

Set up and signed in. Kept here for a forgotten password, until SMTP exists.

Your account `wal.kh.saleh99@gmail.com` exists and is an admin. To set its
password:

1. Run the app locally: `flutter run -d chrome --dart-define-from-file=env.json --web-port=5353`
2. In another terminal, from the project folder — two commands, because
   Windows PowerShell does not accept `&&`:
   ```
   cd supabase
   npm run signin -- wal.kh.saleh99@gmail.com --password
   ```
   Every `npm run` command in this project runs from the `supabase` folder;
   from the project root npm reports "Could not read package.json".
3. Open the link it prints in that Chrome. It asks you to choose a password
   (at least 10 characters, with upper case, lower case and a digit).
4. From then on, sign in normally. **Menu → الإدارة / Admin** is the whole
   service in one screen: health, every seller, costs, events, and errors on
   sellers' screens. Invite sellers from its top bar.

The link is single use and expires in an hour; run step 2 again for a new one.

---

## 1. Production Supabase project — closed 26 September 2026

`Rabta-prod`, ref **`yxewrxkxhmwnyxslyefn`**, in **Frankfurt (`eu-central-1`)**,
on the **Free plan** by decision: one pilot seller does not come near its
limits. The one real gap on Free is **no backups** — see "Backups" below.
Upgrade to Pro ($25/month) when a second seller joins, sign-ups open, or the
first seller depends on Rabta daily for real sales.

Done: all 18 migrations; the four functions and their secrets (a new webhook
verify token, the staging Meta app secret, the staging Anthropic key until
step 6); public sign-up **off** (it was on by default — proven refused); the
password rules; Site URL `http://localhost:5353` until the domain exists; your
admin account. Row-level security and every function were checked from outside,
and the connect flow was seen returning to production, not staging. Supabase's
advisors: the same expected items as staging. Leaked-password protection needs
Pro.

The old Tokyo project is now **staging**.

**Working against production.** Keys live in `supabase/.env.prod` and
`env.prod.json`, both git-ignored. Scripts read staging unless told otherwise:

```
cd supabase
$env:RABTA_ENV="prod"; npm run admin
```

(PowerShell; the variable lasts for that terminal window — close it, or run
`Remove-Item Env:RABTA_ENV`, before working on staging again.) `seed-demo`
deliberately has no production switch. The app against production:
`flutter run -d chrome --dart-define-from-file=env.prod.json --web-port=5353`.

**To sign in the first time:**

```
cd supabase
$env:RABTA_ENV="prod"; npm run signin -- wal.kh.saleh99@gmail.com --password
```

and open the link it prints. It lands on the live site (`APP_URL` in
`.env.prod`), where you choose your password.

**Backups — deferred by decision, 26 September 2026; to be revisited.** Not
in place, and step 1 is closed without them. To build: a nightly `pg_dump` of the production
database to storage you control, keeping about two weeks. Needs somewhere to run
on a schedule (GitHub Actions if the repository is on GitHub).

## 2. Domain and hosting — closed 26 September 2026

**Live at https://rabta.chat** (bought through Cloudflare Registrar), served by
Cloudflare Pages against the production project. `https://rabta.pages.dev`
serves the same site and stays trusted, so no link breaks. The legal pages are
at **https://rabta.chat/privacy** and **https://rabta.chat/data-deletion** (the
`.html` addresses redirect there) — those are the two URLs for Meta.

Done: `rabta.chat` is first in `origins.ts`, with look-alikes refused; the
Supabase Site URL is `https://rabta.chat` and the redirect allowlist holds it,
`rabta.pages.dev` and `http://localhost:5353` (for running locally against
production); `APP_URL` in `.env.prod` makes production sign-in links land on
it. Sign-in links, CORS and the connect flow were checked from outside. Every
file is served `no-cache` (`web/_headers`), so a deploy reaches sellers on their
next reload. DNS: one proxied CNAME, `rabta.chat` → `rabta.pages.dev`. Seen loading on
`rabta.chat` by the product owner on a phone; the same build was seen on
`rabta.pages.dev` in Playwright, in both languages at desktop and phone width.

Not set up, on purpose: `www.rabta.chat` (nobody types it for a signed-in app;
one CNAME and a redirect rule if wanted), and the email records, which come
with step 3.

**To deploy**, from the project folder in PowerShell:

```
.\tool\deploy.ps1
```

It builds against production and uploads to Cloudflare. The Cloudflare token
(Pages: Edit only) and account ID are in `supabase/.env.prod`.

## 3. Email sending — closed 26 September 2026

Production sends through **Resend** (Ireland, `eu-west-1`), as "Rabta"
`<no-reply@rabta.chat>`, at up to 30 emails an hour. DKIM, SPF and DMARC
(`p=none`) are published for `rabta.chat`. The Resend key is send-only and
lives in `supabase/.env.prod`; the domain has no tracking subdomain, so links
in emails are not rewritten.

- **Emails are Rabta's own**, Arabic first with English under it: invitation,
  password reset and sign-in link. Source: `supabase/scripts/email-templates.mjs`;
  after editing, `$env:RABTA_ENV="prod"; npm run email-templates` pushes them,
  and `npm run email-templates -- --preview <folder>` writes them as files.
- **Forgot password** on the sign-in screen: it emails a reset to the address
  typed, and says the same thing whether or not the address has an account.
- **Invitations are emailed** on production (`INVITE_BY_EMAIL=true` on its
  functions); the invite screen says they are on their way. Staging has no
  SMTP, so there it still hands back a link to copy. For a lost email,
  `$env:RABTA_ENV="prod"; npm run invite -- them@example.com --link` makes one.
- **Redirect allowlist** now holds each address both bare and with `/**`.
  Supabase matched a bare `https://rabta.pages.dev` against neither entry and
  sent the link to the Site URL instead — invisible on `rabta.chat`, where the
  two are the same place.

Seen working: a reset email to the owner arrived in the inbox and its button
led to choosing a password on `rabta.chat`; an emailed invitation arrived; an
existing address was refused without sending. The new screens were seen in
both languages at desktop and phone width.

## 4. Legal pages — filled and live 26 September 2026; review still open

**Live:** https://rabta.chat/privacy and https://rabta.chat/data-deletion, in
English and Arabic, operated by **Rabta App, Amman, Jordan**, contact
**rabtaappsupport@gmail.com**, dated 26 September 2026. Seen in both languages
at desktop and phone width.

What changed from the draft beyond filling in: Resend and Cloudflare added to
the providers; the backup sentence now says no separate backups are kept, which
is true on the Free plan — **when backups are added (step 1), both pages must
say how long they keep deleted data.**

A deploy that changes these pages may be served stale by Cloudflare's edge for
a while; Caching → Purge Everything on the `rabta.chat` zone clears it.

Still yours:
- Have them read by someone qualified in Jordan's Personal Data Protection Law.
- Confirm "Anthropic does not use this data to train its models" still matches
  Anthropic's commercial terms.
- Someone answers `rabtaappsupport@gmail.com`: deletion requests carry a
  30-day promise.
- Meta Business Verification may ask for a registered business; "Rabta App"
  is a trading name, not a legal entity (see step 5).

The original step:

**Why.** Meta's App Review requires a privacy policy URL and data deletion
instructions URL. Jordan's Personal Data Protection Law (No. 24 of 2023)
applies to the customer messages Rabta stores.

**Do.**
- Fill every yellow `[BRACKETED]` field in `web/privacy.html` and
  `web/data-deletion.html`: business name, address, contact email, date,
  hosting region, backup retention.
- Have them read by someone qualified for Jordanian data-protection law.
- Confirm the sentence "Anthropic does not use this data to train its models"
  still matches Anthropic's commercial terms when you publish.
- Decide who answers the contact email; deletion requests have a 30-day
  promise on the page.

**Hand back.** The edited files (or the values, and I will fill them in).

## 5. Meta: business verification and App Review — blocker

**Decided 27 September 2026: Live mode with Standard Access, no Business
Verification for now.** The product owner will not register a business for an
app with no users yet; if Rabta grows, registering and verifying is the extra
step then. Until then:

- The app is switched to **Live mode**, which needs no verification. Meta then
  delivers messages from *every* customer to connected Pages and Instagram
  accounts; development mode delivered only from people with a role on the app.
- **Sellers connect as app Testers.** Standard Access covers anyone with a role
  on the app. Each pilot seller is added under App roles → Testers and accepts
  with their Facebook account; without a role, connecting fails.
- **Opening to sellers without an invitation needs Advanced Access**, and so
  Business Verification — the rest of this step, below, is that route.

Meta app icon: `Assets/App Icons/meta-app-icon-1024.png`, made by
`tool/make_icons.py`.

**Checked against Meta's rules on 26 September 2026.**

Rabta reads messages on Pages it does not own, so it needs **Advanced Access**
to its permissions. Advanced Access requires **Business Verification**, and
Meta's **Access Verification** (confirming Rabta is a Tech Provider handling
other businesses' data) requires Business Verification first. Meta verifies
a *registered business* from documents — a registration certificate, business
licence or tax document — whose legal name and address match what is entered.
"Rabta App" is a trading name, not a registered entity, so **this is the one
blocker nothing in the code can remove.**

Suggested route: register a sole proprietorship (مؤسسة فردية) with the Ministry
of Industry, Trade and Supply — reported as JD 5 for a first registration and
days to approve, through the MoITS e-services portal — then verify with its
certificate. Update the legal pages to the registered name afterwards.

Have already: privacy and data-deletion URLs; HTTPS on `rabta.chat`; production
OAuth redirect and webhook URLs and verify token; a working production app to
record screencasts from; a contact email; replies only inside the 24-hour
window, with no message tags.

Still to prepare: a 1024×1024 app icon; Data Use Checkup; a Rabta account and a
test Page or Instagram account for Meta's reviewer; one screencast per
permission; moving the webhook from staging to production.

Automated replies: Meta requires disclosing a bot only *where the law requires
it*, and recommends it everywhere. No Jordanian requirement was found, but that
belongs to the legal review in step 4. A product decision, not a Meta one.

Timing, as reported: Business Verification up to 14 business days; Access
Verification about 5 days; App Review now often 2–3 weeks.

The original step:

**Why.** The app is in development mode: only people with a role on it can
connect, and no Instagram message has ever reached the webhook.

**Do.**
- Complete **Business Verification** in Meta Business Manager.
- In the app dashboard, add the **Privacy Policy URL**
  (`https://<domain>/privacy.html`) and **User data deletion → Data deletion
  instructions URL** (`https://<domain>/data-deletion.html`).
- Update the **OAuth redirect** and **webhook callback** URLs to the new
  production project (I will give you the exact URLs after step 1).
- Submit **App Review** for: `pages_show_list`, `pages_messaging`,
  `pages_manage_metadata`, `pages_read_engagement`, `instagram_basic`,
  `instagram_manage_messages`, `business_management`. Each needs a short
  screencast of the permission in use — record them from the production app.
- Check Meta's current policy on **disclosing automated replies** to
  customers (the assistant's replies are labelled in your inbox, not to the
  customer). If disclosure is required, tell me the wording and I will add it.
- Publish the app (Live mode).

**Hand back.** "It's live." Then send one Instagram DM to a connected account
so we can check `entry.id` — the one Instagram fact never verified (STATUS.md,
"Instagram: configured, not verified").

## 6. Anthropic key for production

**Why.** The key in use is organisation-wide with no spend limit.

**Do.** In the Anthropic console, create a **workspace** for Rabta production,
set a **monthly spend limit** on it, and create an API key in that workspace.

**Hand back.** The key, via `supabase/.env.prod` — I set it on the production
functions. With a workspace-scoped key the workspace id is no longer needed.

## 7. Clean up the test project

**Do**, once production exists: in the current (staging) project, change the
password of `webhook-test@rabta.local` — the old one is in git history — or
delete that account. It must never be made an admin.

## 8. Pilot before opening up

**Why.** The assistant is measured on scripted conversations and one real
thread; it has never met a real shop's catalog and customers.

**Do.**
- Invite 3–5 friendly sellers first (Admin → invite).
- Let them use the inbox for a few days with the assistant **off**, then turn
  it on.
- Check **Admin** daily: health, errors, and each seller's hand-overs.
- Watch each seller's **Results** screen for how often they correct the
  assistant's outcomes; a high rate is the early warning.

---

## Done from the code side (25 September 2026)

For reference — no action needed.

- **Permissions tightened.** Sellers can write only the five conversation
  fields the app writes; functions have fixed search paths; the signup trigger
  is no longer callable; every policy rewritten to Supabase's recommended form.
  Supabase's advisors are clean except the three noted in `STATUS.md`.
- **Password policy.** 10 characters minimum, upper + lower + digit.
- **Logging.** Every important event (failures, dead tokens, connects,
  hand-overs) goes to an `ops_log` table as well as the function log.
- **Costs recorded.** Every model call's tokens and dollar cost in `ai_usage`.
- **Errors on sellers' screens** are reported to `client_errors`.
- **Retention.** Processed raw deliveries deleted after 30 days, logs and
  error reports after 90.
- **Admin screen** in the app, admin-only in the database itself.
- **"New version — Reload" banner** when a new build is deployed.
- **Library versions pinned** in the Edge Functions.
- **Draft privacy and data-deletion pages** in `web/`.

---

## Where it was left — 27 September 2026

**Working in production, and verified:**
- https://rabta.chat (and rabta.pages.dev) serving the app against the
  Frankfurt project, with Supabase auth, email through Resend, legal pages.
- The Meta app is **Live** on Standard Access. Facebook Page messages from any
  customer arrive and are processed — seen on 26 September.
- The owner's Page (`1427711713749572`) and Instagram (`17841401424316998`)
  are connected on production; the Page is subscribed; tokens are valid and
  carry `instagram_manage_messages`.
- The demo shop (`demo@rabta.chat`, STATUS.md) for showing people.

**Not working, and why:** Instagram DMs from customers are never sent by Meta
without App Review — Meta's own webhook documentation says so, and none
arrived in testing while Facebook messages did. The Instagram `entry.id`
question (STATUS.md) is still unverified.

**To resume Instagram:** register a business (a sole proprietorship at the
Ministry of Industry, Trade and Supply), Business Verification in Meta
Business Manager, Access Verification, then App Review for
`instagram_manage_messages` (+ `business_management`), with the screencasts
described under step 5. Then update the legal pages to the registered name.

**A Facebook-only pilot needs none of that:** add sellers as app Testers
(step 5, the Live-mode decision) and they can connect their Pages today.

**While paused, nothing costs money:** Supabase Free (production pauses after a
week without activity; resume it from the dashboard — nothing is lost),
Cloudflare Pages and Resend on free tiers, the Anthropic key spends only when
the assistant answers. The one recurring cost is the `rabta.chat` domain
renewal, due 26 September 2027 at Cloudflare Registrar.

**Loose ends to know about:** production has no backups (step 1); the staging
account `webhook-test@rabta.local` still has a password in git history
(step 7); the demo login is public by design.

