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
