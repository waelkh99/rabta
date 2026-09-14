// Turning a raw Meta webhook payload into messages we can store.
//
// A single request can carry several entries, each with several events, and
// most of them are not messages at all. Anything unrecognised is skipped
// rather than thrown, so one unexpected event cannot cost us the rest of the
// batch — the raw payload is already stored and can be examined later.
//
// Free of Deno-specific APIs so the same code runs under test.

export type Platform = "instagram" | "messenger";
export type Direction = "inbound" | "outbound";

export interface NormalisedMessage {
  /** Meta's id for the Page or Instagram account that received the message. */
  accountExternalId: string;
  platform: Platform;
  /** Meta's id for the customer, scoped to the account above. */
  customerExternalId: string;
  /** Meta's message id. Unique, and what makes redelivery harmless. */
  mid: string;
  direction: Direction;
  text: string | null;
  attachments: unknown[];
  /** ISO 8601. Meta sends milliseconds since the epoch. */
  sentAt: string;
}

export interface ParseResult {
  messages: NormalisedMessage[];
  /** Events understood but deliberately not stored, with the reason. */
  skipped: string[];
}

export function parseWebhookPayload(payload: unknown): ParseResult {
  const messages: NormalisedMessage[] = [];
  const skipped: string[] = [];

  const body = asRecord(payload);
  if (!body) return { messages, skipped: ["payload was not an object"] };

  const platform = platformFor(body.object);
  if (!platform) {
    return { messages, skipped: [`unsupported object type: ${String(body.object)}`] };
  }

  const entries = Array.isArray(body.entry) ? body.entry : [];
  if (entries.length === 0) skipped.push("payload contained no entries");

  for (const rawEntry of entries) {
    const entry = asRecord(rawEntry);
    if (!entry) {
      skipped.push("entry was not an object");
      continue;
    }

    // entry.id is the Page or Instagram account id. It is the dependable way
    // to identify the account: sender and recipient swap places depending on
    // who sent the message.
    const accountExternalId = asString(entry.id);
    if (!accountExternalId) {
      skipped.push("entry had no account id");
      continue;
    }

    const events = Array.isArray(entry.messaging) ? entry.messaging : [];

    for (const rawEvent of events) {
      const event = asRecord(rawEvent);
      if (!event) {
        skipped.push("event was not an object");
        continue;
      }

      const message = asRecord(event.message);
      if (!message) {
        // Delivery receipts, read receipts, reactions, postbacks. Expected and
        // ignored for now.
        skipped.push(`event carried no message: ${Object.keys(event).join(", ")}`);
        continue;
      }

      const mid = asString(message.mid);
      if (!mid) {
        skipped.push("message had no mid");
        continue;
      }

      if (message.is_deleted === true) {
        skipped.push(`message ${mid} was deleted`);
        continue;
      }

      // An echo is a message the seller sent, including one sent from Meta's
      // own apps rather than from Rabta. Handling these is what keeps the
      // inbox correct when the seller works outside the application.
      const isEcho = message.is_echo === true;
      const direction: Direction = isEcho ? "outbound" : "inbound";

      const sender = asRecord(event.sender);
      const recipient = asRecord(event.recipient);

      // On an inbound message the customer is the sender; on an echo the
      // account is the sender and the customer is the recipient.
      const customerExternalId = isEcho
        ? asString(recipient?.id)
        : asString(sender?.id);

      if (!customerExternalId) {
        skipped.push(`message ${mid} had no identifiable customer`);
        continue;
      }

      const sentAt = toIsoTimestamp(event.timestamp);
      if (!sentAt) {
        skipped.push(`message ${mid} had no usable timestamp`);
        continue;
      }

      messages.push({
        accountExternalId,
        platform,
        customerExternalId,
        mid,
        direction,
        text: asString(message.text) ?? null,
        attachments: Array.isArray(message.attachments) ? message.attachments : [],
        sentAt,
      });
    }
  }

  return { messages, skipped };
}

function platformFor(object: unknown): Platform | null {
  if (object === "page") return "messenger";
  if (object === "instagram") return "instagram";
  return null;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function asString(value: unknown): string | null {
  if (typeof value === "string" && value.length > 0) return value;
  // Meta sends ids as strings, but a numeric id in a payload should not cost
  // us the message.
  if (typeof value === "number" && Number.isFinite(value)) return String(value);
  return null;
}

function toIsoTimestamp(value: unknown): string | null {
  const ms = typeof value === "number"
    ? value
    : typeof value === "string" && value.trim() !== ""
    ? Number(value)
    : NaN;

  if (!Number.isFinite(ms) || ms <= 0) return null;

  const date = new Date(ms);
  if (Number.isNaN(date.getTime())) return null;

  return date.toISOString();
}
