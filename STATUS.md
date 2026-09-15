# Where we are

Updated 15 September 2026.

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

- auth user `webhook-test@rabta.local`, and the workspace its signup trigger
  created
- a `connected_accounts` row for the Facebook Page `1427711713749572`
  ("Rabta App"), connected by hand rather than through OAuth, which does not
  exist yet
- the conversation and message from the real delivery, plus the raw events

None of it is real seller data. Clear it whenever it stops being useful — but
note that removing the `connected_accounts` row will send later deliveries back
to being stored and skipped as `unknown-account`.

---

## Not built yet

- **`send-message`.** Messages travel inbound only. Replies cannot be sent from
  the application.
- **Account connection (OAuth).** No seller can connect an account yet.
- **The Flutter application.** Still the default scaffold — no interface exists.

---

## Known defect

**A photo-only message shows as a blank row in the inbox.**

The conversation trigger sets `last_message_preview` from the message text, and
a message carrying only an attachment has no text. Found on 15 September by
sending a real photo to the test Page: the conversation's preview came back
null while the message itself stored correctly.

This matters because customers in social commerce send pictures of what they
want, so it is not a rare edge case.

The obvious fix is the wrong one. Writing `'Photo'` in the trigger puts a
user-facing English string in the database, which contradicts the decision that
there are no hardcoded user-facing strings anywhere.

Proposed, not yet agreed: add `last_message_type` to `conversations`, set it in
the trigger, and let the client render the localized label. Keeps language out
of the database and the inbox query a single read. The alternative is deriving
it client-side from the last message's attachments, which adds a join to the
hottest query in the application.

---

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
- The **"Native or desktop app?" toggle stays off**, despite Phase One being a
  Windows application. It tells Meta the client cannot keep a secret. Our token
  exchange happens in an Edge Function that holds the app secret, and the
  Windows application never sees it.
- Subscribing fields in the dashboard is **not** enough on its own. Each account
  must also be subscribed through `POST /me/subscribed_apps`, which needs
  `pages_manage_metadata`. Miss it and the webhook verifies cleanly and then
  never fires. This belongs in `meta-oauth`, immediately after the token
  exchange.

### The proposed connection flow

Recommended, not yet agreed or built:

1. The application opens the seller's normal browser at Meta's approval page.
2. The seller approves, and Meta redirects the browser to an Edge Function.
3. That function exchanges the code for an access token server-side and stores
   it. The browser shows a plain "you can close this window" page.
4. The desktop application notices through Realtime, because it is already
   watching the database, and continues on its own.

Step 4 is what makes this workable. The usual desktop approaches — a localhost
listener, or registering a `rabta://` URI scheme in the Windows registry — are
fiddly and fail in ways a non-technical seller cannot diagnose. Since Realtime
is already there for messages, the application can watch for the new account
row instead.

The OAuth `state` parameter ties the browser flow back to the right seller, and
is the CSRF protection at the same time.

Planned redirect URL, to be entered in the Meta dashboard:

```
https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-oauth/callback
```

---

## Next

1. Capture a real Instagram delivery. The Page is linked to the Instagram
   account, so what remains is configuring the `Instagram` webhook object with
   the same URL and verify token, subscribing `messages` on it, and confirming
   the account is a Professional one. Messenger shapes are all captured.
2. Decide the blank preview question above, and apply it.
3. Agree the connection flow described above.
4. Build `meta-oauth`, requesting `pages_show_list`, `pages_messaging`,
   `pages_manage_metadata`, `pages_read_engagement`, `instagram_basic`,
   `instagram_manage_messages` and `business_management`, and calling
   `/me/subscribed_apps` once the token is stored.
5. Build `send-message`.
6. Start the Flutter application.

Business verification and App Review need starting early — they run in calendar
time, and no one outside the app's roles can connect until they are through.

## Open questions

Carried from `DECISIONS.md`:

- Multiple Instagram accounts or Pages per seller.
- Whether Phase One links the same customer across channels. Proposed no, and
  close to settled: Meta's customer ids are scoped to the account they wrote
  to, so there is no supported way to connect them.
- Western or Eastern Arabic numerals in the Arabic interface.
- Attachment media: stored or fetched on view.
- Code signing for the Windows installer, which costs money annually.
- The UI itself. Six principles were proposed and not yet agreed; a mockup was
  offered and not yet made.

---

Progress against Phase One is tracked in `CHECKLIST.md`.
