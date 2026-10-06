// Turning a raw Meta webhook payload into messages we can store.
//
// A single request can carry several entries, each with several events, and
// most of them are not messages at all. Anything unrecognised is skipped
// rather than thrown, so one unexpected event cannot cost us the rest of the
// batch — the raw payload is already stored and can be examined later.
//
// Free of Deno-specific APIs so the same code runs under test.

export type Platform = "instagram" | "messenger" | "whatsapp";
export type Direction = "inbound" | "outbound";

export interface NormalisedMessage {
  /** Meta's id for the Page or Instagram account that received the message. */
  accountExternalId: string;
  platform: Platform;
  /** Meta's id for the customer, scoped to the account above. On WhatsApp, their phone number. */
  customerExternalId: string;
  /** WhatsApp only: the name the customer gave WhatsApp. It has no profile API to ask. */
  customerName?: string;
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

  if (platform === "whatsapp") {
    for (const entry of entries) parseWhatsAppEntry(entry, messages, skipped);
    return { messages, skipped };
  }

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
  if (object === "whatsapp_business_account") return "whatsapp";
  return null;
}

// WhatsApp's media types, in the vocabulary Messenger attachments already use,
// so everything downstream of the parser reads them unchanged.
const WHATSAPP_MEDIA: Record<string, string> = {
  image: "image",
  sticker: "image",
  video: "video",
  audio: "audio",
  document: "file",
};

// Not messages a seller needs to see or answer.
const WHATSAPP_IGNORED = new Set(["reaction", "unsupported", "system", "request_welcome"]);

/**
 * One WhatsApp entry. Messages sit in entry.changes[].value; the account is the
 * phone number id in value.metadata, not entry.id (that is the WhatsApp
 * Business Account, which can hold several numbers). Customer messages arrive
 * under `messages`; with Coexistence, replies the seller sends from the
 * WhatsApp Business app arrive under `message_echoes`.
 */
function parseWhatsAppEntry(
  rawEntry: unknown,
  messages: NormalisedMessage[],
  skipped: string[],
): void {
  const entry = asRecord(rawEntry);
  const changes = entry && Array.isArray(entry.changes) ? entry.changes : [];

  for (const rawChange of changes) {
    const value = asRecord(asRecord(rawChange)?.value);
    const accountExternalId = asString(asRecord(value?.metadata)?.phone_number_id);
    if (!value || !accountExternalId) {
      skipped.push("whatsapp change had no phone number id");
      continue;
    }

    const names = new Map<string, string>();
    for (const contact of Array.isArray(value.contacts) ? value.contacts : []) {
      const record = asRecord(contact);
      const waId = asString(record?.wa_id);
      const name = asString(asRecord(record?.profile)?.name);
      if (waId && name) names.set(waId, name);
    }

    if (Array.isArray(value.statuses) && value.statuses.length > 0) {
      skipped.push(`${value.statuses.length} whatsapp status update(s)`);
    }

    const inbound = Array.isArray(value.messages) ? value.messages : [];
    const echoes = Array.isArray(value.message_echoes) ? value.message_echoes : [];

    for (const [list, direction] of [[inbound, "inbound"], [echoes, "outbound"]] as const) {
      for (const raw of list) {
        const message = asRecord(raw);
        const mid = asString(message?.id);
        if (!message || !mid) {
          skipped.push("whatsapp message had no id");
          continue;
        }

        const type = asString(message.type) ?? "unknown";
        if (WHATSAPP_IGNORED.has(type)) {
          skipped.push(`whatsapp ${type} ${mid}`);
          continue;
        }

        const customerExternalId = asString(direction === "inbound" ? message.from : message.to);
        if (!customerExternalId) {
          skipped.push(`message ${mid} had no identifiable customer`);
          continue;
        }

        // WhatsApp sends seconds; Messenger sends milliseconds.
        const seconds = Number(message.timestamp);
        const sentAt = toIsoTimestamp(Number.isFinite(seconds) ? seconds * 1000 : NaN);
        if (!sentAt) {
          skipped.push(`message ${mid} had no usable timestamp`);
          continue;
        }

        const body = asRecord(message[type]);
        let text: string | null = null;
        const attachments: unknown[] = [];

        if (type === "text") {
          text = asString(body?.body);
        } else if (WHATSAPP_MEDIA[type]) {
          text = asString(body?.caption);
          // A media id, not a URL: fetching it needs the account's token, so
          // it is resolved after parsing, where the token is.
          attachments.push({
            type: WHATSAPP_MEDIA[type],
            payload: { media_id: asString(body?.id), mime_type: asString(body?.mime_type) },
          });
        } else {
          // location, contacts, buttons: stored, shown as something the seller
          // should open on their phone.
          attachments.push({ type });
        }

        const name = direction === "inbound" ? names.get(customerExternalId) : undefined;

        messages.push({
          accountExternalId,
          platform: "whatsapp",
          customerExternalId,
          ...(name ? { customerName: name } : {}),
          mid,
          direction,
          text,
          attachments,
          sentAt,
        });
      }
    }
  }
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
