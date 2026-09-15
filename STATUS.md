# Where we are

Updated 14 September 2026.

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

- 46 local tests (`cd supabase && npm test`) covering signature verification,
  payload parsing, message processing, the database schema, the conversation
  trigger, and row level security. Runs in about two seconds with no Docker and
  no network.
- 13 checks against the live database, seeding data first so that the security
  checks proved something rather than querying empty tables.
- 19 checks against the deployed endpoint using genuinely signed requests.
- The suite was verified to fail when the code is deliberately broken.

All test data was removed afterwards; every table is empty.

---

## Not built yet

- **`send-message`.** Messages travel inbound only. Replies cannot be sent from
  the application.
- **Account connection (OAuth).** No seller can connect an account yet.
- **The Flutter application.** Still the default scaffold — no interface exists.

---

## Stopped here

We were about to design **how a seller connects their Meta account**, and hit
the fact that Meta has reorganised app configuration around **use cases**,
which changes where permissions and products are declared. This needs proper
understanding before going further, because it determines which permissions are
available and is painful to change afterwards.

Two things were established just before stopping, and both still hold:

- The "Authorize callback URL" field in the Meta dashboard is the **OAuth
  redirect**, not the webhook callback. The webhook callback lives under the
  Webhooks configuration. Putting the webhook URL in the OAuth field would look
  correct and silently do nothing.
- The **"Native or desktop app?" toggle should stay off**, despite Phase One
  being a Windows application. It tells Meta the client cannot keep a secret.
  Our OAuth exchange happens in an Edge Function that holds the app secret, and
  the Windows application never sees it.

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

1. Understand Meta's use cases model, and decide which use case and permissions
   Phase One needs.
2. Agree the connection flow above.
3. Build `meta-oauth`, so a seller can connect a Page or Instagram account.
4. Register the webhook callback in the Meta dashboard and watch a real message
   arrive. This closes the last unproven part of the webhook service — whether
   Meta's live payloads match the shapes we parse.
5. Build `send-message`.
6. Start the Flutter application.

---

## Open questions

Carried from `DECISIONS.md`:

- Which Meta app type and use case Phase One needs.
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
