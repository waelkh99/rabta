# Rabta

**One inbox for Instagram and Facebook Messenger, with an assistant that
answers customers when the seller cannot.**

Small shops in Jordan sell through Instagram and Messenger. They run two apps,
miss messages between them, and lose sales to questions asked at eleven at
night and answered the next afternoon. Rabta puts both channels in one place
and puts something in the shop overnight.

---

## The inbox

Every conversation from both platforms, in one list.

- **Both channels, one workspace.** Not two inboxes side by side — one list,
  sorted by what needs attention, with each conversation showing where it came
  from.
- **Arabic and English throughout**, right-to-left and left-to-right, following
  the browser and overridable per session. Western numerals in both, because
  that is what sellers write.
- **Unread and waiting are different things.** A conversation the customer is
  waiting on is grouped apart from one already dealt with.
- **Attachments** — photos, videos, voice notes and shared posts are shown for
  what they are rather than rendering as a blank row.
- **Replies go out through Meta's Send API** and come back as the seller's own
  words, with the 24-hour reply window surfaced before they type rather than
  after Meta refuses.

## The assistant

It answers customers from the shop's own catalog, and hands over anything it
would have to invent.

- **It sells rather than answering questions.** A customer who says "I'm
  looking for a gift for my mother" gets two or three real suggestions with a
  reason, not a request to be more specific. Out of stock is answered with what
  *is* in stock; over budget is answered with the cheaper thing.
- **It writes Jordanian**, in Arabic script, in the customer's own dialect —
  including when they type Arabic in Latin letters. Modern Standard Arabic
  reads *more* robotic than a bot, not less. No terms of endearment, ever.
- **It addresses people correctly.** Arabic marks gender in almost every verb;
  it decides once from what the customer says about themselves, then from their
  name, and holds it. It may use their first name where that sounds human, and
  never in a way that reads like a call centre.
- **It reads the kind of message before answering it.** A pleasantry gets the
  pleasantry back and nothing else. A greeting gets a greeting, not a catalogue.
  Suggestions are earned by the customer saying what they want.
- **It states prices; it does not negotiate them.** Asked for a discount it
  gives the listed price, says plainly whether there is a sale, offers something
  that moves the sale forward, and flags the conversation — without inventing a
  policy in either direction.
- **It never goes silent.** Handing over is a last resort and it always says
  something first. An unanswered customer is the failure this exists to prevent.
- **It knows a gap from a fresh start.** Someone picking up yesterday's thread
  gets it picked up; a question nobody ever answered gets answered late rather
  than never.

### What stops it inventing things

The model is the part that can be swapped. The guards are the design.

- **Deterministic guards before the call** — the reply window, whether a human
  is already at the desk, how many times it has answered in a row, and a
  monthly ceiling. Most turns never reach the API.
- **A grounding check on every number.** Every digit in a reply must appear in
  the shop's own facts or in what the customer wrote, or the reply is held back.
  An invented price is the one failure that loses a seller their customer.
- **A claim check for promises with no digits in them** — that the price is
  fixed, that something is selling fast, that it will arrive tomorrow. Those
  have no numbers for the first check to catch, and every one of them was seen
  in testing.
- **Whatever it cannot verify, it hands over** — and the seller sees why, in
  plain words, on the conversation.

---

## How it is built

| | |
|---|---|
| Client | Flutter web, Arabic/English, RTL |
| Backend | Supabase — Postgres, Auth, Edge Functions (Deno) |
| Messaging | Meta Graph API, webhook-driven |
| Assistant | `claude-sonnet-5`, prompt-cached, roughly $4–7 per seller per month |
| Tests | 321 backend, 86 client, plus scripted conversations against the live model |

Row level security on every table, proven against a second seller rather than
assumed. Signature verification on every webhook delivery. Secrets live as
function environment variables, never in the database — Postgres has no
column-level RLS, so anything a seller must not change cannot sit on a table
they can write to.

Sellers connect their own accounts through Facebook Login for Business. There
is no public sign-up: accounts exist by invitation, and the seller chooses
their own password, so it never travels through a chat.

---

## Where it stands

Phase One is functionally complete. Phase Two is deployed and answering real
messages.

Not built yet: marking an AI-answered conversation in the list, browser
notifications, and drafts for threads the assistant handed over. The product
is not publicly launched — Meta app review and hosting are the remaining
blockers, both tracked in `STATUS.md`.

---

## Reading the repository

- `CLAUDE.md` — what the product is, how it should behave, and what is
  deliberately out of scope
- `DECISIONS.md` — every settled decision and the reasoning behind it,
  including what was measured, what was wrong first, and Meta's constraints
- `CHECKLIST.md` — what has been built and proven, phase by phase
- `STATUS.md` — where the work stands right now
- `WEBHOOKS.md` — the webhook service specification
- `ONBOARDING.md` — the seller's first ten minutes

`DECISIONS.md` is the one worth reading. It records the failures as carefully
as the results — an assistant that answered an English customer in Arabic, one
that invented a delivery date out of the seller's own past reply, one that
asked a browsing customer what size they wanted.

---

## Working on it

```
cd supabase && npm test        # backend: typechecks every function, then runs
flutter test && flutter analyze

cd supabase && npm run events      # what Meta actually sent
cd supabase && npm run assistant   # what the assistant did, and why
cd supabase && npm run catalog     # everything the assistant is allowed to know
cd supabase && npm run replay      # replay a chat against the real shop
cd supabase && npm run live        # scripted chats against the real model
```

The last two spend real money. They exist because "does this read like a
person" is the one requirement no assertion can check, and between them they
have found more defects than the unit tests have.

Run the client with `flutter run -d chrome --dart-define-from-file=env.json
--web-port=5353`. The port is pinned because `meta-oauth` only returns a
browser to an origin on its allowlist, and an allowlist cannot hold a port that
changes every run.

`supabase/.env` and `supabase/.env.local` hold the Meta app secret and a
Supabase key that bypasses row level security. Both are protected by
`.gitignore` alone — worth a glance at `git status` before any commit that
touches `supabase/`. Why they must stay separate, and why `META_VERIFY_TOKEN`
cannot be recovered if lost, are in `DECISIONS.md` under Platform constraints.
