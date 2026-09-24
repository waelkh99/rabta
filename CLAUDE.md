# CLAUDE.md

## Project Overview

This project is a social commerce application for businesses and individuals who sell products mainly through Meta platforms.

The long-term goal is to provide one place where sellers can manage customer interactions, understand their customers better, streamline sales-related work, and eventually add useful automation and integrations.

The product should be designed around real seller workflows, not around technical possibilities.

Decisions that have already been settled — supported platforms, backend, and
known Meta limitations — are recorded in `DECISIONS.md`. Read it before making
architectural choices.

`WEBHOOKS.md` specifies the webhook service that receives messages from Meta
and sends replies. It is being built as a standalone piece of work.

---

## Phase One

The first phase is focused only on creating a unified customer inbox.

The user should be able to:

- Connect their supported Meta accounts.
- Receive customer messages from Instagram and Facebook Messenger.
- View all conversations from one place.
- Clearly see which platform each conversation came from.
- Open a conversation and view the message history the application has received.
- Reply to customers from the application.
- See unread conversations and new incoming messages clearly.
- Handle common message attachments where possible.

The goal is to make managing customer conversations simpler than switching between multiple Meta applications.

---

## Out of Scope for Phase One

Do not add these unless explicitly requested:

- ~~AI-generated replies.~~ **Requested 19 September 2026. Now Phase Two —
  see below.**
- ~~Automatic AI responses.~~ **Requested 19 September 2026. Now Phase Two —
  see below.**
- ~~Product catalog management.~~ **Partly requested 19 September 2026.** A
  product catalog exists in Phase Two so the AI can answer questions from it.
  It is not inventory management: no stock counts, no variants, no SKUs, ~~no
  images~~. **Product photos requested 22 September 2026** — see Phase Two.
- Order management.
- Inventory management.
- Delivery company integrations.
- Payments.
- ~~Sales analytics.~~ **Partly requested 24 September 2026** — how each
  conversation ended, and what the assistant learns from it. See "How
  conversations end" below. Revenue reporting is still out.
- Campaign analytics.
- Advanced CRM functionality.
- Other social media platforms.

Do not add features simply because they may be useful later.

The struck-through lines are kept rather than deleted so that a future reader
can see they were deliberately out of scope and were then deliberately asked
for. They do not widen Phase One. Phase One's goal and success criteria above
are unchanged.

---

## Phase Two

Phase Two adds an AI assistant that answers customer inquiries the seller has
not got to yet. Requested by the product owner on 19 September 2026, after
Phase One was functionally complete.

The problem it solves is the one that costs a seller money: a customer asks a
price at 11pm and gets an answer the next afternoon, or never.

The AI should:

- Answer basic inquiries — price, availability, basic product facts — from the
  seller's own product catalog.
- Hand anything else to the seller rather than guess.
- Write like the seller, not like a chatbot.

The goal is that **no customer inquiry goes unanswered, and the seller does not
feel replaced.**

### What "not robotic" means here

The product owner's stated reason for building this is that ordinary chatbots
are too robotic and generic. That is a requirement, not a preference, and it
has three parts:

- **The seller's voice.** The AI writes from the seller's own past replies, so
  it sounds like their shop rather than like an assistant. With one limit:
  **no terms of endearment** — no حبيبتي, no عزيزتي, no "dear" — however freely
  the seller uses them. Warm and professional, never familiar.
- **The customer's language.** The product mainly serves **Jordan**, so
  customers write Jordanian and wider Levantine dialect, often in Latin
  letters. Replying in Modern Standard Arabic reads *more* robotic than a bot,
  not less.
- **Knowing when to stop.** Handing a conversation over is a good outcome, not
  a failure. An AI that answers everything badly is worse than one that answers
  half and says so.

### Still out of scope in Phase Two

~~Insights and recommendations to the seller, analytics,~~ (**partly requested
24 September 2026** — see "How conversations end"), order management, stock
decrementing, product variants, SKUs, ~~and product images~~, and promo codes.

**Asked for on 22 September 2026, and now in Phase Two:**

- **Product photos**, up to five per product. The assistant sends them to a
  customer who asks to see an item, and later recognises a screenshot a
  customer sends of one.
- **Categories**, optional, so an offer can target a group of products.
- **Offers** (العروض) — percentage off, a fixed amount off, and buy X get Y,
  each for the whole shop, some categories or some products, with optional
  dates; and, from 23 September, an offer written in the seller's own words,
  which the assistant reads as written.

- **Excel import and download.** A seller's own sheet is read as it is,
  whatever its column names, and the catalog can be downloaded as a sheet to
  edit and import back.
- **A product code** (رمز المنتج), so a sheet imported again updates the
  products it lists. Matched on the code, never the name — a shop writes one
  product in Arabic in one place and English in another. Every product has
  one: the seller's own, or the next `P-001` style code. This is a label the
  seller already uses, not a SKU in the inventory sense; nothing hangs off it.

Sizes, colours and fit are **not** structured fields. The product owner asked
for the easiest thing for the seller "even if it puts extra load on the agent":
the seller writes them in one details box, in their own words, and the
assistant reads it. A size or colour list with its own stock or price would be
variants, and variants are still out.

The catalog exists so the model can answer questions. It is not a place for the
seller to run their inventory, and it should not grow into one without a
decision that says so.

`DECISIONS.md` holds the settled Phase Two decisions and the reasoning behind
each. `CHECKLIST.md` tracks progress.

### Anything the seller writes down, the assistant should be able to read

**A standing rule, asked for by the product owner on 20 September 2026.**

The assistant can only answer from what it is given. Every time this product
gains a place for the seller to record something — a new field, a new section,
a new screen — that information has to be **fed to the assistant as well**, or
it will keep telling customers it does not know things the seller has already
written down.

This is easy to forget because the two halves look unrelated: one is a form,
the other is a prompt. They are not. A field the seller fills in and the
assistant never sees is a field that makes the product look broken.

So whenever a new source of seller-written information is added:

1. Add it to `renderFacts` in `supabase/functions/meta-webhook/ai.ts`, and to
   the query that feeds it in `process.ts`.
2. Say in the instructions what the assistant may do with it, and what it may
   not.
3. Check it against the guards. `claimsAreGrounded` refuses words the shop
   never wrote — if the new data makes some of them legitimate, the guard has
   to learn that too. A discount field is exactly this case.
4. Re-run `npm run replay` against a real shop, not only the scripted harness.

**Done, and the worked example of this rule:** the pricing stance, added
22 September 2026. Two modes — **strict**, where the listed price is final, and
**notify**, where the assistant answers and brings the conversation to the
seller. All four steps above were needed, and step 3 was the interesting one:
the guard already refused any reply claiming a price was fixed, because until
then no shop had ever said so. It did not need weakening. `renderFacts` writes
the claim, in the exact wording the guard watches for, and the claim becomes
true. Step 4 found the proof, against the real model and the real shop — on
notify the assistant hands price haggling over and says why ("ولا يوجد نص يقول
إن السعر ثابت"), and on strict it says the price is fixed and offers something
cheaper instead of stopping.

**The sales and discounts section inherits this.** Neither mode invents a
discount today; what the assistant may say about money comes from the catalog.
When the sales section exists it becomes a third source feeding the same
`renderFacts` string, and the `خصم` patterns in `claimsAreGrounded` become
legitimate the same way this one did — by the shop having written it down.

**Done 22 September 2026, the second and third worked examples:** the products
section (photos, codes, categories, details) and the offers section. Both feed
`renderFacts`. Offers needed step 3 the same way the pricing stance did — a
running offer writes the discount words into the facts, so the guard finds them
— and photos needed a guard of their own, because the model promised photos
that did not exist. `npm run replay` found both problems, not the unit tests.

**Done 23 September 2026:** offers in the seller's own words, read and
understood by the assistant rather than recited; and recognising a screenshot
a customer sends against the catalog's thumbnails. Both measured against the
real model.

None of this widens Phase Two's goal. It is a rule about keeping the assistant
in step with the product, not a licence to add features.

---

## How conversations end

Requested by the product owner on 24 September 2026. The product owner counts
everything before launch as one phase, so this is not numbered; it is part of
what ships.

The problem: Rabta sees every conversation and does not know which ones became
a sale. Without that, the seller cannot tell where customers are lost, and the
assistant's work is invisible.

**Every conversation gets an outcome**, one of:

- **Ordered** (طلب)
- **Didn't buy** (ما اشترى), with a reason where there is one — price,
  delivery fee, size not available, out of stock, no reply in time
- **Just asking** (استفسار فقط) — nothing was for sale, "where are you?"
- no mark while it is still open

**The assistant sets it; the seller corrects it with one tap; the seller always
wins.** A tag the seller has to set by hand is a tag most sellers never set.
The assistant's mark is shown as its suggestion, not as fact.

**The same pass extracts what the assistant can read from the conversation:**
the products discussed, matched to the catalog; why a customer did not buy;
the customer's area; what kind of questions they asked. It runs once a
conversation has settled, on every conversation — including ones the seller
handled alone or the assistant never touched — not only when the assistant
replies.

**The seller sees it** as a label on the row and a short "this week" view:
how many conversations became orders, the top reasons people did not buy, the
most-asked products, customers lost to silence, and when customers write.
Sentences and numbers first; a chart only where it says more than a number.

**Still out:** an order's value (decided: no value, not even an estimate),
items and quantities typed by the seller, order status, delivery tracking,
revenue, follow-up lists, and campaign analytics. An outcome is a label on a
conversation, not an order record, and should not grow into one without a
decision that says so.

The rule that anything the seller writes down reaches the assistant applies
here in reverse as well: an outcome the seller corrects is the ground truth the
assistant's marks are measured against, and the view says how often it was
right.

---

## Product Direction

This should not feel like separate inboxes placed inside one application.

The experience should feel like one customer communication workspace.

The product should prioritize:

- simplicity;
- speed;
- clear navigation;
- minimal unnecessary steps;
- understandable information;
- clean UX;
- low cognitive load.

The application is intended for people who may not be highly technical.

Do not expose unnecessary technical language to the user.

---

## Product Philosophy

The product should solve real problems in the simplest useful way.

Avoid adding complexity to make the product look more impressive.

When deciding between:

- a complicated solution with many features;
- a simple solution that solves the user's problem well;

prefer the simple solution.

---

## Role of Claude

Claude is the development assistant, not the product owner.

Claude should:

- help implement ideas;
- identify potential problems;
- point out missing cases;
- suggest improvements;
- explain trade-offs;
- help simplify solutions.

Claude should not:

- silently change the product direction;
- invent major features;
- expand the scope without being asked;
- make important UX decisions without discussing them first;
- assume future requirements;
- overengineer the project.

If an important product or UX decision needs to be made, Claude should explain the decision and suggest options before implementing it.

---

## Testing

Everything implemented must be tested. Not described as tested, not assumed to
work — actually run.

This is not negotiable and it is not traded away for speed. Code that has not
been executed is not finished.

Where the obvious way to test something is unavailable, find another way rather
than skipping it. A missing tool is a problem to solve, not a reason to ship
untested work.

Tests must be shown to fail when the code is wrong. A test that passes against
broken code is worse than no test, because it produces false confidence.

Report results honestly. If something fails, say so and show the output. If
something could not be tested, say exactly that and why.

### Anything the seller sees is not done until Playwright has seen it

**A standing rule, asked for by the product owner on 21 September 2026.**

No change that affects the interface may be called done, ticked in
`CHECKLIST.md`, or reported as working on the strength of unit tests. It has to
be driven in a real browser with Playwright and looked at.

This is not a formality and it is not the same rule as the one above. A widget
can pass every test written about it and still be wrong on screen: a line that
overflows its row, a third line that breaks the alignment of the two above it,
text that reads left to right inside an Arabic layout, a colour that is legible
in the theme it was written in and invisible in the other, a control that is off
the edge at phone width. None of those fail a test. All of them are the seller's
whole experience of the feature.

So for any change to a screen, a widget, a string that appears in one, or the
data that decides what a screen renders:

1. Run the application and drive it with Playwright — not a description of what
   it would look like, and not a unit test standing in for the view.
2. Look at it in **both languages**. Arabic is the source language and the one
   the layout is most easily wrong in.
3. Look at it at **desktop and phone width**.
4. Only then tick the box, and say in the tick that it was seen rather than
   tested.

Unit tests still do their job: they cover the logic, and they are still shown to
fail when the code is wrong. They are the floor, not the finish line.

Where the interface cannot be reached — no credentials, no data to render, a
migration not yet applied — that is a blocker to raise, not a reason to tick the
box. Say plainly that it is built but unseen.

---

## User Experience

The product should be designed from the perspective of someone actively handling customer inquiries throughout the day.

Important questions should always include:

- Is this easy to understand?
- Can the user complete this with fewer steps?
- Is important information visible at the right time?
- Would a non-technical person understand what to do?
- Is this helping the seller respond to customers faster?

Avoid unnecessary screens, popups, settings, and steps.

---

## Future Vision

Later phases may include:

- WhatsApp support;
- customer profiles across multiple channels;
- order information;
- delivery company integrations;
- sales insights;
- conversation analytics;
- automation.

AI-assisted replies and AI-powered customer service have moved off this list.
They were requested on 19 September 2026 and are Phase Two, described above.

These are future possibilities only.

They should not influence Phase One or Phase Two unless explicitly requested.

---

## Phase One Success

Phase One is successful when a seller can comfortably manage their Instagram and Facebook Messenger customer conversations from one place without needing to constantly switch between separate applications.

That is the only goal for now.
