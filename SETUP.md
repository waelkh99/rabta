# Setup checklist

Getting a machine ready to work on Rabta. Work down the list; each step has a
way to confirm it worked, so you are never guessing whether it took.

Roughly 30 minutes, most of it downloads.

---

## Before you start

Have these to hand. Chasing them halfway through is what makes setup drag.

- [ ] GitHub account with access to `waelkh99/rabta` (the repository is private)
- [ ] Supabase account with access to the project `xejtffbpfguwvybrwqqj`
- [ ] The Supabase **database password**
      — Supabase dashboard, Settings > Database
- [ ] A copy of **`supabase/.env`**, from a password manager
      — see "If you do not have the .env file" at the end, which is a slower path
- [ ] The Supabase **secret key**, from the dashboard
      — Settings > API Keys, "Publishable and secret keys" tab
- [ ] Meta developer account, if you will be touching the Meta configuration

---

## 1. Install the tools

- [ ] Install Homebrew, if the machine does not have it
      — https://brew.sh
- [ ] `brew install --cask flutter`
- [ ] `brew install node gh supabase/tap/supabase`
- [ ] Confirm all four report a version:

```
flutter --version    # expect 3.44.0 or later
node --version       # expect v26 or later
supabase --version   # expect 2.117.0 or later
gh --version         # expect 2.100.0 or later
```

Docker is **not** needed. The database and functions are hosted, and the tests
run Postgres in-process.

Nothing further is needed to build the application. It is a website, so
`flutter build web` works with the Flutter SDK and a browser alone — no Visual
Studio and no C++ workload. That was a requirement while Phase One was a
Windows application; it no longer is.

## 2. Get the code

- [ ] `gh auth login`
      — choose GitHub.com, HTTPS, authenticate in the browser
- [ ] `gh auth status` shows you logged in
- [ ] `git clone https://github.com/waelkh99/rabta`
- [ ] `cd rabta`
- [ ] `git log --oneline -1` shows a commit

## 3. Install dependencies

- [ ] `flutter pub get`
- [ ] `cd supabase && npm install`
- [ ] `npm ls @electric-sql/pglite` lists the package without errors

## 4. Connect to Supabase

- [ ] `supabase login`
      — opens a browser
- [ ] `supabase link --project-ref xejtffbpfguwvybrwqqj`
      — asks for the database password
- [ ] `supabase migration list` connects and shows `20260914000001` present
      both locally and remotely

If the remote column is empty, the migration has not been applied to that
project. Run `supabase db push`.

## 5. Restore the secrets

Two files, neither in the repository, and the split matters.

**`supabase/.env`** — the Meta secrets, and nothing else. This is the file
`supabase secrets set --env-file` is pointed at, and Supabase **rejects any
secret whose name starts with `SUPABASE_`**. Putting the Supabase credentials
in here is what breaks that command.

- [ ] Copy your saved `supabase/.env` into the `supabase/` folder
- [ ] Confirm both values are filled in, and neither is blank:

```
grep '^META_APP_SECRET=.' supabase/.env >/dev/null && echo "app secret set"
grep '^META_VERIFY_TOKEN=.' supabase/.env >/dev/null && echo "verify token set"
```

**`supabase/.env.local`** — the Supabase credentials, used only by local
tooling such as `npm run events`. Nothing deployed reads it; Supabase injects
these into deployed functions by itself.

- [ ] Create it with:

```
SUPABASE_URL=https://xejtffbpfguwvybrwqqj.supabase.co
SUPABASE_SECRET_KEY=sb_secret_...
```

The secret key is in the dashboard under **Settings > API Keys**, on the
"Publishable and secret keys" tab. There is no longer a Settings > API page.
Use a secret key rather than the legacy `service_role` key, which Supabase is
retiring. A secret key bypasses row level security completely, so it stays on
your machine.

- [ ] Confirm git is ignoring both:

```
git check-ignore -v supabase/.env supabase/.env.local
```

Two lines printed is the good outcome. If either prints nothing, **stop** and
fix `.gitignore` before committing anything.

## 6. Check it all works

- [ ] `cd supabase && npm test`
- [ ] 208 tests pass, in roughly ten seconds

That is the real confirmation. It typechecks every Edge Function with
`deno check`, then exercises signature verification, payload parsing, message
processing, the assistant's guards, the schema, the conversation trigger and
row level security, including booting Postgres in-process. If it passes, the
machine is set up correctly.

- [ ] `flutter test` — 78 tests
- [ ] `flutter analyze` — no issues

### Looking at the built site in a browser

`flutter build web` then serve `build/web` on **port 5353**, which is the origin
the Edge Functions allow (`functions/_shared/origins.ts`).

**Serve it with caching off, and clear the browser cache between builds.** This
has already cost an afternoon once. A static server that sends
`Cache-Control: max-age=3600` — `http-server`'s default — makes the browser hold
`main.dart.js` for an hour, so a rebuild changes nothing on screen and the code
looks broken when it is fine. `flutter clean`, a fresh browser profile and
unregistering the service worker all fail to shift it, because the file is in
the ordinary HTTP cache under an unchanged URL.

    npx http-server build/web -p 5353 -c-1

`-c-1` disables caching. If something still will not update, clear the browser's
cache rather than doubting the build — check the served bytes first with
`curl -s http://localhost:5353/main.dart.js | wc -c` against the file on disk.

## 7. Optional: confirm the deployed endpoint is alive

Only useful if you are working on the webhook.

- [ ] Confirm the handshake answers, using the verify token from your `.env`:

```
TOKEN=$(grep '^META_VERIFY_TOKEN=' supabase/.env | cut -d= -f2-)
curl -s "https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-webhook?hub.mode=subscribe&hub.verify_token=$TOKEN&hub.challenge=hello"
```

- [ ] It prints `hello` and nothing else

Anything else means the verify token on the function does not match your local
one. Fix it with `supabase secrets set --env-file supabase/.env`.

---

## If you do not have the .env file

`META_APP_SECRET` is always recoverable:

- [ ] Meta app dashboard, App Settings > Basic, copy the app secret

`META_VERIFY_TOKEN` is **not** recoverable. Supabase stores it but
`supabase secrets list` returns only a digest, never the value. Generate a new
one and make both sides match again:

- [ ] `cp supabase/.env.example supabase/.env`
- [ ] Paste in the app secret
- [ ] `openssl rand -hex 32` and paste the result as `META_VERIFY_TOKEN`
- [ ] `supabase secrets set --env-file supabase/.env`
- [ ] Update the verify token in the Meta dashboard to the same value
- [ ] Re-run step 7 to confirm the handshake answers
- [ ] Save `supabase/.env` to a password manager, so this is the last time

---

## Before your first commit

- [ ] `git status` does not list `supabase/.env` or `supabase/.env.local`

Between them those files hold the Meta app secret and a Supabase secret key
that bypasses row level security. Both are protected by `.gitignore` alone.
Worth a glance before any commit that touches the `supabase/` folder.
