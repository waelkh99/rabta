# Rabta

One inbox for customer conversations from Instagram and Facebook Messenger.

- `CLAUDE.md` — what the product is and how it should behave
- `DECISIONS.md` — decisions that are settled, and why
- `WEBHOOKS.md` — the webhook service specification
- `STATUS.md` — where the work currently stands

---

## Working on another machine

### 1. Clone

The repository is private, so the machine needs GitHub access first.

```
gh auth login
git clone https://github.com/waelkh99/rabta
cd rabta
```

### 2. Install the tools

Versions below are what the project is known to work with.

| Tool         | Version | Needed for                        |
| ------------ | ------- | --------------------------------- |
| Flutter      | 3.44.0  | the application                   |
| Dart         | 3.12.0  | comes with Flutter                |
| Node         | 26      | backend tests                     |
| Supabase CLI | 2.117.0 | migrations and function deploys   |
| GitHub CLI   | 2.100.0 | cloning and pushing               |

On macOS:

```
brew install --cask flutter
brew install node gh supabase/tap/supabase
```

Docker is **not** needed. The database and functions run in the hosted Supabase
project, and the tests use an in-process Postgres.

To build the Windows application, that machine also needs Visual Studio with
the "Desktop development with C++" workload. Flutter cannot build a Windows
release without it.

### 3. Install dependencies

```
flutter pub get
cd supabase && npm install
```

### 4. Connect to Supabase

```
supabase login
supabase link --project-ref xejtffbpfguwvybrwqqj
```

`link` asks for the database password. It is in the Supabase dashboard under
Settings > Database.

### 5. Restore the secrets

`supabase/.env` is deliberately not in the repository. Copy it across from a
password manager, or rebuild it:

```
cp supabase/.env.example supabase/.env
```

- `META_APP_SECRET` — always retrievable from the Meta app dashboard, under
  App Settings > Basic.
- `META_VERIFY_TOKEN` — **not recoverable.** Supabase stores it but
  `supabase secrets list` returns only a digest, never the value. If the file
  is lost, generate a new one with `openssl rand -hex 32`, apply it with
  `supabase secrets set --env-file supabase/.env`, and update the verify token
  in the Meta dashboard so the two match again.

### 6. Check it works

```
cd supabase && npm test
```

46 tests, about two seconds, no network required. If those pass, the machine is
set up correctly.

---

## Everyday commands

```
cd supabase && npm test                      # run the backend tests
supabase db push                             # apply new migrations
supabase functions deploy meta-webhook       # deploy the webhook
supabase secrets set --env-file supabase/.env  # update function secrets
```

---

## Before committing

`supabase/.env` holds the Meta app secret and is protected by `.gitignore`
alone. Check `git status` before any commit that touches that directory.
