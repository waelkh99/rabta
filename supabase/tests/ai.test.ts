// Answering a customer, or deciding not to.
//
// Almost everything here is about NOT answering. The guards are what stop the
// AI talking over the seller, answering a photo it cannot see, inventing a
// price, or looping at a customer who wanted a person — and each of them is
// cheaper and more reliable than asking the model to behave.
//
// The model itself is faked. Nothing in this file touches a network.

import { strict as assert } from "node:assert";
import { test } from "node:test";
import { readFileSync } from "node:fs";

import {
  ask,
  attachmentTurn,
  buildRequest,
  claimsAreGrounded,
  guard,
  HAIKU,
  HANDOVER_LINE,
  isSpoken,
  MODEL,
  MONTHLY_CEILING,
  DEFAULT_CURRENCY,
  MAX_PHOTOS,
  MAX_THUMBNAILS,
  wordedOfferPrices,
  mentionsPhoto,
  numbersAreGrounded,
  photosMissing,
  photosToSend,
  readDecision,
  readsAsArabic,
  nowInAmman,
  salePrice,
  todayInAmman,
  type Offer,
  readUsage,
  renderCatalog,
  renderFacts,
  type ReplyContext,
  SELLER_PRESENT_MINUTES,
  tidyEmoji,
  toMessages,
} from "../functions/meta-webhook/ai.ts";

// ---------------------------------------------------------------------------
// Promises the shop never made
//
// The number check sees digits and nothing else. Every leak found against the
// real API had no digits in it, which is what this exists for.
// ---------------------------------------------------------------------------

const SHOP_FACTS = "Delivery:\n- عمّان: 2.5 د.ا\n\nCatalog:\n- فستان أحمر | 25.5 د.ا | in stock";

test("a price policy nobody wrote down is caught", () => {
  // Measured on Haiku and again on Sonnet: asked for a discount it answered
  // "السعر ثابت". True or not, nobody told it, and it has no digits.
  assert.equal(claimsAreGrounded("السعر ثابت", SHOP_FACTS, []), "السعر ثابت");
  assert.equal(claimsAreGrounded("سعرها عنا ثابت", SHOP_FACTS, []), "سعرها عنا ثابت");
  assert.equal(claimsAreGrounded("our price is fixed price", SHOP_FACTS, []), "fixed price");
});

test("a durable handbag is not a price policy", () => {
  // The bare word caught "شي أنيق وثابت" — elegant and hard-wearing — and
  // withheld a good recommendation. "ثابت" only matters next to a price.
  assert.equal(claimsAreGrounded("شي أنيق وثابت بيصير هدية تدوم", SHOP_FACTS, []), null);
  assert.equal(claimsAreGrounded("قماش ثابت اللون وما بيبهت", SHOP_FACTS, []), null);
});

test("manufactured popularity is caught", () => {
  // Measured on Sonnet 5: "وعم يلاقوا إقبال كبير".
  assert.equal(claimsAreGrounded("عم يلاقوا إقبال كبير", SHOP_FACTS, []), "إقبال");
  assert.equal(claimsAreGrounded("this is our last one", SHOP_FACTS, []), "last one");
});

test("a delivery time nobody gave is caught", () => {
  // Measured: lifted out of the seller's own example reply, which is shown to
  // the model for tone and is not a source of facts.
  assert.equal(claimsAreGrounded("بيوصلك خلال يومين", SHOP_FACTS, []), "يومين");
  assert.equal(claimsAreGrounded("we can get it to you tomorrow", SHOP_FACTS, []), "tomorrow");
});

test("a discount or a guarantee nobody offered is caught", () => {
  assert.equal(claimsAreGrounded("في خصم عليها", SHOP_FACTS, []), "خصم");
  assert.equal(claimsAreGrounded("it comes with a warranty", SHOP_FACTS, []), "warranty");
});

test("saying there is NO sale is not a promise, and goes through", () => {
  // The product owner's wording: "Currently we don't have a sale on this
  // item." It is true by construction — a discount would be written in the
  // shop's facts, so its absence there is the answer. Claiming one exists is
  // the failure; ruling one out is not.
  assert.equal(claimsAreGrounded("حالياً ما في خصم على هالقطعة", SHOP_FACTS, []), null);
  assert.equal(claimsAreGrounded("مافي خصم هلأ، السعر 25.5", SHOP_FACTS, []), null);
  assert.equal(claimsAreGrounded("ما عنا خصم حالياً", SHOP_FACTS, []), null);
  assert.equal(claimsAreGrounded("no discount on this one right now", SHOP_FACTS, []), null);
  assert.equal(claimsAreGrounded("it's not on sale at the moment", SHOP_FACTS, []), null);
});

test("the negation exemption does not open the door to claiming one", () => {
  // The whole point of it. A sentence that rules a discount out AND offers one
  // must still be caught.
  assert.equal(
    claimsAreGrounded("ما في خصم عام بس بعطيكي خصم خاص", SHOP_FACTS, []),
    "خصم",
  );
  assert.equal(claimsAreGrounded("no sale, but I can give you a discount", SHOP_FACTS, []), "discount");
});

test("what the shop DID write down is allowed through", () => {
  // The point of searching the same haystack as the number check: a shop whose
  // own delivery note promises next-day delivery may say so. Refusing that
  // would be the assistant withholding the shop's own words.
  const generous = `${SHOP_FACTS}\n\nDelivery:\nبنوصل بكرا، وفي خصم 10% فوق 50 دينار`;

  assert.equal(claimsAreGrounded("بنوصلك بكرا", generous, []), null);
  assert.equal(claimsAreGrounded("في خصم فوق 50", generous, []), null);
});

test("what the customer raised is allowed through", () => {
  // A customer who asks "في خصم؟" must be answerable. Otherwise the word they
  // used locks the assistant out of its own reply.
  assert.equal(claimsAreGrounded("ما في خصم حالياً", SHOP_FACTS, ["في خصم؟"]), null);
});

test("an ordinary reply trips nothing", () => {
  assert.equal(claimsAreGrounded("الفستان الأحمر 25.5 د.ا ومتوفر", SHOP_FACTS, []), null);
  assert.equal(
    claimsAreGrounded("أنا بميل للشال، لأنه بتلبسيه كل يوم", SHOP_FACTS, []),
    null,
  );
});

// ---------------------------------------------------------------------------
// Emoji
// ---------------------------------------------------------------------------

test("one safe emoji survives, at the end", () => {
  assert.equal(tidyEmoji("تمام، خدي وقتك 🌸"), "تمام، خدي وقتك 🌸");
  assert.equal(tidyEmoji("شكراً 🙏"), "شكراً 🙏");
});

test("a reply that quotes a price gets no emoji at all", () => {
  // Measured: told to save them for a closing, Sonnet 5 put one on a price
  // quote, on a question and on a product list — most replies in the run.
  // A digit stands in for "this reply is doing work".
  assert.equal(tidyEmoji("الفستان ✨ 25.5 دينار"), "الفستان 25.5 دينار");
  assert.equal(tidyEmoji("شنطة اليد الجلد بـ32 دينار 🙂"), "شنطة اليد الجلد بـ32 دينار");
});

test("a reply that asks a question back gets no emoji", () => {
  // It is not a closing if the shop is still waiting on an answer.
  assert.equal(tidyEmoji("شو بتدوري عليه؟ 🙂"), "شو بتدوري عليه؟");
  assert.equal(tidyEmoji("What size are you after? 🙂"), "What size are you after?");
});

test("a closing keeps one", () => {
  assert.equal(tidyEmoji("تمام، خذي وقتك وأنا هون 🙂"), "تمام، خذي وقتك وأنا هون 🙂");
});

test("a pile of emoji is cut down to one", () => {
  assert.equal(tidyEmoji("أهلين 🌸🌸🌸✨🙏"), "أهلين 🌸");
});

test("emoji outside the safe set are removed entirely", () => {
  // Hearts and grinning faces are familiarity, which is the same thing the pet
  // name rule forbids.
  assert.equal(tidyEmoji("حبيت هالقطعة 😍💕"), "حبيت هالقطعة");
  assert.equal(tidyEmoji("perfect 👌🔥"), "perfect");
});

test("a reply with no emoji is returned unchanged", () => {
  // Most replies. The tidy must not disturb ordinary text or Arabic script.
  const plain = "الفستان الأحمر 25.5 د.ا، متوفر بمقاسات S و M و L.";
  assert.equal(tidyEmoji(plain), plain);
});

test("removing an emoji does not leave ragged spacing behind", () => {
  assert.equal(tidyEmoji("تمام 😍 خدي وقتك"), "تمام خدي وقتك");
});

const NOW = new Date("2026-09-19T12:00:00.000Z");
const minutesAgo = (minutes: number) =>
  new Date(NOW.getTime() - minutes * 60_000).toISOString();
const hoursAhead = (hours: number) =>
  new Date(NOW.getTime() + hours * 3_600_000).toISOString();

/** A conversation the AI is allowed to answer. Each test spoils one thing. */
const open = (overrides: Partial<ReplyContext> = {}): ReplyContext => ({
  enabled: true,
  windowExpiresAt: hoursAhead(12),
  lastSellerReplyAt: null,
  aiRepliesThisMonth: 0,
  ...overrides,
});

// ---------------------------------------------------------------------------
// The guards
// ---------------------------------------------------------------------------

test("a conversation with nothing wrong with it reaches the model", () => {
  assert.equal(guard(open(), NOW), null);
});

test("the AI says nothing until the seller switches it on", () => {
  // The default is off for every workspace that exists, so this is the state
  // almost every seller is in.
  assert.equal(guard(open({ enabled: false }), NOW), "disabled");
});

test("a closed reply window is refused before the model is asked", () => {
  // Meta would refuse the send, so asking the model would buy a sentence
  // nobody can receive.
  assert.equal(guard(open({ windowExpiresAt: hoursAhead(-1) }), NOW), "window_closed");
});

test("a customer who has never written has no window, which is not the same thing", () => {
  assert.equal(guard(open({ windowExpiresAt: null }), NOW), "no_window");
});

test("a photo on its own no longer stops the conversation before it starts", () => {
  // It used to return "no_text", and the customer got nothing at all. On
  // Instagram, sending a screenshot of a story with no words is a normal way
  // to open a sale, so silence was a frequent answer to a real customer.
  // The message now reaches the model written out by attachmentTurn.
  assert.equal(guard(open(), NOW), null);
});

test("there is no limit on replies in a row", () => {
  // It was three, then eight, then twenty, and on 23 September it stopped a
  // live customer mid-conversation. The product owner: "freezing is not an
  // option". Nothing about the conversation's length can stop it now — only
  // the window, the seller being present, and the monthly ceiling.
  assert.equal(guard(open(), NOW), null);
  assert.ok(!("consecutiveAiReplies" in open()), "the context no longer carries a count");
});

// ---------------------------------------------------------------------------
// Telling the customer, rather than leaving them in silence
// ---------------------------------------------------------------------------

test("the customer is told once when the ceiling is reached, not on every message", () => {
  // The hand-over line is itself an AI reply, so sending it pushes the count
  // one past the ceiling. That is the whole mechanism — there is no flag.
  assert.equal(isSpoken("ceiling", open({ aiRepliesThisMonth: MONTHLY_CEILING })), true);
  assert.equal(isSpoken("ceiling", open({ aiRepliesThisMonth: MONTHLY_CEILING + 1 })), false);
});

test("the customer is told once when the monthly ceiling is reached", () => {
  assert.equal(isSpoken("ceiling", open({ aiRepliesThisMonth: MONTHLY_CEILING })), true);
  assert.equal(isSpoken("ceiling", open({ aiRepliesThisMonth: MONTHLY_CEILING + 1 })), false);
});

test("nothing is said on a path where the send would fail anyway", () => {
  // Meta refuses a send outside the window, so a hand-over line would burn a
  // Graph call to produce a message nobody receives.
  assert.equal(isSpoken("window_closed", open()), false);
  assert.equal(isSpoken("no_window", open()), false);
  assert.equal(isSpoken("disabled", open()), false);
});

test("nothing is said while the seller is at their desk", () => {
  // They are about to answer in person, which beats a line promising they will.
  assert.equal(isSpoken("seller_present", open({ lastSellerReplyAt: minutesAgo(1) })), false);
});

// ---------------------------------------------------------------------------
// A message with no words in it
// ---------------------------------------------------------------------------

test("an attachment is written out so the model knows it happened", () => {
  assert.equal(attachmentTurn([{ type: "image" }]), "[the customer sent a photo]");
  assert.equal(attachmentTurn([{ type: "video" }]), "[the customer sent a video]");
  assert.equal(attachmentTurn([{ type: "audio" }]), "[the customer sent a voice note]");
  assert.equal(attachmentTurn([{ type: "share" }]), "[the customer sent a post]");
});

test("an attachment type we have never seen still says something happened", () => {
  // Meta adds attachment types without warning. Silence about one would put
  // the model back to answering a message it has not been told about.
  assert.equal(attachmentTurn([{ type: "sticker" }]), "[the customer sent a file]");
  assert.equal(attachmentTurn([{}]), "[the customer sent a file]");
});

test("a message with no attachments has nothing to write out", () => {
  assert.equal(attachmentTurn([]), null);
  assert.equal(attachmentTurn(null as unknown as unknown[]), null);
});

test("the AI stays quiet while the seller is at their desk", () => {
  // Talking over a seller who is working through their inbox is worse than
  // staying quiet — they will reach this conversation themselves.
  assert.equal(guard(open({ lastSellerReplyAt: minutesAgo(1) }), NOW), "seller_present");
  assert.equal(
    guard(open({ lastSellerReplyAt: minutesAgo(SELLER_PRESENT_MINUTES - 1) }), NOW),
    "seller_present",
  );
});

test("a seller who left hours ago is not treated as present", () => {
  assert.equal(guard(open({ lastSellerReplyAt: minutesAgo(SELLER_PRESENT_MINUTES) }), NOW), null);
  assert.equal(guard(open({ lastSellerReplyAt: minutesAgo(600) }), NOW), null);
});

test("the monthly ceiling stops the bill running away", () => {
  assert.equal(guard(open({ aiRepliesThisMonth: MONTHLY_CEILING }), NOW), "ceiling");
});

test("the window is checked before the ceiling, so an old conversation is cheap to refuse", () => {
  // Order matters only for which reason the seller is shown. The window is the
  // more honest explanation of the two.
  const doomed = open({
    windowExpiresAt: hoursAhead(-1),
    aiRepliesThisMonth: MONTHLY_CEILING,
  });
  assert.equal(guard(doomed, NOW), "window_closed");
});

// ---------------------------------------------------------------------------
// The catalog
// ---------------------------------------------------------------------------

// Jordanian prices. The dinar divides into 1000 fils, so a third decimal
// place is ordinary and 25.500 is a real price rather than a rounding error.
const DRESS = { name: "فستان أحمر", price: "25.500", description: null, inStock: true };
const SHOES = { name: "حذاء", price: 40.75, description: "جلد طبيعي", inStock: false };

const SHOP = {
  currency: "د.ا",
  deliveryNote: "التوصيل مجاني للطلبات فوق 50 دينار",
  locations: "عمّان، شارع الرينبو",
  hours: "السبت إلى الخميس ١٠ص-٨م، الجمعة مغلق",
  about: "الدفع عند الاستلام متاح",
  priceStance: "notify" as const,
};

const ZONES = [
  { name: "عمّان", fee: "2.000" },
  { name: "إربد", fee: 3.5 },
  { name: "العقبة", fee: null },
];

test("the catalog renders the same bytes every time", () => {
  // The cached prefix depends on this. If the rendering wobbles, every request
  // writes a new cache entry and reads none, and the cost model is wrong.
  const once = renderCatalog([DRESS, SHOES]);
  const twice = renderCatalog([DRESS, SHOES]);
  assert.equal(once, twice);
});

test("a price is written the way a seller would write it", () => {
  // Postgres hands back numeric as "25.500". A trailing zero is fine here —
  // what must not happen is the price arriving as something other than what
  // the seller typed.
  const rendered = renderCatalog([DRESS]);
  assert.ok(rendered.includes("25.5"), rendered);
});

test("an out of stock product stays in the catalog and says so", () => {
  // Dropping the row would leave the model unable to tell a product the shop
  // does not sell from one it has run out of.
  const rendered = renderCatalog([SHOES]);
  assert.ok(rendered.includes("حذاء"));
  assert.ok(rendered.includes("out of stock"), rendered);
});

test("an empty catalog says so rather than being blank", () => {
  // A blank string would read as a missing instruction rather than an empty
  // shop, and the model would answer from its own imagination.
  assert.ok(renderCatalog([]).trim().length > 0);
});

// ---------------------------------------------------------------------------
// The shop's own facts
//
// A catalog answers "how much is the dress". Half of what a customer actually
// asks is about delivery, hours and where the shop is, and without these the
// assistant hands back most of a normal conversation.
// ---------------------------------------------------------------------------

test("the price carries the shop's currency", () => {
  // 25.5 on its own is not an answer. Dinars and dollars both circulate, and
  // the wrong unit is as bad as the wrong number.
  const facts = renderFacts({ shop: SHOP, zones: [], products: [DRESS] });
  assert.ok(facts.includes("25.5 د.ا"), facts);
});

test("every delivery zone and its fee reaches the model", () => {
  const facts = renderFacts({ shop: SHOP, zones: ZONES, products: [] });

  assert.ok(facts.includes("عمّان"), facts);
  assert.ok(facts.includes("2 د.ا"), facts);
  assert.ok(facts.includes("إربد"), facts);
  assert.ok(facts.includes("3.5 د.ا"), facts);
});

test("a zone with no fee says the price varies rather than implying free", () => {
  // The seller covers Aqaba but has not priced it. "Free" would be a promise
  // nobody made, and silence would read as "we do not deliver there".
  const facts = renderFacts({ shop: SHOP, zones: ZONES, products: [] });

  assert.ok(facts.includes("العقبة"), facts);
  assert.ok(/العقبة: price varies/.test(facts), facts);
});

test("the shop's own words reach the model unchanged", () => {
  // Hours, address and whatever else the seller wrote. This is the escape
  // hatch when the assistant keeps getting something wrong.
  const facts = renderFacts({ shop: SHOP, zones: [], products: [] });

  assert.ok(facts.includes("شارع الرينبو"), "where it is");
  assert.ok(facts.includes("الجمعة مغلق"), "when it is open");
  assert.ok(facts.includes("الدفع عند الاستلام"), "whatever else it said");
  assert.ok(facts.includes("مجاني للطلبات فوق 50"), "the delivery rules");
});

test("a shop that has filled nothing in still renders its catalog", () => {
  // A seller who added products and nothing else must still get answers about
  // those products.
  const facts = renderFacts({ shop: null, zones: [], products: [DRESS] });

  assert.ok(facts.includes("فستان أحمر"), facts);
  assert.ok(facts.trim().length > 0);
});

test("the facts render the same bytes every time", () => {
  // Same reason as the catalog: this is the cached part of the prompt.
  const once = renderFacts({ shop: SHOP, zones: ZONES, products: [DRESS, SHOES] });
  const twice = renderFacts({ shop: SHOP, zones: ZONES, products: [DRESS, SHOES] });
  assert.equal(once, twice);
});

test("an empty section is left out rather than labelled and blank", () => {
  // "Opening hours:" followed by nothing invites the model to fill the gap.
  const bare = renderFacts({
    shop: {
      currency: "د.ا",
      deliveryNote: null,
      locations: null,
      hours: null,
      about: null,
      priceStance: "notify" as const,
    },
    zones: [],
    products: [DRESS],
  });

  assert.ok(!bare.includes("Opening hours"), bare);
  assert.ok(!bare.includes("Where the shop is"), bare);
  assert.ok(!bare.includes("Delivery"), bare);
});

// ---------------------------------------------------------------------------
// The request
// ---------------------------------------------------------------------------

const requestInput = {
  facts: renderFacts({ shop: SHOP, zones: ZONES, products: [DRESS] }),
  now: NOW,
  examples: ["اهلا وسهلا", "متوفر حبيبي"],
  turns: [{ inbound: true, text: "قديش سعر الفستان؟" }],

};

test("the request names the model and keeps the reply short", () => {
  const body = buildRequest(requestInput);
  assert.equal(body.model, MODEL);
  // Enough to show two or three options, and nowhere near Instagram's 1,000
  // character limit, which checkText enforces on the way out regardless.
  assert.ok((body.max_tokens as number) <= 400);
});

test("thinking is switched off explicitly, because the default is on", () => {
  // The one line that makes a model swap more than a string change. Sonnet 5
  // runs ADAPTIVE thinking when `thinking` is omitted, so changing the model
  // constant alone would quietly start paying to reason about "قديش سعر
  // الفستان؟". Measured: adaptive cost 4% more and the replies were no better.
  const body = buildRequest(requestInput);
  assert.deepEqual(body.thinking, { type: "disabled" });
});

test("Haiku is sent no thinking field at all", () => {
  // It rejects output_config.effort outright and takes budget_tokens rather
  // than adaptive thinking, so the two models default in opposite directions.
  const body = buildRequest({ ...requestInput, model: HAIKU });
  assert.equal("thinking" in body, false);
});

test("effort is never sent", () => {
  // Nothing needs it — thinking is off — and it is a 400 on Haiku, which the
  // comparison harness still runs.
  for (const model of [MODEL, HAIKU]) {
    const output = buildRequest({ ...requestInput, model }).output_config as Record<
      string,
      unknown
    >;
    assert.equal("effort" in output, false, model);
  }
});

test("the cache breakpoint sits on the last stable block, not the conversation", () => {
  // Everything before the marker is the reusable prefix. Putting it after the
  // conversation would write a new entry per customer message and read none.
  const body = buildRequest(requestInput);
  const system = body.system as Record<string, unknown>[];

  const marked = system.filter((block) => "cache_control" in block);
  assert.equal(marked.length, 1, "exactly one breakpoint");

  // Everything after the breakpoint must be volatile, and everything before it
  // stable. Asserted by content rather than by counting back from the end —
  // the position moved every time a volatile block was added, and a test that
  // breaks on every such change stops meaning anything.
  const at = system.findIndex((block) => "cache_control" in block);

  for (const block of system.slice(at + 1)) {
    assert.match(
      String(block.text),
      /Right now it is|customer's name|do not know the customer's name|last message is in/,
      `a stable block sits after the breakpoint: ${String(block.text).slice(0, 60)}`,
    );
  }

  assert.ok(at < system.length - 1, "the breakpoint is not the last block");
});

test("the cache entry lasts an hour, not five minutes", () => {
  // Two customers writing to the same shop are usually more than five minutes
  // apart, so a five minute entry would be dead on most requests.
  const body = buildRequest(requestInput);
  const system = body.system as Record<string, unknown>[];
  const marked = system.find((block) => "cache_control" in block)!;
  const control = marked.cache_control as Record<string, unknown>;

  assert.deepEqual(control, { type: "ephemeral", ttl: "1h" });
});

test("the time sits after the breakpoint, not inside the cached part", () => {
  // It changes every minute. Inside the prefix it would invalidate the whole
  // cache on every single request, which is the most expensive possible bug.
  const body = buildRequest(requestInput);
  const system = body.system as Record<string, unknown>[];

  const marked = system.findIndex((block) => "cache_control" in block);
  const timeBlock = system.findIndex((block) => /Right now it is/.test(String(block.text)));

  assert.ok(timeBlock > marked, "the time must come after the breakpoint");
});

test("the assistant is told what day it is", () => {
  // Without it, asked "are you open now" it knows the opening hours and not
  // what day it is, and correctly refuses to guess. Found by asking it.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Right now it is/);
  assert.match(text, /Saturday|Sunday|Monday|Tuesday|Wednesday|Thursday|Friday/);
});

test("the time is the shop's, not the server's", () => {
  // Opening hours are meaningless in UTC. Amman is UTC+3, so a little past
  // midnight there is still the previous evening in UTC.
  const lateEvening = new Date("2026-09-19T22:30:00.000Z");
  assert.equal(nowInAmman(lateEvening), "Sunday 20 September at 01:30");
});

test("the reply is matched to the KIND of message, before anything else", () => {
  // The complaint, from a real thread: a customer wrote "يغطيك العافية" — a
  // pleasantry, nothing asked — and was answered "نعم، عندنا فستان أحمر. إي
  // مقاس بدّك؟". A pitch at someone who had not said what they wanted.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /FIRST, WORK OUT WHAT KIND OF MESSAGE THIS IS/);
  assert.match(text, /A PLEASANTRY is not an opening/);
  assert.match(text, /Let the customer talk/);
});

test("a gap in the conversation is read from what they wrote, not its length", () => {
  // The product owner's call: "if the customer's reply was regarding an
  // earlier conversation pick it up, if he starts like its a new chat, then
  // its a new chat."
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /PICKING UP WHERE YOU LEFT OFF/);
  assert.match(text, /They are CARRYING ON if they refer back/);
  assert.match(text, /They are STARTING FRESH if they open with a greeting/);
  assert.match(text, /Not from how long \s*the gap was/);
});

test("a question nobody ever answered is answered late rather than never", () => {
  // Seen live: "شفت عندكم فستان" sat unanswered from one day to the next, and
  // the triage added the same day would have left it that way for good. In a
  // feature whose goal is that no inquiry goes unanswered, that was wrong.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /does not expire/);
  assert.match(text, /being late \s*is far better than never/);
  // Measured: given a fresh question and a stale one it led with the stale
  // one. What they just wrote is what they are waiting on.
  assert.match(text, /The newest message is answered FIRST and in full/);
  assert.match(text, /Never open with the old thing/);
  // And it must not become a reason to keep bringing it up.
  assert.match(text, /Once you have answered it, it is answered/);
});

test("the pleasantry rule defers to the unanswered question, rather than fighting it", () => {
  // The two rules meet head-on: one says answer the ritual and stop, the other
  // says never leave a question unanswered. The pleasantry rule names the
  // exception itself so the model is not left to reconcile them.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /unless they asked you something earlier that nobody ever answered/);
  assert.match(text, /give the ritual reply first, \s*then ONE short line/);
});

test("a pleasantry is answered with the pleasantry back and nothing else", () => {
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /يعطيك العافية/);
  assert.match(text, /الله يعافيك/);
  assert.match(text, /Do not \s*add a product, a category, a price, or even a question/);

  // Measured: given the ritual replies, it opened an ordinary gift enquiry
  // with "تسلم إيدك" — thanking a customer who had thanked nobody.
  assert.match(text, /ONLY for when the matching phrase was said to \s*you/);
});

test("a greeting does not draw a list of what the shop sells", () => {
  // This was my own addition and it was wrong: told to "name the KINDS of
  // thing you sell", it answered "كيفك؟" with "عنا فساتين وشناط وشيلان".
  // Suggesting before the customer has said anything is a billboard.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /ANSWER WHAT THEY ACTUALLY SAID/);
  assert.match(text, /Do NOT \s*list what you sell/);
  assert.match(text, /do NOT mention a \s*price/);

  // And the rule that caused it is gone, not merely contradicted elsewhere.
  assert.doesNotMatch(text, /name the KINDS of thing you sell/);
});

test("suggesting is gated on the customer having said something", () => {
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /ONCE THEY HAVE TOLD YOU SOMETHING/);
  assert.match(text, /Only once they have \s*said something/);
});

test("the Modern Standard giveaways are named, not just forbidden in general", () => {
  // The real reply opened with "نعم". The dialect rule had been there since
  // 19 September and did not stop it; naming the word does.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Never write "نعم"/);
  assert.match(text, /آه/);
});

test("the instructions quote no Arabic reply that offers stock or a price", () => {
  // This started stricter — no Arabic shop reply of any kind — because a
  // handful of them made the model answer an English customer in Arabic, and
  // no wording stopped it.
  //
  // Narrowed 20 September, after the root cause was fixed properly: the
  // customer's language is now DECIDED by readsAsArabic and stated to the
  // model as a fact, rather than inferred by it. Measured against the same
  // large all-Arabic shop that used to break it — "hi", "thanks a lot!" and
  // "do you deliver to Amman?" came back in English six times out of six, with
  // the Levantine pleasantry replies sitting in the instructions.
  //
  // Which matters, because those cannot be taught any other way: "يعطيك
  // العافية" is answered "الله يعافيك" and there is no English gloss that
  // teaches it. What stays forbidden is the risky class — an Arabic sentence
  // that offers stock or quotes a price, which is a reply to copy rather than
  // a social formula.
  const body = buildRequest({ ...requestInput, examples: [] });
  const instructions = (body.system as Record<string, unknown>[])[0].text as string;

  const quoted = instructions.match(/"[^"]*[\u0600-\u06FF][^"]*"/g) ?? [];
  const sellsSomething = quoted.filter((q) => /عنا |عندنا |بـ ?\d/.test(q));

  assert.deepEqual(
    sellsSomething,
    [],
    `the instructions model a sales reply in Arabic: ${sellsSomething}`,
  );
});

test("the language is stated as a fact, not left to the model to infer", () => {
  // Measured against a shop whose catalog, hours and notes are all Arabic: an
  // English customer was answered in Arabic on two runs of three, with the
  // shop's own Arabic examples already withheld. Instruction wording did not
  // move it and neither did moving the rule to the end — there is simply more
  // Arabic in the context than any sentence can outweigh.
  const english = buildRequest({
    ...requestInput,
    turns: [{ inbound: true, text: "do you deliver to Amman?" }],
  });
  const arabic = buildRequest({
    ...requestInput,
    turns: [{ inbound: true, text: "بتوصلوا عمان؟" }],
  });

  const last = (body: Record<string, unknown>) =>
    ((body.system as Record<string, unknown>[]).at(-1)!.text as string);

  assert.match(last(english), /last message is in ENGLISH/);
  assert.match(last(arabic), /last message is in ARABIC/);
});

test("the language statement sits outside the cached prefix", () => {
  // It changes with the customer, so inside the prefix it would write a new
  // cache entry per conversation and read none.
  const body = buildRequest(requestInput);
  const system = body.system as Record<string, unknown>[];

  const breakpoint = system.findIndex((block) => block.cache_control);
  const stated = system.findIndex((block) =>
    /last message is in (ENGLISH|ARABIC)/.test(String(block.text))
  );

  assert.ok(stated > breakpoint, `stated at ${stated}, breakpoint at ${breakpoint}`);
});

test("a photo placeholder does not decide the language", () => {
  // The placeholder is our English, written to the model, not the customer's
  // words. Measured: a photo-only message from an Arabic customer came back
  // "I can't see the photo — could you tell me what you're looking for?".
  const body = buildRequest({
    ...requestInput,
    turns: [
      { inbound: true, text: "مرحبا، بدي أسأل عن شي" },
      { inbound: true, text: "[the customer sent a photo]" },
    ],
  });

  const system = body.system as Record<string, unknown>[];
  assert.match(String(system.at(-1)!.text), /last message is in ARABIC/);
});

test("a photo with nothing before it falls back to Arabic", () => {
  // Most of these shops are in Jordan. Guessing English for a customer who has
  // written no words at all is the wrong way round.
  const body = buildRequest({
    ...requestInput,
    turns: [{ inbound: true, text: "[the customer sent a photo]" }],
  });

  const system = body.system as Record<string, unknown>[];
  assert.match(String(system.at(-1)!.text), /last message is in ARABIC/);
});

test("the assistant does not hedge about what it can see", () => {
  // Measured: "مافي عندي معلومة عن خصم حالياً" and "رح نرجعلك بجواب لو في
  // إمكانية بالسعر". Both honest, both weak — the product owner's read was
  // that indecisive answers give the customer no confidence.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /SOUND LIKE YOU KNOW YOUR SHOP/);
  assert.match(text, /Never hedge about \s*something written down/);
  assert.match(text, /a shop nobody buys \s*from/);
  assert.match(text, /One commitment per reply/);
});

test("the assistant does not reason in front of the customer", () => {
  // Measured: "بس عندي تنورة... بصراحة ما في تنورات ثانية عنا" — it began
  // offering a second skirt, found there wasn't one, and said so mid-sentence.
  // Honest, and it reads as someone working it out while you watch.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Never think out loud/);
  assert.match(text, /never take back an offer halfway through it/);
});

test("answering the price and then promising to check it is forbidden", () => {
  // It had been doing both: "سعر الشنطة 32 دينار. رح نرجعلك بجواب بخصوص
  // السعر". The second sentence takes back the first.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Do NOT tell them you will get back \s*to them about the price/);
  assert.match(text, /undoes the answer you gave one sentence earlier/);
});

test("a price objection is moved forward, not just absorbed", () => {
  // What someone who runs a shop actually does: hands the customer a way to
  // say yes, out of what is already written down.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /MOVE IT FORWARD with something that IS written down/);
  assert.match(text, /hand the customer a way to say yes/);
});

test("price is stated, never negotiated and never refused", () => {
  // The product owner's call: the assistant lists the price it can see and
  // nothing more, and a customer asking for a discount is handled gently
  // rather than turned down. Both halves matter — a flat "no" costs the sale
  // as surely as an invented discount does.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /WHEN THEY WANT TO TALK ABOUT PRICE/);
  assert.match(text, /You do not negotiate and you do not discuss price/);
  assert.match(text, /do NOT refuse them, do NOT bargain, and do NOT hedge/);
  assert.match(text, /A customer asking for a better price is a customer who wants to buy/);
  assert.match(text, /Sound like \s*someone who wants to sell to them/);
});

test("the assistant may not invent a price policy, but may rule a sale out", () => {
  // Two claims that look alike and are not. "السعر ثابت" is a policy nobody
  // wrote down. "حالياً ما في خصم على هالقطعة" is what the shop's own list
  // says, because a discount would be written there — the product owner's
  // call, and the one that gives a customer an actual answer.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /NEVER say the price is fixed, final, or the best you can do/);
  assert.match(text, /NEVER offer a discount, a round-down or a better price yourself/);
  assert.match(text, /there is no sale on this item at the moment/);
  assert.match(text, /it is a different claim from "there is no sale right now"/);
});

test("not knowing about a discount is forbidden, because it does know", () => {
  // "مافي عندي معلومة عن خصم حالياً" was the reply that prompted this. It is
  // a hedge dressed as honesty: the information is right there in the facts.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /What you must NOT say is that you do not know/);
  assert.match(text, /you do know, because it would be written down/);
});

test("the assistant IS the shop, with nobody standing behind it", () => {
  // Decided by the product owner: "It shouldn't reference the shop owner, if
  // something it does not know, it simply should say will get back to you with
  // an answer, no reference to anyone, we are the shop owners of sorts."
  //
  // It had been deferring to a third party on every hand-over, and inventing
  // that person's gender while it did — "صاحب المحل" in one reply and "صاحبة
  // المحل" in the next, in one conversation.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /You ARE the shop/);
  assert.match(text, /There \s*is nobody behind you/);
  assert.match(text, /NEVER mention a shop owner, a manager, a colleague or anyone else/);
  assert.match(text, /رح نرجعلك بجواب/);
});

test("not knowing is answered with a promise to come back, not a referral", () => {
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /you say that you will come back with an answer/);
  assert.match(text, /Never \s*say who will answer/);
});

test("nothing the model reads describes handOver as fetching a person", () => {
  // Including the JSON schema, which sits in the same context as everything
  // else and is where the phrase "the shop owner" survived longest.
  const body = buildRequest(requestInput);
  const schema = JSON.stringify(
    (body.output_config as Record<string, Record<string, unknown>>).format,
  );

  assert.doesNotMatch(schema, /shop owner/);
  assert.match(schema, /needs a human/);
});

test("the fixed hand-over line refers to nobody, and promises an answer", () => {
  for (const line of Object.values(HANDOVER_LINE)) {
    assert.doesNotMatch(line, /صاحب|صاحبة|owner|manager/);
  }
  assert.match(HANDOVER_LINE.arabic, /رح نرجعلك بجواب/);
  assert.match(HANDOVER_LINE.english, /with an answer/);
});

test("Arabizi is told to answer in Arabic, not English", () => {
  // The same heuristic that withholds the examples decides this, so the two
  // cannot disagree — a customer typing "2adesh" must not be told they wrote
  // English while their Arabic examples are being kept for them.
  const body = buildRequest({
    ...requestInput,
    turns: [{ inbound: true, text: "2adesh se3r el shanta?" }],
  });

  const system = body.system as Record<string, unknown>[];
  assert.match(String(system.at(-1)!.text), /last message is in ARABIC/);
});

test("numbers are to be written in Western figures, even in Arabic", () => {
  // Measured: the same conversation gave "32 دينار" and then "٣٢ دينار". The
  // interface uses Western numerals everywhere (docs/DECISIONS.md), the shop's own
  // list is written that way, and a shop that changes numeral system halfway
  // through reads as two different people.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Western figures/);
  assert.match(text, /Never\s+٠١٢٣٤٥٦٧٨٩/);
});

test("the address does not switch gender mid-conversation", () => {
  // Measured: "شو بتدوري عليه" then "قول لي وبساعدك" in the same sentence.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /WHO YOU ARE TALKING TO/);
  assert.match(text, /Decide ONCE, at the \s*start/);
  assert.match(text, /Switching halfway/);
});

test("the customer's name reaches the model, and decides the gender", () => {
  // It was in the database and never sent — the strongest signal available,
  // and the model was guessing without it.
  const body = buildRequest({ ...requestInput, customerName: "سارة الخطيب" });
  const last = (body.system as Record<string, unknown>[]).map((b) => String(b.text)).join(" ");

  assert.match(last, /The customer's name is سارة الخطيب/);
});

test("an unknown name falls back to the masculine, not to a guess", () => {
  // The product owner's call: ambiguous means masculine, and a customer it
  // does not fit will correct it. An edge case, handled rather than left open.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => String(b.text)).join(" ");

  assert.match(text, /use the MASCULINE/);
  assert.match(text, /a name that goes either \s*way, initials, a shop or a brand name/);
  assert.match(text, /We do not know the customer's name/);
});

test("a name it is sure of may be used, in a greeting or a closing", () => {
  // The product owner: "If the agent is super sure it recognizes the name, and
  // its clear like a jack, Ahmad whatever, it can use it in welcoming or
  // ending messages to be a bit more human."
  const body = buildRequest({ ...requestInput, customerName: "أحمد" });
  const text = (body.system as Record<string, unknown>[]).map((b) => String(b.text)).join(" ");

  assert.match(text, /USING THEIR NAME/);
  assert.match(text, /Use the FIRST name only/);
  // Placement is the model's judgement, not a whitelist — the product owner
  // widened it from greeting-and-closing to "wherever it finds suitable".
  assert.match(text, /use it \s*wherever it genuinely fits/);
  assert.match(text, /Judge it yourself/);
});

test("a handle, a brand or an unreadable name is not used", () => {
  // The failure this guards against is addressing a shop as a person, or
  // getting a real customer's name wrong — both worse than using none.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => String(b.text)).join(" ");

  assert.match(text, /NOT a business or brand name, not a handle/);
  assert.match(text, /If any part of that is in doubt, leave the name out/);
});

test("the name is not to be repeated in every message", () => {
  // The call-centre tic, and the fastest way to undo the warmth it buys.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => String(b.text)).join(" ");

  // The constraint is frequency, not position: sprinkling it is the tic.
  assert.match(text, /Never twice in one message, and not in \s*every message/);
  assert.match(text, /A name in every reply is worse than no name at all/);
  assert.match(text, /is a call centre, not a shop/);
});

test("a name we do have overrides nothing the customer said about themselves", () => {
  // Order matters: what they say about themselves beats what we were told
  // their name is, because Meta profile names are often wrong or a business.
  const body = buildRequest({ ...requestInput, customerName: "أحمد" });
  const text = (body.system as Record<string, unknown>[]).map((b) => String(b.text)).join(" ");

  const own = text.indexOf("What the customer says about THEMSELVES");
  const byName = text.indexOf("Their name, which is given to you");

  assert.ok(own > -1 && byName > own, "their own words must be listed first");
});

test("the name sits outside the cached prefix", () => {
  // It changes with every conversation. Inside the prefix it would write a new
  // cache entry per customer and read none — the $21-a-month failure.
  const body = buildRequest({ ...requestInput, customerName: "سارة" });
  const system = body.system as Record<string, unknown>[];

  const breakpoint = system.findIndex((b) => b.cache_control);
  const named = system.findIndex((b) => /The customer's name is/.test(String(b.text)));

  assert.ok(named > breakpoint, `name at ${named}, breakpoint at ${breakpoint}`);
});

test("a blank or whitespace name is treated as no name", () => {
  for (const name of ["", "   ", null, undefined]) {
    const body = buildRequest({ ...requestInput, customerName: name });
    const text = (body.system as Record<string, unknown>[]).map((b) => String(b.text)).join(" ");
    assert.match(text, /We do not know the customer's name/, JSON.stringify(name));
  }
});

test("the assistant is told what emoji it may use, and when", () => {
  // Decided by the product owner: the safe ones, sparingly, when closing.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Emoji: almost never/);
  assert.match(text, /No hearts/);
  assert.match(text, /If you are unsure, use none/);
});

test("the assistant is told never to promise when", () => {
  // The single mistake a customer remembers. tidyEmoji's sibling guard catches
  // it deterministically, but the instruction is what stops it being written.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Never promise WHEN/);
  assert.match(text, /Never offer a discount, a guarantee, a warranty or a refund/);
});

test("the voice examples are named as tone and not as facts", () => {
  // Measured: a delivery time was lifted out of a seller's own past reply and
  // sent to a customer as a promise. The examples block already says "TONE
  // ONLY"; this says it again where the rules are, because that is where the
  // model was looking when it did it.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /They are NOT facts/);
  assert.match(text, /do not repeat it/);
});

test("a policy nobody wrote down is not the assistant's to state", () => {
  // Measured: asked for a discount it answered "السعر ثابت" — a policy that
  // appears nowhere in the shop's facts. It is the same failure as an invented
  // price, and the grounding check cannot catch it because it has no digits.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Never state a policy nobody wrote down/);
});

test("the assistant is told to sell, not merely to answer", () => {
  // The whole complaint: it waited to be asked an exact question, and expected
  // the customer to already know what they wanted.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Show them around/);
  assert.match(text, /Never stop at no/);
  assert.match(text, /name what is in stock instead/);
  assert.match(text, /point at the cheaper thing/);
});

test("an upsell may not be built on invented qualities", () => {
  // The product owner: "trying to upsell shouldn't include any made up
  // information". Measured — asked to recommend, it called a handbag whose
  // whole description is "جلد طبيعي بني" an "أنيق وثابت" gift that "تدوم".
  // Elegant, hard-wearing and lasting are three things nobody wrote down.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /the reason comes out of the shop's own \s*description, never out of your head/);
  assert.match(text, /an \s*upsell built on invented qualities is the same lie as an invented price/);
});

test("nothing to praise is answered with what the thing is", () => {
  // The escape hatch, without which the rule above just pushes the model into
  // finding a different adjective.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /If the description gives you nothing to praise/);
  assert.match(text, /Reaching for a quality \s*you were not given/);
});

test("a pairing may be suggested but not praised", () => {
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Saying two \s*things go together is a suggestion and it is allowed/);
  assert.match(text, /saying the second one is \s*beautiful, or popular, or a bargain, is not/);
});

test("the question asked matches how far along the customer is", () => {
  // Live: asked "بدور على هدية لعيد الأم كيف ممكن تساعدني" — a want, not a
  // choice — it described the one dress and asked "أي مقاس بدك؟". The old
  // wording literally offered "which size, which colour" as the question to
  // ask, so this was the prompt doing as it was told.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /match it to how far along they \s*actually are/);
  assert.match(text, /has NOT chosen anything \s*yet/);
  assert.match(text, /Do not ask which size, which colour, or whether to reserve it/);
  assert.match(text, /only AFTER they show interest in \s*one particular thing/);
});

test("the assistant is told not to push", () => {
  // Suggesting and pestering are a short step apart, and a shop that is hard
  // to get away from loses the customer the suggestion just earned.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /DO NOT PUSH/);
  assert.match(text, /never invent urgency/);
  // Measured on Sonnet 5: "عم يلاقوا إقبال كبير" — nobody said that, and
  // manufactured popularity is the oldest pressure tactic there is.
  assert.match(text, /Never claim other people are buying it/);
  assert.match(text, /If they do not pick it up, let it go/);
});

test("handing over is named as a last resort, and never a silent one", () => {
  // The old instructions called escalating "a good outcome, not a failure",
  // which it read as licence to do at the first hesitation — and the customer
  // heard nothing at all when it did.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /handOver is a LAST RESORT/);
  assert.match(text, /STILL WRITE text/);
  assert.match(text, /Leaving the customer with nothing/);
});

test("counts are to be written as words, so the grounding check leaves them alone", () => {
  // Every digit-run in a reply must appear in the shop's facts. A count the
  // model worked out — "three colours" — is written down nowhere, so as a
  // digit it would be held back and the customer would get silence in place of
  // a perfectly true sentence.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Never write a digit that does not appear/);
  assert.match(text, /write it as a word/);
});

test("the assistant is told a photo is something it cannot see", () => {
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /\[the customer sent a photo\]/);
  assert.match(text, /Do not guess what is in it/);
});

test("the assistant is told not to add numbers up", () => {
  // It offered a correct total — 25.5 plus 2.5 delivery — which the grounding
  // check would then hold back, because the sum appears nowhere in the shop's
  // facts. Giving the parts is just as useful and stays grounded.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /Never add numbers up/);
});

test("a total worked out from two real prices is still held back", () => {
  // Guards the reason the instruction above exists: the check cannot tell an
  // arithmetic result from an invention, and should not try.
  const facts = renderFacts({ shop: SHOP, zones: ZONES, products: [DRESS] });

  assert.equal(numbersAreGrounded("25.5", facts, []), true);
  assert.equal(numbersAreGrounded("2", facts, []), true);
  assert.equal(numbersAreGrounded("المجموع 27.5", facts, []), false);
});

test("the instructions forbid pet names outright", () => {
  // A seller may call every customer حبيبتي; a shop's assistant should not,
  // ever. Measured against examples where every single one uses an endearment,
  // including the cases most likely to draw one out — a bare greeting and a
  // thank-you: none of nine replies used one.
  //
  // Unlike the language rule, this one survives the examples, so it stays an
  // instruction rather than a filter over the reply. A filter would have to
  // cut a word out of a finished sentence and would read worse than the
  // problem it solved.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /حبيبتي/, "names the words it means");
  assert.match(text, /NEVER use a term of endearment/);
  assert.match(text, /do NOT copy that habit/);
});

test("Arabic typed in Latin letters still reads as Arabic", () => {
  // Arabizi borrows digits for letters Latin does not have, and glues them to
  // letters. That is what separates it from English.
  assert.equal(readsAsArabic("2adesh se3r el shanta?"), true);
  assert.equal(readsAsArabic("fi 3endkom el fostan el a7mar?"), true);
  assert.equal(readsAsArabic("قديش سعر الشنطة؟"), true);
});

test("plain English does not read as Arabic", () => {
  assert.equal(readsAsArabic("How much is the red dress?"), false);
  assert.equal(readsAsArabic("Do you deliver to Amman?"), false);

  // A standalone digit is a quantity, not a borrowed letter.
  assert.equal(readsAsArabic("I want 2 dresses"), false);
});

test("the shop's Arabic examples are withheld from an English customer", () => {
  // Measured: a few Arabic example replies make the model answer an English
  // customer in Arabic, and no wording of the language rule fixes it. With the
  // examples gone the same question comes back "The red dress is 25.5 JD."
  const english = buildRequest({
    ...requestInput,
    turns: [{ inbound: true, text: "How much is the red dress?" }],
  });

  const text = (english.system as Record<string, unknown>[]).map((b) => b.text).join(" ");
  assert.ok(!text.includes("اهلا وسهلا"), "no Arabic voice examples");
});

test("the examples are kept for a customer writing Arabic", () => {
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.ok(text.includes("اهلا وسهلا"), "the shop's own voice still reaches it");
});

test("the last customer message decides, not an earlier one", () => {
  // A conversation that switches language mid-way should follow the switch.
  const body = buildRequest({
    ...requestInput,
    turns: [
      { inbound: true, text: "قديش سعر الفستان؟" },
      { inbound: false, text: "25.5" },
      { inbound: true, text: "Do you deliver to Amman?" },
    ],
  });

  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");
  assert.ok(!text.includes("اهلا وسهلا"));
});

test("Arabizi is answered in Arabic script, in the same dialect", () => {
  // Typing in Latin letters is a keyboard constraint, not a reading one — a
  // customer who writes Arabizi reads Arabic script perfectly well, and a shop
  // that writes back in Latin letters looks careless. The dialect is still
  // mirrored; only the script is normalised.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.match(text, /ARABIC SCRIPT/);
  assert.match(text, /2adesh/, "carries a worked example, not just a rule");
  assert.match(text, /قديش/, "and an Arabic-script example beside it");
});

test("a shop with no example replies still gets a breakpoint", () => {
  // A new seller has written nothing yet. The catalog is still worth caching.
  const body = buildRequest({ ...requestInput, examples: [] });
  const system = body.system as Record<string, unknown>[];

  assert.equal(system.filter((block) => "cache_control" in block).length, 1);
});

test("the catalog reaches the model", () => {
  const body = buildRequest(requestInput);
  const system = body.system as Record<string, unknown>[];
  const text = system.map((block) => block.text).join("\n");

  assert.ok(text.includes("فستان أحمر"), "the product name");
  assert.ok(text.includes("25.5"), "the price");
});


test("the instructions forbid answering dialect in Modern Standard Arabic", () => {
  // The stated reason this product exists is that chatbots sound robotic, and
  // this is the specific way it would sound robotic in Arabic. The shops are
  // mostly Jordanian, so that is the dialect named.
  const body = buildRequest(requestInput);
  const text = (body.system as Record<string, unknown>[]).map((b) => b.text).join(" ");

  assert.ok(/Modern Standard Arabic/i.test(text), "names the failure mode");
  assert.ok(/same script|Latin letters/i.test(text), "covers Arabizi");
  assert.ok(/Jordan|Levantine/i.test(text), "names the region these shops are in");
});

// ---------------------------------------------------------------------------
// Turning a conversation into turns
// ---------------------------------------------------------------------------

test("a customer firing off three lines is one turn, not three", () => {
  // Normal behaviour, and the API expects the two sides to alternate.
  const messages = toMessages([
    { inbound: true, text: "هلو" },
    { inbound: true, text: "بكم الفستان؟" },
    { inbound: true, text: "؟؟" },
  ]);

  assert.equal(messages.length, 1);
  assert.equal(messages[0].role, "user");
  assert.ok(messages[0].content.includes("هلو"));
  assert.ok(messages[0].content.includes("بكم الفستان؟"));
});

test("the two sides alternate", () => {
  const messages = toMessages([
    { inbound: true, text: "بكم؟" },
    { inbound: false, text: "25.500" },
    { inbound: true, text: "زين" },
  ]);

  assert.deepEqual(messages.map((m) => m.role), ["user", "assistant", "user"]);
});

test("a conversation cannot open with the shop talking", () => {
  // The API refuses a leading assistant turn, and it happens whenever the
  // window slice starts just after one of the seller's own replies.
  const messages = toMessages([
    { inbound: false, text: "اهلا" },
    { inbound: true, text: "بكم؟" },
  ]);

  assert.equal(messages.length, 1);
  assert.equal(messages[0].role, "user");
});

test("an empty message is dropped rather than sent as a blank turn", () => {
  const messages = toMessages([
    { inbound: true, text: "   " },
    { inbound: true, text: "بكم؟" },
  ]);

  assert.equal(messages.length, 1);
  assert.equal(messages[0].content, "بكم؟");
});

// ---------------------------------------------------------------------------
// Reading the answer
// ---------------------------------------------------------------------------

const answer = (payload: unknown, usage: Record<string, number> = {}) => ({
  content: [{ type: "text", text: JSON.stringify(payload) }],
  usage,
});

test("a reply is read back", () => {
  const decision = readDecision(answer({ text: "25.500 دينار", handOver: false }));
  assert.deepEqual(decision, { text: "25.500 دينار", handOver: false, reason: null, photos: [] });
});

test("a hand-over carries its reason AND still carries a reply", () => {
  // These used to be alternatives, so a customer who asked two things — one
  // answerable, one not — received nothing at all.
  const decision = readDecision(
    answer({ text: "الفستان 25.5، وصاحب المحل رح يرد عن الباقي", handOver: true, reason: "wants a discount" }),
  );

  assert.deepEqual(decision, {
    text: "الفستان 25.5، وصاحب المحل رح يرد عن الباقي",
    handOver: true,
    reason: "wants a discount",
    photos: [],
  });
});

test("a hand-over with no reason carries none, rather than an English stand-in", () => {
  // The reason is shown to the seller now, so a placeholder written here would
  // be the one line of the interface that is never translated. Null instead,
  // and the interface supplies the general wording in the seller's language.
  const decision = readDecision(answer({ text: "رح يرد عليك صاحب المحل", handOver: true }));
  assert.equal(decision?.handOver, true);
  assert.equal(decision?.reason, null);
});

test("the reason is asked for in the customer's language, not in English", () => {
  // It sits beside the conversation's own preview in the inbox. A reason
  // written in English under an Arabic preview reads as a system message.
  const schema = JSON.stringify(
    (buildRequest(requestInput).output_config as Record<string, Record<string, unknown>>).format,
  );

  assert.match(schema, /same language you are writing to the customer in/);
  assert.doesNotMatch(schema, /a few words, in English/i);
});

test("a reply that is not handing over carries no reason", () => {
  // Otherwise a stray reason shows on the seller's row for a conversation that
  // was answered and needs nothing from them.
  const decision = readDecision(answer({ text: "أهلين", handOver: false, reason: "leftover" }));
  assert.equal(decision?.reason, null);
});

test("an answer with no text is unusable, whatever else it says", () => {
  // The schema requires text, so this is the model ignoring it. There is no
  // shape that is allowed to leave the customer with nothing.
  assert.equal(readDecision(answer({ text: "", handOver: false })), null);
  assert.equal(readDecision(answer({ text: "   ", handOver: true, reason: "a complaint" })), null);
  assert.equal(readDecision(answer({ handOver: true, reason: "a complaint" })), null);
});

test("an answer that is not JSON is unusable rather than fatal", () => {
  // Structured output makes this unlikely, not impossible, and a crash here
  // would lose a message that is already stored.
  assert.equal(readDecision({ content: [{ type: "text", text: "sorry, what?" }] }), null);
});

test("anything other than true is not handing over", () => {
  assert.equal(readDecision(answer({ text: "أهلين", handOver: "yes" }))?.handOver, false);
  assert.equal(readDecision(answer({ text: "أهلين" }))?.handOver, false);
});

test("an empty or malformed body is unusable rather than fatal", () => {
  assert.equal(readDecision(null), null);
  assert.equal(readDecision({}), null);
  assert.equal(readDecision({ content: [] }), null);
  assert.equal(readDecision("nonsense"), null);
});

test("the cache counters are read, because they are how we know caching works", () => {
  // cache_read_input_tokens staying at zero across requests is the signal that
  // the prefix is being invalidated and the cost model is wrong.
  const usage = readUsage(
    answer({ action: "escalate" }, {
      input_tokens: 120,
      output_tokens: 30,
      cache_read_input_tokens: 9000,
      cache_creation_input_tokens: 0,
    }),
  );

  assert.deepEqual(usage, {
    inputTokens: 120,
    outputTokens: 30,
    cacheReadTokens: 9000,
    cacheWriteTokens: 0,
  });
});

test("a body with no usage reports zeros rather than throwing", () => {
  assert.equal(readUsage({}).inputTokens, 0);
  assert.equal(readUsage(null).cacheReadTokens, 0);
});

// ---------------------------------------------------------------------------
// The grounding check
// ---------------------------------------------------------------------------

const FACTS = renderFacts({ shop: SHOP, zones: ZONES, products: [DRESS, SHOES] });

test("a price taken from the catalog passes", () => {
  assert.equal(numbersAreGrounded("25.500 دينار", FACTS, []), true);
});

test("a price the model invented is caught", () => {
  // The failure that loses a seller their customer, and the one a language
  // model is most prone to.
  assert.equal(numbersAreGrounded("19.750 دينار", FACTS, []), false);
});

test("a price off by a digit is caught", () => {
  assert.equal(numbersAreGrounded("255 دينار", FACTS, []), false);
});

test("a delivery fee the shop set passes", () => {
  // The whole reason the shop's facts and the grounding haystack are rendered
  // by one function: a fee the model was told about must not be refused on the
  // way out as something it made up.
  assert.equal(numbersAreGrounded("التوصيل لعمّان 2 دينار", FACTS, []), true);
  assert.equal(numbersAreGrounded("إربد 3.5", FACTS, []), true);
});

test("a delivery fee for a place the shop never priced is caught", () => {
  // The shop lists Amman, Irbid and Aqaba. Quoting 7 dinars to anywhere is an
  // invention, and an expensive one to get wrong.
  assert.equal(numbersAreGrounded("التوصيل 7 دنانير", FACTS, []), false);
});

test("a number from the shop's own delivery note passes", () => {
  // "free over 50 dinars" is written down, so the model may repeat it.
  assert.equal(numbersAreGrounded("مجاني فوق 50 دينار", FACTS, []), true);
});

test("Arabic-Indic numerals match facts written in Western ones", () => {
  // The interface uses Western numerals, but a customer may type ٢٥ and the
  // model may echo it back. Comparing scripts naively would fail every time.
  assert.equal(numbersAreGrounded("٢٥.٥٠٠ دينار", FACTS, []), true);
});

test("an invented delivery time is caught", () => {
  // Nobody authorised this promise, and it is nowhere in the shop's facts.
  assert.equal(numbersAreGrounded("يوصل خلال 24 ساعة", FACTS, []), false);
});

test("a number the customer themselves used is grounded", () => {
  // The customer naming a quantity or an order number is not the model
  // inventing one.
  assert.equal(numbersAreGrounded("نعم 3 قطع", FACTS, ["اريد 3 قطع"]), true);
});

test("a reply with no numbers at all is grounded", () => {
  assert.equal(numbersAreGrounded("متوفر حبيبي", FACTS, []), true);
});

test("a small number is checked like any other", () => {
  // No floor, deliberately. Delivery in Jordan costs 2 or 3 dinars, so
  // exempting small numbers as "probably a quantity" would exempt exactly the
  // figures most worth guarding. 2 is one of the shop's own fees, so it passes;
  // 9 is nowhere in its facts, so it does not.
  assert.equal(numbersAreGrounded("عندنا 2 الوان", FACTS, []), true);
  assert.equal(numbersAreGrounded("عندنا 9 الوان", FACTS, []), false);
});

test("the same price written with fils matches the one without", () => {
  // The seller types 25.500 and the catalog stores 25.5. A check comparing
  // digit strings would reject the assistant's own correct answer.
  assert.equal(numbersAreGrounded("25.500", FACTS, []), true);
  assert.equal(numbersAreGrounded("25.5", FACTS, []), true);
});

// ---------------------------------------------------------------------------
// The call itself
// ---------------------------------------------------------------------------

/** A stand-in for the API that records what it was sent. */
function api(
  reply: unknown,
  { ok = true, status = 200, fail = false, garbage = false } = {},
) {
  const sent: string[] = [];

  const fetcher = ((_url: string, init?: RequestInit) => {
    sent.push(String(init?.body ?? ""));
    if (fail) return Promise.reject(new Error("network"));

    return Promise.resolve({
      ok,
      status,
      json: () => (garbage ? Promise.reject(new Error("bad json")) : Promise.resolve(reply)),
    } as Response);
  }) as unknown as typeof fetch;

  return { fetcher, sent };
}

test("a decision comes back with what it cost", async () => {
  const { fetcher, sent } = api(
    answer({ text: "25.500", handOver: false }, { cache_read_input_tokens: 8000 }),
  );

  const outcome = await ask("key", requestInput, fetcher);

  assert.equal(outcome.status, "decided");
  assert.equal(sent.length, 1);
  if (outcome.status === "decided") {
    assert.deepEqual(outcome.decision, { text: "25.500", handOver: false, reason: null, photos: [] });
    assert.equal(outcome.usage.cacheReadTokens, 8000);
  }
});

test("the api key travels in the header and never in the body", async () => {
  const { fetcher, sent } = api(answer({ text: "أهلين", handOver: true }));
  await ask("sk-secret", requestInput, fetcher);

  assert.ok(!sent[0].includes("sk-secret"), "the key must not be in the request body");
});

test("a network failure is an outcome, not an exception", async () => {
  // This runs after Meta already had its 200. Throwing would lose nothing that
  // matters, but it would be logged as an error rather than as a quiet skip.
  const { fetcher } = api(null, { fail: true });
  const outcome = await ask("key", requestInput, fetcher);

  assert.equal(outcome.status, "failed");
});

test("an error status is an outcome, not an exception", async () => {
  const { fetcher } = api(null, { ok: false, status: 429 });
  const outcome = await ask("key", requestInput, fetcher);

  assert.equal(outcome.status, "failed");
  if (outcome.status === "failed") assert.ok(outcome.detail.includes("429"));
});

test("an unreadable body is an outcome, not an exception", async () => {
  const { fetcher } = api(null, { garbage: true });
  const outcome = await ask("key", requestInput, fetcher);

  assert.equal(outcome.status, "failed");
});

test("an unusable answer carries a snippet of what came back", async () => {
  // Otherwise it is invisible: the customer gets the fixed hand-over line and
  // the log says nothing about why. Seen once live and not reproduced.
  const { fetcher } = api({
    content: [{ type: "text", text: "{\"handOver\": true}" }],
    stop_reason: "end_turn",
  });

  const outcome = await ask("key", requestInput, fetcher);

  assert.equal(outcome.status, "unusable");
  if (outcome.status === "unusable") {
    assert.match(outcome.detail, /stop=end_turn/);
    assert.match(outcome.detail, /handOver/);
  }
});

test("a body with no text block at all still reports something", async () => {
  const { fetcher } = api({ content: [], stop_reason: "max_tokens" });
  const outcome = await ask("key", requestInput, fetcher);

  assert.equal(outcome.status, "unusable");
  if (outcome.status === "unusable") assert.match(outcome.detail, /max_tokens.*no text block/);
});

test("an answer the model garbled is unusable, and the seller gets the conversation", async () => {
  const { fetcher } = api({ content: [{ type: "text", text: "not json" }], usage: {} });
  const outcome = await ask("key", requestInput, fetcher);

  assert.equal(outcome.status, "unusable");
});

// ---------------------------------------------------------------------------
// A shop that does not haggle
// ---------------------------------------------------------------------------
//
// The setting is one boolean. The part worth testing is that turning it on does
// not weaken `claimsAreGrounded`: the guard still refuses an invented price
// policy, and now lets through one the seller actually stated. It does that
// without knowing the setting exists, because the claim is written into the
// same `facts` string it searches.

const strictShop = { ...SHOP, priceStance: "strict" as const };

const factsWhere = (priceStance: "strict" | "notify") =>
  renderFacts({
    shop: { ...SHOP, priceStance },
    zones: [],
    products: [{ name: "فستان أحمر", price: 25.5, description: null, inStock: true }],
  });

test("a shop that has not said so has no price policy in its facts", () => {
  const facts = factsWhere("notify");

  assert.doesNotMatch(facts, /fixed price/i);
  assert.doesNotMatch(facts, /ثابت/);
});

test("an unfamiliar stance is read as notify, never as strict", () => {
  // The safe direction. A value this build has not heard of must not become a
  // licence to tell customers the price is final on a shop that never said so.
  const facts = renderFacts({
    shop: { ...SHOP, priceStance: "something_added_later" as unknown as "notify" },
    zones: [],
    products: [],
  });

  assert.doesNotMatch(facts, /fixed price/i);
});

test("the strict stance is told to offer something cheaper, not just to refuse", () => {
  // The part the product owner asked for: saying no and stopping is how a
  // customer who was ready to buy leaves. The facts have to carry it, because
  // this is the one path where the assistant does not hand over and so nobody
  // else gets a chance to save the sale.
  const facts = factsWhere("strict");

  assert.match(facts, /cheapest/i);
  assert.doesNotMatch(factsWhere("notify"), /cheapest/i);
});

test("a fixed price shop says so in the facts, in both languages", () => {
  // Both, because the assistant answers in the customer's language and the
  // guard searches this string in whichever language the reply came back in.
  const facts = factsWhere("strict");

  assert.match(facts, /fixed price/i);
  assert.match(facts, /non-negotiable/i);
  assert.match(facts, /السعر عنا ثابت/);
});

test("the guard still refuses an invented price policy", () => {
  // Unchanged, and the reason this feature is not simply a prompt edit.
  const facts = factsWhere("notify");

  assert.equal(claimsAreGrounded("السعر عنا ثابت", facts, []), "السعر عنا ثابت");
  assert.equal(claimsAreGrounded("It is a fixed price.", facts, []), "fixed price");
  assert.equal(claimsAreGrounded("Sorry, non-negotiable.", facts, []), "non-negotiable");
});

test("the guard lets the claim through once the seller has made it", () => {
  const facts = factsWhere("strict");

  assert.equal(claimsAreGrounded("السعر عنا ثابت، بس متوفر بكل المقاسات.", facts, []), null);
  assert.equal(claimsAreGrounded("It is a fixed price, but it comes in all sizes.", facts, []), null);
  assert.equal(claimsAreGrounded("The price is non-negotiable.", facts, []), null);
});

test("a fixed price shop still cannot invent a discount or a guarantee", () => {
  // The exemption is about one claim, not an amnesty on the rest. Getting this
  // wrong would turn a pricing preference into a hole in the whole check.
  const facts = factsWhere("strict");

  assert.equal(claimsAreGrounded("في خصم 10% اليوم", facts, []), "خصم");
  assert.equal(claimsAreGrounded("It is guaranteed for a year.", facts, []), "guarantee");
  assert.equal(claimsAreGrounded("This is the last one!", facts, []), "last one");
});

test("ruling a sale out still passes, either way round", () => {
  // The negation strip predates this setting and must survive it.
  for (const stance of ["strict", "notify"] as const) {
    assert.equal(
      claimsAreGrounded("حالياً ما في خصم على هالقطعة", factsWhere(stance), []),
      null,
    );
  }
});

test("the model is told to follow the facts rather than a rule of its own", () => {
  // One prompt, not two. The instructions defer to the shop's facts, so the
  // cached prefix is identical for every shop and there is no second variant
  // to keep in step. If this ever becomes two prompts, the cache halves.
  const instructions = String(
    (buildRequest(requestInput).system as Record<string, unknown>[])[0].text,
  );

  assert.match(instructions, /UNLESS the shop's facts say/);
  assert.match(instructions, /do not set handOver for this/);
});

test("the fixed price instructions are the same bytes for every shop", () => {
  // The guard against the above quietly becoming per-shop.
  const plain = buildRequest(requestInput).system as Record<string, unknown>[];
  const strict = buildRequest({
    ...requestInput,
    facts: renderFacts({ shop: strictShop, zones: [], products: [] }),
  }).system as Record<string, unknown>[];

  assert.equal(plain[0].text, strict[0].text);
});

// ---------------------------------------------------------------------------
// Categories and photos, 22 September 2026
//
// The assistant has to read what the seller now writes down — a category and
// a photo — and it sends a photo by naming a product, never by handling a URL.
// ---------------------------------------------------------------------------

const PHOTO = "https://example.supabase.co/storage/v1/object/public/product-photos/ws/abc.jpg";

const BAG = {
  name: "شنطة جلد",
  price: 18,
  description: "اللون: أسود، بيج\nالمقاسات: وسط",
  inStock: true,
  category: "شنط",
  photo: PHOTO,
};

test("a product's category and photo reach the catalog, and the URL does not", () => {
  const rendered = renderCatalog([BAG]);

  assert.ok(rendered.includes("category: شنط"), rendered);
  assert.ok(rendered.includes("has photo"), rendered);
  // The model names products; it never needs the address, and could copy it
  // into a reply if it had it.
  assert.ok(!rendered.includes("http"), rendered);
});

test("details written over several lines stay on the product's one line", () => {
  // Excel imports write one detail per line. Left as they are, a line reading
  // "المقاسات: وسط" would sit in the list with no product in front of it.
  const rendered = renderCatalog([BAG]);

  assert.equal(rendered.split("\n").length, 1, rendered);
  assert.ok(rendered.includes("اللون: أسود، بيج; المقاسات: وسط"), rendered);
});

test("a product with no photo says nothing about one", () => {
  assert.ok(!renderCatalog([DRESS]).includes("photo"));
});

test("photos come back from the model's answer", () => {
  const decision = readDecision(answer({ text: "هاي هي", handOver: false, photos: ["شنطة جلد"] }));
  assert.deepEqual(decision?.photos, ["شنطة جلد"]);
});

test("a missing or malformed photos field is no photos, not an unusable answer", () => {
  assert.deepEqual(readDecision(answer({ text: "هلا", handOver: false }))?.photos, []);
  assert.deepEqual(
    readDecision(answer({ text: "هلا", handOver: false, photos: "شنطة" }))?.photos,
    [],
  );
  assert.deepEqual(
    readDecision(answer({ text: "هلا", handOver: false, photos: [3, "شنطة جلد"] }))?.photos,
    ["شنطة جلد"],
  );
});

test("a photo is sent only for a product that has one, named exactly", () => {
  const products = [BAG, { ...DRESS, photo: null }];

  assert.deepEqual(photosToSend(["شنطة جلد"], products, []), [{ product: "شنطة جلد", url: PHOTO }]);
  // Close is not the same product. The wrong photo under a price is worse
  // than none.
  assert.deepEqual(photosToSend(["شنطة"], products, []), []);
  assert.deepEqual(photosToSend(["فستان أحمر"], products, []), []);
  assert.deepEqual(photosToSend(["something invented"], products, []), []);
});

test("a photo already sent in this conversation is not sent again", () => {
  const turns = [
    { inbound: true, text: "بدي أشوف الشنطة" },
    { inbound: false, text: attachmentTurn([{ type: "image", product: "شنطة جلد" }], false)! },
  ];

  assert.deepEqual(photosToSend(["شنطة جلد"], [BAG], turns), []);
});

test("no more than two photos go with one reply, and none twice", () => {
  const products = ["a", "b", "c"].map((name) => ({ ...BAG, name, photo: `${PHOTO}?${name}` }));

  const chosen = photosToSend(["a", "a", "b", "c"], products, []);
  assert.deepEqual(chosen.map((c) => c.product), ["a", "b"]);
  assert.equal(chosen.length, MAX_PHOTOS);
});

test("the shop's own photo is written as the shop's, with the product it showed", () => {
  assert.equal(
    attachmentTurn([{ type: "image", product: "شنطة جلد" }], false),
    "[the shop sent a photo of شنطة جلد]",
  );
  assert.equal(attachmentTurn([{ type: "image" }], false), "[the shop sent a photo]");
  // Inbound is unchanged.
  assert.equal(attachmentTurn([{ type: "image" }]), "[the customer sent a photo]");
});

test("the model is told how to send a photo, and asked for the field", () => {
  const body = buildRequest({
    facts: renderFacts({ shop: SHOP, zones: [], products: [BAG] }),
    now: new Date("2026-09-22T10:00:00Z"),
    examples: [],
    turns: [{ inbound: true, text: "بدي أشوف الشنطة" }],
    customerName: null,
  }) as { system: { text: string }[]; output_config?: unknown };

  const instructions = body.system[0].text;
  assert.ok(instructions.includes('"has photo"'), "the instructions explain the marker");

  const schema = JSON.stringify(body);
  assert.ok(schema.includes('"photos"'), "the schema asks for photos");
});

// ---------------------------------------------------------------------------
// Offers, 22 September 2026
//
// The sale price is worked out in code and written into the facts, never
// calculated by the model — the grounding check would refuse a number it
// made up, and rightly.
// ---------------------------------------------------------------------------

const SHARED = JSON.parse(
  readFileSync(new URL("../../test/fixtures/offers.json", import.meta.url), "utf8"),
) as {
  cases: {
    name: string;
    product: { id: string; price: number | null; categoryId: string | null };
    offers: Offer[];
    today: string;
    expected: number | null;
  }[];
};

for (const example of SHARED.cases) {
  test(`sale price, shared with the client: ${example.name}`, () => {
    const product = { ...example.product, name: "x", description: null, inStock: true };
    assert.equal(salePrice(product, example.offers, example.today)?.price ?? null, example.expected);
  });
}

test("today is Amman's date, not the server's", () => {
  // 22:30 UTC on the 22nd is already the 23rd in Amman (UTC+3), which is the
  // difference between an offer that ended yesterday and one still running.
  assert.equal(todayInAmman(new Date("2026-09-22T22:30:00Z")), "2026-09-23");
  assert.equal(todayInAmman(new Date("2026-09-22T12:00:00Z")), "2026-09-22");
});

const DRESS_ON_SALE = { ...DRESS, id: "p_dress", categoryId: "c_dresses", category: "فساتين" };
const EID: Offer = {
  name: "عرض العيد",
  kind: "percent",
  value: 20,
  categoryIds: ["c_dresses"],
  endsOn: "2026-09-30",
};

const withOffers = (offers: Offer[], today = "2026-09-22") =>
  renderFacts({ shop: SHOP, zones: [], products: [DRESS_ON_SALE, SHOES], offers, today });

test("a product on sale shows its sale price beside the listed one, and when it ends", () => {
  const facts = withOffers([EID]);
  const dress = facts.split("\n").find((line) => line.startsWith("- فستان أحمر"))!;

  assert.ok(dress.includes("on sale: 20.4 د.ا instead of 25.5"), dress);
  assert.ok(dress.includes("عرض العيد"), dress);
  assert.ok(dress.includes("until 2026-09-30"), dress);
  // The shoes are not in the category.
  assert.ok(!facts.split("\n").find((line) => line.startsWith("- حذاء"))!.includes("on sale"));
});

test("the offers section says what each offer covers, by name", () => {
  const facts = withOffers([
    EID,
    { kind: "buy_get", buy: 2, get: 1, productIds: ["p_dress"] },
    { kind: "amount", value: 3 },
  ]);

  assert.ok(facts.includes("عرض العيد: 20% off (خصم 20%), on everything in فساتين, until 2026-09-30"), facts);
  assert.ok(facts.includes("buy 2 get 1 free (اشتري 2 وخذ 1 مجاناً)"), facts);
  assert.ok(facts.includes("on فستان أحمر"), facts);
  assert.ok(facts.includes("3 د.ا off"), facts);
  assert.ok(facts.includes("on everything in the shop"), facts);
});

test("an offer that has ended, not started, or been switched off is not written at all", () => {
  for (const offer of [
    { ...EID, endsOn: "2026-09-21" },
    { ...EID, startsOn: "2026-09-23", endsOn: null },
    { ...EID, enabled: false },
  ]) {
    const facts = withOffers([offer]);
    assert.ok(!facts.includes("on sale"), facts);
    assert.ok(!facts.includes("خصم"), facts);
    assert.ok(!facts.includes("Offers"), facts);
  }
});

test("an offer on products that no longer exist says nothing", () => {
  const facts = withOffers([{ kind: "percent", value: 10, productIds: ["deleted"] }]);
  assert.ok(!facts.includes("Offers"), facts);
});

test("with no offers the facts are what they were before offers existed", () => {
  // Byte-identical, so every shop that has not made an offer keeps its cache
  // and its behaviour exactly.
  assert.equal(
    withOffers([]),
    renderFacts({ shop: SHOP, zones: [], products: [DRESS_ON_SALE, SHOES] }),
  );
});

test("a running offer makes the discount true, and the guard lets it through", () => {
  const reply = "الفستان عليه خصم 20% بعرض العيد، صار 20.4 بدل 25.5";

  // No offer: an invented discount, refused — the guard is unchanged.
  assert.equal(claimsAreGrounded(reply, withOffers([]), []), "خصم");
  // An offer running: written in the facts, so it is true, and allowed.
  assert.equal(claimsAreGrounded(reply, withOffers([EID]), []), null);
  assert.equal(numbersAreGrounded(reply, withOffers([EID]), []), true);

  // The same in English.
  const english = "The dress is on sale: 20.4 instead of 25.5, a 20% discount";
  assert.notEqual(claimsAreGrounded(english, withOffers([]), []), null);
  assert.equal(claimsAreGrounded(english, withOffers([EID]), []), null);
});

test("a sale price the model worked out for itself is refused", () => {
  // 25.5 at 30% off is 17.85 — a real number, and not one the shop wrote.
  assert.equal(numbersAreGrounded("صار سعره 17.85", withOffers([EID]), []), false);
});

test("the instructions are the same for a shop with offers as without", () => {
  const request = (offers: Offer[]) =>
    (buildRequest({
      facts: withOffers(offers),
      now: new Date("2026-09-22T10:00:00Z"),
      examples: [],
      turns: [{ inbound: true, text: "في خصم؟" }],
      customerName: null,
    }) as { system: { text: string }[] }).system[0].text;

  assert.equal(request([]), request([EID]));
  assert.ok(request([]).includes("Do not work one out yourself"));
});

test("a product's code reaches the catalog, so a customer can quote it", () => {
  const rendered = renderCatalog([{ ...DRESS, code: "FS-101" }]);
  assert.ok(rendered.includes("code: FS-101"), rendered);
  // A product without one says nothing about it.
  assert.ok(!renderCatalog([DRESS]).includes("code"));
});

test("of two products with one name, the one with a photo is the one sent", () => {
  const products = [
    { ...BAG, name: "فستان سهرة", photo: null },
    { ...BAG, name: "فستان سهرة", photo: PHOTO },
  ];
  assert.deepEqual(photosToSend(["فستان سهرة"], products, []), [{ product: "فستان سهرة", url: PHOTO }]);
});

test("a photo asked for that no product has is reported as missing", () => {
  const products = [BAG, { ...DRESS, photo: null }];
  assert.deepEqual(photosMissing(["شنطة جلد"], products), []);
  assert.deepEqual(photosMissing(["فستان أحمر", "made up"], products), ["فستان أحمر", "made up"]);
});

test("a reply that talks about a photo is recognised, in either language", () => {
  for (const text of ["تمام، هاي صورته", "رح أبعتلك الصورة", "Here's a photo", "sending you a picture", "pics coming"]) {
    assert.equal(mentionsPhoto(text), true, text);
  }
  for (const text of ["الفستان الأحمر بـ 25.5 د.ا", "The red dress is 25.5", "topic"]) {
    assert.equal(mentionsPhoto(text), false, text);
  }
});

// ---------------------------------------------------------------------------
// 22 September, second round: currency, worded offers, customer photos
// ---------------------------------------------------------------------------

test("a shop that never set a currency is in Jordanian dinars", () => {
  const facts = renderFacts({ shop: null, zones: [], products: [DRESS] });
  assert.ok(facts.includes(`25.5 ${DEFAULT_CURRENCY}`), facts);
  assert.equal(DEFAULT_CURRENCY, "دينار أردني");

  const blank = renderFacts({ shop: { ...SHOP, currency: "  " }, zones: [], products: [DRESS] });
  assert.ok(blank.includes(DEFAULT_CURRENCY), blank);
  // A currency the shop did set is kept.
  assert.ok(renderFacts({ shop: SHOP, zones: [], products: [DRESS] }).includes("25.5 د.ا"));
});

const WORDED: Offer = {
  name: "عرض الخريف",
  kind: "text",
  description: "خصم 20% على كل الفساتين، والتوصيل مجاني",
  endsOn: "2026-09-30",
};

test("an offer in the shop's own words is read as written, marked as such", () => {
  const facts = withOffers([WORDED]);
  assert.ok(
    facts.includes("- عرض الخريف: خصم 20% على كل الفساتين، والتوصيل مجاني (in the shop's own words), until 2026-09-30"),
    facts,
  );
  // It is not pretended to cover the whole shop, and it computes nothing.
  assert.ok(!facts.includes("everything in the shop"), facts);
  assert.ok(!facts.includes("on sale:"), facts);
});

test("a worded offer the seller also scoped says its limit", () => {
  const facts = withOffers([{ ...WORDED, categoryIds: ["c_dresses"] }]);
  assert.ok(facts.includes("and only on everything in فساتين"), facts);
});

test("a worded offer that has ended, or is empty, is not written", () => {
  assert.ok(!withOffers([{ ...WORDED, endsOn: "2026-09-21" }]).includes("own words"));
  assert.ok(!withOffers([{ ...WORDED, description: "  " }]).includes("own words"));
});

test("a worded offer lets the model apply its percentage to a listed price", () => {
  const prices = wordedOfferPrices([DRESS, SHOES], [WORDED], "2026-09-22");
  // 25.5 at 20% off is 20.4, a saving of 5.1; 40.75 is 32.6 and 8.15.
  for (const value of [20.4, 5.1, 32.6, 8.15]) assert.ok(prices.includes(value), `${value} in ${prices}`);

  const reply = "الفستان عليه خصم 20% صار 20.4 بدل 25.5";
  const facts = withOffers([WORDED]);
  assert.equal(numbersAreGrounded(reply, facts, []), false, "without the worded prices it is refused");
  assert.equal(numbersAreGrounded(reply, facts, [], prices), true);
});

test("a worded offer allows one step, not any arithmetic", () => {
  const prices = wordedOfferPrices([DRESS, SHOES], [WORDED], "2026-09-22");
  // Two items together, after the discount: a basket total nobody wrote.
  assert.equal(numbersAreGrounded("المجموع 53", withOffers([WORDED]), [], prices), false);
});

test("a worded offer's prices respect a scope the seller picked, and its dates", () => {
  const scoped = wordedOfferPrices([DRESS_ON_SALE, SHOES], [{ ...WORDED, categoryIds: ["c_dresses"] }], "2026-09-22");
  assert.ok(scoped.includes(20.4));
  assert.ok(!scoped.includes(32.6), "the shoes are not in the category");

  assert.deepEqual(wordedOfferPrices([DRESS], [{ ...WORDED, endsOn: "2026-09-21" }], "2026-09-22"), []);
  assert.deepEqual(wordedOfferPrices([DRESS], [{ ...WORDED, enabled: false }], "2026-09-22"), []);
});

test("an amount written in the shop's words is applied the same way", () => {
  const prices = wordedOfferPrices([DRESS], [{ kind: "text", description: "5 دنانير خصم على أي قطعة" }], "2026-09-22");
  assert.ok(prices.includes(20.5), `${prices}`);
});

const THUMB = "https://example.supabase.co/storage/v1/object/public/product-photos/ws/abc_s.jpg";
const SCREENSHOT = "https://scontent.xx.fbcdn.net/v/screenshot.jpg";

const photoRequest = (turns: { inbound: boolean; text: string; image?: string }[], extra = {}) =>
  buildRequest({
    facts: "x",
    now: new Date("2026-09-22T10:00:00Z"),
    examples: [],
    turns,
    customerName: null,
    products: [{ ...BAG, code: "P-004", thumb: THUMB }, { ...DRESS, thumb: null }],
    ...extra,
  }) as { messages: { role: string; content: unknown }[] };

test("a photo the customer just sent is shown with the catalog's thumbnails", () => {
  const body = photoRequest([{ inbound: true, text: "كم سعر هاد؟", image: SCREENSHOT }]);
  const last = body.messages.at(-1)!;
  const blocks = last.content as { type: string; text?: string; source?: { url: string } }[];

  const images = blocks.filter((b) => b.type === "image").map((b) => b.source!.url);
  assert.deepEqual(images, [THUMB, SCREENSHOT], "the thumbnail first, the customer's photo after");
  assert.ok(blocks.some((b) => b.text === "P-004 — شنطة جلد"), "each thumbnail is labelled");
  assert.equal(blocks.at(-1)!.text, "كم سعر هاد؟", "their words come last");
  // A product with no photo has no thumbnail to show.
  assert.ok(!blocks.some((b) => b.text?.includes("فستان أحمر")));
});

test("an older photo is not sent again, nor one when told to leave images out", () => {
  const older = photoRequest([
    { inbound: true, text: "[the customer sent a photo]", image: SCREENSHOT },
    { inbound: false, text: "قصدك الشنطة؟" },
    { inbound: true, text: "آه" },
  ]);
  assert.equal(typeof older.messages.at(-1)!.content, "string");

  const without = photoRequest([{ inbound: true, text: "كم سعر هاد؟", image: SCREENSHOT }], { withImages: false });
  assert.equal(typeof without.messages.at(-1)!.content, "string");
});

test("no more than MAX_THUMBNAILS products go with one photo", () => {
  const many = Array.from({ length: MAX_THUMBNAILS + 10 }, (_, i) => ({ ...BAG, name: `p${i}`, thumb: `${THUMB}?${i}` }));
  const body = buildRequest({
    facts: "x", now: new Date(), examples: [], customerName: null, products: many,
    turns: [{ inbound: true, text: "?", image: SCREENSHOT }],
  }) as { messages: { content: { type: string }[] }[] };
  const images = body.messages.at(-1)!.content.filter((b) => b.type === "image");
  assert.equal(images.length, MAX_THUMBNAILS + 1);
});

test("a request refused over its images is asked again without them", async () => {
  const bodies: string[] = [];
  const fetcher = ((_url: string, init?: RequestInit) => {
    bodies.push(String(init?.body));
    const withImage = String(init?.body).includes(SCREENSHOT);
    return Promise.resolve(
      withImage
        ? ({ ok: false, status: 400, json: () => Promise.resolve({}) } as Response)
        : ({
          ok: true,
          status: 200,
          json: () => Promise.resolve(answer({ text: "أي قطعة قصدك؟", handOver: false, photos: [] })),
        } as Response),
    );
  }) as unknown as typeof fetch;

  const outcome = await ask("key", {
    facts: "x", now: new Date(), examples: [], customerName: null,
    turns: [{ inbound: true, text: "[the customer sent a photo]", image: SCREENSHOT }],
    products: [{ ...BAG, thumb: THUMB }],
  }, fetcher);

  assert.equal(outcome.status, "decided");
  assert.equal(bodies.length, 2);
  assert.ok(!bodies[1].includes(SCREENSHOT));
});

test("a failure with no images in the request is not retried", async () => {
  let calls = 0;
  const fetcher = (() => {
    calls++;
    return Promise.resolve({ ok: false, status: 400, json: () => Promise.resolve({}) } as Response);
  }) as unknown as typeof fetch;

  const outcome = await ask("key", { facts: "x", now: new Date(), examples: [], turns: [{ inbound: true, text: "hi" }] }, fetcher);
  assert.equal(outcome.status, "failed");
  assert.equal(calls, 1);
});

import { usageCost } from "../functions/meta-webhook/ai.ts";

test("a call is priced from its tokens, cache reads at a tenth and writes at double", () => {
  // 1M input at $2, 100k output at $10, 1M cache read at $0.20, 100k write at $4.
  const cost = usageCost("claude-sonnet-5", {
    inputTokens: 1_000_000,
    outputTokens: 100_000,
    cacheReadTokens: 1_000_000,
    cacheWriteTokens: 100_000,
  });
  assert.equal(Math.round(cost * 100) / 100, 2 + 1 + 0.2 + 0.4);
});

test("an unknown model is priced, not free", () => {
  assert.ok(usageCost("some-new-model", { inputTokens: 1000, outputTokens: 0, cacheReadTokens: 0, cacheWriteTokens: 0 }) > 0);
});
