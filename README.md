# Rabta

One inbox for customer conversations from Instagram and Facebook Messenger.

Built for sellers who currently switch between Meta's apps all day. Phase One
is a web application; the backend runs on Supabase.

---

## Documentation

- `SETUP.md` — getting a machine ready to work on this
- `CHECKLIST.md` — Phase One progress
- `STATUS.md` — where the work currently stands
- `CLAUDE.md` — what the product is and how it should behave
- `DECISIONS.md` — decisions that are settled, and why
- `WEBHOOKS.md` — the webhook service specification
- `ONBOARDING.md` — the seller's first ten minutes, and what it requires

---

## Getting started

Work through `SETUP.md`. It takes about half an hour, most of it downloads, and
each step says how to confirm it worked.

The short version, once the tools are installed:

```
git clone https://github.com/waelkh99/rabta
cd rabta
flutter pub get
cd supabase && npm install
supabase login && supabase link --project-ref xejtffbpfguwvybrwqqj
# restore supabase/.env (Meta secrets) from a password manager
# create supabase/.env.local (Supabase URL + secret key) — see SETUP.md
npm test
```

56 passing tests means the machine is set up correctly.

Docker is not needed. The database and functions are hosted, and the tests run
Postgres in-process.

---

## Running the application

The Supabase URL and publishable key are **compiled in**, so a build without
them produces an application that cannot reach the database whatever is in the
environment when it runs. That is the cause of a "Missing SUPABASE_URL" screen.

Create `env.json` in the repository root — it is git-ignored:

```json
{
  "SUPABASE_URL": "https://xejtffbpfguwvybrwqqj.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

The publishable key is in the dashboard under Settings > API Keys. It is meant
to be public and is safe in a browser — row level security is what protects the
data, not the key — but keeping it out of the repository means rotating it is
not a commit.

```
flutter run -d chrome --dart-define-from-file=env.json --web-port=5353
flutter build web --release --dart-define-from-file=env.json
```

`.vscode/launch.json` passes the file already, so starting a debug session from
the editor works without flags.

The port is pinned rather than left to Flutter's random choice because
`meta-oauth` will only return a browser to an origin on its allowlist, and an
allowlist cannot hold a port that changes on every run. Change it in one place
and it has to change in `supabase/functions/meta-oauth/state.ts` too.

The interface is Arabic and English, and follows the browser's language, falling
back to Arabic. `?lang=ar` or `?lang=en` overrides that, which is how to see the
other language without changing the whole browser. There is also a language
switch on the sign-in screen and in the inbox header.

## Giving someone an account

There is no public sign-up: `disable_signup` is on, so an account only exists
because we made one. Inviting is how, and it means the seller chooses their own
password — we never know it and it never travels through a chat.

From inside the product, an admin can do this on the invite screen — the
person-add control in the header. From the command line:

```
cd supabase
npm run invite -- them@example.com          # sends the invitation by email
npm run invite -- them@example.com --link   # prints the link instead
```

Admins are the accounts allowed to create other accounts. Granting it needs the
service key, so there is no screen for it:

```
npm run admin                        who is an admin
npm run admin -- them@example.com    make one
npm run admin -- them@example.com --revoke
```

Use `--link` until custom SMTP is configured. Supabase's built-in sender is
rate limited to a handful of messages an hour and is explicitly not for
production, so a real invitation can fail to arrive at the worst moment.

The link lands on a screen that asks them to choose a password, and their
workspace is created by the database trigger the moment the account exists.
Links expire — Supabase's default is 24 hours — and are single use.

`--return <origin>` sets where the link lands, defaulting to the development
origin. It must be an allowed redirect URL on the project, or Supabase quietly
substitutes the Site URL instead.

Sign in while developing with `webhook-test@rabta.local` / `rabta-dev-2026` —
see `STATUS.md` for what that account owns.

---

## Everyday commands

```
cd supabase && npm test                        # run the backend tests
cd supabase && npm run events                  # show what Meta actually sent
supabase db push                               # apply new migrations
supabase functions deploy meta-webhook         # deploy the webhook
supabase secrets set --env-file supabase/.env  # update function secrets
```

`npm run events` reads `webhook_events`, which is where every delivery is
stored before anything is done with it. It takes an object filter and a count:
`npm run events -- instagram`, `npm run events -- page 25`. It needs
`supabase/.env.local`.

---

## Before committing

`supabase/.env` holds the Meta app secret; `supabase/.env.local` holds a
Supabase secret key that bypasses row level security. Both are protected by
`.gitignore` alone. Check `git status` before any commit that touches that
directory.

The two are separate on purpose: `supabase secrets set --env-file` rejects any
name beginning with `SUPABASE_`, so the Supabase credentials cannot live in
`.env` without breaking it.
