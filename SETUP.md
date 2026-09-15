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

- [ ] Only if you will build the Windows application: install Visual Studio
      with the **Desktop development with C++** workload. Flutter cannot
      produce a Windows build without it, and the error when it is missing is
      not obvious.

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

`supabase/.env` is deliberately not in the repository. It holds the Meta app
secret.

- [ ] Copy your saved `supabase/.env` into the `supabase/` folder
- [ ] Confirm both values are filled in, and neither is blank:

```
grep -c . supabase/.env          # expect 14
grep '^META_APP_SECRET=.' supabase/.env >/dev/null && echo "app secret set"
grep '^META_VERIFY_TOKEN=.' supabase/.env >/dev/null && echo "verify token set"
```

- [ ] Confirm git is ignoring it:

```
git check-ignore -v supabase/.env
```

If that prints nothing, **stop** and fix `.gitignore` before committing
anything. Printing a line is the good outcome.

## 6. Check it all works

- [ ] `cd supabase && npm test`
- [ ] 46 tests pass, in roughly two seconds

That is the real confirmation. It exercises signature verification, payload
parsing, message processing, the schema, the conversation trigger and row level
security, including booting Postgres in-process. If it passes, the machine is
set up correctly.

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

- [ ] `git status` does not list `supabase/.env`

That file holds the Meta app secret and is protected by `.gitignore` alone.
Worth a glance before any commit that touches the `supabase/` folder.
