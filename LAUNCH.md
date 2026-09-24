# Launch checklist — the steps that need you

Written 25 September 2026, after a launch-readiness review. Everything that
could be done in code is done (see "Done from the code side" at the end). What
is left needs an account, a payment, a legal decision or a person — so it is
yours. Work down the list; each step says why it matters and what to hand back
so the code side can finish it.

Readiness at the time of writing: **about 6.5 / 10** for a public launch —
product and security are strong; hosting, backups, legal pages and Meta review
are what is missing. Items 1–5 are blockers.

---

## 0. Your admin account (do this first)

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

## 1. Production Supabase project — blocker

**Why.** The current project is in **Tokyo** (`ap-northeast-1`), on a plan
with **no backups** (the live API reports `backups: []`), and it holds test
data and a test account whose password is in the git history. A region cannot
be changed after creation, and free projects pause after a week idle.

**Do.**
- Upgrade the organisation to **Pro** (daily backups; enables leaked-password
  protection).
- Create a **new project** in **Frankfurt (`eu-central-1`)** — the closest
  Supabase region to Jordan. Name it e.g. `rabta-prod`.
- Keep the current project as **staging** for testing.
- Later, once real sellers are on it: turn on **Point-in-Time Recovery**
  (a paid add-on).

**Hand back.** The new project's ref, its secret (service) key and publishable
key — put them in a new `supabase/.env.prod` (never committed) and tell me. I
will apply all migrations, deploy the four functions, set their secrets, turn
on leaked-password protection, and repeat the password policy.

## 2. Domain and hosting — blocker

**Why.** There is nowhere to serve the app from. Every link — invitations,
password resets, the Meta connect flow — needs a real HTTPS address.

**Do.**
- Buy a domain (e.g. `rabta.app` or a `.jo`).
- Pick static hosting for the Flutter web build. Any of: Cloudflare Pages,
  Netlify, Vercel, Firebase Hosting. Cloudflare Pages is the simplest and free.
- Point the domain at it.

**Hand back.** The final address (e.g. `https://app.rabta.jo`). I will add it
to `supabase/functions/_shared/origins.ts`, set the Supabase **Site URL** and
redirect allowlist (still `http://localhost:3000` today), wire the build and
deploy, and confirm `/privacy.html` and `/data-deletion.html` are served.

## 3. Email sending (SMTP) — blocker

**Why.** Supabase's built-in email sends 2 a minute and is not for
production. Without it, invitations and password resets depend on a person
copying links around.

**Do.** Create an account with an email provider (Resend, Postmark or Amazon
SES), verify your domain with it, then in Supabase: *Authentication → Emails →
SMTP Settings*.

**Hand back.** Tell me it is set. I will build the "forgot password" button
and switch invitations to real emails.

## 4. Legal pages — blocker for Meta review

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
