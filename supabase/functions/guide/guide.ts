// Reading the seller's guide for the assistant into steps.
//
// The seller writes, in plain words, how they want conversations run: "always
// ask which size first", "anyone who complains comes to me". The model reads
// that once, when it is saved, into a short list of situations and what to do
// in each — drawn back to the seller as a diagram, so they can see it was
// understood before a customer finds out it was not.
//
// The seller's words stay the source. They fix a wrong reading by changing
// what they wrote, never by editing boxes: a flow editor is exactly the tool a
// non-technical seller cannot use.
//
// Pure apart from `askGuide`'s fetch, so every rule is testable without a
// network. See CLAUDE.md, "Anything the seller writes down".

import {
  ANTHROPIC_URL,
  type GuideSteps,
  MODEL,
  readUsage,
  type Usage,
} from "../meta-webhook/ai.ts";

/** The longest guide accepted; the column refuses more. */
export const GUIDE_LIMIT = 4000;

/** A diagram longer than this is not one a seller checks. */
const MAX_RULES = 12;
const MAX_ACTIONS = 6;
const MAX_CANNOT = 8;
const MAX_LABEL = 160;

const INSTRUCTIONS = `\
A shop owner has written how they want their shop's assistant to handle \
customer conversations on Instagram, Messenger and WhatsApp. Turn it into \
short steps. They will be drawn as a diagram for the owner to check that they \
were understood, and the assistant will follow them.

Write every label in the language the owner wrote in, in their own words and \
dialect where you can — Arabic if they wrote Arabic, English if they wrote \
English. Keep each label short: a few words, one line.

rules — one for each situation the owner describes, in their order.
- "when" is the situation, written so it reads after the word "When" (English) \
or "إذا" (Arabic): "the customer asks for a discount", "الزبون طلب خصم". Use \
null for what applies to every conversation: "always greet them", "never send \
more than two photos".
- "do" is what the assistant does in that situation, in order, one action per \
item. It may be empty when the only thing to do is hand over.
- "handover" is true when the owner wants that situation passed to them.
Do not add anything the owner did not write. Do not merge separate situations \
into one. Do not split one instruction into several rules.

cannot — what the owner asked for that the assistant has no way to do.
The assistant CAN: reply in the chat while the customer is writing; answer \
from what the shop has written in the app (products, prices, photos, offers, \
delivery, hours, locations, notes); ask the customer questions, including \
their name, area or phone; suggest products; send product photos; pass the \
conversation to the owner.
It CANNOT: phone anyone; take, send or check payments; create, change or track \
orders or deliveries; check stock beyond what the products say; message a \
customer first or follow up later after they stop replying; send voice notes; \
use terms of endearment such as حبيبتي, عزيزتي or "dear".
For each such request, "text" is what the owner asked for and "why" is a short \
reason, both in the owner's language. When part of a request is possible, put \
that part in rules and only the rest in cannot.

If nothing the owner wrote is guidance for the assistant, return empty lists.`;

const SCHEMA = {
  type: "object",
  properties: {
    rules: {
      type: "array",
      items: {
        type: "object",
        properties: {
          when: { anyOf: [{ type: "string" }, { type: "null" }] },
          do: { type: "array", items: { type: "string" } },
          handover: { type: "boolean" },
        },
        required: ["when", "do", "handover"],
        additionalProperties: false,
      },
    },
    cannot: {
      type: "array",
      items: {
        type: "object",
        properties: { text: { type: "string" }, why: { type: "string" } },
        required: ["text", "why"],
        additionalProperties: false,
      },
    },
  },
  required: ["rules", "cannot"],
  additionalProperties: false,
};

export function buildGuideRequest(guide: string, model = MODEL): Record<string, unknown> {
  return {
    model,
    max_tokens: 1500,
    system: [{ type: "text", text: INSTRUCTIONS }],
    messages: [{ role: "user", content: `What the owner wrote:\n\n${guide}` }],
    output_config: { format: { type: "json_schema", schema: SCHEMA } },
    // Explicit, because the default on Sonnet 5 is adaptive thinking — the
    // same trap ai.ts documents for the reply path.
    thinking: { type: "disabled" },
  };
}

function label(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const text = value.replace(/\s+/g, " ").trim();
  if (!text) return null;
  return text.length > MAX_LABEL ? `${text.slice(0, MAX_LABEL - 1)}…` : text;
}

/**
 * What the model said, narrowed to what can be drawn and stored, or null when
 * it said nothing usable. A rule that neither does anything nor hands over is
 * a box with no meaning, and is dropped.
 */
export function readGuide(body: unknown): GuideSteps | null {
  const blocks = (body as { content?: unknown })?.content;
  const first = Array.isArray(blocks)
    ? blocks.find((b) => (b as { type?: unknown })?.type === "text") as { text?: unknown } | undefined
    : undefined;
  if (typeof first?.text !== "string") return null;

  let parsed: { rules?: unknown; cannot?: unknown };
  try {
    parsed = JSON.parse(first.text);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== "object") return null;
  if (!Array.isArray(parsed.rules) || !Array.isArray(parsed.cannot)) return null;

  const rules: GuideSteps["rules"] = [];
  for (const raw of parsed.rules) {
    const rule = raw as { when?: unknown; do?: unknown; handover?: unknown } | null;
    if (!rule || typeof rule !== "object") continue;

    const actions = Array.isArray(rule.do)
      ? rule.do.map(label).filter((a): a is string => a !== null).slice(0, MAX_ACTIONS)
      : [];
    const handover = rule.handover === true;
    if (actions.length === 0 && !handover) continue;

    rules.push({ when: label(rule.when), do: actions, handover });
    if (rules.length === MAX_RULES) break;
  }

  const cannot: GuideSteps["cannot"] = [];
  for (const raw of parsed.cannot) {
    const item = raw as { text?: unknown; why?: unknown } | null;
    const text = label(item?.text);
    if (!text) continue;
    cannot.push({ text, why: label(item?.why) ?? "" });
    if (cannot.length === MAX_CANNOT) break;
  }

  return { rules, cannot };
}

export type GuideReading =
  | { status: "read"; steps: GuideSteps; usage: Usage }
  | { status: "failed"; detail: string };

/** Asks the model, without ever throwing. */
export async function askGuide(
  apiKey: string,
  guide: string,
  options: { fetcher?: typeof fetch; workspaceId?: string; model?: string } = {},
): Promise<GuideReading> {
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
      body: JSON.stringify(buildGuideRequest(guide, options.model)),
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

  const steps = readGuide(body);
  return steps
    ? { status: "read", steps, usage: readUsage(body) }
    : { status: "failed", detail: "unusable" };
}
