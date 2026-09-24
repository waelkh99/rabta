// How a conversation ended, read by the assistant once it has settled.
//
// A different job from answering: nothing here is sent to the customer. The
// model reads a finished conversation and says what came of it — an order, a
// customer who did not buy and why, or someone who was only asking — plus what
// it can see along the way: the products discussed, where the customer is, and
// what kind of questions they asked. The seller sees the result as a label they
// can correct, and the "this week" view is built from it.
//
// Pure apart from `readOutcome`'s caller, so every rule is testable without a
// network. See CLAUDE.md, "How conversations end".

import { ANTHROPIC_URL, MODEL, readUsage, type Usage } from "./ai.ts";

export const OUTCOMES = ["ordered", "not_bought", "just_asking", "undecided"] as const;
export type Outcome = typeof OUTCOMES[number];

/** Why a customer did not buy. `unknown` when they simply went quiet. */
export const LOST_REASONS = [
  "price",
  "delivery_fee",
  "delivery_time",
  "size_or_variant",
  "out_of_stock",
  "not_sold",
  "no_answer",
  "unknown",
] as const;
export type LostReason = typeof LOST_REASONS[number];

export const TOPICS = [
  "price",
  "availability",
  "size",
  "delivery",
  "photo",
  "offer",
  "location_hours",
  "payment",
  "other",
] as const;
export type Topic = typeof TOPICS[number];

export interface Reading {
  outcome: Outcome;
  reason: LostReason | null;
  /** Catalog names exactly as listed; anything else is dropped. */
  products: string[];
  /** A city or area the customer named, as they wrote it. */
  area: string | null;
  topics: Topic[];
  /** The line that decided the outcome, quoted from the conversation. */
  evidence: string;
}

/** One side of the conversation, oldest first. */
export interface Line {
  fromCustomer: boolean;
  text: string;
}

const INSTRUCTIONS = `You read a finished conversation between a shop and a customer on Instagram or Facebook Messenger, and say how it ended. The shop sells mainly in Jordan; customers write Jordanian or Levantine Arabic, sometimes in Latin letters, sometimes English. Nothing you write is sent to anyone.

Choose exactly one outcome:

- "ordered": the customer committed to buy. They confirmed the order, sent a delivery address or phone number to deliver to, or the shop confirmed the order was placed or sent. Asking the price, saying "nice", or asking about delivery is NOT ordering.
- "not_bought": the customer showed interest in buying something and it did not happen. Asking about a product at all — its price, whether it is available, its size, its quality, a photo of it — IS interest in buying, and so is asking whether the shop sells something. If no order followed, this is "not_bought": they declined, raised a problem that was not solved, went quiet after the shop answered, or ended politely with "thanks" or "lovely". Also this when they asked about buying and the shop never answered.
- "just_asking": nothing in the conversation was about buying a product — a greeting, where the shop is, opening hours, a complaint about an earlier order, something unrelated.
- "undecided": ONLY when the customer said in words that they will decide later — "I'll think about it", "I'll ask my husband", "I'll get back to you" — and nothing after that settled it. Going quiet is not this; going quiet is "not_bought".

When the outcome is "not_bought", give the reason, choosing the one that best explains it:
- "price": the price was too high for them, or they asked for a discount and did not get one they accepted.
- "delivery_fee": the delivery cost put them off.
- "delivery_time": delivery would take too long, or no delivery time could be given.
- "size_or_variant": the size, colour or kind they wanted is not available.
- "out_of_stock": the item is out of stock.
- "not_sold": the shop does not sell what they wanted.
- "no_answer": the shop never answered their question.
- "unknown": they went quiet and the conversation does not say why.
For any other outcome, the reason is null.

Also report:
- "products": every product the customer asked about, including ones they decided against, written EXACTLY as they appear in the catalog list below. Leave out anything that is not in the list. Empty when none.
- "area": a city, town or area the customer named for delivery or as where they are, written as they wrote it. Null when none.
- "topics": the kinds of question the customer asked, from the allowed list.
- "evidence": the one short line from the conversation, quoted exactly, that decided the outcome.

Judge only from what is written. Do not assume an order happened because the conversation was friendly.`;

const SCHEMA = {
  type: "object",
  properties: {
    outcome: { type: "string", enum: [...OUTCOMES] },
    reason: { anyOf: [{ type: "string", enum: [...LOST_REASONS] }, { type: "null" }] },
    products: { type: "array", items: { type: "string" } },
    area: { anyOf: [{ type: "string" }, { type: "null" }] },
    topics: { type: "array", items: { type: "string", enum: [...TOPICS] } },
    evidence: { type: "string" },
  },
  required: ["outcome", "reason", "products", "area", "topics", "evidence"],
  additionalProperties: false,
};

/** The conversation as one block to read, not as turns to continue. */
export function transcript(lines: Line[]): string {
  return lines
    .map((line) => line.text.trim() ? `${line.fromCustomer ? "Customer" : "Shop"}: ${line.text.trim()}` : null)
    .filter((line): line is string => line !== null)
    .join("\n");
}

export function buildOutcomeRequest(
  lines: Line[],
  catalog: string[],
  model = MODEL,
): Record<string, unknown> {
  const products = catalog.length > 0
    ? catalog.map((name) => `- ${name}`).join("\n")
    : "(the shop has listed no products)";

  return {
    model,
    max_tokens: 300,
    system: [
      // The instructions alone are under every model's cache minimum; marked
      // anyway, as in ai.ts, because below the minimum it is a free no-op.
      { type: "text", text: INSTRUCTIONS, cache_control: { type: "ephemeral", ttl: "1h" } },
      { type: "text", text: `The shop's catalog:\n${products}` },
    ],
    messages: [{ role: "user", content: `The conversation:\n\n${transcript(lines)}` }],
    output_config: { format: { type: "json_schema", schema: SCHEMA } },
    // Explicit, because the default on Sonnet 5 is adaptive thinking — the
    // same trap ai.ts documents for the reply path.
    thinking: { type: "disabled" },
  };
}

/**
 * What the model said, narrowed to what we can store, or null when it said
 * nothing usable. Products not in the catalog are dropped rather than trusted:
 * a name the shop never wrote is not a product the seller can act on.
 */
export function readOutcome(body: unknown, catalog: string[]): Reading | null {
  const blocks = (body as { content?: unknown })?.content;
  const first = Array.isArray(blocks)
    ? blocks.find((b) => (b as { type?: unknown })?.type === "text") as { text?: unknown } | undefined
    : undefined;
  if (typeof first?.text !== "string") return null;

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(first.text);
  } catch {
    return null;
  }

  const outcome = parsed.outcome as Outcome;
  if (!OUTCOMES.includes(outcome)) return null;

  const reason = outcome === "not_bought" && LOST_REASONS.includes(parsed.reason as LostReason)
    ? parsed.reason as LostReason
    : outcome === "not_bought" ? "unknown" : null;

  const known = new Set(catalog);
  const products = Array.isArray(parsed.products)
    ? [...new Set(parsed.products.filter((p): p is string => typeof p === "string" && known.has(p)))]
    : [];

  const topics = Array.isArray(parsed.topics)
    ? [...new Set(parsed.topics.filter((t): t is Topic => TOPICS.includes(t as Topic)))]
    : [];

  const area = typeof parsed.area === "string" && parsed.area.trim() ? parsed.area.trim() : null;
  const evidence = typeof parsed.evidence === "string" ? parsed.evidence.trim() : "";

  return { outcome, reason, products, area, topics, evidence };
}

export type ReadOutcome =
  | { status: "read"; reading: Reading; usage: Usage }
  | { status: "failed"; detail: string };

/** Asks the model, without ever throwing. A failure leaves the row unmarked. */
export async function askOutcome(
  apiKey: string,
  lines: Line[],
  catalog: string[],
  options: { fetcher?: typeof fetch; workspaceId?: string; model?: string } = {},
): Promise<ReadOutcome> {
  const fetcher = options.fetcher ?? fetch;
  let response: Response;
  try {
    response = await fetcher(ANTHROPIC_URL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        ...(options.workspaceId ? { "anthropic-workspace-id": options.workspaceId } : {}),
      },
      body: JSON.stringify(buildOutcomeRequest(lines, catalog, options.model)),
    });
  } catch (error) {
    return { status: "failed", detail: `unreachable: ${error}` };
  }

  if (!response.ok) return { status: "failed", detail: `http ${response.status}` };

  let body: unknown;
  try {
    body = await response.json();
  } catch {
    return { status: "failed", detail: "unparseable" };
  }

  const reading = readOutcome(body, catalog);
  return reading
    ? { status: "read", reading, usage: readUsage(body) }
    : { status: "failed", detail: "unusable" };
}
