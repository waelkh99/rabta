# Onboarding

What a seller goes through between opening Rabta and seeing their first
customer message, and what the application has to handle along the way.

`CLAUDE.md` describes what the product is. `DECISIONS.md` records what has been
settled. This file describes the seller's first ten minutes, because that is
where a product like this is usually lost.

Most of this is still not built. It is written down because it defines work
that is otherwise in nobody's plan — failure states the connect screen has to
handle, none of which are visible from the happy path.

Three things described here **are** built: the empty inbox explains itself
rather than looking broken, and accounts are created by invitation rather than
by signing up (22 September 2026); and an account whose token Meta no longer
accepts is found when the inbox opens and shown as a red banner leading to
Accounts (24 September 2026).

---

## What the seller never sees

All of this is one-time work on the Meta app, done once and never repeated:
creating the app, configuring the webhook objects, the callback URL and verify
token, subscribing webhook fields, and the `/me/subscribed_apps` call.

A seller does none of it. This is worth stating plainly because setting it up
by hand the first time gives a misleading impression of how involved connecting
an account is.

---

## What has to be true before any seller can connect

Three things that do not exist yet:

- **Business verification** of the Meta app.
- **App Review** for the messaging permissions.
- The app switched from development mode to **Live**.

Until then, only people with a role on the app — Administrator, Developer or
Tester — can connect anything at all. Every test so far has worked only because
of that.

Both reviews run in **calendar time, not development time**. They are the
longest lead item in Phase One and are worth starting well before the
application is finished.

---

## What the seller must already have

Not part of the application, and not something it can create for them:

- **A Facebook Page.** Messenger delivers messages to Pages, never to personal
  profiles. Without a Page there is nothing to connect.
- **An Instagram Professional account, linked to that Page**, if they want
  Instagram. This follows from the decision to use Facebook Login for Business
  only — see `DECISIONS.md`.

Both are free and take a few minutes, but both happen **outside Rabta**, in
Meta's own interfaces, and neither is obvious to someone who has not done it
before.

---

## The intended flow

1. Open the link. There is nothing to download and nothing to install — Rabta
   is a website, decided 17 September 2026.
2. Open the invitation and choose a password. There is no public sign-up —
   an admin invites the seller, and they set their own password from the link,
   so it is never ours and never travels through a chat. The workspace is
   created for them; they are never asked to name one.
3. Press **Connect**, which goes to Meta's approval page.
4. The seller approves. Meta redirects to an Edge Function which exchanges the
   code for a token, stores it, and subscribes the account to the webhook.
5. That function sends the browser back to Rabta, still signed in.

Three minutes and one decision, with nothing to close and nothing to come back
to. Steps 4 and 5 are the whole of it — see the connection flow section of
`STATUS.md`.

---

## The failure states

These are the work. Each one is a seller stopped dead, and in every case Meta's
own error is either absent or meaningless.

The last two were not predicted. They were found by connecting a real account
on 17 September, and both cost hours to identify from the inside, with full
access to the dashboard and the database. A seller has neither.

### The seller has no Facebook Page

The most likely state for a small seller who has always sold from a personal
profile.

The application must recognise it and say so in plain language — that a Page is
needed, that it is free, and what it is for — with a direct link to create one
and a way to retry without restarting the whole flow.

What it must not do is show an authorisation error, or an empty list of
accounts with no explanation.

### The seller's Instagram is not a Professional account

Instagram messaging does not work on personal accounts at all. No webhook will
ever arrive.

The application must detect this and explain the switch, which is free and
reversible. Since it happens in the Instagram mobile app rather than in a
browser, the instruction has to be followable on a phone while the seller is
sitting at their computer.

### The seller has a Page but does not grant it

Distinct from having no Page, and it looks identical from our side.

Meta's asset-selection screen asks which Pages and Instagram accounts the app
may use. Clicking through without ticking anything grants nothing, and the
connect flow then completes successfully with no accounts attached. Observed
repeatedly while setting this up on 17 September, by someone who knew what the
screen was for.

There is a second way to reach the same state, which is worse because it is
not the seller's doing at all: **`/me/accounts` returns an empty array under
Facebook Login for Business even when the Page was granted** — see `STATUS.md`.
An implementation that trusts it will tell sellers they have no Page while they
are looking at one. `meta-oauth` reads the granted ids from `debug_token`
instead.

### The seller's Instagram has third-party message access turned off

**Instagram app → Settings and activity → Messages and story replies → Message
controls → Connected tools → Allow access to messages.**

Off by default, only present in the mobile application, and invisible from the
Meta app dashboard. With it off, everything else can be correct — Professional
account, linked Page, permissions granted, webhooks subscribed — and no message
will ever be delivered. No error appears anywhere.

This one cannot be detected before the fact. What the application can notice is
the shape of the problem afterwards: **an Instagram account connected some time
ago that has never received a single message.** That is a strong enough signal
to prompt the seller to check this setting, and it is the only handle we have.

### The seller's Instagram is Professional but not linked to a Page

The most confusing of the three, because the account looks correct from
Instagram's side and simply does not appear when connecting.

This needs its own message. Telling the seller to "switch to a Professional
account" when they already have one will make them think the product is broken.

---

## Immediately after connecting

**The inbox will be empty, and that is not a bug.** Webhooks deliver nothing
retroactive; history starts at the moment of connection. See `DECISIONS.md`.

A seller who connects successfully and sees an empty screen will conclude it
did not work. **Built**: the empty inbox says so before they have a chance to
wonder — that conversations appear as customers write, and that earlier
messages stay in Meta's apps. One screen, and it prevents the most likely early
support question.

### Alerts, on a phone, are a second invisible step

**iPhone only, and it has the same shape as Connected tools above.** A site open
in a Safari tab cannot show a notification at all — the API is absent, not
refused. The seller has to use **Share → Add to Home Screen** first, after which
Rabta can notify them like any installed app. Android needs nothing.

The menu row reads "not available here" rather than "blocked" in that state,
which is true and not the seller's fault, but it does not yet tell them what to
do about it. That instruction is not built.

Worth planning alongside the Connected tools walkthrough rather than twice:
both are per-device, both are invisible from our side, and in both the product
looks broken while nothing on screen explains why. See `DECISIONS.md`, "Telling
the seller something happened".

---

## Getting in, before any of the above

There is no longer anything here. Until 17 September 2026 this section covered
installing a Windows application, where the first thing a seller saw was not
Rabta but "Windows protected your PC" — an unsigned installer's warning landing
immediately before they were asked to connect their business accounts, which is
the worst possible moment for a trust problem.

Shipping a website removes that step entirely. The seller opens a link. This is
the single largest thing the platform decision bought, and it is recorded here
rather than deleted because it is easy to forget what was avoided.

---

## The ceiling on who can adopt this

Many small sellers run their business from a **personal** Facebook profile and a
**personal** Instagram account, handling orders in their own direct messages.

Meta's messaging APIs do not work with either. For those sellers, adopting
Rabta means creating a Page and moving their customers to it — a change to how
they run their business, not a setup step. No amount of interface design
removes that.

This is not a problem to solve in Phase One. It is a fact worth knowing early,
because it bounds who the product can serve, and it should inform how much
effort goes into smoothing the connect flow versus finding sellers who already
have a Page.

Worth answering before Phase One ships: **how common is a Page among the
sellers actually being targeted?**

---

## Open

- How the connect screen detects each of the three failure states, and whether
  Meta's API distinguishes them cleanly enough to tell them apart.
- Whether a seller can connect more than one Page or Instagram account — still
  open in `DECISIONS.md`, and it changes this screen from a button into a list.
- ~~What happens when a token expires or is revoked from Meta's side.~~
  **Built 24 September 2026:** `meta-oauth/check` runs as the inbox opens and a
  red banner leads to Accounts. Still open: walking the seller through the
  reconnect itself, which is the ordinary Connect flow today.
- How a seller is walked through Add to Home Screen, and whether it is worth
  prompting for at all before notifications can reach a closed browser — which
  needs Web Push, which needs hosting.
