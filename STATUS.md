# Where we are

Updated 18 September 2026.

A running log of what is built, what is live, and what comes next. `CLAUDE.md`
holds the product direction, `DECISIONS.md` the settled decisions, and
`WEBHOOKS.md` the webhook service specification.

---

## Built and working

**The webhook service receives messages.** Schema applied and the receiving
function deployed to the Supabase project `xejtffbpfguwvybrwqqj`.

Endpoint:

```
https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-webhook
```

Both `META_APP_SECRET` and `META_VERIFY_TOKEN` are configured on the function.
The endpoint has been confirmed live to accept a request signed with the real
app secret and reject a forged one.

**Tested, not assumed:**

- 47 local tests (`cd supabase && npm test`) covering signature verification,
  payload parsing, message processing, the database schema, the conversation
  trigger, and row level security. Runs in about five seconds with no Docker and
  no network.
- 13 checks against the live database, seeding data first so that the security
  checks proved something rather than querying empty tables.
- 19 checks against the deployed endpoint using genuinely signed requests.
- One real Meta delivery, received and processed end to end. See below.
- The suite was verified to fail when the code is deliberately broken.

### Test data currently in the live database

Deliberately kept, so that a message sent to the test Page flows straight
through without setting anything up again:

- auth user `webhook-test@rabta.local`, password `rabta-dev-2026`. This is the
  account the application signs in as while developing. Not a secret worth
  protecting — it owns nothing but this test data — and written down because it
  is otherwise unrecoverable: the password was generated when the user was
  created and reset by hand afterwards.
- its workspace, `0c839c31-4a49-485b-a9f9-b2e4af479b8b`, created by the signup
  trigger. Needed by hand until the application can start the connect flow
  itself:

  ```
  .../functions/v1/meta-oauth/start?workspace=0c839c31-4a49-485b-a9f9-b2e4af479b8b
  ```

- `connected_accounts` rows for the Facebook Page `1427711713749572`
  ("Rabta App") and the Instagram account `17841401424316998` (`djangus_w`),
  both connected through `meta-oauth`
- the conversations and messages from the real deliveries, plus the raw events

None of it is real seller data. Clear it whenever it stops being useful — but
note that removing the `connected_accounts` row will send later deliveries back
to being stored and skipped as `unknown-account`.

---

## Known defect

**Browser autofill fills the sign-in fields without Flutter seeing them.**
Observed in Chrome on 18 September: the email field shows a value, the
controller behind it is empty, and signing in fails with "missing email or
phone". The field looks filled and the button rejects it — a bad first minute,
on the first screen. Not fixed.

---

## Not built yet

- **Publishing the app.** The app is in development mode, so Meta only
  delivers messages from accounts holding a role on it. This is now on the
  critical path rather than a background task: Instagram cannot be verified
  until it is done.
- **Connecting an account from the interface.** The inbox is built and
  running, replying works and new messages arrive live. What is still missing
  is starting the connect flow without a URL pasted by hand.
- **The font is fetched rather than bundled.** Almarai renders, but through
  `google_fonts`, which pulls it from Google's CDN at runtime. Subsetting it to
  the two weights actually used and serving it ourselves is still to do, and
  until then every cold load makes a third-party request and shows a fallback
  face in the meantime.

---

## Fixed

**A photo-only message showed as a blank row in the inbox.** Found on
15 September by sending a real photo to the test Page: the message stored
correctly but the conversation's `last_message_preview` came back null, because
a message carrying only an attachment has no text. Customers in social commerce
send pictures of what they want, so this was a primary path rather than an edge
case.

Fixed on 17 September in `20260917000001_last_message_type.sql`. A
`last_message_type` column on `conversations` records what kind of thing the
last message was — `text`, `image`, `video`, `audio`, `file`, `share` or
`other` — set by the same trigger that already maintains the rest of the
summary. The client renders the localized label.

The two alternatives were both worse. Writing `'Photo'` in the trigger puts a
user-facing English string in the database, which contradicts the decision that
there are no hardcoded user-facing strings anywhere. Deriving the type
client-side would put a join on the conversation list query, which is the
hottest read in the product.

**Verified by six tests, each shown to fail against broken code:**

- With the old trigger restored, all six fail.
- With the out-of-order guard removed, exactly the late-delivery test fails —
  a message that was sent earlier but delivered later must not overwrite a
  newer summary.
- With unknown attachment types returning null instead of `other`, two fail.
  Meta adds attachment types without warning, and an unfamiliar one must
  neither fail the insert nor render blank.

The suite is 56 tests. The test harness now applies every file in
`migrations/` in order rather than only the initial one, so a new migration is
covered the moment it is added instead of silently going untested.

**Applied to the live database**, and confirmed on 18 September by selecting
`last_message_type` through the live REST API — with a nonexistent column as
the control, which returns 400 where the real one returns 200.

## Where we are

The blocker recorded on 14 September is resolved. Meta's reorganisation around
**use cases** mattered because it decides how a seller connects, and that is now
settled in `DECISIONS.md`: **Facebook Login for Business only**, with Instagram
reached through the seller's linked Page rather than through Instagram's own
login. One connect flow covers both platforms.

The webhook callback has been registered in the Meta app dashboard against the
**Page** and **Instagram** objects, both pointing at the live endpoint with the
same verify token.

**A real Meta delivery has now been received and processed end to end.** A
message sent to the connected Page on 15 September arrived, passed signature
verification, parsed with nothing skipped, and produced a conversation and a
message row. `window_expires_at` was set to exactly 24 hours after the
customer's own timestamp, computed from Meta's milliseconds rather than ours.
The signup trigger also fired against the live database, creating a workspace
automatically.

Four real deliveries have now been captured and turned into fixtures in
`tests/parse.test.ts`, recorded with their ids untouched: a plain text message,
an Arabic message, an image attachment and an echo. The suite is 50 tests. Each
fixture was checked by breaking the parser deliberately and watching that
fixture fail, so none of them are tests that pass against anything.

The conversation trigger was confirmed on the real echo: the seller's reply
cleared the unread count, advanced `last_message_at`, left `last_inbound_at`
alone, and **did not extend `window_expires_at`** — the 24 hour window still
runs from the customer's last message, which is the rule Meta actually enforces.

Arabic survived the round trip byte for byte, including the Arabic question
mark U+061F.

Still unproven against real payloads: **Instagram**. Everything above is
Messenger.

Also established, and still holding:

- The "Authorize callback URL" field is the **OAuth redirect**, not the webhook
  callback. The webhook callback lives under the Webhooks configuration. Putting
  the webhook URL in the OAuth field would look correct and silently do nothing.
- The **"Native or desktop app?" toggle stays off**. It tells Meta the client
  cannot keep a secret. Our token exchange happens in an Edge Function that
  holds the app secret, and the client never sees it. This was already correct
  when Phase One was a Windows application; now that it is a web application it
  is simply the ordinary setting.
- Subscribing fields in the dashboard is **not** enough on its own. Each account
  must also be subscribed through `POST /me/subscribed_apps`, which needs
  `pages_manage_metadata`. Miss it and the webhook verifies cleanly and then
  never fires. This belongs in `meta-oauth`, immediately after the token
  exchange.

### The connection flow

**Simplified on 17 September 2026** by the decision to ship a web application
rather than a Windows one — see `DECISIONS.md`. The earlier proposal is
recorded at the end of this section, because the reason it is gone is worth
keeping.

Not yet built:

1. The seller presses Connect in the application and is sent to Meta's approval
   page.
2. The seller approves, and Meta redirects to the `meta-oauth` callback.
3. That function exchanges the code for an access token server-side, stores it,
   and calls `/me/subscribed_apps` to subscribe the account to the webhook.
4. The function redirects the browser back to the application, which is already
   signed in and carries on.

The OAuth `state` parameter ties the flow back to the right seller and is the
CSRF protection at the same time. It is still required.

**The one thing to get right:** step 4 means `meta-oauth` performs a redirect
to an address after handling an access token. The destination must come from a
fixed allowlist inside the function and never from the request, or the callback
becomes an open redirect on the most sensitive endpoint in the system. This is
the only new risk the web flow introduces, and it replaces several harder
problems.

Registering the callback as the Edge Function's own URL rather than the
application's means the value entered in the Meta dashboard is the same in
development and production. Where the browser goes after the exchange is the
function's decision.

Planned redirect URL, to be entered in the Meta dashboard:

```
https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-oauth/callback
```

**Facebook Login for Business configuration id: `1063344539629710`**

Created 17 September. Not a secret — it appears in the login URL the browser
is sent to — so it lives here rather than in `.env`.

Facebook Login for Business does not use a plain OAuth dialog. The request
must carry `config_id`, and that configuration is what decides which
permissions are asked for and which assets the seller is offered to select:

```
https://www.facebook.com/v26.0/dialog/oauth
  ?client_id=<app id>
  &config_id=1063344539629710
  &redirect_uri=https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-oauth/callback
  &response_type=code
  &state=<random, ties the flow back to the seller>
```

This is also why Graph API Explorer stopped being able to issue Page tokens
for this app once Facebook Login for Business was added: Explorer sends no
`config_id`, so the login falls through to an ordinary user login with no
asset-selection step, and returns a user token every time.

*Superseded:* while Phase One was a Windows application, the plan was for the
callback to show a "you can close this window" page while the application
noticed the new account row through Realtime — chosen to avoid a loopback
listener or a `rabta://` URI scheme in the Windows registry, both of which fail
in ways a non-technical seller cannot diagnose. None of that is needed when the
application is already in the browser.

---

## Connecting accounts

`meta-oauth` is built and deployed. Two routes:

```
/meta-oauth/start?workspace=<uuid>   sends the browser to Meta
/meta-oauth/callback                 exchanges the code and stores what it finds
```

It exchanges the code, reads which Pages and Instagram accounts the token was
granted, stores `connected_accounts` and `account_tokens` for each, and calls
`/{page-id}/subscribed_apps` itself. That last step is the one that is invisible
and silent when missed.

**Proven on 17 September** against the live project: a Page was connected from a
browser, and a Messenger message sent afterwards arrived, parsed and appeared in
the inbox tables. The failure paths were tested too — unknown route, missing
workspace, absent state, tampered state, a seller pressing cancel — and the
signed state was checked in both directions, accepting a correctly signed value
and rejecting the same value with one character changed.

### Two Meta behaviours that are not in the documentation

Both were found by running the real flow, and both would have shipped as bugs.

**`/me/accounts` returns an empty array under Facebook Login for Business**, even
when the Page was explicitly granted. `debug_token` on the same token reported
`pages_show_list`, `pages_messaging`, `pages_manage_metadata` and
`pages_read_engagement`, each with `granular_scopes.target_ids` containing the
exact Page id that `/me/accounts` omitted. The documented way to list a seller's
Pages therefore reports that they have none — which is indistinguishable from a
seller who genuinely has none, and is the failure `ONBOARDING.md` says to detect
and explain. `meta-oauth` reads the granted ids from `debug_token` instead.

**`instagram_business_account` on a Page requires `instagram_basic`.** Without
it the field is simply absent rather than erroring, so the documented way to
find a seller's Instagram account silently returns nothing. The Instagram ids
are also present in `granular_scopes`, which is where `meta-oauth` reads them.

### Facebook Login for Business changes how tokens are obtained

Graph API Explorer cannot issue Page tokens for this app any more. Explorer
sends no `config_id`, so the login falls through to an ordinary user login with
no asset-selection step, and returns a user token every time. This is not a
misconfiguration and there is no way around it in Explorer — the OAuth flow
through `meta-oauth` is now the only way to obtain a Page token.

---

## Instagram: configured, not verified

Everything that can be checked is correct, and no Instagram message has ever
reached the webhook.

Confirmed:

- The account is Professional and linked. Meta itself reports
  `instagram_business_account` as `17841401424316998` (`djangus_w`) on the Page.
- It was granted to the app on the asset screen, and is stored in
  `connected_accounts` with its token.
- The Page's app subscription is `messages, messaging_postbacks, message_echoes`.
- **Connected tools → Allow access to messages** is on, in the Instagram app.
  This one is account-side, off by default, and invisible from the app
  dashboard — a seller will have to be walked through it.
- Direct messages reach the Page's inbox in Meta Business Suite.
- The function handles `object: "instagram"` end to end. A signed Instagram
  delivery replayed against the deployed endpoint on 17 September produced a
  conversation and a message with an Arabic preview, and the probe data was
  removed afterwards.

The remaining blocker is **development mode**. Meta only delivers from accounts
holding a role on the app, which is what blocked Messenger until the sending
account was an app administrator. Instagram has no equivalent that fits: the
Instagram Tester role resolves against a Facebook-linked identity, and a
standalone Instagram account created for testing has none, so Meta rejects it
with "does not resolve to a valid user id".

**The first thing to check once the app is published**, before anything else is
built on top:

```
entry.id == 17841401424316998   the Instagram account id, which is what we store
entry.id == 1427711713749572    the Page id, which would mean every Instagram
                                message is stored and then skipped as belonging
                                to an unknown account
```

Meta's documentation says the first. Nothing has confirmed it for this app.

---

## Replying works

Built and run on 18 September. `send-message` is deployed, and a reply typed
into the browser reached the customer with Meta echoing it back.

The function authorises as the seller and writes as the service role: the
conversation is read through the seller's own JWT so row level security proves
it is theirs, and only the service role touches `account_tokens`. Refusals come
back as codes and never sentences, so the interface picks the language.

**Three things were found by running it that no test had caught:**

- **CORS.** The function had no `Access-Control-Allow-Origin` and no preflight,
  so the browser blocked the call before it left the page. Every earlier check
  used curl, which does not enforce CORS. The origin allowlist built for the
  OAuth return now lives in `functions/_shared/origins.ts` and serves both.
- **The client blamed Meta for it.** A failure with no reason code was reported
  as "the platform did not accept this reply", which would send a seller off
  rewriting a message that was never the problem. A missing code now reads as
  unreachable, because our function always returns one.
- **The details pane and the composer contradicted each other** — "Reply window
  closed" beside "8h left to reply", about the same conversation, on the same
  screen. Both asked whether the customer wrote last; the right question is
  whether the window is open, which is what the server enforces. Now one
  predicate, `replyWindowOpen`, answers it for both.

Also fixed while looking: the thread opened at the oldest message and did not
follow a reply down, so a sent reply landed with its timestamp cut off by the
composer. The list is anchored at the newest message instead.

**Arabic went through the whole path**, typed into the composer in an English
interface, right-to-left in the box, and echoed back by Meta unchanged.

**Still to do here:** the seller's own sent bubble is built locally rather than
read back, so its id and timestamp are approximate until the conversation is
reopened. Nothing depends on either yet.

---

## Next

1. **Business verification and App Review, then publish the app.** This has
   moved from a background task to the blocking one. Instagram cannot be
   verified while the app is in development mode, and no seller outside the
   app's roles can connect at all. It runs in calendar time.
2. Capture a real Instagram delivery and check `entry.id` against the value
   stored for the account — see above. Everything else about Instagram is
   already configured and confirmed.
3. ~~Build `send-message`.~~ **Done 18 September**, and proven end to end.
4. Decide where the application is hosted, then add that origin to
   `functions/_shared/origins.ts`.

Before `meta-oauth` is exposed to a real seller it needs the return origin
validated against an allowlist before redirecting, which is not yet written
because there is no application to return to. A destination taken from the
request would make an open redirect of the most sensitive endpoint we have.

## Open questions

Carried from `DECISIONS.md`:

- Multiple Instagram accounts or Pages per seller.
- Whether Phase One links the same customer across channels. Proposed no, and
  close to settled: Meta's customer ids are scoped to the account they wrote
  to, so there is no supported way to connect them.
- Attachment media: stored or fetched on view.
- Where the web application is hosted, and on what domain.
- The six interface principles proposed below, and the palette with them.
- How a conversation near the end of its reply window is marked in the list,
  now that newest-first sorting no longer surfaces it.

---

## The interface

A read-only inbox is built and running against the live database: sign in, the
conversation list, the thread, and a details pane. Everything visual is settled
in `DECISIONS.md` — principles, palette, typography, layout, language.

**Built:**

- Sign-in, with the language choice on it, because being unable to read that
  screen is the one failure a seller cannot click past.
- The conversation list, in two groups: waiting for a reply with the longest
  wait at the top, then answered, newest first.
- The thread, with message direction taken per message rather than per locale.
- The details pane, above 1180px wide.
- Arabic and English throughout, Arabic as the template and the fallback.
- The app icon, generated into the web icon set by `tool/make_icons.py`.

**Replying is built.** The composer states the window before the seller types,
Enter sends and Shift+Enter breaks the line, and a reply that failed stays in
the box rather than asking the seller to type it again. Answering moves the
conversation out of the waiting group immediately, without a reload and without
dropping the inbox back to a spinner.

**Deliberately not built.** Realtime, so the list does not update until
reloaded. Marking a conversation read. Connecting an account from the
interface: that runs through `meta-oauth` in a browser, with the workspace id
in the URL.

**Verified in a browser**, in both languages, at desktop and phone width:
signing in, the list, opening a thread, Arabic and English messages side by side
in one conversation, the real image attachment, the reply window countdown, the
back gesture on a phone, and session restore on reload. Console clean.

**32 tests on the client, 93 on the backend.** The ones worth knowing about are
the ordering, which caught an inverted comparison that would have left every
answered conversation in the waiting group; the Arabic plurals; a scan of the
whole Arabic file for Eastern numerals, which caught a `٢٤` that two
spot-checks had missed; and a test that no two refusal codes share a sentence,
because a closed window and an expired connection need different actions from
the seller.

**Customers are named now.** Meta sends only an opaque id with a message, so
the name and picture are asked for separately, once per customer rather than
once per message. Proven live on 18 September: the deployed webhook filled in
the real name and profile picture, and a redelivery of the same event did not
ask Meta again.

The picture is stored as Meta's own URL rather than copied. Measured the same
day, the URL lasted about 30 days and was fetchable with no access token — the
same shape as attachment URLs. Profiles refresh at 25 days, which replaces the
URL before it breaks while a conversation is active. A dormant conversation's
picture eventually dies and the interface falls back to the monogram it already
draws, which is the right trade: a name identifies a customer, a picture
decorates them.

A customer whose name Meta withholds is recorded as an answer rather than a
failure. Without that distinction the lookup would run again on every message
they ever send.

**Instagram profiles are configured but unverified**, like everything else
Instagram. The fields differ — `username` is asked for there and deliberately
not on Messenger, because Graph rejects a whole request naming a field it does
not know rather than ignoring it.

Progress against Phase One is tracked in `CHECKLIST.md`.
