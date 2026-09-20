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
Phase One, because the application only needs realtime updates while the seller
has it open in a browser tab. When mobile arrives, Firebase Cloud Messaging
fills the gap, called from a Supabase Edge Function. FCM is free at this scale.

---

### 2026-09-14 — Windows desktop first — superseded 2026-09-17

Phase One ships a Windows desktop application. Mobile comes later.

**Superseded by the web decision dated 2026-09-17 below.** The entry is
kept because its reasoning about keyboard and screen space still holds, and
because its consequences are the list the web decision cancels.

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

### 2026-09-17 — The application is a website, not a Windows desktop app

Phase One ships a web application, running in the browser. This supersedes the
Windows desktop decision above. Mobile still comes later.

**Why:** A seller can be using it seconds after opening a link, on whatever
machine is in front of them, with nothing to download and nothing to install.
For a product whose first five minutes decide whether it is adopted at all,
removing the install step removes the largest obstacle standing in front of it.
The original argument for desktop — a keyboard and the screen space for a
conversation list beside an open conversation — is satisfied just as well by a
browser on that same PC.

**Consequences:**

- **Connecting an account becomes the ordinary web OAuth flow, and this is the
  largest gain.** The whole problem of getting the browser back to the
  application after Meta's redirect — the loopback listener, the `rabta://` URI
  scheme, and the Realtime workaround proposed in `STATUS.md` to avoid both —
  existed only because the application was not itself in the browser. Now Meta
  redirects to the Edge Function, the function exchanges the code and subscribes
  the account, and then redirects the browser back to the application. There is
  no "you can close this window" page and nothing to notice after the fact.
- **A new hole opens where that one closed: the return redirect.** The Edge
  Function now sends the browser somewhere after the exchange. If the
  destination is carried in `state` and used without checking, that is an open
  redirect on an endpoint that handles access tokens. The return origin must be
  validated against a fixed allowlist held by the function, never taken from the
  request. This is the one thing the web flow makes easier to get wrong.
- The registered redirect URI stays the Edge Function's own URL in every
  environment, so development and production do not need separate entries in the
  Meta dashboard. Where the browser goes afterwards is the function's decision,
  not Meta's.
- **The installer, code signing, updates and the "Windows protected your PC"
  warning all disappear.** That removes an annual cost, a release process, and a
  trust problem placed immediately before the seller is asked to connect their
  business accounts.
- The application needs a hosted origin and a domain. That is now a Phase One
  requirement rather than an afterthought, and it is small work compared to what
  it replaces.
- Notifications still only reach a seller who has the tab open. Phase One keeps
  in-page notification and title badge, which is the same limit the desktop
  application had. Web Push can lift it later without a native app, but it is
  not Phase One.
- The "Native or desktop app?" toggle in the Meta dashboard stays off, as it
  already was. It is now straightforwardly correct rather than a subtlety that
  needed explaining.
- Mobile browsers get a usable inbox for free, which the desktop plan gave
  nothing toward. This is a side effect, not a reason, and a layout built for a
  wide screen is not a mobile product.

**The Flutter web concern, measured rather than argued.** A release web build
was produced on 17 September 2026 with Flutter 3.47.4 and it builds and runs.
The cost is first load: the current scaffold compiles to 504 KB of gzipped
JavaScript, and the renderer adds roughly 1.5–2 MB of gzipped WebAssembly on
top depending on the browser. So a cold first visit is on the order of 2.5 MB
before anything appears, cached from then on. That is the real cost of Flutter
on the web and it does not go away. It is paid once per seller rather than
every time, which is what makes it acceptable here — but it should be measured
again once there is an actual interface, because the JavaScript half grows with
the application while the renderer half does not.

**Arabic and right-to-left on the web renderer: tested, and it works.** This
was the real risk — not bundle size — because the inbox is a text-heavy,
bidirectional, Arabic-first product and Flutter draws its own text rather than
using the browser's. A throwaway probe was built and rendered in Chrome on
17 September 2026, using the real Arabic message captured in
`tests/parse.test.ts`. All five of the things that could have failed did not:

- Arabic letters shape and join correctly, rather than rendering as isolated
  forms.
- Bidirectional text is correct. `سعر iPhone 15 Pro هو 1200 دولار؟` keeps the
  Latin product name and the Western digits running left to right inside a
  right-to-left sentence.
- The Arabic question mark U+061F lands at the correct visual end.
- Eastern Arabic numerals `١٢٣٤٥٦٧٨٩٠` render.
- **Per-message direction works** — an English message nested inside a
  right-to-left interface takes its own direction, which is the case
  `CLAUDE.md` warns is easy to miss because it looks fine when testing in one
  language.

This tested the renderer, not the typography. Choosing a font with proper
Arabic glyphs is still required, and is a separate decision recorded above.

**Reconsider if** something in the real interface contradicts the probe — text
selection, input method behaviour while typing Arabic, or screen reader
support, none of which a static render exercises. Rebuilding this as a plain
web application against the same Supabase backend would cost the client only;
nothing in the backend, the schema or the webhook service assumes Flutter.

---

### 2026-09-17 — The inbox: layout, sort order, typeface and numerals

Four interface decisions taken together, because each one constrains the
others. Agreed by the product owner; the options and trade-offs were put side
by side before choosing.

**Two-pane layout.** The conversation list beside the open conversation.
Filters and platform controls sit above the list rather than in a column of
their own. Rejected: a three-pane layout, which spends a whole column on four
links when there is one seller and two platforms; and a right-hand customer
panel, which is the cross-channel customer profile that `CLAUDE.md` places in a
later phase.

**Sort order — revised the same day.** Newest-message-first was chosen first,
for familiarity. On review it was replaced by a **two-group order**: the
conversations still awaiting a reply come first, oldest wait at the top, and
everything already answered follows below them, newest first.

The original reasoning still holds for the second group and is kept there. What
changed is the recognition that the two conventions exist because there are two
different jobs. Personal messaging applications sort newest-first because the
reader is under no obligation to answer everyone. Customer-service inboxes sort
by longest wait because every item has to be served. Rabta looks like the first
and behaves like the second.

Newest-first is last-in-first-out, and a LIFO queue starves its oldest item: a
customer can sit at the bottom indefinitely while newer messages keep arriving.
With a hard 24-hour reply window, starvation is not slow service — it is a
conversation that can never be answered again.

**Almarai** as the single typeface, covering Arabic and Latin from one family,
at weights 300 for previews and 700 for names. Chosen on measured clarity rather
than on style.

**Alexandria was chosen first and then reversed on evidence.** The three
candidates were rendered as real conversation rows and their text measured at
identical weights and sizes on 17 September. Width decides here, because a
narrow list column shows as much of a customer's message as the typeface allows:

| Typeface | Arabic 12.5/300 | Arabic 13.5/700 | Latin 12.5/300 |
|---|---|---|---|
| Almarai | **151.9 px** | **167.7 px** | 183.0 px |
| Cairo | 155.0 px | 171.0 px | **172.9 px** |
| Alexandria | 157.0 px | 175.9 px | 204.9 px |

Almarai is the narrowest in Arabic, which is the language that matters most
here, and Alexandria is the widest in both — 18% wider than Cairo in Latin. All
three shape Arabic correctly, so none was disqualified on rendering; the
decision came down to how much of a message survives in the column. Cairo wins
on Latin alone and is the runner-up.

Almarai also ships only 300/400/700/800 rather than a variable axis, which is an
advantage rather than a limit: those are the weights the design uses, and fewer
weights mean a smaller font payload on a web application whose first load
already costs about 2.5 MB.

*Superseded reasoning:* Alexandria was originally argued for on being less
common than Cairo, and therefore less likely to look templated. That was the
wrong criterion. Clarity in a dense bilingual list read all day is decided by
legibility and width, not by how many other products use the face.

**Western numerals (1234)** throughout, including in the Arabic interface, for
times, counts, prices and dates. This closes the numerals question open since
14 September.

**Consequences:**

- **The two-group order removes the starvation problem rather than papering
  over it.** The conversation closest to losing its reply window is at or near
  the top of the first group by construction, so no separate urgency marker is
  needed to rescue it. A row state for a window about to close is still worth
  having, but it is now a refinement rather than a defect being patched.
- **It needs no schema change.** `last_message_at` advances on every message
  while `last_inbound_at` advances only on inbound ones, so a conversation is
  awaiting a reply exactly when `last_message_at = last_inbound_at`. Both
  columns already exist and the trigger already maintains them. An index on
  `(workspace_id, last_inbound_at)` is worth adding for the list query.
- **The cost is that it is not what Messenger does.** The divider between the
  groups has to carry that meaning in plain language — "waiting for a reply" —
  so the order reads as deliberate rather than arbitrary. When the seller has
  answered everyone the first group is empty, which is a useful thing to see
  rather than a blank state to apologise for.
- **Weight contrast does more for scannability than the family does.** Names at
  700 against previews at 300 let the name detach at a glance; the same families
  at 300/500 did not. Use 300 for previews and 700 for names. Weights below 300
  are display-only and unusable at list sizes.
- The width figures above are canvas measurements at fixed sizes, which is the
  right way to compare but is not the same as the final column. Re-check once
  the list has a real width and real customer names in it.
- One typeface family means one font to load on a web application where first
  load already costs ~2.5 MB. Subset it to the weights actually used.
- Western numerals must be applied deliberately rather than inherited, since
  some Arabic locale settings will otherwise render Eastern numerals for dates
  and times.

**Verified, not assumed:** Alexandria was rendered in Chrome on 17 September
with the real Arabic message from `tests/parse.test.ts`. Shaping, joining,
bidirectional text with Latin product names and Western numerals, and the Latin
side of the family were all checked visually at display and interface sizes.

---

### 2026-09-18 — The interface: principles, palette, language and layout

Settled over one day of building and looking, so the reasoning below is what
survived seeing it on screen rather than what was proposed in the morning.

**Six principles.** They exist to give the interface a point of view, because
the failure mode for a product like this is not ugliness — it is looking like
every other generated dashboard.

1. **The list is the product.** The seller lives in the conversation list, not
   in the thread. Anything added to a row has to displace something already
   there.
2. **Colour means something, or it is absent.** One accent, for the seller's
   own actions and their own words. Red only for a reply window about to close.
   Platform shown as a mark, never by tinting the interface.
3. **The reply window is stated before the seller types, not after.** A reply
   that fails once written is a design failure, not an error message.
4. **Every message takes its direction from its own text**, never from the
   interface language.
5. **Weight and space carry hierarchy — not boxes.** No card per conversation,
   no elevation, no one border radius applied to every surface.
6. **Motion only confirms an action.** Nothing animates on arrival or on load.

**The palette is violet on white, and the accent is sampled from the app icon.**

| Role | Light | Used for |
|------|-------|----------|
| ground | `#FAF8FC` | behind everything |
| surface | `#FFFFFF` | the list, the thread header, the customer's bubbles |
| raised | `#F2EAFC` | a row that is open or hovered |
| line | `#E5DCF4` | hairlines inside a pane |
| edge | `#CFBDEE` | boundaries between panes, and group rules |
| ink | `#1B1526` | names, message text |
| muted | `#6E6880` | previews, timestamps |
| accent | `#6010C0` | the seller's own actions and words, and nothing else |
| urgent | `#D1365B` | a reply window about to close, and nothing else |

*Superseded on the same day:* a near-white canvas with a deep teal accent, then
a deep teal shell behind the list. The first read as unfinished rather than
restrained; the second was replaced when the brief changed to something closer
to the platforms the product lives inside. The teal is gone entirely.

**`line` and `edge` are two colours on purpose.** A single neutral hairline at
this weight disappears against a near-white ground, which is what made the panes
read as one undifferentiated sheet. `edge` is tinted toward the accent and
carries only the boundaries that matter.

**Colours are a `ThemeExtension`, not constants.** Widgets read
`context.rabta.ink`, and `RabtaColors.dark` is already written beside the light
scheme, so dark mode is a toggle and one line in `main.dart` rather than a sweep
through every widget. The dark values were chosen with the light ones in front
of us rather than guessed later.

**Contrast, measured rather than assumed:** white on accent 9.00, ink on
surface 17.77, accent on surface 9.00, muted on surface 5.31, urgent on surface
4.78. AAA on everything structural, AA on secondary text.

**Three panes, by width.** Under 760 the list and the thread take turns; from
760 both show; from 1180 a details pane joins, carrying who the customer is and
the state of the reply window. The thread was previously taking a whole wide
screen for a message column capped at 470px, which does not make it more
readable. What the details pane may contain is bounded by Phase One — no
orders, no products, no notes, no tags — because an empty heading promising
something that does not exist is worse than not having the pane.

**The wait rail is the one loud element.** A vertical gauge on every waiting
row showing how much of the 24 hour window is left, and the same gauge enlarged
in the empty reading pane and lying down in the details pane. Length is the
reading, not colour, so it works without knowing what any colour means and for
someone who cannot distinguish the red. Colour joins only in the last four
hours.

**Every string is localised, with Arabic as the template.** `lib/l10n/app_ar.arb`
is the source and English is the translation, not the other way round. Arabic is
also the fallback locale: an unrecognised browser language lands on Arabic. The
seller can override with the switch on the sign-in screen or `?lang=`.

- Arabic plurals go through ICU, because the language distinguishes singular,
  dual, and small from large plurals — `زبون واحد ينتظر`, `زبونان ينتظران`,
  `3 زبائن`. String interpolation is wrong for every count but the large ones.
- Western numerals throughout, including in Arabic. `٢٤` was written into one
  string by hand and survived two spot-checking tests, so the suite now scans
  the whole file for Eastern digits.
- Interface direction follows the locale. Direction is set by hand in exactly
  two places: the wordmark, which is a lockup, and message content.

**The name is ربطة — a tie.** Not رابطة, which is a league or an association,
and which was used by mistake for half a day. The Latin "Rabta" is a
transliteration of it rather than the other way round, so the two are set at
equal weight in `lib/wordmark.dart` and never drift apart.

**Consequences:**

- The app icon is the brand's fixed point. The interface accent was changed to
  match it rather than the reverse, because the two sit side by side in a
  browser tab and the icon is the harder one to change later.
- Icons are generated by `tool/make_icons.py` rather than exported by hand. The
  source artwork sits on white rather than transparency, and its padding is
  right for a phone home screen and wrong at 16px, where the interlocking
  bubbles close into a smudge — so each size is trimmed differently.
- Platform marks are drawn as paths in `lib/platform_icon.dart`.
  `font_awesome_flutter` does not compile against Flutter 3.47, where
  `IconData` became a final class it can no longer extend. Worth knowing that
  `flutter analyze` passed and only `dart2js` failed.

---

### 2026-09-18 — Replying: what decides it, what it says, and how it is sent

Settled while building the composer, because each question only became real
once there was a box to type into.

**The reply window decides whether a seller may reply — not who wrote last.**
These are different questions and conflating them is the mistake this entry
exists to prevent. Whether the customer wrote last says who is *waiting*, which
is what the two-group list order is built on. Whether Meta will accept a reply
is decided by the 24 hours since the customer's message, and a seller who has
already answered may follow up for as long as those run.

Reading it the wrong way put **"Reply window — Closed" beside "8h left to
reply"**, about the same conversation, on the same screen, the first time both
panes were open together. Both now go through one predicate,
`replyWindowOpen`, which tests exactly what `send-message` tests on the server.
Client and server disagreeing here means the interface refuses what the
platform would have accepted, or offers what it would not.

**The server returns a refusal code; the client writes the sentence.** Same
reasoning that put `last_message_type` in the database rather than the word
"Photo": the server does not choose the seller's language. The codes are
`empty`, `too_long`, `window_closed`, `no_window`, `not_found`, `disconnected`,
`rejected` and `unreachable`.

- **`no_window` is not `window_closed`.** A customer who has never written is a
  different situation from one whose window has run out, and a seller can act
  on the difference. A test asserts no two codes share a sentence.
- **An unfamiliar code reads as a plain refusal.** Meta adds error codes
  without warning, and a wrong explanation is worse than an honest "this did
  not send".
- **An answer carrying no code at all means we never heard from our own
  function**, so it reads as unreachable rather than as Meta refusing. Getting
  this wrong sends a seller off rewriting a message that was never the problem.

**Enter sends; Shift+Enter breaks the line.** This is a keyboard job done all
day, and it is what Messenger itself does. A reply that fails stays in the box —
asking a seller to type it again is the worst thing this screen could do.

**Answering updates the list locally rather than reloading it.** The
conversation leaves the waiting group the instant Meta accepts the reply, with
no round trip and no spinner across an inbox the seller is reading.
`Conversation.afterReply` makes the same four changes the database trigger
makes, and deliberately leaves `window_expires_at` alone, because answering
does not extend the window.

**The thread is anchored at its newest message**, with `reverse: true` rather
than by scrolling after the fact. Scrolling afterwards races the layout, and it
lost: a sent reply landed with its timestamp cut off behind the composer.

**Consequences:**

- The sent bubble is built in the client rather than read back, so its id and
  timestamp are approximate until the conversation is reopened. Nothing depends
  on either, and reading it back would cost a round trip on the path that most
  needs to feel immediate.
- **The origin allowlist is now shared.** `functions/_shared/origins.ts` serves
  both the OAuth return redirect and the CORS check on `send-message`, so an
  origin cannot be trusted for one and not the other, and the production domain
  is one edit. CORS is not optional here: without it the reply is sent or
  refused perfectly well and the seller sees neither — which is exactly what
  happened, because every check until then had used curl, which does not
  enforce it.
- The echo of our own reply needed no new code. Storing the message under the
  id Meta returns makes the echo collide with the existing unique `mid`.

---

### 2026-09-18 — Who the customer is, and how the inbox stays current

**The name and picture are asked for once per customer, not once per message.**
Meta delivers a message with an opaque sender id and nothing else, so every row
in the inbox read "Customer" — which defeats the list the whole product is built
around. `conversations.customer_profile_fetched_at` records having asked.

Without that column there are only two available behaviours, and both are
wrong: ask on every message, which is a Graph call per message forever; or
never ask again for a customer whose name Meta withheld, which leaves them
nameless permanently. **A withheld name is recorded as an answer**, not as a
failure — Meta withholds names depending on the person's own settings, so it is
a normal outcome. An *error* records nothing and is retried.

**The picture is stored as Meta's URL, not copied into our storage.** Measured
18 September 2026: a real `profile_pic` URL carried `ext=1792333334`, about 30
days out, and was fetchable with no access token — the same shape as attachment
URLs, and the same 30 days. Profiles refresh at 25 days, replacing the URL
before it breaks while a conversation is active.

A dormant conversation's picture eventually dies. That is the right trade: a
name identifies a customer, a picture decorates them, and the interface already
draws a monogram when there is none. Copying every customer's picture into
storage would buy a graceful failure we already have. **This is a narrower
answer than the open attachments question** — it does not settle that one, where
the media *is* the message.

**Messenger and Instagram are asked for different fields.** `username` is an
Instagram idea, and Graph rejects an entire request naming a field it does not
know rather than ignoring it — so asking a Messenger id for a username loses
the name too. The Instagram half is unverified, like everything else Instagram.

**Realtime is a signal, not a source of data.** The payload is ignored: on any
change the list is read again through the ordinary query, so everything that
reaches the screen has passed row level security exactly as it would on a
reload. A change feed is the last place to start trusting rows about other
people's customers, and it costs one query per incoming message to avoid the
question entirely.

Subscribing to `conversations` alone is enough, because the trigger touches it
on every message in either direction.

**The socket has to be given the seller's token, and does not inherit it.**
This is the trap worth recording: without `realtime.setAuth`, the subscription
is made as the anonymous role. It connects, reports `Subscribed to PostgreSQL`
with `status: ok`, and then delivers nothing forever — because row level
security correctly shows the anonymous role no conversations at all. A
successful subscription that can never fire. The token is also re-applied when
the session refreshes, since this is a tab left open all day and an hour-old
token would otherwise stop the inbox updating some time in the afternoon.

**Consequences:**

- A reply is shown the instant Meta accepts it and arrives again moments later
  as Meta's echo. `mergeMessages` drops the duplicate on `mid`, which is the
  one id our database, the echo and the send all agree on, and prefers the
  stored row. It sorts by time rather than appending, because a message
  delivered late belongs where it was sent.
- Neither a failed refresh nor a failed profile lookup is allowed to break
  anything. A refresh that fails leaves what is on screen alone; a profile that
  cannot be fetched never fails the event, because the message is already
  stored and losing it over a missing name would be a poor trade.
- An expired access token is recorded on the account as `needs_reconnect` when
  Meta reports code 190 on a send. That covers the sending path only — the
  receiving path still has no detection, and remains on the checklist.

---

### 2026-09-18 — Admins are us; sellers are customers

A second kind of account, marked by `rabta_admin: true` in `app_metadata`. An
admin can create accounts. A seller cannot.

**This does not contradict the 14 September decision that there are no roles.**
That one is about roles *inside* a workspace — teammates, assignment,
permissions over the same inbox — and it still holds. This is a different axis:
who operates the platform, as against who buys it. A seller still owns their
workspace alone and there is still nothing to invite a colleague to.

**Why `app_metadata`:**

- `user_metadata` is writable by the account it belongs to, so a seller could
  make themselves an admin. It must never be read for authority.
- `role` is already GoTrue's: every signed-in account is `authenticated`.
  Overloading it invites exactly the confusion this check cannot afford.
- Strictly `=== true`. The string `"false"` is truthy, and a loose check here
  is the whole of the vulnerability.

**The check runs on the server, from the user record rather than the token.**
That costs one call per invitation, which is rare, and buys two things: an
admin who is revoked loses it at once instead of when their hour-old token
expires, and the client's idea of who is an admin is never what is trusted.
The button in the interface is presentation. Anyone can edit the page in their
own browser; the answer does not change.

**There is deliberately no screen for granting it.** Making someone an admin
needs the service key, which only we have — `npm run admin -- them@example.com`.
That is also the answer to the bootstrap problem: the first admin cannot be
made from inside the product, and an admin cannot quietly promote a seller
through a screen someone forgot to protect.

**Consequences:**

- **The invitation link is returned, not emailed**, until custom SMTP exists.
  The screen says so rather than pretending, because an invitation that
  silently fails to arrive is worse than one handed over deliberately.
- Invitation links expire — Supabase's default is 24 hours — and are single
  use. Worth knowing before sitting on a call with a new customer.
- An address that already has an account gets its own answer rather than a
  generic failure, because the person inviting needs to know it exists.

---

### 2026-09-18 — We control access to Rabta. We control nothing about Meta.

Decided by the product owner. Two different doors, and only one of them is ours.

**Ours: who gets into Rabta at all.** The product is not opened to whoever
finds it. It is given to a paying customer, so accounts are created by us and
there is no public sign-up.

**Not ours: the seller's connection to Meta.** Connecting a Page or an
Instagram account runs on the seller's own Facebook login and their own
approval on Meta's asset screen. We cannot do it for them, we should never hold
their credentials, and we have no control over whether Meta grants it. **So the
Connect flow belongs in the interface, as something the seller does.** It is in
Phase One scope.

*Corrected the same day.* This entry first said the opposite — that connecting
was an onboarding step we ran, and therefore out of scope. That was a misreading
of the decision. Controlling access to the platform is not the same as
controlling the seller's Meta accounts, and conflating them would have left the
product without the one screen a new customer cannot start without.

**How access is controlled, and what is still open:**

- **Public sign-up is turned off.** *Was on when this was written on
  18 September, and turned off the same day.* `/auth/v1/settings` now reports
  `disable_signup: true` and a real attempt returns 422 `signup_disabled`. The
  publishable key ships in the JavaScript by design, so it was never what
  protected this; row level security meant a stranger would have seen only
  their own empty workspace and no seller's data, but it was still contrary to
  the decision above.
- **Accounts are created by invitation, not by us choosing a password.** The
  seller sets their own through the invite link, so their password is never
  ours and never travels through a chat. The `handle_new_user` trigger already
  creates their workspace on the way in, so nothing else is needed.
- **A password reset flow is now required.** Real customers forget passwords,
  and without one every forgotten password is a message to us and a seller
  locked out of their inbox in the meantime. The screen a reset link lands on
  is built; what is missing is the button that sends the email, which is
  useless until SMTP exists.
- **Custom SMTP is deferred, deliberately.** Supabase's built-in sender is rate
  limited to a handful of messages an hour and is explicitly not for
  production, so invitations and resets can fail to arrive exactly when someone
  is waiting. Until it is configured, invitations are handed over as a link
  instead of emailed, which the invite screen says plainly. **This is a known
  gap to close before the first paying customer, not a surprise to discover
  then.**
- `supabase config push` is **not** the way to turn sign-up off here.
  `config.toml` holds only function settings, so a push would send defaults for
  every auth setting it does not mention and overwrite the live ones.

**Consequences:**

- The connect screen has to explain the two failures a seller can hit and act
  on: an Instagram account not linked to a Page, and a Page not granted on
  Meta's asset screen. `meta-oauth` already detects the second and says so in a
  plain sentence.
- The workspace id currently travels in the URL by hand. Once the seller starts
  the flow themselves it has to come from their own session instead, or one
  seller could start a connection into another's workspace.

---

### 2026-09-19 — Phase Two: the AI answers what it can and hands over the rest

Decided by the product owner. Phase One was functionally complete, and the gap
it left was inquiries arriving when nobody is looking.

**The shape of it.** The AI answers basic inquiries — price, availability,
basic product facts — from the seller's own catalog, and escalates everything
else to the seller. The goal in the product owner's words is that **no customer
inquiry gets missed.**

**Why not a fully supervised drafting tool.** That was proposed first, and
argued for: if a human approves every message, nothing wrong ever reaches a
customer. It was rejected because it does not solve the stated problem. The
value is answering at 11pm when the seller is asleep; a draft waiting in a box
is still an unanswered customer. "Supervised" and "nothing gets missed" cannot
both be fully true, and the product owner chose the second.

**Why not fully autonomous either.** The escalation path is what keeps this
honest. An AI that answers everything badly is worse than one that answers half
and says so. The deterministic guards recorded below are what enforce it.

**The catalog is a real table the seller controls**, plus a fillable template
for bulk entry — the product owner's decision over the leaner alternative of a
single free-text blob. It holds name, price, description and an in-stock
boolean. It is deliberately **not** inventory management: no stock counts, no
variants, no SKUs, no images. `CLAUDE.md` still rules those out.

`in_stock` is a boolean rather than free text on purpose. Free-text
availability invites the model to turn "usually available" into a promise.

**The trigger is split**, because the two halves serve different people:

- **Auto-answer fires on message arrival.** It has to. Waiting for the seller
  to open the thread would defeat the entire point.
- **Drafts are generated when the seller opens an escalated thread.** This half
  serves the seller, not the customer, and is sequenced last.

**Notification is the inbox, plus a browser notification and title badge.** The
inbox already does most of this: grouping is driven by `last_message_at` versus
`last_inbound_at`, so an escalated conversation stays in the waiting group with
no new mechanism at all. The browser notification closes a gap already listed
as unbuilt in `STATUS.md`.

**The AI starts reserved and is loosened by the seller.** `enabled` defaults to
false. A `caution` setting of `reserved` answers only what is literally in the
catalog; `normal` also handles greetings and delivery questions. It is a prompt
string selected by a setting, **not a learning system** — do not build one
without a decision that says so.

**Consequences:**

- An AI-answered conversation leaves the waiting group on its own, which means
  the seller can stop seeing what the AI said. It must carry a visible marker.
  In the first month, the seller reviewing those replies is the entire safety
  net.
- `theme.dart` reserves `accent` for "the seller's own actions and their own
  words, and nothing else". An AI message must not use it. How an AI message is
  shown is an open UX decision, not something to settle in passing.

---

### 2026-09-19 — What the AI costs, and the model that serves it

**`claude-haiku-4-5`**, at $1/MTok in and $5/MTok out. The work is a short,
well-scoped generation with the catalog already in the prompt; it does not need
a larger model. Sonnet 5 is exactly 2× and Opus 5 roughly 5×, and both remain
available if measurement says Haiku cannot hold the dialect.

The target subscription is **$20–30/month**, which is what makes the numbers
below matter rather than being trivia.

**The cache marker is set on every request, with the 1-hour TTL.**

*This started out as "conditional on the prefix reaching 4096 tokens" and was
simplified while implementing, once the cost of an unmet minimum was checked
rather than assumed.* Both facts still hold:

- Haiku 4.5's minimum cacheable prefix is **4096 tokens**. Below that,
  `cache_control` **silently does nothing** — `cache_creation_input_tokens: 0`,
  no error, no warning. A small seller's catalog will not reach it.
- Use the **1-hour TTL**, not the 5-minute default. Writes cost 1.25× at 5
  minutes and 2× at 1 hour; reads cost 0.1× and refresh the timer for free. At
  the expected traffic — roughly one event every 15 minutes in business hours —
  a 5-minute entry is dead on most requests and would pay the write premium
  nearly every time, costing *more* than not caching at all.

What changed is the conclusion drawn from the first point. An unmet minimum
writes **nothing**, so it costs nothing: the marker is a free no-op and a small
shop simply does not benefit, rather than paying for the attempt. (That is a
different case from a prefix which is long enough but *changes* every request —
that one does pay the write premium for reads it never gets, and is the case
the caching guidance warns about.) So there is no branch: mark it always.

Rough monthly cost per seller at ~1,900 replies: about **$7** for a small
catalog, about **$7** for a large one *with* caching, and about **$21** for a
large one without it. That last figure is why the marker matters at all.

**The number to watch is `cache_read_input_tokens`.** If it stays at zero
across repeated requests, something is invalidating the prefix — most likely
the catalog rendering differently between calls, or the voice examples changing
on every seller reply — and the $21 row is what the bill will look like.
`readUsage` in `ai.ts` exists to surface exactly that.

**The monthly ceiling is derived, not counted.** `count(*) from messages where
workspace_id = $1 and origin = 'ai' and created_at >= date_trunc('month',
now())`. A stored counter was rejected: it has to be kept in sync, it can
drift, and it would have to live on a table the seller can write to.

**Why that last point matters generally:** Postgres has no column-level row
level security. Every column on a client-writable table is client-writable. Any
value the seller must not be able to change belongs on a table with no policies
— the `account_tokens` pattern — or must not be stored at all.

---

### 2026-09-19 — How the AI is triggered: no cron, no queue

The auto-answer runs **inside the background task the webhook already has**,
next to `refreshCustomerProfile` in `meta-webhook`'s post-200 work. It sleeps
about 30 seconds, re-reads the conversation, and returns if `last_message_at`
moved — meaning another delivery owns the burst.

**Why the sleep:** customers send three fragments in a row. One answer per
burst is cheaper and better manners. Three fragments means three sleeping
tasks and exactly one survivor.

**Why this fails well:** if the isolate is recycled mid-sleep, the result is no
reply at all. The thread stays in the waiting group and the seller answers it.
Silence, not a double-send.

**pg_cron plus pg_net was proposed and rejected.** Recorded because it is an
obvious idea that will be proposed again:

1. **It breaks the test suite on contact.** `tests/helpers/db.ts` reads every
   `.sql` in `migrations/` and executes it into PGlite. A `create extension`
   line throws at boot and kills all 126 existing tests, none of which are
   about AI. Working around it means either undocumented dashboard state or
   shim code for something the tests cannot exercise anyway.
2. **pg_net cannot tell you whether it worked.** It is fire-and-forget with a
   5-second default timeout, against a model call of 2–5 seconds plus a Graph
   send. Healthy runs would routinely be logged as timeouts.
3. **It would put the service-role key in the database.** That key bypasses row
   level security and today exists only as a function environment variable.
   Storing it as a row to call our own backend is a worse trust boundary for no
   capability gained.

Revisit it when the failed-event retry sweep is actually built and cron has two
callers. Until then it is one mechanism serving one need.

**The claim asks whether a message has been considered, not whether a run
happened recently.** *Corrected 19 September, after the first version dropped a
real customer's message in production.*

The first version allowed a claim only when `ai_last_run_at` was null or older
than two minutes. That is the right shape for stopping two runs colliding on
one burst, and the wrong shape for everything else: a customer who writes again
inside the window is new work, and the previous run's own timestamp locked the
conversation against it. Seen live — the assistant answered "مرحبا", the
customer wrote "شفت عندكم فستان" thirty-six seconds later, and that message was
never answered at all. From outside it looks as though the assistant died
mid-conversation, which is worse than it never having spoken.

The predicate now also allows a claim when the last run started **before the
message being answered**, since such a run cannot have considered it. The
double-send guarantee survives: two runs for the same message race, the first
sets `ai_last_run_at` to now, and now is after that message, so the second
matches no clause.

PostgREST cannot compare two columns, so the message's own timestamp is passed
as a value rather than read from `last_inbound_at`.

**Concurrency is one conditional UPDATE**, not a lock:

```sql
update conversations set ai_last_run_at = now()
 where id = $1
   and (ai_last_run_at is null or ai_last_run_at < now() - interval '2 minutes')
returning id
```

Zero rows back means another run owns this conversation. This is atomic by
Postgres guarantee: the second UPDATE blocks on the row lock, then re-evaluates
its WHERE against the committed new version under READ COMMITTED and matches
nothing. Advisory locks were rejected — they are connection-scoped and
PostgREST pools connections, so there is no reasoning about when the lock
drops.

**Double-sending the same sentence to a customer is the one failure that
cannot be repaired after the fact.** It is why this is a claim and not a flag.

---

### 2026-09-19 — The guards that keep the model out of the room

Most turns should never reach the API. These run first, cost nothing, and are
pure functions that can be tested exhaustively without a network:

| Condition | Action |
|---|---|
| Reply window closed | Skip — the send would fail anyway |
| Latest inbound has no text (sticker or image only) | Escalate |
| Three or more consecutive AI replies with no seller message | Escalate |
| Seller sent anything in the last 15 minutes | Escalate — a human is present |
| Monthly ceiling reached | Escalate |

Two more run on the way back out, after the model has answered:

- **The grounding check.** Every digit-run in the reply must appear in the
  rendered catalog or in the conversation, or the reply is escalated instead of
  sent. An invented price is the single failure that loses a seller their
  customer, and this catches it deterministically rather than hoping the model
  behaves.
- **`checkText`**, the existing helper. Instagram's limit is 1000 characters
  and Arabic runs long. Over-length escalates rather than letting Meta reject
  the send and the customer receive nothing.

The guards are the design. The model is the part that can be swapped.

---

### 2026-09-19 — It holds the conversation, and hands over when it would have to invent

Asked for by the product owner after watching the first real reply: it should
"be able to hold a basic conversation to an extent", and the seller picks it up
after that.

**Both caution settings are about facts, not about talking.** They used to
escalate anything that was not a price, which would hand a "مرحبا" to the shop
owner and leave the customer watching silence over something anyone could
answer. Now the assistant carries the ordinary run of a chat — greeting back,
acknowledging, asking which item or size they mean, quoting what is written —
and escalates the moment an answer would need a fact nobody wrote down.

Measured on a seven-turn thread, each reply fed back in. On the careful setting
it held six turns and handed over on "طيب امتى بيوصل؟", because no delivery time
is written anywhere:

    ← مرحبا              → مرحبا، كيف أساعدك؟
    ← شو عندكم؟           → عندنا فستان أحمر وشنطة يد. شو اللي بدك؟
    ← قديش الفستان الأحمر؟  → الفستان الأحمر 25.5 دينار، وفيه مقاسات S و M و L.
    ← في مقاس M؟          → آه، مقاس M موجود.
    ← تمام، بتوصلوا لعمّان؟ → آه، التوصيل لعمّان 2.5 دينار، أو مجاني فوق 50.
    ← طيب امتى بيوصل؟      → handed to the seller

**A greeting gets a greeting.** The first real reply in production answered
"مرحبا" with a price and a delivery fee nobody had asked for. Part of that was
our own mess — a synthetic test message had left a real question unanswered in
the thread, and the model answered it — but the rule is worth stating anyway: a
shop that answers hello with a price list is a leaflet, not a person.

**It is told not to add numbers up.** On the freer setting it offered a total —
25.5 plus 2.5 delivery — which is correct arithmetic and which the grounding
check then holds back, because the sum appears nowhere in the shop's facts.
Loosening the check to allow arithmetic would weaken the one guard against
invented prices, so the instruction goes the other way: give the parts and let
the customer add them up. Just as useful, and it stays grounded.

**Usage is logged per reply.** `cacheRead` staying at zero for a shop with a
large catalog is the signal that the cached prefix is being invalidated, which
would roughly ten times the input cost and would otherwise show up only on an
invoice.

---

### 2026-09-19 — What the model actually did, measured

The first run against the real API. Recorded because two of these were
assumptions that turned out to need work, and one was an assumption that held.

**Jordanian dialect holds on Haiku 4.5.** "اكيد بنوصل إربد، التوصيل 3.5 د.ا" —
dialect, not Modern Standard Arabic, and visibly shaped by the seller's own
example replies. The largest assumption in the cost model, and it survived.

**Arabizi is answered in Arabic script — decided by the product owner, and the
better call.** It was first built to mirror the customer's script, on the
reasoning that someone typing in Latin letters may not have an Arabic keyboard.
That reasoning is about *input*: anyone who types Arabizi reads Arabic script
perfectly well, so answering in script costs them nothing and a shop that
writes back in Latin letters looks careless. The dialect is still mirrored —
only the script is normalised. "2adesh se3r el shanta?" is answered "الشنطة بـ
18 دينار ومتوفرة هلق".

**The seller's own example replies decide the reply's language, and no wording
stops them.** Normalising Arabizi to Arabic script turned an English customer's
question into an Arabic answer. Putting the language rule first, giving it
worked examples, and telling the model outright that the examples do not decide
the language all failed. Removing the examples fixed it instantly — the same
question came back "The red dress is 25.5 JD."

So the fix is structural rather than more instruction text: **the shop's Arabic
example replies are withheld when the customer is plainly writing English.**
Arabic typed in Latin letters still counts as Arabic, detected by the digits
Arabizi borrows for letters Latin does not have — "2adesh", "a7mar", "3a" —
which it glues to letters in a way ordinary English does not. "I want 2
dresses" has a space and is not caught.

It is a heuristic, and it fails back to the behaviour we already had. The
general lesson is worth more than the rule: **a few examples outweigh a great
deal of instruction**, so when the model will not obey a rule, look at what is
being shown to it before writing the rule again.

**No pet names, ever — decided by the product owner.** A seller may call every
customer حبيبتي; a shop's assistant should not. Warm and professional, never
familiar.

This one *does* survive the examples, which is worth knowing given the language
rule did not. Measured against a seller whose every example reply used an
endearment, and including the two cases most likely to draw one out — a bare
"مرحبا" and a "شكرا كتير" — none of nine replies used one, while the tone stayed
Levantine and friendly: "أهلاً وسهلاً، كيف أساعدك؟".

So it stays an instruction rather than a filter over the finished reply. A
filter would have to cut a word out of a written sentence, and would read worse
than the problem it solved. **Why one rule holds and the other does not seems
to be the shape of it:** "never do X" survives contrary examples, while "do Y
when the examples show Z" does not.

**It could not answer "are you open today", and said so.** It knew the opening
hours and not what day it was, and refused to guess rather than inventing one.
Correct, and a gap: the current time is now sent — **after** the cache
breakpoint, because it changes every minute and inside the prefix it would
invalidate the whole cache on every single request.

**Caching behaves exactly as the cost model assumed.** A 220-product shop wrote
12,930 tokens on the first call and read all 12,930 back on the second, with 37
uncached. A five-product shop wrote and read nothing at all — confirming that
below the 4,096-token minimum the marker is a free no-op, which is what
justifies setting it unconditionally rather than measuring the prefix first.

**Cost is lower than estimated: about $0.0013 a reply**, roughly $2.50 per
seller per month at 1,900 replies, against $7 estimated. The estimate assumed a
10,000-token prompt; a real small shop's is closer to 1,100. The $7 figure
still stands for a shop with a few hundred products.

**The end-to-end run escalated rather than delivering**, because Meta refused
the send with `window_closed`. That is the designed failure path working in
production — the conversation went back to the seller and no message row was
written for something the customer never received. Meta's 24-hour window opens
on a real message from the customer; a synthetic signed delivery does not open
it, so a genuine reply to a genuine customer is still unproven.

---

### 2026-09-19 — The product serves Jordan, not Iraq

Stated by the product owner partway through Phase Two, after a good deal had
been written on the wrong assumption. Recorded rather than quietly corrected,
because the assumption had reached the schema.

Three things changed, and two of them were defects rather than wording:

- **Prices carry three decimal places.** The Jordanian dinar divides into 1000
  fils, so 12.750 is an ordinary price. `numeric(12,2)` would have rounded it
  to 12.75 — the application quietly changing a number the seller typed, and
  the kind of thing nobody notices until a customer is quoted wrong.
- **Price parsing broke on the currency itself.** "د.ا" — the dinar — contains
  a dot. The parser stripped everything that was not a digit or a dot, which
  left "30.750." and parsed as nothing at all, so a price written the ordinary
  way came out empty. It now takes the first number in the cell instead.
- **The dialect named in the prompt.** Jordanian and wider Levantine — "قديش
  سعرها", "بتوصلوا عمان؟" — not Iraqi. Naming the wrong one would have been
  worse than naming none, since the whole point is not sounding generic.

The default currency is `د.ا`, and it is stored rather than assumed: dollars
circulate too, and the wrong unit is as bad as the wrong number.

---

### 2026-09-19 — The shop's own facts, beside its catalog

Asked for by the product owner: name and price "won't cut it", and delivery
fees, currency and locations "must be accounted for".

A catalog answers "how much is the red dress". It cannot answer "how much is
delivery to Irbid", "do you deliver to Aqaba", "are you open now" or "where are
you" — and those are asked as often as anything about a product. Without them
the assistant hands back most of an ordinary conversation, which reads as
broken rather than careful.

**Delivery is a list of zones plus a note**, not one or the other. The list
gives "how much to Irbid" an exact answer instead of an interpretation of
prose, and keeps the invented-number guard meaningful. The note holds the rules
a list cannot — free over 50 dinars, same day inside Amman.

**A zone with no fee is not free.** It means the shop covers that place but the
price depends, which is a truthful answer. Requiring a number would make the
seller invent one and the assistant repeat it.

**Locations, hours and "anything else" are free text.** Real hours are "السبت
إلى الخميس ١٠ص-٨م، الجمعة مغلق", and a structured editor for that is a lot of
screen for something the model reads as a sentence anyway. The same goes for a
shop with two branches. The catch-all field is deliberately open — no shop is
the same shape as the next, and a field per fact is a form nobody finishes. It
is also the escape hatch when the assistant keeps getting something wrong.

**A product gained nothing but a better-labelled details box.** A code, a sale
price and a category were all offered and all declined. The existing
description field is the flexible one; it just needed to say that the assistant
reads it.

**`ai_settings` was folded into `shop`.** Both were one row per workspace, and
two settings tables means two queries, two policies and a standing question
about which one a new setting belongs in. Done while the only data in it was a
single test row.

**One function renders what the model is told and what the guard searches.**
`renderFacts` produces a single string used for both. If those two came from
different code, a delivery fee the model was given could be refused on the way
out as a number it made up — the assistant escalating its own correct answer.

---

### 2026-09-19 — The grounding check compares numbers, not digits

*Replaces the digit-substring approach recorded the same day.*

It compared the digits a number was written with, which broke the moment fils
arrived: the seller types 25.500, the catalog stores 25.5, the model answers
"25.500", and the check rejected it. The assistant would have escalated its own
correct answer.

It now parses both sides into numbers. A comma is a thousands separator and a
dot a decimal point — 1,250 is one thousand two hundred and fifty, 1.250 is one
and a quarter dinars.

**The floor is gone, too.** Small numbers used to be exempt as "probably a
quantity". Delivery in Jordan costs 2 or 3 dinars, so that exempted exactly the
figures most worth guarding. Every number is checked now, and a reply
mentioning a number nobody wrote down is escalated rather than sent. Escalating
is the safe failure: the seller answers it.

---

### 2026-09-19 — Settings save one field at a time

The shop screen writes only the field that changed, rather than the whole row.

Found by running it: two edits in quick succession and the second silently
undid the first. Each save sent a complete row built from whatever the screen
had last loaded, so the second carried a stale copy of the first.

Sending only what changed removes the race, and makes clearing a field
possible — an absent value and a value set to nothing look identical when the
whole object is copied and replaced.

---

### 2026-09-19 — Products are their own screen, reached from a side menu

Decided by the product owner: "a standalone page where the seller views and
controls his products", reached through "something like a side menu".

**The screen.** `products_page.dart`, its own route with add, edit and delete,
following the shape `accounts_page.dart` already set: the `Future` is the
state, a per-row busy id rather than a screen-wide flag, and a refresh by
reassigning the future. The assistant's own switch sits at the top of it,
because the two are one decision — an assistant with no catalog has nothing to
say, and a catalog with the assistant off is a list nobody reads. The switch is
disabled until a product exists, and says why.

**The menu replaces a row of unlabelled icons.** The inbox header had grown to
three: products, accounts, sign out. Three icons a seller has to hover to
identify is three guesses a day. The drawer names them.

**A drawer rather than a permanent rail.** A rail costs horizontal space on
every screen, and this product already spends that on three panes above
1180px. The menu is opened perhaps a few times a day — the seller lives in the
inbox — so it does not earn permanent space.

**The menu lives on the inbox only.** Products and Accounts are pushed routes
and carry a back arrow. One way in, one way out. A drawer on every screen as
well as a back arrow would be two ways to leave and a question about where you
are.

Flutter resolves a drawer against the locale, so it opens from the right in
Arabic and the left in English with no code to say so. Verified in a browser in
both.

---

### 2026-09-19 — A catalog is pasted, not uploaded

The plan said a downloadable template the seller fills in and uploads. It is a
paste box instead, and the parser accepts tabs as well as commas.

**Why.** Copying cells out of Excel or Google Sheets puts **tab-separated**
text on the clipboard. So if the parser reads tabs, a seller selects their rows,
copies, and pastes — no file to save, no format to choose, no upload control,
and nothing to explain. Reading only commas would have turned each pasted row
into one long product name with the price buried in it.

**What it avoids.** File upload on Flutter web needs either a new dependency or
`package:web` with `dart:js_interop`. The second is worse than it looks: those
imports are web-only, and `lib/` is imported by the VM test suite, so the
parsing would have had to move behind conditional imports to stay testable. The
paste box needs none of it, and the parsing stays pure functions with tests.

A blank template is still offered, copied to the clipboard rather than
downloaded, so a seller who wants the column names can paste them into Excel.
It carries a **UTF-8 byte order mark** — without it Excel reads the file in the
system codepage and every Arabic product name arrives as mojibake.

Add real file upload if sellers ask for it. Nobody has.

---

### 2026-09-19 — An assistant message is teal, and says so

Decided by the product owner: automatic replies get their own colour rather
than the quieter label that was proposed.

**Why a colour at all.** The seller is accountable for everything that leaves
their inbox. The one thing they must never have to work out is which messages
they wrote themselves, and in the first months — when they are deciding whether
to trust this — that check is the whole safety net.

**Teal, `#0B7A6E` light and `#58D5C9` dark.** The palette is deliberately tight
and three of its colours were already spoken for: `accent` is the seller's own
words and nothing else, `urgent` is a closing reply window and nothing else,
and both platform colours appear on the same row. Teal is the furthest readable
hue from the violet that none of those had claimed.

Measured rather than assumed: message text on it is **5.22:1** in light and
**9.96:1** in dark, both past the 4.5:1 needed for normal text. Verified again
in a browser by reading the rendered pixels — the bubble is `#0b7a6e` against
the seller's `#6010c0` and the customer's `#ffffff`.

**Colour is not the only signal, and this part was not optional.** The two
bubble fills differ by only **1.72:1** in luminance, so they are told apart by
hue alone. A seller who cannot separate violet from teal would have nothing
left to go on, which is the one accessibility rule worth spending a line of
interface on. Every assistant message also carries a short word — "رد تلقائي" /
"Automatic reply" — above its text.

**`origin` is read together with `direction`.** The column carries a value on
inbound rows where it means nothing, so reading it alone would paint a
customer's own messages as machine-written.

---

### 2026-09-19 — Where the AI code lives, and what it reuses

**One file, `meta-webhook/ai.ts`**, mirroring `profile.ts`: pure functions plus
`fetcher: typeof fetch = fetch` injected so it is testable with no network. One
caller means one file. A `_shared/ai.ts` plus `_shared/claude.ts` pair was
proposed and cut — two shared modules for one consumer.

The orchestration — `autoReply` — lives in `process.ts` beside
`refreshCustomerProfile`, for the same reason the profile split works that way:
the pure decisions sit in their own file, and the part that needs a `Store`
sits with the other code that needs one.

**The Edge Functions are typechecked with `deno check`, added 19 September.**

They were not, until this was written. `node --test` uses native type
stripping, which removes types without checking them, so a `Store`
implementation missing a method compiled to nothing and failed only when the
line ran — which is exactly what happened: five methods were added to `Store`,
the fake store did not implement them, and all 193 tests stayed green.

`npm test` now runs `npm run typecheck` first. It takes about a third of a
second warm, so there is no reason to skip it. Two things were needed to make
it work:

- `@types/node` as a dev dependency, for the `node:test` and `node:assert`
  imports in the test files.
- `supabase/deno.json` with `"nodeModulesDir": "auto"`, without which Deno
  cannot resolve supabase-js's own npm dependencies and the entrypoints cannot
  be checked at all.

It found two real problems in code written before Phase Two. Both were
type-only fixes with no change in behaviour:

- `send-message/index.ts` read six fields off a row that supabase-js had
  widened to a union it could not see through, because the select uses an
  embedded join and there are no generated schema types. The row is now named
  explicitly at the query.
- `meta-oauth/index.ts` passed a possibly-undefined Page name where null was
  expected. Meta does return Pages without names, and undefined would have
  silently dropped the field from the write rather than storing null.

Generating schema types (`supabase gen types`) would remove the need for the
first cast, and is worth doing once the CLI is set up here.

**The `send.ts` helpers are imported across function directories, not moved.**
`checkText`, `checkWindow`, `sendRequest`, `readSendResult` and `refusalFor`
are already pure and already tested. `send-message/index.ts` already imports
`../_shared/origins.ts` and ships today, which proves the CLI bundles the
entrypoint's whole module graph — `_shared` is a deploy-slug convention, not a
bundler rule. The cost is deploy coupling: change `send.ts` and redeploy both
functions.

**The request shape**, recorded because two of these are easy to get wrong:

- `model: "claude-haiku-4-5"`, `max_tokens: 300`.
- **No `thinking` and no `output_config.effort`.** Haiku 4.5 rejects `effort`
  outright and takes `budget_tokens` rather than adaptive thinking. We use
  neither.
- Structured output via `output_config.format`, returning
  `{action: "reply" | "escalate", text?, reason?}`. The JSON arrives as the
  first `text` block — parse it, never string-match it.

**The seller's own past replies are the voice.** A stable slice of their last
~40 outbound messages goes into the prompt as style exemplars. The slice must
be refreshed on a slow cadence, not per reply — otherwise the prefix changes
every time the seller types and the cache never hits.

This exists to solve a specific problem: customers write Jordanian and wider
Levantine dialect, frequently in Latin letters ("2adesh el si3r", "fi bl azra2?"). A
model answering in Modern Standard Arabic reads *more* robotic than a bot. If
live testing shows plain instructions carry the dialect well enough, drop the
exemplars — they are the largest single part of the prefix.

---

### 2026-09-20 — The assistant sells. It was an answering machine.

Asked for by the product owner, in their words: it "can only handle very
specific cases, and it expects the customer to know exactly what he wants".
What they wanted instead was "the guy that could tour you around the shop, give
you details when you ask, upsell, give options and reason with the customer to
get him to buy" — and, added straight after, **"but not too pushy"**.

The model was not the problem. Four things in our own code were.

**1. Silence was the default outcome.** Every one of the six exits in
`autoReply` ended by marking the conversation escalated and sending the customer
nothing. Six ways to go quiet, one way to speak, in a feature whose stated
purpose is that no inquiry goes unanswered. From the customer's side an
assistant that hands over is indistinguishable from one that has died.

**2. It died at the third reply.** `MAX_CONSECUTIVE_AI` was 3. The seven-turn
transcript recorded on 19 September as proof it could hold a conversation was
fed in by hand and never passed through `guard`; in production that thread
stopped after "قديش الفستان الأحمر؟" — the point the customer was closest to
buying. It is now 8, and reaching it sends a line rather than vanishing.

**3. The prompt had no vendor in it.** Ten prohibitions and no instruction to
sell. Nothing told it to offer the nearest thing when the answer was no, to name
two options for a customer who was vague, or to say what *was* in stock. It was
written to prevent a bad reply rather than to produce a good one, so it waited
to be asked an exact question. "One or two sentences, never a list" then
forbade the one format an alternative needs.

**4. `reserved` was the default, and it was written as "stop".** *"Keep talking
as long as you are sure, and stop the moment you would have to invent
something."*

**What replaces it.** One decision shape with two independent fields — `text`,
always sent, and `handOver`, which tells the seller to take over. They used to
be alternatives, so a customer who asked one answerable thing and one
unanswerable one received nothing at all. Now they get the answer and the seller
gets the rest. `text` has no exception: **there is no shape the model can return
that leaves the customer in silence.**

The instructions are a brief rather than a rulebook — show them around, never
stop at no, name what is in stock when the asked-for thing is not, point at the
cheaper thing when it is over their budget, ask the one question that moves this
forward. Then a section that exists because of the product owner's second
sentence: **DO NOT PUSH.** No invented urgency, no asking twice, a second item
mentioned once and dropped if they do not pick it up.

**Handing over is a last resort and is never silent.** The guards that speak are
`ai_streak` and `ceiling`, and only at the exact moment the limit is crossed —
the hand-over line is itself an AI reply, so it pushes the count one past the
limit and the next message finds the equality false. Said once, no new state.
`conversations.ai_state` was the obvious flag and is the wrong one: nothing
clears it, so a conversation escalated once would never hear the line again.
`window_closed` and `no_window` stay silent because Meta would refuse the send;
`seller_present` stays silent because the seller is about to answer in person.

**`assistant_caution` is deleted.** Both settings were limits on what the
assistant could say, and both produced this complaint. There is nothing left for
the setting to choose between. A control over behaviour nobody has tuned is a
control nobody can set well; it comes back when there is a real difference for
it to name.

**A photo on its own is no longer refused.** `last_message_type` is not read any
more, and attachment-only rows are no longer filtered out of the conversation.
They reach the model as `[the customer sent a photo]`, which it answers by
saying it cannot see it and asking what it is. On Instagram, a screenshot of a
story with no words is a normal way to open a sale, and it used to get silence.

---

### 2026-09-20 — What the rewrite got wrong, measured against the real API

`supabase/scripts/live-ai.ts` runs nine scripted Jordanian conversations through
the real model and prints the transcripts. It is not part of `npm test` — it
costs money and needs a key. It exists because "does this read like a person" is
the one requirement no assertion can check, and it found five defects that 260
passing unit tests went straight past. Each now has a test of its own.

**A large Arabic catalog beats any language instruction.** An English customer —
"do you deliver to Amman? and what do you have for around 15?" — was answered in
Arabic on two runs of three, *with the shop's Arabic examples already withheld*.
Isolated: a five-product shop answers in English every time, the same shop with
a full Arabic catalog, hours, address and notes does not. Putting the rule first
did not help; repeating it at the end did not help.

So the model is no longer asked to work the language out. `readsAsArabic`
already decides it, for the examples; the same answer is now **stated as a
fact** in a block after the cache breakpoint. Three of three in English.

The general lesson extends the one from 19 September. That one was *a few
examples outweigh a great deal of instruction*. This one is broader: **anything
you can decide deterministically, decide deterministically and tell the model.**
Instruction wording is the weakest lever in the file.

**The instructions must not quote a reply in Arabic.** The first draft showed a
model greeting — "مرحبا" answered with "أهلين! شو بتدوري عليه؟" — and that alone
put the English failure back. Arabic naming what a *customer* writes is fine,
and the dialect rule needs it. Arabic showing what the *shop* writes is not.
There is a test that scans the instructions for exactly this.

**It switched numeral systems mid-conversation.** "32 دينار" in one reply and
"٣٢ دينار" in the next. The interface is Western numerals everywhere and so is
the seller's own list. Now an explicit rule.

**It switched gender mid-sentence.** "شو بتدوري عليه" then "قول لي وبساعدك".
Nothing reads more plainly as nobody being there.

**It invented a policy, which the grounding check cannot catch.** Asked to come
down on price it answered "السعر ثابت" — the shop's policy, stated as fact,
written down nowhere. The grounding check only sees digits, and that sentence
has none. Haggling is now named in the instructions as the clearest hand-over
there is, with the invented sentence quoted back. It now hands over *and*
answers: "صاحب المحل بيقدر يرد عليك أحسن مني على الموضوع".

**Our own placeholder decided the language.** `[the customer sent a photo]` is
English, written by us, so an Arabic customer who sent only a photo was answered
in English. Attachment markers are skipped when choosing the language, and a
customer who has written no words at all defaults to Arabic.

**What is left, and is Haiku's rather than ours.** The prose wobbles
occasionally — "بتنال ايدك أيهما أكتر؟" is not a sentence. It is the strongest
argument yet for measuring Sonnet 5 against this prompt, which doubles the cost
per the 19 September model.

**Also unresolved: the voice examples leak facts.** The shop's own past replies
are given "for TONE ONLY", and it copied a delivery time out of one — "بيوصلك
خلال يومين", a promise nobody authorised. Words, not digits, so the grounding
check missed it. Not fixed here.

---

### 2026-09-20 — Sonnet 5, because it costs 8% more and not 100%

Asked for by the product owner: to stand next to ManyChat and the rest, "we
need something smarter". Measured rather than argued — nine scripted
conversations, fifteen replies, three variants, same prompt and same shop.

| | per reply | per seller per month (1,900 replies) | cached |
|---|---|---|---|
| Haiku 4.5 | $0.00339 | **$6.44** | nothing — 43,671 uncached input tokens |
| Sonnet 5, thinking off | $0.00365 | **$6.94** | 44,512 read, 6,654 written |
| Sonnet 5, adaptive thinking | $0.00381 | $7.23 | same |

**The sticker price says 2×. The bill says 8%.** Sonnet 5 is $2/$10 per MTok
against Haiku's $1/$5, and it still lands within a rounding error, because of
one number nobody had looked up: **the minimum cacheable prefix is 1,024 tokens
on Sonnet 5 and 4,096 on Haiku 4.5.** A real shop's prompt lands between the
two. Haiku cached *nothing at all* across fifteen replies — every request paid
full input price — while Sonnet read 44,512 tokens back at a tenth of base.

The 19 September entry recorded that a small shop "simply does not benefit"
from caching below the minimum, and treated that as free. It is free in the
sense that the marker costs nothing. It was not free in the sense that
mattered: it meant the cheaper model was the one paying full price on every
token, which is why the two models converge.

**This reverses for a large catalog.** Once the prefix clears 4,096 tokens
Haiku caches too and the gap goes back towards 2×. The 19 September measurement
of a 220-product shop was 12,930 tokens, so a shop that size on Sonnet is
roughly $14/month rather than $7. Re-run `npm run live` when such a seller
exists; `HAIKU` is kept in `ai.ts` for exactly that.

**Thinking is switched off explicitly, and that line is the whole migration.**
Haiku 4.5 rejects `output_config.effort`, takes `budget_tokens` rather than
adaptive thinking, and does no thinking unless asked — so omitting the field
was correct. Sonnet 5 defaults the other way: **omitting `thinking` runs
adaptive thinking.** Changing the model string alone would have quietly started
paying to reason about "قديش سعر الفستان؟". Adaptive was measured anyway: 4%
dearer, and the replies were not better. Every fact is already in the prompt and
the answer is two sentences.

**What the money actually buys.** Sonnet gives a reason where Haiku gives a
list. Asked "شو بتنصحني؟" for a gift:

    Haiku   → الفستان الأحمر إذا أمك بتحب تطلع... أما إذا بتفضل حاجة يومية...
              واللي بتحب تلبس شال...  (three options, no recommendation)

    Sonnet  → أنا بميل للشال، لأنه شي بتلبسه كل يوم وبيدفّي بهالجو، وألوانه
              بتناسب أي ذوق.  (a recommendation, and why)

That is the difference the product owner asked for, and it is not a difference
any amount of prompt work was going to produce on the smaller model.

**Sonnet found a defect the prompt had missed, now fixed.** It offered
"وعم يلاقوا إقبال كبير" — other people are buying this. Nobody told it that;
manufactured popularity is pressure dressed as a fact, and it has no digits so
the grounding check cannot see it. Named explicitly in DO NOT PUSH.

**Open, and the product owner's call: emoji.** Sonnet closed a browsing
conversation with "أي استفسار انا هون 🌸". No rule covers it. The no-pet-names
rule was about familiarity, not warmth, and a Jordanian shop on Instagram uses
emoji freely — but the seller's own example replies have none.

---

### 2026-09-20 — A promise with no digits in it is still a promise

Asked for by the product owner alongside the move to Sonnet 5: "enforce not
generating answers not based on facts". **Enforce**, not instruct — which is
the right word, because instructing had already been tried and had already
failed three times.

`numbersAreGrounded` sees digits and nothing else. Every leak found against the
real API had none:

- "السعر ثابت" — a price policy nobody wrote down.
- "عم يلاقوا إقبال كبير" — manufactured popularity.
- "بيوصلك خلال يومين" — a delivery time lifted out of the seller's own past
  reply, which is shown to the model for tone and is not a source of facts.

All three were already forbidden in the instructions when the model wrote them.

**So the watched-word check.** The same rule the numbers get, applied to a
small list of words a reply only reaches for when it is promising something: a
price policy, scarcity, a discount, a guarantee, a delivery time. A watched
word may appear in a reply only if it appears in what the shop wrote down or in
what the customer said — searching the same two haystacks as the number check,
so there is one idea here rather than two.

That second haystack is what keeps it usable. A shop whose delivery note says
"بنوصل بكرا" may promise tomorrow; a customer who asks "في خصم؟" may be answered
about a discount. Only an *invented* one is held.

**It is a word list, not a fact-checker, and the code says so.** A fabricated
sentence using none of those words still goes through. The upgrade path is a
second model call to check the first, which doubles cost and latency and is
itself fallible — worth doing only if measurement shows leaks that matter. A
failure here is safe in the way the rest of this is: the conversation goes to
the seller and the customer gets the hand-over line, not silence.

**Measured: nine conversations, fifteen replies, zero held back.** No false
positives, which was the real risk — a check that gags good replies would undo
the work of the rewrite.

---

### 2026-09-20 — Emoji: yes, rarely, and decided in code rather than asked for

The product owner's call: "Its ok to use emojis as long as they are the safe
ones but keep it to a minimum like when closing a chat."

**Safe** is a short allow-list — 🌸 🙏 ✨ 🙂 👋. No hearts and no faces beyond a
plain smile: those sit in the same family as the pet names ruled out on
19 September. Warmth is fine, familiarity is not, and 😍 from a shop to a
customer is familiarity.

**Minimum** was asked of the model first, and the model did not deliver it.
Told to save them for a closing, Sonnet 5 put one on a price quote, on a
question back, and on a product list — most replies in the run.

So it is decided in `tidyEmoji`, by the same reasoning that settled the
language: **what can be decided deterministically should be.** At most one, at
the end, and only on a reply containing no digit and no question mark. A digit
or a question mark stands in for "this reply is doing work" — a price, a fee, a
size, or a question the shop is still waiting on an answer to. A closing has
neither.

It is a proxy and it is named as one in the code. It will occasionally strip an
emoji from a warm reply that happens to contain a number; that failure is
invisible, and the opposite one is a shop that punctuates its prices with
smileys.

**Emoji are stripped, not escalated — the one place a finished reply is
edited.** The 19 September decision rejected filtering replies because cutting
a word out of a written sentence reads worse than the problem it solves. An
emoji is not a word: removing it changes nothing the customer needed to read.
An invented fact still hands the conversation over, because there is no way to
remove it without changing what the sentence says.

**After: three of fifteen replies carry one, all of them closings** — "تمام،
خذي وقتك وارجعيلي متى ما حبيتي 🌸", and the hand-over line on a haggling
customer.

---

### 2026-09-20 — Read what kind of message it is before answering it

From a real thread, shown as a screenshot. The customer wrote "يغطيك العافية" —
a pleasantry, nothing asked — and got back **"نعم، عندنا فستان أحمر. إي مقاس
بدّك؟"**. The product owner's words: "That's not friendly like at all and its so
context unaware, like I still haven't said anything and its recommending stuff,
let the customer talk be intelligent."

**Reproduced first, and the reproduction is the useful part.** Run against the
current code, that same message comes back "الله يعافيك 🙏" — no red dress. The
screenshot is the **deployed** function, which is still running the code from
before the 20 September rewrite. Nothing from that day has been deployed.

So the reported failure was already fixed. The complaint underneath it was not,
and it was mine:

**"A greeting gets a greeting and a way in... name the KINDS of thing you
sell."** That line was my own addition earlier the same day, written against a
"dead end" worry the product owner never raised. It did exactly what it said:
asked "كيفك؟" — how are you — the assistant replied "أهلاً فيكي، تمام الحمدلله
🙂 عنا فساتين وشناط وشيلان حلوة، شو بتدوري عليه؟". A product list, at someone
who had asked after its health.

**What replaces it is a triage, before anything else in the prompt.**

- A **pleasantry** is not an opening. "يعطيك العافية", "تسلم إيديك", "شكراً",
  "كيفك؟" are ritual; the whole reply is the matching ritual back, and then it
  stops. No product, no category, no price, not even a question.
- A **greeting** is an opening and nothing more. Greet back, ask what they are
  after. Do not list what the shop sells.
- A **question or a want** is where all the selling behaviour starts. Only once
  the customer has said something does the assistant suggest, compare or offer
  an alternative.

*Suggesting before they have told you anything is not helpfulness, it is a
billboard in a conversation.*

**"نعم" is named specifically.** The dialect rule had been in the prompt since
19 September and the real reply still opened with Modern Standard Arabic. A
general rule did not stop it; naming the word does — along with "هل", "ماذا",
"لماذا", "أريد".

**Measured after, on the same messages:** every pleasantry gets the ritual and
nothing else — "الله يعافيك", "الله يسلمك", "العفو". "مرحبا" gets "أهلاً وسهلاً
فيكِ، تفضلي شو بتدوّري عليه؟" with no catalog. And the selling behaviour it now
gates is intact: "بدي هدية لأمي" still draws two options with a reason, an
out-of-stock item still names an alternative, a low budget still gets the
cheaper thing.

**The ritual replies then leaked the other way**, which is worth recording
because it is the same mistake in reverse: given the formulas, the assistant
opened an ordinary gift enquiry with "تسلم إيدك" — thanking a customer who had
thanked nobody. The rule now says those replies are only for when the matching
phrase was said to you.

**A test was narrowed, deliberately.** "The instructions quote no Arabic reply
the model could copy" existed because Arabic model replies used to drag an
English customer into Arabic. The pleasantry rules cannot be written any other
way — there is no English gloss that teaches "يعطيك العافية" → "الله يعافيك".
It is safe now because the root cause was fixed properly on the same day: the
customer's language is decided by `readsAsArabic` and stated to the model as a
fact. Re-measured against the large all-Arabic shop that used to break it —
"hi", "thanks a lot!" and "do you deliver to Amman?" came back in English six
times out of six. What stays forbidden is the risky class: an Arabic sentence
that offers stock or quotes a price.

**Two things measured in passing.**

- **The claim check earned its place on live output.** Asked to come down on
  price, the assistant wrote "السعر عنا ثابت حسب ما بعرف" — an invented price
  policy, no digits in it — and the watched-word guard held the reply and
  handed over. That is the guard catching a real case, not a synthetic one.
- **Steady-state cost is about half the earlier figure.** A run against a warm
  cache came in at **$0.00193 a reply, ~$3.67 per seller per month**, against
  the ~$7 measured when every run paid a cold cache write. The $7 figures were
  worst-case, not typical.

---

### 2026-09-20 — The assistant reads the price out. It does not discuss it.

Decided by the product owner: "I don't want the agent to discuss prices, it
simply lists the prices it sees... any price discussion should be dealt with
gently. Not outright refusal."

Both halves matter, and before this the assistant was failing the second one
twice over. Asked to come down on price it either invented a policy — "السعر
ثابت", which the watched-word check then held, leaving the customer with a bare
hand-over line — or it handed over with nothing useful said. From the
customer's side both read as a door closing.

**The rule now has its own section in the prompt, because a bullet was not
enough.** The number in the shop's facts is the price and the only thing the
assistant knows about cost: no discount list, no offer, no margin, and nothing
written down about whether this shop bargains at all. So:

- Say the listed price again, warmly, as information and not as a verdict.
- Say someone will come back to them about the price, and hand over. That
  decision belongs to the shop.
- **Never** say the price is fixed, final, or the best available, and never say
  there is no discount — nobody said any of that, and stating it as the shop's
  position is inventing a policy.
- **Never** offer a discount, a round-down or a better price. Not the
  assistant's to give.

*A customer asking for a better price is a customer who wants to buy.*

**Measured on seven ways of asking** — "بتنزلي السعر شوي؟", "آخر سعر؟", "في
خصم؟", "غالي شوي", "ما بتعملي حسم للزباين الدايمين؟", "لو أخدت كمان وحدة بتخففي
السعر؟", "can you do 28?". All seven now give the listed number and a gentle
hand-over. Nothing was held back by either guard, and nothing was refused. The
best of them answered "مافي عندي معلومة عن خصم حالياً، السعر المكتوب 32 دينار" —
which is the honest shape: it does not know, rather than there being none.

**The assistant stopped naming the shop owner.** In one conversation it wrote
"صاحب المحل" and then "صاحبة المحل" — it does not know who runs the shop or
whether they are a man or a woman, and picking one is inventing a fact about a
real person. It now says "رح نرجعلك", and `HANDOVER_LINE` was changed to match:
"رح نرجعلك بأقرب وقت." / "We'll get back to you shortly."

**The Arabic-quote guard caught our own new text**, which is the second time it
has paid for itself. The price section was first written with a worked example
— "سعر الشنطة عنا 32 دينار" — and the test refusing Arabic sentences that quote
a price failed on it. Replaced with an English gloss. The guard is doing the
job it was narrowed to do.

**Recorded, not built: the sales and discounts section.** The product owner:
"Later down the line, when we add the sales/discounts section we will make the
agent read from it whatever suits the item the customer is talking about." When
that exists it joins `renderFacts` beside the catalog and the delivery zones,
and this section's first line changes from "the number in the shop's facts is
the price" to "the number, and any discount written against that item". Nothing
about that is built, and `CLAUDE.md` still rules out a catalog that grows into
inventory management. It is written down here so the shape is known when
somebody asks for it, not so it gets built early.

---

### 2026-09-20 — It is the shop. It does not defer, and it does not hedge.

Three corrections from the product owner in one sitting, all of them about
confidence rather than correctness.

**1. No third party. "We are the shop owners of sorts."** The assistant had
been deferring on every hand-over — "رح يرد عليك صاحب المحل" — and inventing
that person's gender while it did: "صاحب المحل" in one reply and "صاحبة المحل"
in the next, in one conversation. It now speaks as the shop in the first
person, and the instructions say outright that there is nobody behind it. The
`handOver` flag is described to the model as *"a flag on our side; the customer
never hears about it"* — including in the JSON schema, which sits in the same
context and is where the phrase "the shop owner" survived longest.
`HANDOVER_LINE` became "رح نرجعلك بجواب بأقرب وقت." / "We'll get back to you
with an answer shortly."

Measured: a full nine-conversation run with no "صاحب", no "صاحبة", no "حدا من
المحل", no owner and no manager anywhere in it.

**2. No hedging. "Indecisive answers don't give the customer any
confidence."** The replies it was producing were honest and weak — "مافي عندي
معلومة عن خصم حالياً", "رح نرجعلك بجواب لو في إمكانية بالسعر". *A shop that
sounds unsure about its own prices is a shop nobody buys from.* Everything in
the shop's facts, it knows; it states it plainly. When it genuinely does not
know, that is one plain commitment and then silence — never two, and never
about something it has already answered.

The specific failure was answering the price and then promising to go and check
it: "سعر الشنطة 32 دينار. رح نرجعلك بجواب بخصوص السعر." The second sentence
takes back the first. A price objection is now **moved forward** with something
that is actually written down — a cheaper item, free delivery over the written
amount, the sizes it comes in. That is what someone who runs a shop does with a
price objection: hands the customer a way to say yes.

**3. "Currently we don't have a sale on this item" — not "I don't have
information about a discount".** The product owner's wording, and it overturns
a rule written earlier the same day. It is not an invented policy, because a
discount *would* be written in the shop's facts, so its absence there is the
answer. Saying "I don't know" about something visible in front of you is a
hedge dressed as honesty.

That required the watched-word check to change: **a negation is not a
promise.** "حالياً ما في خصم على هالقطعة" is stripped before the check runs, so
ruling a sale out passes while claiming one still fails — including a sentence
that does both: "ما في خصم عام بس بعطيكي خصم خاص" is caught.

The distinction the prompt now draws, and it is a fine one worth keeping
straight: *"السعر ثابت" is a policy you invented. "حالياً ما في خصم" is what the
shop's own list says.*

**4. An upsell may not be built on invented qualities.** The product owner:
"trying to upsell shouldn't include any made up information." Measured — asked
to recommend a handbag whose entire description is "جلد طبيعي بني", it called
it "أنيق وثابت" and a gift that "تدوم". Elegant, hard-wearing and lasting are
three claims nobody wrote down, and an upsell built on them is the same lie as
an invented price. The reason to buy now comes out of the shop's own
description or not at all, with an escape hatch so the rule does not just push
the model towards a different adjective: **if there is nothing to praise, say
what the thing is and stop.**

**And it stopped reasoning in front of the customer.** "بس عندي تنورة...
بصراحة ما في تنورات ثانية عنا" — it began offering a second skirt, found there
wasn't one, and said so mid-sentence. Honest, and it reads as someone working
it out while you watch. Check the list, then write one finished sentence.

**The watched list became patterns rather than bare words**, because a bare
word was too blunt: "ثابت" caught "شي أنيق وثابت" — hard-wearing, about a
handbag — and withheld a good recommendation to send a bare hand-over line
instead. The word only matters next to a price, so that is what the pattern
says. The matched text itself is now what the seller sees as the reason, which
reads better than a pattern would.

**What is left, and is not fixable this way.** One adjective still slipped
through the final run — "شي أغلى شوي وثابت أكتر", more durable, about the same
bag. Invented qualities are not deterministically catchable without false
positives that cost more than the leak does; the instruction reduces them and
will not eliminate them. Recorded rather than papered over.

**`unusable` is now logged.** It happened once in a live run and did not
reproduce in three attempts on the same input — the worst kind of failure to
have no record of, because the customer silently gets the fixed line instead of
an answer. `ask` now returns a short snippet of what came back, and the webhook
logs it. It is the shop's own outgoing text, never the customer's.

---

### 2026-09-20 — Deployed, and what the live shop showed that the harness could not

Deployed as version 13, then 14 after the fix below. The verify handshake
returns the challenge on the right token and 403 on a wrong one.

**`supabase db push` was deliberately not run.** `20260920000001_assistant.sql`
drops `shop.assistant_caution`, and a web build still running the old
`data.dart` selects that column — the shop screen would break. Nothing in the
assistant needs it. It goes after the client is rebuilt.

*Superseded the next day: there is no deployed web build, so nothing was ever
at risk and the hold was unnecessary. Applied 21 September — see below.*

**The CLI has no `functions logs`, so the evidence comes from the rows.** Two
scripts were added, and both immediately earned it:

- `npm run assistant` — every recent conversation's `ai_state`, its escalation
  reason, and the messages with who wrote each.
- `npm run catalog` — everything the assistant is allowed to know. The answer
  to "did it make that up?": if a detail is not printed, it was invented.
- `npm run replay` — replays a conversation against the **real** catalog and
  the **real** voice examples, pulled from the database.

**The red dress was not invented, and the reason matters.** The reported
screenshot — "يغطيك العافية" answered with "نعم، عندنا فستان أحمر. إي مقاس
بدّك؟" — turned out to have a cause the reproduction missed. The thread carried
an unanswered question from the day before:

    09-19 11:13  customer > شفت عندكم فستان      <- never answered
    09-20 19:45  customer > يغطيك العافية

The old instruction was "reply to the customer's newest messages — the ones
since the shop last wrote", and both of those qualified. So it answered the
older one, a day late, and ignored the newer one. The triage fixes the
ordering. **What it does not fix, and is now open:** the triage answers the
pleasantry and stops, which leaves that day-old question unanswered forever —
in a feature whose stated goal is that no inquiry goes unanswered.

**The seller's own thread is teaching the assistant its voice, out of test
data.** `aiPrompt` takes the tone examples from outbound messages with origin
'seller', and the six it is actually getting are:

    نعم، الشحن مجاني داخل المدينة.
    شكراً لتواصلك معنا.
    تفضل، الشحن مجاني 2026
    مرحبا، سعر iPhone 15 Pro هو 1200 دولار؟
    ?????? ??? ????? ?????? ?? ????. Test reply 1200.
    test 33

Every one a synthetic test message. That "نعم" is where the screenshot's
Modern Standard "نعم" came from — a prompt rule was written against the
symptom, and the cause was that the shop appears to talk that way. The rule
holds anyway: the same shop now answers "الله يعافيك". They should still be
deleted.

**A real catalog is one product, and the harness has eight.** Every "offer an
alternative", "name what is in stock instead", "point at the cheaper thing"
rule has nowhere to go in a one-product shop, and the scripted harness could
never have shown that. `npm run replay` exists so the real shape can be tested.

---

### 2026-09-20 — The question you ask depends on how far along they are

Reported from the live thread. Asked "بدور على هدية لعيد الام كيف ممكن تساعدني"
— looking for a Mother's Day gift, how can you help — the assistant described
the one dress it has and asked **"أي مقاس بدك؟"**, of a customer who had never
said they wanted the dress.

**The prompt was doing exactly as it was told.** The bullet read: *"Ask at most
one question, and make it the one that moves this forward: which size, which
colour, which of the two."* With one product "which of the two" is unavailable,
so it took the next item on the list.

A size question is a *closing* question. It assumes a decision, and to a
customer who is still looking it reads as being hurried — which is the thing
the product owner has now objected to three separate times.

So the question is matched to the stage. Someone who has only said what they
are looking for has not chosen anything: ask what helps them choose — who it is
for, what they usually like, what they want to spend — or ask nothing and offer
to say more. "أي مقاس بدك؟" belongs only after they show interest in one
particular thing.

Measured against the real one-product shop, replaying the real conversation:

    ← بدور على هدية لعيد الام كيف ممكن تساعدني
    → عنا فستان أحمر قطن، سعره 25.5 د.ا ومتوفر بمقاسات S وM وL.
      بتحبي أخبرك أكتر عنه؟
    ← تمام بدي اشتريه
    → تمام! أي مقاس بدك، S ولا M ولا L؟

The size question moved to where it belongs, on its own.

**The other half of the report was a false alarm, and checking it was the
point.** The assistant had said the dress was cotton. `npm run catalog` shows
the description is literally "قطن، مقاسات S M L" — the fabric and the sizes are
both the seller's own words. Nothing invented. That script exists so this
question can be answered in seconds rather than argued about.

---

### 2026-09-20 — Arabic makes you choose a gender, so choose deliberately

Raised by the product owner: Arabic marks the person you are addressing in
nearly every verb and pronoun, so the assistant has to get it right, and
"if the username is ambiguous stick to male wording and the customer would
correct".

**The signal was in the database and was never sent.** `conversations.
customer_name` is filled by `refreshCustomerProfile` from Meta's profile API,
and `aiPrompt` never passed it to the model. The strongest available signal for
how to address someone was sitting one table away while the model guessed. It
is now read in `aiContext` — the conversation row is already being fetched, so
it costs no extra query — and sent after the cache breakpoint with the clock
and the language, because it changes with every conversation and inside the
prefix it would write a cache entry per customer and read none.

**The order of evidence, and it matters:**

1. What the customer says about themselves. "أنا مبسوطة" settles it.
2. Their name, when Meta gave us one.
3. Otherwise the **masculine** — the ordinary Arabic default for someone you
   have not met, and a customer it does not fit will say so.

Their own words come first because a Meta profile name is often a business, a
handle, or simply wrong.

**Measured against the real one-product shop, four ways:**

| name we hold | addressed as | used the name |
|---|---|---|
| Wael K. Saleh | masculine — فيك، بتحب، خذ وقتك | "وائل", greeting and closing |
| سارة الخطيب | feminine — بتحبي، خدي وقتك | "سارة", greeting |
| rabta_store_92 | masculine | no — correctly left out |
| (none) | masculine | no |

---

### 2026-09-20 — It may use the customer's name, and judge where

Also the product owner's: "If the agent is super sure it recognizes the name,
and its clear like a jack, Ahmad whatever, it can use it in welcoming or ending
messages" — then, a moment later, "or whenever/wherever it finds suitable".

So **placement is the model's judgement, not a whitelist.** Greeting and
closing are where it sits most naturally and the instructions say so, but it
may use the name wherever it genuinely fits.

**The real constraint is frequency, not position.** Never twice in one message,
and not in every message. A name in every reply is worse than no name at all,
and repeating it back while quoting somebody a price is a call centre rather
than a shop.

**Certainty is the other constraint.** Only a personal first name it actually
recognises — not a business or brand name, not a handle like `ahmad_shop_92`,
not initials, not a name it is unsure how to read. First name only: "Wael K.
Saleh" is "وائل", never the surname and never the whole thing. If any part of
that is in doubt, the name is left out — a warm reply without a name is
perfectly good, and one that gets somebody's name wrong is not.

That rule held under test: both the handle and the empty name produced replies
with no name in them at all.

**A brittle test was fixed on the way.** Two cache tests located the breakpoint
by counting back from the end of the `system` array, so every volatile block
added after it broke them — three times in one day. They now assert by content:
everything after the breakpoint must be the clock, the language, or the name,
and everything before it must be stable. A test that breaks on every ordinary
change stops meaning anything.

---

### 2026-09-21 — A gap in a conversation is read, not timed

Decided by the product owner, closing the question left open the day before:
"the agent should answer, based on context, if the customer's reply was
regarding an earlier conversation pick it up, if he starts like its a new chat,
then its a new chat."

So the assistant works it out from **what they wrote**, never from how long the
gap was. They are carrying on if they refer back to something, answer a
question it asked them, say "هو" or "it" about a thing already under
discussion, or ask something that only makes sense given what came before. They
are starting fresh if they open with a greeting, ask about something unrelated,
or simply write as though the conversation were new.

**A question nobody ever answered does not expire.** This is the half that
matters for the stated goal — no customer inquiry goes unanswered — and it is
what the triage added on 20 September had accidentally ruled out. If they asked
something before the gap and never got a reply, it gets answered now, late.
That holds even after a bare pleasantry: the ritual reply first, then one short
line answering what they asked before.

The pleasantry rule names this exception itself rather than leaving the model
to reconcile two instructions that meet head-on.

Measured against the real shop, on the exact live case:

    ← مرحبا
    → مرحبا، كيف أساعدك؟
    ← شفت عندكم فستان          (never answered)
    ← يغطيك العافية            (a day later)
    → الله يعافيك 🙂 تفضل، عن أي فستان بتسأل؟

And, once it has been answered, it stays answered — the same thread with the
dress question already dealt with gets back "الله يعافيك 🙂" and nothing more.

One thing did not hold: told the newest message is answered first, it still led
with the older question when both arrived in a burst with no shop reply
between. That case is a burst rather than a gap, answering both is right either
way, and the ordering instruction is left in for the case it was written for.

---

### 2026-09-21 — The client was never hosted, so the migration was never blocked

`20260920000001_assistant.sql` had been held back for a day on the reasoning
that it drops `shop.assistant_caution` and a deployed web build would still be
selecting that column. Checking rather than assuming: `STATUS.md` says plainly
that there is no origin to serve the site from. The client runs locally, from
this repo, which already has the new `data.dart`. There was nothing to break.

Pushed. One row lost `assistant_caution = 'reserved'`, a setting the function
had ignored since version 13, and `assistant_enabled` was untouched. The web
client was rebuilt and the bundle confirmed to contain no reference to the
dropped column.

The lesson is the ordinary one: the risk was real in shape and imaginary in
fact, and one grep through `STATUS.md` settled it a day earlier than it was
settled.

---

### 2026-09-21 — Deleting a message on Facebook does not delete ours

Asked by the product owner, about the synthetic test replies teaching the
assistant its voice: "I will delete the test messages off facebook not sure if
that's enough."

It is not. Meta does send a deletion event, and `parse.ts` **skips** it — a
message flagged `is_deleted` is never processed. That is right for an incoming
delivery and it means nothing removes a row that is already stored. The six
test replies sit in our own `messages` table and would keep feeding
`aiPrompt`'s voice examples however thoroughly they were deleted in Messenger.

They have to be deleted from the database directly. Six rows, all outbound,
all origin 'seller', all between 15 and 18 September.

**Deleted 21 September**, on the product owner's go-ahead, by explicit id
rather than by filter so the delete could not reach further than intended.
Checked first that none of them was the newest message in its conversation, so
`last_message_at` and the unread counts were untouched. The shop now has no
voice examples at all, and writes from its instructions alone until real seller
replies accumulate — which is worth watching: every measurement recorded above
was taken with examples present.

---

### 2026-09-19 — `conversations_owner_update` is fine. ~~It is missing `with check`.~~

**This entry was wrong when first written, and is corrected here rather than
deleted.** It originally claimed that `conversations_owner_update` had a
security gap, because it has a `using` clause and no `with check`, and that a
seller could therefore move a conversation into another workspace. A migration
was written to "fix" it.

**There is no gap.** When `with check` is omitted, Postgres uses the `using`
expression for both — which rows you may act on *and* which rows you may leave
behind. The policy already refuses the move.

This was settled by running it, not by reading the documentation: the test "a
seller cannot move their own conversation into another workspace" in
`tests/schema.test.ts` passes identically with the original policy and with the
rewritten one. The rewrite was therefore dropped. Dropping and recreating a
working policy on a live table is churn and a brief window of risk in exchange
for no change in behaviour.

**What is true, and is the reason the mistake was worth making:** `using` and
`with check` are only interchangeable while they are the same expression. The
moment a policy wants them to differ — a seller who may *read* a wider set than
they may *write* — the implicit behaviour stops being what you want, silently.

So the new `products` and `ai_settings` policies spell `with check` out even
though it is redundant today. Not because it is required, but so that widening
`using` later cannot quietly widen what may be written too.

**The general lesson is about method, not about policies.** The claimed gap
looked obviously right, was recorded as a finding, and was wrong. What caught
it was writing the test first, breaking the thing on purpose, and noticing that
the test passed anyway. A test that cannot fail proves nothing — see the
Testing section of `CLAUDE.md`.

---

## Platform constraints

These are not choices. They are limits Meta imposes, recorded here so they are
not rediscovered later as bugs.

### `META_VERIFY_TOKEN` cannot be recovered, only replaced

Recorded here on 21 September 2026 when `SETUP.md` was deleted, because it is
the one thing in that file that was neither obvious nor reconstructible.

`META_APP_SECRET` is always recoverable from the Meta app dashboard, under App
Settings > Basic. `META_VERIFY_TOKEN` is not. Supabase stores it, and
`supabase secrets list` returns only a digest — never the value. Losing
`supabase/.env` therefore means generating a new token and making both sides
agree again:

```
cp supabase/.env.example supabase/.env     # paste the app secret in
openssl rand -hex 32                       # paste as META_VERIFY_TOKEN
supabase secrets set --env-file supabase/.env
```

Then set the same value in the Meta dashboard, and confirm the handshake
answers `hello` and nothing else:

```
TOKEN=$(grep '^META_VERIFY_TOKEN=' supabase/.env | cut -d= -f2-)
curl -s "https://xejtffbpfguwvybrwqqj.supabase.co/functions/v1/meta-webhook?hub.mode=subscribe&hub.verify_token=$TOKEN&hub.challenge=hello"
```

Anything other than `hello` means the token on the function and the token in
the dashboard disagree.

**The two env files stay separate for a reason**, and it is the same kind of
constraint: `supabase secrets set --env-file` **rejects any secret whose name
begins with `SUPABASE_`**. So Meta's secrets live in `supabase/.env`, which
that command is pointed at, and the Supabase credentials live in
`supabase/.env.local`, which only local tooling reads. Merging them breaks the
command.

### Replies are only allowed inside a time window

A seller cannot reply to a customer whenever they want. Messenger and Instagram
allow free replies for 24 hours after the customer's last message, extendable
to 7 days with the human agent tag.

This is a user-facing problem, not a technical detail. If the seller opens an
old conversation, types a reply and watches it fail, the application looks
broken. The inbox must make the state of a conversation clear before the seller
starts typing.

**The human agent tag and the AI.** The 7-day extension exists for a *human*
agent. Claiming it on a conversation the AI answered would be dishonest and a
policy risk, so the default is that we do not. Recorded here rather than in the
Phase Two decisions because it is a Meta constraint, not a choice of ours.

Meta's disclosure requirements for automated experiences have **not** been
checked. They are listed as an open question and must be verified against
current policy before the AI speaks to a real customer — not assumed.

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

- ~~**How does a seller connect a Meta account on desktop?**~~ **Closed
  17 September 2026** by the decision to ship a web application. The question
  was only ever how the browser returns to a program running outside it. It
  does not arise when the application is the browser. The loopback listener,
  the `rabta://` URI scheme and the Realtime workaround proposed in `STATUS.md`
  are all dropped. What replaces it is smaller and listed as a consequence of
  that decision: the Edge Function must validate the origin it redirects back
  to against an allowlist.

- ~~**Code signing for the Windows installer.**~~ **Closed 17 September 2026.**
  There is no installer. The annual certificate cost is removed from Phase One
  along with it.

- **Can one seller connect more than one Instagram account or Facebook Page?**
  Common for people running several shops.

- ~~**Which numerals in Arabic?**~~ **Closed 17 September 2026:** Western
  (1234) everywhere, including the Arabic interface. Recorded above.

- **Does Phase One link the same customer across channels?** Proposed: no. A
  customer who writes on both Instagram and Messenger is two conversations.
  Cross-channel customer profiles are listed in `CLAUDE.md` as a future phase.

- **Attachment media: stored or proxied?** Depends partly on what Supabase
  storage costs at the volumes we expect. Also tracked in `WEBHOOKS.md`.

### Phase Two

- **Standing: every new place the seller writes something must be fed to the
  assistant.** Asked for by the product owner on 20 September 2026 and written
  into `CLAUDE.md` as a rule rather than left here as a question, because it
  applies to work that has not been proposed yet. The assistant answers only
  from what it is given, so a field the seller fills in and the assistant never
  sees makes the product look broken. Four steps each time: add it to
  `renderFacts` and the query behind it, say in the instructions what may be
  done with it, check whether `claimsAreGrounded` needs to learn that some
  previously forbidden words are now legitimate, and re-run `npm run replay`
  against a real shop.

- **Expand the products section.** Named by the product owner as the next thing
  the catalog needs. It currently holds a name, a price, a free-text
  description and an in-stock boolean, which is thin — a seller has more to say
  about what they sell than fits on one line, and the assistant is limited to
  exactly what is there. What it should grow into is not decided; `CLAUDE.md`
  still rules out stock counts, variants, SKUs and images, so this is a
  decision to take deliberately rather than by accretion.

- **The sales and discounts section**, already promised. When it exists the
  assistant reads whatever applies to the item being asked about, and the
  blanket "حالياً ما في خصم على هالقطعة" stops being the default answer. The
  negation exemption in `claimsAreGrounded` was built for exactly the world
  where that sentence is true; it will need revisiting when it is not.

- **A question asked before the shop last replied, and never answered.** Seen
  live: "شفت عندكم فستان" sat unanswered from 19 September, and the pleasantry
  sent on 20 September was answered with it instead. The triage now answers the
  pleasantry and stops, which is right for the pleasantry and leaves the older
  question unanswered for good. In a feature whose stated goal is that no
  inquiry goes unanswered, that needs a decision.

- **Clear the synthetic test messages out of the seller's own thread.** The
  shop's voice examples are taken from its outbound messages, and all six it is
  currently learning from are test data — "test 33", an iPhone 15 Pro priced in
  dollars, a row of question marks. Not a code change; someone has to delete
  them.

- **What does Meta require us to disclose about automated replies?** Not
  checked. Must be verified against current policy before the AI answers a real
  customer, not assumed. This is the one open question that can block the
  feature outright.

- **How is an AI-sent message shown in the thread?** `theme.dart` reserves
  `accent` for the seller's own words and nothing else, so an AI message cannot
  use it. Proposed: the outbound bubble shape with a `muted` label. Needs a
  decision before it is built — a seller who cannot tell at a glance what they
  said and what the AI said has lost the thing that makes this safe.

- ~~**Do the voice exemplars survive?**~~ **Answered 20 September 2026: they
  survive, and they leak.** They still shape the voice, and they are still
  withheld from a customer writing English. But "for TONE ONLY, do not copy the
  content" does not hold: a delivery time was lifted out of a seller's own past
  reply — "بيوصلك خلال يومين" — and sent to a customer as a promise. It has no
  digits, so the grounding check cannot see it. **Open in its place: what stops
  a fact leaking out of an exemplar?**

- ~~**Should escalation cover an upset customer?**~~ **Closed 20 September
  2026.** A complaint and an upset customer are both named in the hand-over
  list. It costs nothing, and since the rewrite handing over no longer means
  the customer hears silence — they are answered and the seller is told.

- **Can Haiku 4.5 hold the dialect?** **Mostly, measured 20 September 2026.**
  Nine scripted conversations came back in Jordanian dialect, in Arabic script,
  with no pet names, and read like a shop rather than a bot. The prose wobbles:
  "بتنال ايدك أيهما أكتر؟" is not a sentence. Whether that is worth doubling the
  cost for Sonnet 5 is the open part, and it is now a judgement call on
  transcripts rather than an unknown.
