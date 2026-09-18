# Where we are

Updated 18 September 2026.

What is built, what is live, and what comes next. `CLAUDE.md` holds the product
direction, `DECISIONS.md` the settled decisions and why, `CHECKLIST.md` the
Phase One progress, and `WEBHOOKS.md` the webhook service specification.

**In one paragraph.** Phase One is functionally complete as a product: a seller
signs in, connects their Meta accounts, reads their Instagram and Messenger
conversations in one inbox, and replies — with messages arriving live and
customers named. What is left is mostly not code. The Meta app is still in
development mode, so nobody outside its own roles can connect at all, and
Instagram has never been verified against a real delivery. There is nowhere to
host the site yet. Those are the critical path.

---

## Live right now

Supabase project `xejtffbpfguwvybrwqqj`. Four migrations applied, four Edge
Functions deployed.

| Function | What it does | Auth |
|---|---|---|
| `meta-webhook` | receives deliveries from Meta | HMAC signature, no JWT |
| `meta-oauth` | `/start`, `/callback`, `/disconnect` | seller's JWT, except the callback |
| `send-message` | sends a reply | seller's JWT |
| `admin-invite` | creates an account | seller's JWT, admins only |

```
https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-webhook
https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-oauth/callback
```

The second is the **OAuth redirect** registered in the Meta dashboard. The
webhook callback is registered separately, under the Webhooks configuration,
against both the **Page** and **Instagram** objects with the same verify token.

`META_APP_SECRET` and `META_VERIFY_TOKEN` are set on the functions. Public
sign-up is off: `/auth/v1/settings` reports `disable_signup: true`.

**126 backend tests** (`cd supabase && npm test`, about six seconds, no Docker
and no network) and **40 client tests** (`flutter test`). Each new piece of
logic is shown to fail when deliberately broken rather than assumed to be
covered.

---

## What works, end to end

Everything here has been run against the live project and seen to work, not
inferred from the code.

**Messages arrive.** Signature verified over the raw bytes, the raw payload
stored before anything is done with it, a fast 200 and processing afterwards.
Redelivery is idempotent. Echoes of the seller's own replies are stored as
outbound and clear the unread state. Four real deliveries are captured as
fixtures in `tests/parse.test.ts` with their ids untouched.

**Accounts connect.** The seller presses Connect, approves on Meta's screen,
and the callback exchanges the code, stores the token, subscribes the account
to the webhook and sends the browser back. Turning an account off stops new
messages without deleting its history.

**Replies send.** A reply typed in the browser reaches the customer, and Meta's
echo of it comes back and does not appear twice. Arabic survives the round trip
byte for byte, including U+061F and Western digits inside a right-to-left
sentence.

**The inbox updates live.** Realtime is used as a signal, never as a source of
data: on any change the list is read again through the ordinary query, so
everything on screen has passed row level security exactly as it would on a
reload.

**Customers have names and faces.** Meta sends only an opaque id with a
message, so the profile is fetched once per customer rather than once per
message.

**Accounts are created by invitation.** There is no public sign-up. An admin
invites someone; they choose their own password from the link, so it is never
ours and never travels through a chat.

**The interface.** Sign-in, the two-group conversation list, the thread, the
composer, the details pane, the accounts screen, the invite screen. Arabic and
English throughout, Arabic as the source language and the fallback. Verified in
a browser in both languages, at desktop and phone width.

---

## Not built, and known gaps

- **Publishing the Meta app.** It is in development mode, so Meta only delivers
  from accounts holding a role on it. **This blocks everything else**: no real
  seller can connect, and Instagram cannot be verified. Calendar time.
- **Hosting.** There is no origin to serve the site from. Once there is one it
  goes in `supabase/functions/_shared/origins.ts`, the single list serving both
  the OAuth return and the CORS checks.
- **Site URL is still `http://localhost:3000`**, the Supabase default. Any auth
  link whose redirect is not on the allowlist falls back to it.
- **Custom SMTP — deferred deliberately.** Supabase's built-in sender is rate
  limited and not for production, so invitations can fail to arrive exactly
  when someone is waiting. Until then the invite screen hands over a link
  rather than emailing it, and says so. **Close this before the first paying
  customer.**
- **Sending a password reset.** The screen a reset link lands on is built and
  the routing handles `type=recovery`; the button that sends the email is not,
  and is useless until SMTP exists.
- **A sweep that retries events which failed processing.**
- **Token expiry on the receiving side.** A send that fails with Meta's code
  190 marks the account `needs_reconnect`; nothing detects it on the receive
  path, where messages simply stop arriving and the seller thinks business is
  quiet.
- **Attachments are shown from Meta's URLs**, which expire after about 30 days.
  Whether to copy them into storage is still open.
- **The font is fetched, not bundled.** Almarai renders through `google_fonts`,
  which pulls from Google's CDN at runtime, so every cold load makes a
  third-party request and shows a fallback face until it lands.
- **Marking a conversation read**, and in-page notification and title badge.
- **Instagram, verified against a real delivery.** See below.

---

## What needs you, not code

1. **Business verification and App Review, then publish the app.** The blocking
   item, and calendar time rather than development time.
2. **Somewhere to host the site, and a domain.**
3. **Custom SMTP**, before the first paying customer.
4. **Set Site URL** to the real origin once it exists.

---

## Test data in the live database

Deliberately kept, so a message sent to the test Page flows straight through
without setting anything up again.

- auth user `webhook-test@rabta.local`, password `rabta-dev-2026`. Written down
  because it is otherwise unrecoverable, and because it owns nothing but this
  test data.

  **It must never be an admin.** That password is in this repository and in its
  history, so an admin flag on it would hand account creation to anyone who can
  read the repo. It was briefly an admin on 18 September while the invite
  screen was tested, and was revoked afterwards. There are currently **no
  admins**. Grant one to a real account whose password is not written down
  here: `npm run admin -- you@example.com`.

- its workspace, `0c839c31-4a49-485b-a9f9-b2e4af479b8b`
- `connected_accounts` for the Facebook Page `1427711713749572` ("Rabta App")
  and the Instagram account `17841401424316998` (`djangus_w`), both connected
  through `meta-oauth` and both active
- one conversation with the customer `28847995138118550` ("Wael K. Saleh"), its
  messages, and the raw events behind them

None of it is real seller data. Clear it whenever it stops being useful — but
removing a `connected_accounts` row sends later deliveries back to being stored
and skipped as `unknown-account`.

---

## What Meta does that its documentation does not say

All found by running the real flow. Each one would have shipped as a bug.

**`/me/accounts` returns an empty array under Facebook Login for Business**,
even when the Page was explicitly granted. `debug_token` on the same token
reports the Page id under `granular_scopes.target_ids` for every `pages_*`
scope. The documented way to list a seller's Pages therefore says they have
none, which is indistinguishable from a seller who genuinely has none.
`meta-oauth` reads the granted ids from `debug_token` instead.

**`instagram_business_account` on a Page requires `instagram_basic`.** Without
it the field is simply absent rather than erroring, so the documented way to
find a seller's Instagram account silently returns nothing. The Instagram ids
are in `granular_scopes` too.

**Graph API Explorer can no longer issue Page tokens for this app.** Explorer
sends no `config_id`, so the login falls through to an ordinary user login with
no asset-selection step and returns a user token every time. Not a
misconfiguration — the OAuth flow is now the only way to obtain a Page token.

**Subscribing fields in the dashboard is not enough.** Each account must also
be subscribed through `POST /{id}/subscribed_apps`, which needs
`pages_manage_metadata`. Miss it and the webhook verifies cleanly and then
never fires. `meta-oauth` does it immediately after the token exchange.

**The "Authorize callback URL" field is the OAuth redirect, not the webhook
callback.** Putting the webhook URL there looks correct and silently does
nothing.

**The "Native or desktop app?" toggle stays off.** It tells Meta the client
cannot keep a secret; ours never sees one.

**Profile picture and attachment URLs last about 30 days** and are fetchable
with no access token. Measured 15 and 18 September.

**Facebook Login for Business configuration id: `1063344539629710`.** Not a
secret — it appears in the login URL the browser is sent to. Without a
`config_id` the dialog has no asset-selection step at all.

---

## Instagram: configured, not verified

Everything checkable is correct, and **no Instagram message has ever reached
the webhook.**

Confirmed: the account is Professional and linked; Meta reports
`instagram_business_account` as `17841401424316998` on the Page; it was granted
on the asset screen and is stored with its token; the Page's subscription is
`messages, messaging_postbacks, message_echoes`; **Connected tools → Allow
access to messages** is on in the Instagram app — account-side, off by default,
invisible from the app dashboard, and something a seller will have to be walked
through; direct messages reach the Page's inbox in Meta Business Suite; and the
function handles `object: "instagram"` end to end, proven by replaying a signed
delivery on 17 September.

The blocker is development mode. Meta only delivers from accounts holding a
role on the app, and Instagram has no role that fits: the Instagram Tester role
resolves against a Facebook-linked identity, and a standalone Instagram account
has none, so Meta rejects it with "does not resolve to a valid user id".

**The first thing to check once the app is published**, before anything is
built on top:

```
entry.id == 17841401424316998   the Instagram account id, which is what we store
entry.id == 1427711713749572    the Page id, which would mean every Instagram
                                message is stored and then skipped as
                                belonging to an unknown account
```

Meta's documentation says the first. Nothing has confirmed it for this app.

---

## Next

1. Business verification and App Review, then publish the app.
2. Capture a real Instagram delivery and check `entry.id` against the value
   stored for the account.
3. Decide where the site is hosted, add that origin to
   `functions/_shared/origins.ts`, and set Site URL to match.
4. Custom SMTP, then the password reset button.

---

## Open questions

Carried from `DECISIONS.md`:

- Can one seller connect more than one Instagram account or Page?
- Does Phase One link the same customer across channels? Proposed no, and close
  to settled: Meta's customer ids are scoped to the account they wrote to, so
  there is no supported way to connect them.
- Attachment media: stored or fetched on view.
- Where the site is hosted, and on what domain.
- How a conversation near the end of its reply window is marked in the list.
