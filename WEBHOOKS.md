# Webhook Service

The webhook service is the part of Rabta that receives messages from Meta,
stores them, and sends replies back. It is being built as a standalone piece of
work with its own scope and its own definition of done.

It has no user interface. Its job is to make the database an accurate,
up-to-date mirror of what is happening in the seller's Instagram and Facebook
Messenger inboxes, and to send messages back out on request.

Product context is in `CLAUDE.md`. Settled decisions are in `DECISIONS.md`.

---

## Scope

**In scope**

- Receiving Meta webhook events for Instagram and Facebook Messenger.
- Verifying that events genuinely came from Meta.
- Turning raw events into conversations and messages.
- Sending outbound replies through the Graph API.
- Holding Meta access tokens securely.
- Tracking the reply window for each conversation.

**Not in scope**

- WhatsApp. Deferred — see `DECISIONS.md`.
- Push notifications. Phase One is a Windows desktop application and only needs
  realtime updates while running. Push returns with mobile.
- Any user interface.
- Linking the same customer across platforms.
- Automated or AI-generated replies.

---

## Shape

```
Meta  ──POST──>  meta-webhook  ──insert──>  webhook_events (raw)
                      │                           │
                   200 OK                    processor
                  (immediately)                   │
                                            conversations + messages
                                                  │
                                       Realtime ──> Flutter client


Flutter client ──> send-message ──> Graph API ──> Meta
                        │
                  messages (outbound)
```

Receiving and processing are deliberately separated. The receiver verifies the
request, stores the raw payload, and returns 200. Everything else happens after
the response has been sent.

### Why the split

Meta expects a fast 200 and penalises anything else. Slow or failing responses
are retried, and sustained failures can cause Meta to disable the webhook
subscription for the entire app — which would break message delivery for every
connected seller at once, not just the one whose event failed.

Storing the raw payload first also means no event is ever lost to a processing
bug. The payload is already on disk and can be reprocessed.

### The raw event table earns its place

During integration, the most common question is "what did Meta actually send?"
as opposed to what we assumed it would send. Without stored payloads that
question cannot be answered. The table doubles as the retry buffer, so it is
one table serving two real purposes.

A simpler design — one function that parses and inserts inline, with no raw
table — would work at low volume. It is not recommended, but it is a legitimate
fallback if the two-stage version proves awkward.

---

## Endpoints

### `GET /meta-webhook` — verification

Meta verifies the endpoint before it will deliver anything. It sends:

| Parameter          | Meaning                                  |
| ------------------ | ---------------------------------------- |
| `hub.mode`         | `subscribe`                              |
| `hub.verify_token` | A secret string we choose and configure  |
| `hub.challenge`    | A random value to echo back              |

Compare `hub.verify_token` against our configured value. If it matches, respond
`200` with `hub.challenge` as **plain text and nothing else**. Otherwise respond
`403`.

This handshake is required to register the webhook at all, and it runs again on
every subscription change — the endpoint must always support it, not just at
setup time.

### `POST /meta-webhook` — delivery

Meta posts a batch of events. The body looks like:

```jsonc
{
  "object": "page",          // or "instagram"
  "entry": [{
    "id": "<page or ig account id>",
    "time": 1234567890,
    "messaging": [{
      "sender":    { "id": "<customer scoped id>" },
      "recipient": { "id": "<our account id>" },
      "timestamp": 1234567890,
      "message": {
        "mid": "<unique message id>",
        "text": "...",
        "attachments": [ /* optional */ ],
        "is_echo": false     // present when we or the seller sent it
      }
    }]
  }]
}
```

A single request can carry multiple entries, and each entry multiple events.
Process all of them. Events other than messages arrive here too — delivery
receipts and read receipts — and can be ignored for now, but should not cause
errors.

Respond `200` as soon as the payload is stored.

---

## Security

These three points are the security boundary of the whole product. The endpoint
is public, and it writes into sellers' inboxes.

### Verify the signature, on the raw bytes

Every POST carries an `X-Hub-Signature-256` header of the form `sha256=<hex>`.
It is an HMAC-SHA256 of the request body, keyed with the Meta app secret.

Compute the HMAC over the **raw body text, before parsing**. Parsing and
re-serialising JSON changes the bytes and the signature will never match.
Reject any request that fails the check.

Without this, anyone who discovers the URL can post fabricated messages into any
seller's inbox and the application will display them as genuine customer
messages.

### Deploy with JWT verification disabled

Supabase Edge Functions require an auth token by default. Meta does not send
one, so this function must be deployed with `verify_jwt = false`.

This is precisely why the signature check must be correct — it is the only
thing protecting the endpoint.

### Access tokens never leave the server

Meta access tokens are keys to a seller's business inbox. They are stored in
Supabase Vault, or in a table whose row level security policy denies all access
and which only the service role can read.

The Flutter client never receives a token and never calls the Graph API
directly.

---

## Data

Exact schema is decided during implementation. This is the intended shape.

**`workspaces`** — the owner of everything. One member for now; see
`DECISIONS.md`.

**`connected_accounts`** — one row per connected Instagram account or Facebook
Page.
`workspace_id`, `platform`, `external_id`, `name`, `avatar_url`, token
reference, `connected_at`.

**`conversations`** — one row per customer per connected account.
`account_id`, `customer_external_id`, `customer_name`, `customer_avatar_url`,
`last_message_at`, `last_message_preview`, `unread_count`, `window_expires_at`.

**`messages`**
`conversation_id`, `mid` (unique), `direction`, `text`, `attachments`,
`sent_at`, `delivery_status`.

**`webhook_events`** — raw ingest.
`received_at`, `object`, `payload`, `signature_valid`, `processed_at`, `error`.

### The customer identifier is scoped to the account

The id Meta gives for a customer is scoped to the Page or Instagram account
they wrote to. The same person messaging two different Pages appears as two
unrelated ids, and there is no supported way to connect them.

This is worth knowing because it means cross-channel customer identity is not
merely out of scope for Phase One — it is not straightforwardly possible with
these APIs. Any future work on customer profiles will need matching on
something else.

---

## Processing rules

### Duplicates will happen

Meta retries, and retries redeliver messages already stored. Every message
carries a unique `mid`. Put a unique constraint on it and upsert, so the
database enforces idempotency rather than relying on the code being careful.

### Order is not guaranteed

Events can arrive out of order. Always sort by Meta's `timestamp`, never by
arrival time or insertion order.

### Echoes must be handled, not discarded

When the seller replies from the real Instagram or Messenger app, Meta sends an
event with `is_echo: true`. Store these as outbound messages.

Handling them keeps the inbox correct even when the seller works outside Rabta.
Ignoring them means Rabta shows unanswered conversations the seller has already
replied to. During the period when a seller is still switching between apps —
which is every seller at the start — this is the difference between the product
looking reliable and looking broken.

### Reply window

Messenger and Instagram allow free replies for 24 hours after the customer's
last message. Set `window_expires_at` on the conversation to the inbound
message's timestamp plus 24 hours, every time an inbound message arrives.

Storing it means the interface can disable the composer *before* the seller
types, rather than showing a failure afterwards.

### Unread state

Increment `unread_count` on inbound messages that are not echoes. An echo means
the seller has seen and answered the conversation elsewhere, so it should clear
the unread state rather than add to it.

---

## Sending

`send-message` is a separate Edge Function, called by the Flutter client.

1. Authenticate the caller and confirm they own the conversation.
2. Check `window_expires_at`. Refuse with a clear, specific error if the window
   has closed — the client needs to distinguish this from a network failure.
3. Read the access token server-side.
4. Call the Graph API.
5. Store the outbound message with the `mid` Meta returns.

Step 5 matters for deduplication: the echo for this message will arrive by
webhook shortly afterwards, and it carries the same `mid`. The unique
constraint makes that collision harmless.

---

## Failure handling

- Signature failure — reject with 401, do not store, do not process.
- Processing failure — the raw event stays in `webhook_events` with `error` set
  and `processed_at` null. A periodic sweep retries unprocessed rows.
- Graph API failure on send — surface it to the client with enough detail to
  show a useful message. Expired tokens need to be distinguishable, since they
  require the seller to reconnect their account.

Token expiry deserves attention. When it happens, messages silently stop
arriving, and the seller has no way to know. The service should detect it and
mark the account as needing reconnection.

---

## Testing

```
cd supabase && npm test
```

No Docker, no Supabase CLI, no network, no Meta account. The suite runs in
about two seconds, so there is no excuse for not running it.

**How that is possible.** Two choices in the code make it so, and both should
be preserved:

- `signature.ts` and `parse.ts` use only Web Crypto and standard APIs, with no
  Deno-specific imports, so the same source runs in Supabase's runtime and
  under Node.
- `process.ts` depends on a narrow `Store` interface rather than on Supabase's
  query builder, so the routing and idempotency rules can be tested against an
  in-memory stand-in.

**The database is tested too, not assumed.** `tests/helpers/db.ts` boots a real
Postgres in-process using PGlite, applies the migration, and recreates the few
things Supabase provides that bare Postgres does not — the `auth` schema,
`auth.uid()`, the roles, and the default grants. The grants matter: without
them a policy test could pass merely because permission was denied, which
proves nothing.

This covers the parts that would otherwise only be discovered in production —
the conversation trigger's handling of out-of-order messages, and whether row
level security really stops one seller reading another's inbox.

**Tests are checked against deliberate breakage.** The suite has been verified
to fail when the signature check is disabled, when echo messages are attributed
to the wrong party, when a reply stops clearing unread state, and when tenant
isolation is removed. A test that passes against broken code is worse than
none.

### Not covered by the suite

These need a real Meta app and cannot be proven locally:

- The verification handshake against Meta's own checker.
- That Meta's live payloads match the shapes parsed here.
- Delivery through the Graph API.

---

## Deploying

Docker is not needed for any of this. `db push` and `functions deploy` both
work against the hosted project directly.

**One-off setup.** Both commands take their secrets interactively, so no key
needs to be pasted anywhere it would be recorded:

```
supabase login
supabase link --project-ref xejtffbpfguwvybrwqqj
```

`link` asks for the database password — the one set when the project was
created. It is recoverable from the Supabase dashboard under
Settings > Database if it has been lost.

**Applying the schema:**

```
supabase db push
```

**Configuring and deploying the function:**

```
cp supabase/.env.example supabase/.env     # then fill in the two Meta values
supabase secrets set --env-file supabase/.env
supabase functions deploy meta-webhook
```

The function is then reachable at:

```
https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-webhook
```

That URL is what goes into the Meta app dashboard as the callback URL, with
`META_VERIFY_TOKEN` as the verify token. Meta immediately sends the GET
handshake, so a successful save there is also the first real proof the endpoint
works.

`supabase secrets set` must run before the Meta configuration is saved. Without
`META_VERIFY_TOKEN` in place, the handshake fails and Meta refuses the URL.

---

## Local development

Meta requires a public HTTPS URL, so webhooks cannot be tested against
localhost. Either deploy a development function to Supabase, or run
`supabase functions serve` behind a Cloudflare tunnel.

Worth setting up before anything else — it is otherwise the slowest part of the
first day.

---

## Current state

The schema is applied and the receiving function is deployed to
`xejtffbpfguwvybrwqqj`. The endpoint is live at:

```
https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-webhook
```

Both `META_APP_SECRET` and `META_VERIFY_TOKEN` are configured, and the endpoint
has been confirmed to accept a request signed with the real app secret and to
reject a forged one.

The remaining step is registering the URL above in the Meta app dashboard as
the webhook callback, with `META_VERIFY_TOKEN` as the verify token, then
subscribing to the `messages` and `messaging_postbacks` fields and connecting a
Page or Instagram account.

`send-message` is not built yet, so replies cannot be sent from the application
yet — messages only travel inbound.

### Proven against the live deployment

Verified by signing real requests to the deployed endpoint and reading what
reached the database, with all test data removed afterwards:

- The verification handshake echoes the challenge, and refuses a wrong token.
- Unsigned, forged, and tampered-body requests are all rejected with 401.
- A correctly signed delivery is accepted and stored.
- A customer message creates a conversation, with unread state and a reply
  window 24 hours out.
- Redelivery of the same payload creates no duplicate and does not inflate the
  unread count.
- An echo is stored as outbound in the same conversation and clears the unread
  count.
- An event for an account not connected here returns 200 rather than failing.
- With no app secret configured, a previously valid signature is rejected.

## Done when

- [x] A request with an invalid signature is rejected.
- [x] Replaying the same webhook payload twice creates no duplicate rows.
- [x] A reply sent from the seller's own app appears as an outbound message.
- [ ] A message sent from a real Facebook Messenger account appears in the
      database within seconds.
- [ ] The same for Instagram.
- [ ] A reply sent through `send-message` arrives on the customer's phone.
- [ ] A conversation older than 24 hours reports its window as closed.

The unchecked items need a real Meta app. The mechanics behind them are tested;
what is unproven is Meta's live behaviour against them.

---

## Open

- Attachments: whether media is copied into our own storage or fetched on view.
  Meta's attachment URLs expire.
- Whether to process delivery and read receipts, or continue ignoring them.
- How the sweep for failed events is scheduled.
