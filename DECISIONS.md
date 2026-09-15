# Decisions

This file records decisions that have been made, why they were made, and what
they commit us to. `CLAUDE.md` describes what the product should be. This file
describes what we have chosen and settled. `WEBHOOKS.md` specifies the webhook
service, which is being built as a standalone piece of work.

When a decision changes, edit the entry and note the change. Do not delete
history — knowing that something was reconsidered is useful.

---

## Decided

### 2026-09-14 — Phase One covers Instagram and Facebook Messenger only

WhatsApp is deferred to a later phase.

**Why:** WhatsApp is not a third variation of the same integration. It runs on
the WhatsApp Business Platform, requires separate business approval, and a
phone number connected to the API can no longer be used in the WhatsApp
Business app on the seller's phone. Asking a seller to give up the app they
currently run their business from is a hard sell and a real risk to adoption.

Instagram and Messenger share nearly the same API surface, so supporting both
costs much less than twice the work of supporting one.

**Consequences:** Phase One ships two connections. Nothing in the data model
should assume there will only ever be two — WhatsApp is deferred, not
cancelled, so "platform" stays an open set.

---

### 2026-09-14 — Flutter client plus a managed backend

The application is not a standalone Flutter app. It is a Flutter client talking
to a hosted backend.

**Why:** Meta delivers messages by pushing them to a webhook — a public HTTPS
endpoint that must be reachable whether or not the seller has the app open. A
mobile client cannot receive those. The backend also holds the Meta access
tokens, which must never be stored on a device.

---

### 2026-09-14 — Supabase as the backend

**Why:** The data is relational — accounts, conversations, messages, unread
state, sorted by recent activity and filtered by platform. Postgres handles
that with a query and an index. In a document store, unread counts become
counters maintained by hand in every write path, and they drift.

Row Level Security enforces tenant isolation in the database itself rather than
depending on every query being written correctly. The application holds other
people's customer conversations, so that guarantee is worth having.

Pricing is a free tier and then a flat monthly cost, rather than metered per
read with no hard spending cap. An inbox with live listeners is exactly the
workload that generates reads.

**Consequences:** Supabase has no push notifications. This does not matter in
Phase One, because the Windows application only needs realtime updates while it
is running. When mobile arrives, Firebase Cloud Messaging fills the gap, called
from a Supabase Edge Function. FCM is free at this scale.

---

### 2026-09-14 — Windows desktop first

Phase One ships a Windows desktop application. Mobile comes later.

**Why:** Replying to customers at volume is a typing task, and a keyboard is
far faster than a phone. The natural inbox layout — conversation list beside
the open conversation — needs the screen space. Many sellers in the target
market already work from a PC at a shop or desk.

**Consequences:**

- Push notifications are not needed in Phase One. A desktop application that
  stays open only needs realtime updates, a local notification and a taskbar
  badge. This removes Firebase Cloud Messaging from the Phase One scope
  entirely — it returns when mobile does.
- The seller only sees new messages while the application is running. This is
  a real gap compared to a phone, and part of why mobile follows.
- Connecting a Meta account is harder on desktop than on mobile. See below.
- Distribution is our problem, not an app store's. Installer, code signing and
  updates are work that mobile would have handled for us.

---

### 2026-09-14 — One seller per workspace, no roles in Phase One

Phase One has a single user who owns everything and handles all connected
platforms. There are no roles, no invitations, and no permissions.

Roles and role-based features come later, once a basic product is running.

**Why:** Team features are a large amount of work — invitations, permissions,
assignment, conflict handling when two people answer at once — and none of it
helps the first sellers using the product.

**Consequences:** Connected accounts and conversations belong to a
**workspace**, not directly to a user, even though every workspace will have
exactly one member. Adding a team later is then a membership table rather than
re-parenting every row in the database and rewriting every security policy.
This is invisible to the user and costs one extra table now.

---

### 2026-09-14 — Arabic and RTL support from day one

Arabic is a primary language for this product, not a later addition. The
application supports Arabic and English from the first screen built.

**Why:** Right-to-left layout is not a feature that can be retrofitted. It
affects layout, alignment, icons, animation direction, fonts and text handling
in every widget. Adding it after the fact means revisiting every screen.

**Consequences:**

- No hardcoded user-facing strings, ever. Localization files from the first
  screen.
- Use direction-aware layout throughout — `EdgeInsetsDirectional` rather than
  `EdgeInsets`, start/end rather than left/right.
- Choose a font with proper Arabic glyphs. The Material default is not
  adequate for Arabic.
- **Message content direction is separate from interface direction.** A seller
  using the English interface will receive Arabic messages, and the reverse.
  Each message bubble takes its direction from its own text, not from the
  app's locale. Getting this wrong makes conversations unreadable, and it is
  easy to miss because it looks correct while testing in one language.

---

### 2026-09-15 — Sellers connect through Facebook Login for Business only

Instagram is connected through the seller's Facebook Page, not through
Instagram's own login. One connection flow covers both platforms.

Meta offers two ways to reach Instagram messaging:

- **Instagram API with Instagram Login** — the seller signs in with Instagram
  and no Facebook Page is involved. Uses `instagram_business_manage_messages`.
- **Instagram API with Facebook Login** — the seller signs in with Facebook and
  their Instagram account must be linked to a Page. Uses
  `instagram_manage_messages` and `pages_show_list`.

We use the second.

**Why:** Phase One covers Messenger as well, and Messenger requires Facebook
Login for Business regardless. Supporting Instagram Login too would mean a
second OAuth flow, a second token type and a second send API to build and
maintain in `send-message` — close to twice the connection work — to serve
sellers who could instead link a Page once.

One button that connects everything is also the better first five minutes for a
non-technical seller than being asked to choose between two login options whose
difference they have no way to judge.

**Consequences:**

- A seller whose Instagram is not linked to a Facebook Page cannot connect
  until they link it. We cannot do this for them, so the connect screen has to
  explain it clearly when it happens. This is the main cost of the decision.
- Instagram messages are sent and received through the Messenger Platform's
  Instagram Messaging API, not Instagram's own messaging API.
- Permissions requested at connection time:
  `pages_show_list`, `pages_messaging`, `pages_manage_metadata`,
  `pages_read_engagement`, `instagram_basic`, `instagram_manage_messages`,
  and `business_management`, which `pages_messaging` depends on.
- `pages_manage_metadata` is what allows subscribing an account to our webhook.
  Without it messages never arrive.

**Reconsider if** real sellers turn out to be blocked by the Page requirement
often enough to matter. Adding Instagram Login later is additive — `platform`
is already an open set — so this is not a one-way door.

---

## Platform constraints

These are not choices. They are limits Meta imposes, recorded here so they are
not rediscovered later as bugs.

### Replies are only allowed inside a time window

A seller cannot reply to a customer whenever they want. Messenger and Instagram
allow free replies for 24 hours after the customer's last message, extendable
to 7 days with the human agent tag.

This is a user-facing problem, not a technical detail. If the seller opens an
old conversation, types a reply and watches it fail, the application looks
broken. The inbox must make the state of a conversation clear before the seller
starts typing.

### Message history starts when the account is connected

Webhooks only deliver messages from the moment of connection. Messenger and
Instagram offer a conversations read API that can pull some history, but its
limits need to be verified before we promise anything.

"View its message history" in `CLAUDE.md` means history the application has
seen, not everything that ever happened on the account.

### Attachment media expires

Meta returns attachment URLs that stop working after a period. Whether media is
copied into our own storage or fetched on view is an open question, listed
below.

Measured on 15 September 2026 from a real image sent to the test Page:

- The URL is on `scontent.xx.fbcdn.net` and is **publicly fetchable with no
  access token** — a plain GET returned the PNG.
- Its `oe=` query parameter is a hex Unix timestamp marking expiry. For that
  delivery it was **roughly 30 days** after the message arrived.
- The file was 5.9 MB, sent from a phone without any resizing. Storing media
  means storing files of that size, not thumbnails.

Thirty days is long enough that proxying on view is viable for recent
conversations and guarantees nothing for older ones. Both facts — public access
and the 30 day window — should be re-checked before relying on them, since
neither is documented and Meta can change both.

### Access requires review, and review takes time

Business verification and App Review for the messaging permissions are required
before anyone other than us can connect an account. This runs in calendar time,
not development time, and should be started early and in parallel with
building.

---

## Open

These need answers. Several affect the data model, so the earlier they are
settled the cheaper they are.

- **How does a seller connect a Meta account on desktop?** The Meta login is a
  web flow that redirects back to an address. Mobile has deep links for this;
  Windows does not, so it needs either a loopback listener or a registered URI
  scheme. This lands at the most fragile moment in the product — a
  non-technical seller's first five minutes — so it deserves a proper answer
  rather than whatever is quickest.

  Narrowed on 15 September 2026: *which* login the seller uses is now settled
  above — Facebook Login for Business. What remains open is only how the
  browser gets back to the desktop application afterwards. `STATUS.md`
  proposes redirecting to an Edge Function and letting the application notice
  through Realtime, which avoids both the loopback listener and the URI
  scheme. Proposed, not yet agreed.

- **Code signing for the Windows installer.** Unsigned applications show
  "Windows protected your PC" on first run. For an audience being asked to
  connect their business accounts, that warning is a serious trust problem.
  Certificates cost money annually and need to be budgeted.

- **Can one seller connect more than one Instagram account or Facebook Page?**
  Common for people running several shops.

- **Which numerals in Arabic?** Western (1234) or Eastern Arabic (١٢٣٤) for
  times, counts and dates. A small decision, but it should be consistent and
  made once.

- **Does Phase One link the same customer across channels?** Proposed: no. A
  customer who writes on both Instagram and Messenger is two conversations.
  Cross-channel customer profiles are listed in `CLAUDE.md` as a future phase.

- **Attachment media: stored or proxied?** Depends partly on what Supabase
  storage costs at the volumes we expect. Also tracked in `WEBHOOKS.md`.
