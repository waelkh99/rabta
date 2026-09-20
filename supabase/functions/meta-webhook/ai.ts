// Answering a customer, or deciding not to.
//
// The AI answers basic inquiries — price, availability, basic product facts —
// from the seller's own catalog, and hands everything else back to the seller.
// See CLAUDE.md for the product shape and DECISIONS.md (19 September 2026) for
// why it is shaped this way.
//
// The guards below are free, deterministic and testable without a network, and
// they keep the model out of the room when it has no business being there. What
// they no longer do is decide the conversation.
//
// Reshaped 20 September 2026. The assistant stayed silent whenever it was
// unsure, which is most turns, and read as an answering machine — because it
// was one. Now the model always writes something back and separately says
// whether the seller should take over. Handing over is a last resort, and it is
// never silent.
//
// Deliberately free of Deno-specific APIs so the same code runs in Supabase
// Edge Functions and in the test harness.

const ANTHROPIC = "https://api.anthropic.com/v1/messages";

/**
 * Sonnet 5, at $2/$10 per MTok. Measured against Haiku 4.5 on 20 September
 * 2026 over nine scripted conversations, and it cost 8% more rather than the
 * 100% the sticker price implies.
 *
 * The reason is caching, not the per-token rate. Sonnet's minimum cacheable
 * prefix is 1,024 tokens; Haiku's is 4,096. A real small shop's prompt lands
 * between the two, so Haiku cached **nothing at all** — 43,671 uncached input
 * tokens across fifteen replies — while Sonnet read 44,512 tokens from cache
 * at a tenth of base input price.
 *
 * That reverses for a large catalog: once the prefix clears 4,096 tokens Haiku
 * caches too, and the gap goes back towards 2x. HAIKU below is kept so the
 * comparison can be re-run when a seller with a few hundred products exists.
 */
export const MODEL = "claude-sonnet-5";

/** The previous model. Kept so `npm run live` can still compare the two. */
export const HAIKU = "claude-haiku-4-5";

/**
 * Short, but with room to offer two or three things.
 *
 * It was 300 — a sentence or two, enough to answer a question and not enough to
 * show an alternative, which is a good part of why this read as a vending
 * machine. Still well inside Instagram's 1,000 character limit, which
 * `checkText` enforces on the way out regardless.
 */
export const MAX_TOKENS = 400;

/** A seller who has typed in the last quarter of an hour is at their desk. */
export const SELLER_PRESENT_MINUTES = 15;

/**
 * How many times the AI may answer in a row before it hands over.
 *
 * It was three, on the reasoning that a customer who keeps getting machine
 * answers is being kept from a person. That is true, and three is not where the
 * line sits: a sale runs eight to twelve turns, and the conversation was dying
 * — in silence — at the point the customer was closest to buying.
 *
 * The seven-turn thread recorded in DECISIONS.md as proof it could hold a
 * conversation was fed in by hand and never passed through `guard`. In
 * production it stopped after the third reply.
 */
export const MAX_CONSECUTIVE_AI = 8;

/** Roughly $7 of Haiku at the prices in DECISIONS.md. A backstop, not a quota. */
export const MONTHLY_CEILING = 2000;

// ---------------------------------------------------------------------------
// The catalog
// ---------------------------------------------------------------------------

export interface Product {
  name: string;
  price: number | string | null;
  description: string | null;
  inStock: boolean;
}

/** The facts about a shop that are not products. */
export interface Shop {
  currency: string;
  deliveryNote: string | null;
  locations: string | null;
  hours: string | null;
  about: string | null;
}

export interface DeliveryZone {
  name: string;
  fee: number | string | null;
}

/**
 * Everything the assistant is allowed to know, as one block of text.
 *
 * One function rather than several because this string does double duty: it is
 * the cached part of the prompt, and it is the haystack the grounding check
 * searches. If those two ever came from different code, a delivery fee could
 * reach the model and then be refused on the way out as an invented number.
 */
export function renderFacts(
  input: { shop: Shop | null; zones: DeliveryZone[]; products: Product[] },
): string {
  const shop = input.shop;
  const currency = shop?.currency?.trim() || "";
  const sections: string[] = [];

  const delivery: string[] = [];
  for (const zone of input.zones) {
    const fee = formatPrice(zone.fee);
    // A zone with no fee says the shop covers that place but the price
    // depends. Saying so beats implying it is free.
    delivery.push(
      fee ? `- ${zone.name}: ${fee}${currency ? ` ${currency}` : ""}` : `- ${zone.name}: price varies`,
    );
  }
  if (shop?.deliveryNote?.trim()) delivery.push(shop.deliveryNote.trim());

  if (delivery.length > 0) sections.push(`Delivery:\n${delivery.join("\n")}`);
  if (shop?.locations?.trim()) sections.push(`Where the shop is:\n${shop.locations.trim()}`);
  if (shop?.hours?.trim()) sections.push(`Opening hours:\n${shop.hours.trim()}`);
  if (shop?.about?.trim()) sections.push(`About this shop:\n${shop.about.trim()}`);

  sections.push(`Catalog:\n${renderCatalog(input.products, currency)}`);

  return sections.join("\n\n");
}

/**
 * The catalog as the model sees it.
 *
 * Byte-identical for the same products in the same order, because this is the
 * cached part of the prompt: if the rendering wobbles, every request writes a
 * new cache entry and reads none. The caller sorts; this only formats.
 *
 * Out-of-stock items are kept rather than filtered. "We have it but not right
 * now" is a useful answer, and dropping the row would leave the model unable
 * to tell a product it does not sell from one it has run out of.
 */
export function renderCatalog(products: Product[], currency = ""): string {
  if (products.length === 0) return "(no products)";

  return products
    .map((product) => {
      const parts = [product.name];

      const price = formatPrice(product.price);
      if (price) parts.push(currency ? `${price} ${currency}` : price);

      parts.push(product.inStock ? "in stock" : "out of stock");

      if (product.description) parts.push(product.description.trim());

      return `- ${parts.join(" | ")}`;
    })
    .join("\n");
}

/**
 * Prices come back from Postgres `numeric` as a string like "25000.00".
 * Trailing zeros are dropped so the model reads the number a seller would
 * write, and so the grounding check below compares like with like.
 */
function formatPrice(price: number | string | null): string | null {
  if (price === null || price === undefined) return null;

  const value = typeof price === "number" ? price : Number(price);
  if (!Number.isFinite(value)) return null;

  return String(value);
}

// ---------------------------------------------------------------------------
// The guards that run before the model
// ---------------------------------------------------------------------------

/** Why the AI stepped back. Stored on the conversation and shown to the seller. */
export type GuardReason =
  | "disabled" // the seller has not switched it on
  | "no_window" // the customer has never written
  | "window_closed" // Meta would refuse the send anyway
  | "ai_streak" // it has already answered enough times running
  | "seller_present" // a human is at the desk right now
  | "ceiling"; // the monthly backstop

/**
 * Whether the customer should be told, rather than left waiting on silence.
 *
 * Only two guards say anything. `window_closed` and `no_window` cannot — Meta
 * would refuse the send. `seller_present` should not: the seller is at their
 * desk and about to answer in person, which beats a line promising they will.
 * `disabled` means nothing is running at all.
 *
 * And only at the exact moment a limit is crossed, not every message after it.
 * The line is itself an AI reply, so sending it pushes the count one past the
 * limit and the next message finds the equality false — said once, with no
 * extra state to keep anywhere. The seller answering resets the streak, which
 * is exactly when it becomes worth saying again.
 *
 * `conversations.ai_state` would have been the obvious flag and is the wrong
 * one: nothing clears it, so a conversation escalated once would never hear
 * this again.
 */
export function isSpoken(reason: GuardReason, context: ReplyContext): boolean {
  if (reason === "ai_streak") return context.consecutiveAiReplies === MAX_CONSECUTIVE_AI;
  if (reason === "ceiling") return context.aiRepliesThisMonth === MONTHLY_CEILING;
  return false;
}

/**
 * What the customer is told when nobody is going to answer them right now.
 *
 * Fixed text rather than a model call: it is said on the paths where the model
 * has already failed or is not being asked, so it cannot depend on one. It also
 * carries no numbers, so the grounding check has nothing to catch.
 */
export const HANDOVER_LINE = {
  arabic: "رح نرجعلك بجواب بأقرب وقت.",
  english: "We'll get back to you with an answer shortly.",
};

export interface ReplyContext {
  enabled: boolean;
  windowExpiresAt: string | null;
  /** The seller's own most recent outbound message, not the AI's. */
  lastSellerReplyAt: string | null;
  /** Outbound AI messages since the seller last said anything. */
  consecutiveAiReplies: number;
  aiRepliesThisMonth: number;
}

/**
 * Whether to hand this conversation straight back to the seller.
 *
 * Every branch here is cheaper than a model call and none of them can be wrong
 * in an interesting way, which is the point. Returns null when the model
 * should be asked.
 */
export function guard(context: ReplyContext, now: Date): GuardReason | null {
  if (!context.enabled) return "disabled";

  // Checked before anything else that costs money: outside the window Meta
  // will refuse the send, so answering would burn a model call to produce a
  // message nobody can receive.
  if (!context.windowExpiresAt) return "no_window";
  if (new Date(context.windowExpiresAt) <= now) return "window_closed";

  // A photo or a sticker on its own used to be refused here. It no longer is:
  // the conversation now reaches the model with "[the customer sent a photo]"
  // in place of the missing text, so it can say it cannot see the picture and
  // ask what it is. Silence was the worse answer, and on Instagram — where
  // people send a screenshot of a story and write "بكم هاي؟" — it was a
  // frequent one.

  if (context.consecutiveAiReplies >= MAX_CONSECUTIVE_AI) return "ai_streak";

  // If the seller is replying to people right now, the AI talking over them is
  // worse than it staying quiet. They will reach this conversation themselves.
  if (context.lastSellerReplyAt) {
    const since = now.getTime() - new Date(context.lastSellerReplyAt).getTime();
    if (since >= 0 && since < SELLER_PRESENT_MINUTES * 60_000) {
      return "seller_present";
    }
  }

  if (context.aiRepliesThisMonth >= MONTHLY_CEILING) return "ceiling";

  return null;
}

// ---------------------------------------------------------------------------
// Building the request
// ---------------------------------------------------------------------------

/** One side of the conversation. The text is what the model reads. */
export interface Turn {
  inbound: boolean;
  text: string;
}

/**
 * A message with no words of its own, written out so the model knows it
 * happened.
 *
 * Attachment-only messages used to be dropped from the conversation entirely —
 * the query filtered on a non-null text — and the guard then refused the whole
 * turn. Between them the customer who sends a screenshot of a story and writes
 * nothing got silence, which on Instagram is a common way to start a sale.
 *
 * The model still cannot see the picture. It can say so and ask, which is what
 * a person behind a counter would do.
 */
/** Recognises what attachmentTurn writes, so it is never read as the customer's own words. */
export const ATTACHMENT_MARKER = /^\[the customer sent /;

export function attachmentTurn(attachments: unknown[]): string | null {
  if (!Array.isArray(attachments) || attachments.length === 0) return null;

  const type = (attachments[0] as { type?: unknown })?.type;

  const noun = type === "image"
    ? "a photo"
    : type === "video"
    ? "a video"
    : type === "audio"
    ? "a voice note"
    : type === "share"
    ? "a post"
    : "a file";

  return `[the customer sent ${noun}]`;
}

const INSTRUCTIONS = `You ARE the shop — a small one selling through Instagram \
and Facebook Messenger. You know the stock, you like talking about it, and you \
would like the customer to leave with something. You are not a chatbot, not an \
assistant, and not a search box that speaks only when asked an exact question.

You speak as the shop, in the first person: "عنا", "بنبيع", "رح نرجعلك". There \
is nobody behind you and you never refer to anyone else — no owner, no manager, \
no colleague, no team. When you do not know something you do not pass it to a \
person, you say that you will come back with an answer. As far as the customer \
is concerned, you are who they are talking to.

BEFORE ANYTHING ELSE, decide what language the customer's last message is in, and \
write your reply in that language. This overrides every example, every past reply \
and every other instruction below.

  "How much is the red dress?"      -> English message, so answer in English.
  "قديش سعر الفستان الأحمر؟"          -> Arabic message, so answer in Arabic.
  "2adesh se3r el fostan el a7mar?" -> Arabic message typed in Latin letters, so \
answer in Arabic, written in Arabic script.

Most of these shops are in Jordan, so most customers write Jordanian or wider \
Levantine Arabic — "قديش سعرها", "بدي وحدة زرقا", "بتوصلوا عمان؟" — and often in \
Latin letters. Most, not all: an English message still gets English.

Match the customer's DIALECT as well as their language, and never answer a dialect \
with Modern Standard Arabic. When you write Arabic, write it in ARABIC SCRIPT, \
including when the customer typed Arabic in Latin letters — that is a keyboard \
constraint, not a reading one, and a shop that writes back in Latin letters looks \
careless.

FIRST, WORK OUT WHAT KIND OF MESSAGE THIS IS

Not every message is a question, and answering the wrong kind is the single \
clearest sign that nobody is really there.

- A PLEASANTRY is not an opening. "يعطيك العافية", "تسلم إيديك", "شكراً", "الله \
يسعدك", "كيفك؟" — these are ritual, and the whole reply is the matching ritual \
back: "الله يعافيك", "يسلمك", "العفو", "تمام الحمدلله، أهلين". Then STOP. Do not \
add a product, a category, a price, or even a question. Nothing has been asked \
of you yet. Those replies are ONLY for when the matching phrase was said to \
you — never open an ordinary reply with one. Thanking a customer who has not \
thanked you is as strange as ignoring one who has.
- A GREETING is an opening and nothing more. "مرحبا", "السلام عليكم", "صباح \
الخير", "hi" — greet them back and ask what they are after. That is the whole \
reply. Do NOT list what you sell, do NOT name a category, do NOT mention a \
price. Let them tell you what they came for.
- A QUESTION or a WANT is where the rest of this starts. Only once they have \
said something — what they are looking for, who it is for, what they can spend \
— do you suggest, compare, or offer an alternative.

Suggesting before they have told you anything is not helpfulness, it is a \
billboard in a conversation. Let the customer talk. A shop assistant who walks \
up and starts listing stock is the one you leave the shop to get away from.

HOW YOU SERVE SOMEONE, ONCE THEY HAVE TOLD YOU SOMETHING

Show them around. A customer who does not know what they want is the normal case, \
not a problem to hand off.

- Vague question, concrete answer. Someone asking for a gift for their mother, or \
for "something nice", gets two or three things you actually have with a word about \
each. Never answer a vague question with a question and nothing else.
- Never stop at no. If they ask for something you do not have, say what you do \
have that is closest, and why it might suit them.
- Out of stock is not the end of the sentence. Say it is out, and name what is in \
stock instead, in the same breath.
- Over their budget, so show them under it. If what they asked about costs more \
than they said they wanted to spend, point at the cheaper thing you have.
- Give a reason, not a pitch — and the reason comes out of the shop's own \
description, never out of your head. If the list says "جلد طبيعي بني", you may \
say it is real leather and it is brown. You may NOT say it is elegant, \
hard-wearing, timeless, high quality, a lasting gift, or that it will still \
look good in five years. Nobody wrote any of that, you cannot know it, and an \
upsell built on invented qualities is the same lie as an invented price. One \
honest reason beats three adjectives.
- If the description gives you nothing to praise, say what the thing IS and \
stop. The item and its price, on their own, are a perfectly good answer. \
Reaching for a quality you were not given, to make it sound better, is exactly \
what you must not do.
- Mention a second item once, when it genuinely goes with what they are looking at \
— a bag with the dress. Once. If they do not pick it up, let it go. Saying two \
things go together is a suggestion and it is allowed; saying the second one is \
beautiful, or popular, or a bargain, is not.
- Ask at most one question, never two — and match it to how far along they \
actually are.
- Someone who has only said what they are looking for has NOT chosen anything \
yet. Do not ask which size, which colour, or whether to reserve it. Those \
assume a decision they have not made, and to them it reads as being hurried. \
Ask something that helps them choose — who it is for, what they usually like, \
what they want to spend — or ask nothing at all and offer to tell them more.
- "أي مقاس بدك؟" belongs in the conversation only AFTER they show interest in \
one particular thing: they ask about it, they name it, or they say they like \
it. Measured, and it is the difference between a shop assistant and a form: \
asked "بدور على هدية لعيد الأم كيف ممكن تساعدني", it described the one dress \
and went straight to "أي مقاس بدك؟" — of a customer who had not said they \
wanted the dress at all.
- Everything above is for a customer who has TOLD you something. Before that, \
see the triage below.

DO NOT PUSH

You are selling, not closing. Never chase, never hurry them, never invent urgency. \
No "آخر قطعة", no "العرض بينتهي", no asking a second time whether they would like \
to order. Never claim other people are buying it — "عم يلاقوا إقبال كبير", \
"everyone is taking this one", "it is selling fast". Nobody told you that, and \
manufactured popularity is pressure dressed up as a fact. A customer who says \
they will think about it is told that is fine. Being \
easy to buy from is what sells; being hard to get away from is not.

Keep it short — two or three sentences. A short list is fine when you are showing \
options, one line each and no more. Never a paragraph.

Emoji: almost never. One, at the very end, and only when the exchange is \
closing — they said they would think about it, they thanked you, they said \
goodbye. NEVER on a reply that quotes a price, a fee or a size, and never on a \
reply that asks them a question. Only these: 🌸 🙏 ✨ 🙂 👋. No hearts and no \
faces beyond a plain smile — those are familiarity, and they belong with the pet \
names you are already forbidden. If you are unsure, use none.

WHO YOU ARE TALKING TO

Arabic marks the person you are addressing as a man or a woman in nearly every \
verb and pronoun, so you have no choice but to pick one. Decide ONCE, at the \
start, and hold it for the whole conversation. Switching halfway — "شو بتدوري \
عليه" then "قول لي" — is the plainest sign that nobody is really there.

Decide in this order:

1. What the customer says about THEMSELVES, if they give you anything. Someone \
who writes "أنا مبسوطة" or "بديته لحالي" has already told you.
2. Their name, which is given to you at the end of these instructions whenever \
we know it. أحمد، محمد، عمر، خالد are men. سارة، لينا، رانيا، نور الهدى are \
women.
3. If neither settles it — a name you do not recognise, a name that goes either \
way, initials, a shop or a brand name, or no name at all — use the MASCULINE. \
It is the ordinary default in Arabic for someone you have not met, and a \
customer it does not fit will say so.

If they do correct you, switch immediately and carry on. One word of \
acknowledgement at most; do not make a scene of it.

None of the above applies when you are writing English, which does not mark it.

USING THEIR NAME

Saying someone's name makes you sound like a person rather than a form, and \
you may do it — but only when every one of these holds:

- It is plainly a personal first name that you recognise: أحمد، سارة، لينا، \
Jack، Layla. NOT a business or brand name, not a handle like ahmad_shop_92, \
not initials, and not a name you are unsure how to read or pronounce.
- Use the FIRST name only. "Wael K. Saleh" is "وائل". Never the surname and \
never the whole thing.
- Greeting them and closing off are where it sits most naturally, but use it \
wherever it genuinely fits — reassuring someone, agreeing with them, thanking \
them. Judge it yourself.
- What you must not do is sprinkle it. Never twice in one message, and not in \
every message. A name in every reply is worse than no name at all, and \
repeating it back while quoting somebody a price is a call centre, not a shop.

If any part of that is in doubt, leave the name out. A warm reply without a \
name is perfectly good; a reply that gets somebody's name wrong is not.

WHAT YOU MAY NEVER SAY

- Never state a price, a fee, a size, a colour, a material, a delivery time or any \
other fact that is not written in the shop's facts below. Suggesting is free; \
inventing is not. You may say a bag would go well with a dress. You may not say it \
comes in blue unless that is written down.
- Never write a digit that does not appear in the shop's facts or in what the \
customer wrote. If you need to say how many of something there are, write it as a \
word — "three colours" — rather than as a figure.
- Write every number in Western figures — 1 2 3 4 5 — even in Arabic. Never \
٠١٢٣٤٥٦٧٨٩. The shop's own list is written that way and so is the rest of the \
product.
- Never add numbers up. Give the parts — the item's price, and the delivery fee, \
separately — and let the customer total them. A sum you worked out is a number \
nobody wrote down, and it will be held back before it reaches them.
- Never state a policy nobody wrote down. Whether the price is fixed, whether you \
hold an item, whether a discount exists: if it is not written below, you do not \
know it. Anything to do with price has its own section further down — read it.
- Never promise WHEN. Not "بكرا", not "خلال يومين", not "same day", not \
"overnight" — unless that is written below in those words. How long delivery \
takes is the shop's to say and not yours, and a date you invent is the one \
mistake a customer will remember.
- Never offer a discount, a guarantee, a warranty or a refund. If the shop has \
not written it down, it does not exist.
- The shop's own past replies are shown to you for TONE — how warm it is, how \
long its sentences run, the words it likes. They are NOT facts. If one of them \
mentions a delivery time, a price or a policy that is not in the shop's facts \
below, do not repeat it. That is how a promise nobody authorised gets made \
twice.
- NEVER use a term of endearment — not حبيبتي، not حبيبي، not عزيزتي، not حياتي، \
not يا قلبي، not "dear", not "hun", and nothing else of that kind. Not once. The \
shop's own replies may be full of them; do NOT copy that habit. Warmth comes from \
being quick, clear and helpful, not from pet names.
- Never say you are an assistant, never apologise for being one, and never say you \
will "check with the team".
- Never write "نعم". Say "آه", "ايوه" or "أكيد". "نعم" is Modern Standard \
Arabic and it is the clearest single tell that a machine wrote the sentence. \
The same goes for "هل", "ماذا", "لماذا", "أريد", "لا أعلم" — nobody talks like \
that in a shop.

ANSWER WHAT THEY ACTUALLY SAID. Reply to the customer's newest messages — the ones \
since the shop last wrote. Everything before that is context for understanding \
them, not a list of things to go back and answer.

A line like [the customer sent a photo] means exactly that: a message you cannot \
see. Do not guess what is in it. Say plainly that you cannot see it and ask what \
it is.

SOUND LIKE YOU KNOW YOUR SHOP

Everything in the shop's facts, you know. State it plainly. Never hedge about \
something written down in front of you: no "بظن", no "حسب ما بعرف", no "مافي \
عندي معلومة", no "على ما أعتقد", no "I think", no "probably", no "as far as I \
know". A shop that sounds unsure about its own prices is a shop nobody buys \
from.

When you genuinely do not know, that is not hedging either. Say once, plainly, \
that you will come back with an answer — then stop. One commitment per reply, \
never two, and never about something you have already answered.

Never think out loud. Work out what you actually have BEFORE you start the \
sentence, and never take back an offer halfway through it — "بس عندي تنورة... \
بصراحة ما في تنورات ثانية عنا" is you reasoning in front of the customer. Check \
the list, then write one finished sentence.

WHEN THEY WANT TO TALK ABOUT PRICE

You do not negotiate and you do not discuss price. You state it.

The number in the shop's facts is the price. It is the whole truth about what \
anything costs here: if a sale or a discount existed it would be written there, \
so when it is not written there, there is not one.

So when someone asks you to come down — "بتنزلي السعر شوي؟", "آخر سعر؟", "في \
خصم؟", "غالي شوي" — do NOT refuse them, do NOT bargain, and do NOT hedge:

- State the price plainly and warmly, once. The item and the number the shop \
wrote down, in their language. No apology, no softening — you know the price, \
so say it like someone who knows it.
- If they asked specifically about a discount or a sale, tell them straight: \
there is no sale on this item at the moment. "حالياً ما في خصم على هالقطعة." \
Say it as a fact about right now, not as a rule forever, and never as an \
apology. What you must NOT say is that you do not know, or that you have no \
information about it — you do know, because it would be written down.
- Then MOVE IT FORWARD with something that IS written down: a cheaper item you \
have, free delivery over a certain amount if the shop said so, the sizes it \
comes in. That is what someone who runs a shop does with a price objection — \
they hand the customer a way to say yes.
- Set handOver. That is a flag on our side, the customer never sees it, and \
somebody may still choose to offer them something. Do NOT tell them you will \
get back to them about the price: you have just answered it, and promising to \
go and check undoes the answer you gave one sentence earlier.
- NEVER mention a shop owner, a manager, a colleague or anyone else. Not "صاحب \
المحل", not "صاحبة المحل", not "حدا من المحل", not "the owner", not "someone \
from the shop". You are the shop. Measured: it wrote "صاحب المحل" in one reply \
and "صاحبة المحل" in the next — it does not know who runs this shop or whether \
they are a man or a woman, and it should not be talking about them at all.
- NEVER say the price is fixed, final, or the best you can do. Nobody told you \
that, and it is a different claim from "there is no sale right now": one is a \
policy you invented, the other is what the shop's own list says.
- NEVER offer a discount, a round-down or a better price yourself, however \
small. It is not yours to give.
- Do not lecture them about it either. One warm sentence with the price in it, \
one that moves them forward. That is the whole reply.

A customer asking for a better price is a customer who wants to buy. Sound like \
someone who wants to sell to them.

HANDING OVER

You return two things. "text" is always sent to the customer. "handOver" tells the \
conversation for a human to pick up. It is a flag on our side, not something \
the customer sees or hears about — never mention it to them.

handOver is a LAST RESORT, not an exit. Before you set it, check whether anything \
above lets you help — an alternative, a suggestion, a question, a fact that is \
written down. It usually does. Most of an ordinary conversation is yours to carry, \
and a customer handed off for something you could have answered is a customer left \
waiting for no reason.

Set it for: a complaint, an upset customer, haggling over price, anything about an \
order already placed, anything about payment or returns that is not written below, \
and any answer that would need a fact nobody wrote down.

When you set it, STILL WRITE text. Answer whatever part of it you can, then say \
YOU will come back to them with an answer on the rest — "رح نرجعلك بجواب". Never \
say who will answer, because from the customer's side it is you. Leaving the \
customer with nothing is \
the one thing you must never do — it is the whole reason you are here.`;

/**
 * Two fields, not one choice between them.
 *
 * It used to be an action of either "reply" or "escalate", which made those
 * mutually exclusive — so a customer asking two things, one answerable and one
 * not, received nothing at all. Answering and handing over are separate
 * questions and are now asked separately. `text` has no exception: there is no
 * shape the model can return that leaves the customer in silence.
 */
const DECISION_SCHEMA = {
  type: "object",
  properties: {
    text: {
      type: "string",
      description: "What to send the customer. Always required, including when handing over.",
    },
    handOver: {
      type: "boolean",
      description:
        "True when this conversation needs a human to pick it up. A flag on our side; the customer never hears about it.",
    },
    reason: {
      type: "string",
      description:
        "A few words, in English, on why this needs a human. Only when handOver is true.",
    },
  },
  required: ["text", "handOver"],
  additionalProperties: false,
};

/**
 * The day and time a customer is writing at, in the shop's own time.
 *
 * Fixed to Amman: the product serves Jordan, and a shop's opening hours are
 * meaningless in UTC. Revisit when a seller outside that timezone signs up —
 * it would become a column on `shop` rather than a constant.
 */
export function nowInAmman(now: Date): string {
  return new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Amman",
    weekday: "long",
    day: "numeric",
    month: "long",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(now);
}

/**
 * Whether the shop's own Arabic replies are worth showing the model.
 *
 * Measured, not guessed: a handful of Arabic example replies make the model
 * answer an English customer in Arabic, and no amount of instruction wording
 * fixes it — with the examples removed the same question is answered "The red
 * dress is 25.5 JD." So the examples are withheld when the customer is plainly
 * writing English, and the language rule is left to win on its own.
 *
 * Arabic typed in Latin letters still counts as Arabic, and it is what the
 * digit test finds: Arabizi borrows digits for letters Latin does not have —
 * "2adesh", "a7mar", "3a" — and glues them to letters, which ordinary English
 * does not do. "I want 2 dresses" has a space and is not caught.
 *
 * ponytail: a heuristic, and the way it fails is the behaviour we had before —
 * Arabic examples sent to an English speaker. Swap it for asking the model if
 * a seller ever reports the wrong language.
 */
export function readsAsArabic(text: string): boolean {
  if (/[؀-ۿ]/.test(text)) return true;
  return /\d[a-z]|[a-z]\d/i.test(text);
}

export interface RequestInput {
  /** Everything the shop has told us, from renderFacts. */
  facts: string;

  /** When the customer is writing. Injected so tests are not clock-dependent. */
  now: Date;
  /** The seller's own recent replies, as examples of how this shop talks. */
  examples: string[];
  turns: Turn[];

  /**
   * What Meta says the customer is called, when it has told us. The strongest
   * signal available for which grammatical gender to address them in, and it
   * was sitting in the database unused until 20 September.
   */
  customerName?: string | null;

  /** Defaults to MODEL. Set by the comparison harness, not in production. */
  model?: string;
  /**
   * Sonnet only, and only for measuring. Thinking is off by default because a
   * two-sentence reply to a customer is not a reasoning problem — but whether
   * that is true is exactly what the comparison is for.
   */
  think?: boolean;
}

/**
 * The POST body for the Messages API.
 *
 * The stable part — instructions, catalog, examples — goes in `system` and
 * carries the cache breakpoint on its last block. The conversation varies per
 * request and comes after it, which is the whole point: everything before the
 * breakpoint is reused.
 *
 * The one hour TTL rather than the five minute default, because the gap
 * between two customers writing to the same shop is usually longer than five
 * minutes and a read refreshes the timer for free.
 *
 * The marker is set unconditionally. The minimum cacheable prefix is 1,024
 * tokens on Sonnet 5 (it was 4,096 on Haiku 4.5, which is why a small shop
 * used to get no benefit at all), and an unmet minimum is a silent no-op that
 * writes nothing and therefore costs nothing. Checking the length first would
 * be a branch that buys nothing.
 *
 * `thinking` is sent explicitly, and that line is the whole reason a model
 * swap is not a one-character change.
 *
 * The two models default in opposite directions. Haiku 4.5 rejects
 * `output_config.effort`, takes `budget_tokens` rather than adaptive thinking,
 * and does no thinking unless asked — so omitting the field was correct.
 * Sonnet 5 is the other way round: **omitting `thinking` runs adaptive
 * thinking**, so changing the model string alone would have quietly started
 * paying to reason about "قديش سعر الفستان؟".
 *
 * Disabled rather than adaptive, measured: adaptive cost 4% more and the
 * replies were not better. Every fact is already in the prompt and the answer
 * is two sentences — there is nothing to reason about.
 */
export function buildRequest(input: RequestInput): Record<string, unknown> {
  const system: Record<string, unknown>[] = [
    { type: "text", text: INSTRUCTIONS },
    { type: "text", text: input.facts },
  ];

  // Withheld from a customer writing English — see readsAsArabic. The last
  // inbound message decides, because that is the one being answered.
  //
  // Skipping our own attachment placeholders, which are English because the
  // instructions are: a photo-only message read as an English customer and was
  // answered "I can't see the photo" to someone writing Arabic. The placeholder
  // is our words about the customer, never the customer's own.
  const lastFromCustomer = [...input.turns]
    .reverse()
    .find((turn) => turn.inbound && !ATTACHMENT_MARKER.test(turn.text));

  const arabic = lastFromCustomer ? readsAsArabic(lastFromCustomer.text) : true;

  if (input.examples.length > 0 && arabic) {
    system.push({
      type: "text",
      text: "How this shop writes, for TONE ONLY — its warmth, its length, the " +
        "words it favours. Do not copy the content.\n" +
        input.examples.map((example) => `- ${example}`).join("\n"),
    });
  }

  // On the last stable block, so everything above it is the reusable prefix.
  system[system.length - 1].cache_control = { type: "ephemeral", ttl: "1h" };

  // After the breakpoint on purpose: the time changes every minute, and inside
  // the cached prefix it would invalidate the whole thing on every request.
  //
  // Without it the assistant cannot answer "are you open now" — it knows the
  // opening hours and not what day it is, which it correctly refuses to guess
  // at. Found by asking it.
  system.push({ type: "text", text: `Right now it is ${nowInAmman(input.now)}.` });

  // The language, decided here rather than left to the model.
  //
  // Withholding the shop's Arabic examples was enough when a shop had five
  // products. It is not enough for a real one: measured against a shop whose
  // catalog, hours, address and notes are all Arabic, an English customer —
  // "do you deliver to Amman?", with the examples already withheld — was
  // answered in Arabic on two of three runs. Nothing in the instructions
  // outweighs that much Arabic sitting in the context, and moving the rule to
  // the end did not change it.
  //
  // So the model is not asked to work the language out. `readsAsArabic`
  // already decides it for the examples above, and the same answer is stated
  // here as a fact. It is the same heuristic with the same failure mode, used
  // for one more thing.
  //
  // After the breakpoint, so it costs a handful of uncached tokens and leaves
  // the prefix stable.
  // After the breakpoint with the clock and the language: it changes with every
  // conversation, and inside the cached prefix it would write a new entry per
  // customer and read none.
  const name = input.customerName?.trim();
  system.push({
    type: "text",
    text: name
      ? `The customer's name is ${name}. Use it to decide whether to address ` +
        "them as a man or a woman, per the rule above — and when the name does " +
        "not settle it, the masculine."
      : "We do not know the customer's name. Address them as a man unless their " +
        "own words say otherwise.",
  });

  system.push({
    type: "text",
    text: arabic
      ? "The customer's last message is in ARABIC. Write your reply in Arabic " +
        "script, in their own dialect — not Modern Standard Arabic — however " +
        "the customer typed it."
      : "The customer's last message is in ENGLISH. Write your reply in " +
        "ENGLISH. This holds however much Arabic is written above: the shop's " +
        "catalog, hours and notes are in Arabic because that is how the shop " +
        "wrote them down, and it says nothing about what this customer reads.",
  });

  const model = input.model ?? MODEL;

  return {
    model,
    max_tokens: MAX_TOKENS,
    system,
    messages: toMessages(input.turns),
    output_config: { format: { type: "json_schema", schema: DECISION_SCHEMA } },
    // Haiku takes no `thinking` field at all; everything else must be told,
    // because the default there is adaptive. See the note above.
    ...(model === HAIKU
      ? {}
      : { thinking: { type: input.think ? "adaptive" : "disabled" } }),
  };
}

/**
 * The conversation as the API wants it.
 *
 * Consecutive messages from the same side are joined rather than sent as
 * separate turns, because a customer firing off three lines in a row is normal
 * and the API expects the two sides to alternate. Leading replies from the
 * shop are dropped, since a conversation has to open with the customer.
 */
export function toMessages(turns: Turn[]): { role: string; content: string }[] {
  const messages: { role: string; content: string }[] = [];

  for (const turn of turns) {
    const text = turn.text.trim();
    if (text.length === 0) continue;

    const role = turn.inbound ? "user" : "assistant";
    if (messages.length === 0 && role === "assistant") continue;

    const last = messages[messages.length - 1];
    if (last && last.role === role) {
      last.content = `${last.content}\n${text}`;
    } else {
      messages.push({ role, content: text });
    }
  }

  return messages;
}

// ---------------------------------------------------------------------------
// Reading the answer
// ---------------------------------------------------------------------------

export interface Decision {
  /** Always sent. There is no decision that leaves the customer with nothing. */
  text: string;
  /** Whether the seller should take the conversation over. */
  handOver: boolean;
  /** A few words for the seller's row. Null when it is not handing over. */
  reason: string | null;
}

/**
 * What the model decided, or null if it did not give us something usable.
 *
 * Null is not an error worth retrying — it is a reason to hand the
 * conversation to the seller, which is what the caller does with it.
 */
export function readDecision(body: unknown): Decision | null {
  const answer = body as { content?: unknown } | null;
  if (!answer || typeof answer !== "object") return null;

  const blocks = Array.isArray(answer.content) ? answer.content : [];
  const first = blocks.find(
    (block) => block && typeof block === "object" && (block as { type?: unknown }).type === "text",
  ) as { text?: unknown } | undefined;

  if (!first || typeof first.text !== "string") return null;

  // Structured output means this is JSON, but it arrives as a string in a text
  // block and must be parsed rather than matched against.
  let parsed: unknown;
  try {
    parsed = JSON.parse(first.text);
  } catch {
    return null;
  }

  const decision = parsed as { handOver?: unknown; text?: unknown; reason?: unknown } | null;
  if (!decision || typeof decision !== "object") return null;

  // No text is the one unusable answer. The schema requires it, so this is the
  // model having ignored the schema rather than a case we expect.
  if (typeof decision.text !== "string" || decision.text.trim().length === 0) return null;

  const handOver = decision.handOver === true;
  const reason = typeof decision.reason === "string" && decision.reason.trim().length > 0
    ? decision.reason.trim()
    : null;

  return {
    text: decision.text.trim(),
    handOver,
    reason: handOver ? (reason ?? "the assistant was not confident") : null,
  };
}

export interface Usage {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
}

/**
 * What the call cost, for the log.
 *
 * `cacheReadTokens` staying at zero across repeated requests is the signal
 * that the cached prefix is being invalidated by something — the catalog being
 * rendered differently each time, or the examples changing on every reply. It
 * is the one number worth watching.
 */
export function readUsage(body: unknown): Usage {
  const usage = (body as { usage?: Record<string, unknown> } | null)?.usage ?? {};

  const count = (value: unknown): number =>
    typeof value === "number" && Number.isFinite(value) ? value : 0;

  return {
    inputTokens: count(usage.input_tokens),
    outputTokens: count(usage.output_tokens),
    cacheReadTokens: count(usage.cache_read_input_tokens),
    cacheWriteTokens: count(usage.cache_creation_input_tokens),
  };
}

// ---------------------------------------------------------------------------
// The grounding check
// ---------------------------------------------------------------------------

/**
 * Whether every number in the reply came from somewhere real.
 *
 * A price the model invented is the one failure that loses a seller their
 * customer, and it is the failure a language model is most prone to. Rather
 * than trusting the instruction not to, every run of digits in the reply must
 * appear in the catalog or somewhere in the conversation.
 *
 * This catches invented delivery times too: "within 24 hours" fails unless 24
 * is written down somewhere, which is correct — that is a promise nobody
 * authorised.
 *
 * Compares numbers, not the digits they are written with. 25.500 and 25.5 are
 * the same price — the dinar divides into 1000 fils, so a seller types the
 * first and the catalog stores the second — and a check that compared digit
 * strings would reject the assistant's own correct answer.
 *
 * Every number is checked, with no floor. Delivery in Jordan costs 2 or 3
 * dinars, so exempting small numbers as "probably a quantity" would exempt
 * exactly the figures most worth guarding.
 */
export function numbersAreGrounded(
  reply: string,
  facts: string,
  conversation: string[],
): boolean {
  // The same string the model was given, so a delivery fee it was told about
  // cannot be refused on the way out as something it made up.
  const known = numbersIn([facts, ...conversation].join(" "));

  for (const value of numbersIn(reply)) {
    if (!known.has(value)) return false;
  }

  return true;
}

/**
 * Words that a reply only reaches for when it is promising something.
 *
 * The grounding check above sees digits and nothing else, and every leak found
 * on 20 September was a claim with no digits in it: "السعر ثابت" (a price
 * policy), "عم يلاقوا إقبال كبير" (manufactured popularity), "بيوصلك خلال
 * يومين" (a delivery time lifted out of a seller's own past reply). The
 * instructions forbid all three and the model wrote them anyway.
 *
 * So the same rule the numbers get: a watched word may appear in a reply only
 * if it appears in what the shop wrote down, or in what the customer said. A
 * shop whose delivery note says "خصم" may talk about a discount; one that
 * never wrote the word may not invent it.
 *
 * ponytail: a word list, not a fact-checker. It catches a promise dressed in
 * one of these words and nothing else — a fabricated sentence using none of
 * them still gets through. The upgrade path is a second model call to check
 * the first, which doubles cost and latency and is itself fallible; do that
 * only if measurement shows leaks that matter.
 */
/**
 * Patterns rather than bare words, because a bare word was too blunt.
 *
 * "ثابت" caught "شي أنيق وثابت" — elegant and hard-wearing, about a handbag —
 * and withheld a good recommendation to hand the customer a bare line instead.
 * The word only matters next to a price, so that is what the pattern says.
 * Each one is matched against the reply and, if it hits, against what the shop
 * and the customer wrote; the matched text itself becomes the reason shown to
 * the seller, which reads better than a pattern would.
 *
 * None of these carry the `g` flag: `test` is stateful with it, and a shared
 * pattern that remembers where it last matched is a bug that only shows up on
 * the second call.
 */
const WATCHED: RegExp[] = [
  // A price policy nobody stated.
  /(?:سعر|السعر|سعرها|سعره|الأسعار|بسعر)\s*(?:عنا\s*|عندنا\s*)?ثابت/,
  /ثابت\s*(?:ال)?سعر/,
  /fixed price/i,
  /non-negotiable/i,
  // Scarcity and popularity, the oldest pressure tactics there are.
  /إقبال/,
  /آخر (?:قطعة|وحدة|واحدة)/,
  /last one/i,
  /selling fast/i,
  /in demand/i,
  /going fast/i,
  // Money the shop never offered.
  /خصم/,
  /تنزيلات/,
  /discount/i,
  /on sale/i,
  // A promise nobody made.
  /مضمون/,
  /كفالة/,
  /guarantee/i,
  /warranty/i,
  /refund/i,
  // A delivery time nobody gave.
  /بكرا/,
  /بكره/,
  /tomorrow/i,
  /نفس اليوم/,
  /same day/i,
  /يومين/,
  /overnight/i,
];

/**
 * Saying a thing does NOT exist is not a promise.
 *
 * "حالياً ما في خصم على هالقطعة" — currently there is no sale on this item — is
 * what the product owner asked for in place of "مافي عندي معلومة عن خصم", and
 * it is true by construction: a discount would be written in the shop's facts,
 * so its absence there is the answer. Claiming one exists is the failure;
 * ruling one out is not.
 *
 * Stripped before the check rather than special-cased inside it, so the check
 * itself stays one line.
 */
const NEGATED = [
  /ما\s*في\s+(خصم|تنزيلات)/g,
  /ما\s*عنا\s+(خصم|تنزيلات)/g,
  /مافي\s+(خصم|تنزيلات)/g,
  /no\s+(discount|sale)/gi,
  /not\s+on\s+sale/gi,
];

/**
 * Whether the reply promises anything the shop did not.
 *
 * Deliberately the same shape as numbersAreGrounded, and searching the same
 * two haystacks, so there is one idea here rather than two.
 */
export function claimsAreGrounded(
  reply: string,
  facts: string,
  conversation: string[],
): string | null {
  const known = [facts, ...conversation].join(" ").toLowerCase();

  let said = reply.toLowerCase();
  for (const negation of NEGATED) said = said.replace(negation, " ");

  for (const pattern of WATCHED) {
    const hit = said.match(pattern);
    if (hit && !pattern.test(known)) return hit[0];
  }

  return null;
}

// ---------------------------------------------------------------------------
// Emoji
// ---------------------------------------------------------------------------

/**
 * The emoji the assistant may use, decided by the product owner: the safe
 * ones, and sparingly.
 *
 * No hearts and no faces beyond a plain smile. They sit in the same family as
 * the pet names the 19 September decision ruled out — warmth is fine,
 * familiarity is not, and 😍 or 💕 from a shop to a customer is familiarity.
 */
const ALLOWED_EMOJI = ["🌸", "🙏", "✨", "🙂", "👋"];

/** Every emoji-ish codepoint, including the variation selector that trails some. */
const ANY_EMOJI =
  /[\u{1F000}-\u{1FAFF}\u{2190}-\u{21FF}\u{2300}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]/gu;

/**
 * At most one safe emoji, at the end, and only on a reply that is not doing
 * any work.
 *
 * Stripped rather than escalated, which is the opposite of how an invented
 * fact is handled and deliberately so. The 19 September decision rejected
 * filtering the finished reply because cutting a word out of a written
 * sentence reads worse than the problem it solves — an emoji is not a word,
 * and removing it changes nothing the customer needed to read.
 *
 * "Sparingly, like when closing a chat" was asked for and the instruction did
 * not deliver it: told to save emoji for a closing, Sonnet 5 put one on a
 * price quote, on a question and on a product list — most replies in the run.
 * So it is decided here instead, by the same reasoning as the language: what
 * can be decided deterministically should be.
 *
 * ponytail: a digit or a question mark stands in for "this reply is doing
 * work". A closing has neither — "تمام، خذي وقتك وأنا هون" — while a price, a
 * fee, a size or a question back all have one. It is a proxy and it will
 * occasionally strip an emoji from a warm reply that happens to contain a
 * number; that failure is invisible, and the opposite one is a shop that
 * punctuates its prices with smileys. Replace it with a real closing-detector
 * only if someone asks for emoji back.
 */
export function tidyEmoji(text: string): string {
  const stripped = text.replace(ANY_EMOJI, "").replace(/[ \t]{2,}/g, " ").trim();

  const working = /\d/.test(stripped) || /[?؟]/.test(stripped);
  if (working) return stripped;

  const kept = ALLOWED_EMOJI.find((emoji) => text.includes(emoji));
  return kept ? `${stripped} ${kept}` : stripped;
}

/**
 * Every number in the text, as numbers.
 *
 * Arabic-Indic digits are folded onto Western ones, and a comma is treated as
 * a thousands separator rather than a decimal point — "25,000" is twenty-five
 * thousand, while "25.500" is twenty-five and a half dinars.
 */
function numbersIn(text: string): Set<number> {
  const normalised = normaliseDigits(text).replace(/,/g, "");
  const found = new Set<number>();

  for (const match of normalised.match(/\d+(?:\.\d+)?/g) ?? []) {
    const value = Number(match);
    if (Number.isFinite(value)) found.add(value);
  }

  return found;
}

/**
 * Arabic-Indic and Extended Arabic-Indic digits folded onto Western ones.
 *
 * The interface uses Western numerals throughout (DECISIONS.md), but a
 * customer may well type ٢٥٠٠٠, and the model may echo it back. Comparing
 * those against a catalog written in Western digits would fail every time.
 */
function normaliseDigits(text: string): string {
  return text.replace(/[٠-٩۰-۹]/g, (digit) => {
    const code = digit.charCodeAt(0);
    const base = code >= 0x06F0 ? 0x06F0 : 0x0660;
    return String(code - base);
  });
}

// ---------------------------------------------------------------------------
// The call
// ---------------------------------------------------------------------------

export type AskOutcome =
  | { status: "decided"; decision: Decision; usage: Usage }
  /** `detail` is a snippet of what came back, so this is diagnosable in a log. */
  | { status: "unusable"; usage: Usage; detail: string }
  | { status: "failed"; detail: string };

/**
 * A short, log-safe snippet of what the model actually returned.
 *
 * Seen once in a live run and not reproduced in three attempts on the same
 * input, which is the worst kind of failure to have no record of: the customer
 * gets the fixed hand-over line instead of an answer, and nothing says why.
 * This is the shop's own outgoing text, never the customer's, so it is safe to
 * put in a function log.
 */
function snippet(body: unknown): string {
  const blocks = (body as { content?: unknown })?.content;
  const first = Array.isArray(blocks)
    ? blocks.find((b) => b && typeof b === "object" && (b as { type?: unknown }).type === "text")
    : undefined;

  const text = (first as { text?: unknown })?.text;
  const stop = (body as { stop_reason?: unknown })?.stop_reason;

  return typeof text === "string"
    ? `stop=${String(stop)} ${text.slice(0, 200)}`
    : `stop=${String(stop)} no text block`;
}

/**
 * Asks the model, without ever throwing.
 *
 * Runs after the 200 has already gone back to Meta, so a failure here must
 * cost nothing: the message is stored, the conversation stays in the seller's
 * waiting group, and they answer it themselves. Silence is the correct way for
 * this to fail.
 *
 * `fetcher` is injected so every decision above can be tested without a
 * network, in the same way `refreshCustomerProfile` takes one.
 */
export async function ask(
  apiKey: string,
  input: RequestInput,
  fetcher: typeof fetch = fetch,
  workspaceId = "",
): Promise<AskOutcome> {
  let response: Response;

  try {
    response = await fetcher(ANTHROPIC, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        // An organisation-level key is not tied to a workspace, and every
        // request then has to name the one to bill. A workspace-scoped key
        // carries that itself and needs no header, so this is sent only when
        // one is configured.
        ...(workspaceId ? { "anthropic-workspace-id": workspaceId } : {}),
      },
      body: JSON.stringify(buildRequest(input)),
    });
  } catch (error) {
    return { status: "failed", detail: `unreachable: ${error}` };
  }

  if (!response.ok) {
    return { status: "failed", detail: `http ${response.status}` };
  }

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    return { status: "failed", detail: "unparseable" };
  }

  const usage = readUsage(body);
  const decision = readDecision(body);

  return decision
    ? { status: "decided", decision, usage }
    : { status: "unusable", usage, detail: snippet(body) };
}
