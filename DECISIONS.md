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

- **Public sign-up must be turned off.** Checked on 18 September and it is
  currently **on**: `/auth/v1/settings` reports `disable_signup: false`, so
  anyone who finds the URL can create an account. The publishable key is in the
  shipped JavaScript by design, so it is not what protects this. Row level
  security means a stranger would see only their own empty workspace and no
  seller's data, but it is still contrary to the decision above.
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
