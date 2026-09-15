# Rabta

One inbox for customer conversations from Instagram and Facebook Messenger.

Built for sellers who currently switch between Meta's apps all day. Phase One
is a Windows desktop application; the backend runs on Supabase.

---

## Documentation

- `SETUP.md` — getting a machine ready to work on this
- `CHECKLIST.md` — Phase One progress
- `STATUS.md` — where the work currently stands
- `CLAUDE.md` — what the product is and how it should behave
- `DECISIONS.md` — decisions that are settled, and why
- `WEBHOOKS.md` — the webhook service specification

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
# restore supabase/.env from a password manager
npm test
```

46 passing tests means the machine is set up correctly.

Docker is not needed. The database and functions are hosted, and the tests run
Postgres in-process.

---

## Everyday commands

```
cd supabase && npm test                        # run the backend tests
supabase db push                               # apply new migrations
supabase functions deploy meta-webhook         # deploy the webhook
supabase secrets set --env-file supabase/.env  # update function secrets
```

---

## Before committing

`supabase/.env` holds the Meta app secret and is protected by `.gitignore`
alone. Check `git status` before any commit that touches that directory.
