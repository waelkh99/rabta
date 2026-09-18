// Who the customer is.
//
// Meta delivers a message with an opaque sender id and nothing else — no name,
// no picture. Both have to be asked for separately, per customer, with the
// account's own access token.
//
// Deliberately free of Deno-specific APIs so the same code runs in Supabase
// Edge Functions and in the test harness.

import type { Platform } from "./parse.ts";

const GRAPH = "https://graph.facebook.com/v26.0";

/**
 * How long a stored profile is trusted before Meta is asked again.
 *
 * Chosen from the picture, not the name. A profile picture URL measured on
 * 18 September 2026 expired about 30 days out, so refreshing at 25 days
 * replaces it before it breaks, while a conversation is still active. A
 * conversation nobody writes in goes stale and its picture eventually 404s,
 * which is the right trade: the interface falls back to the monogram, and
 * refreshing dormant conversations would mean a Graph call per customer per
 * month forever.
 */
export const PROFILE_REFRESH_DAYS = 25;

export interface CustomerProfile {
  name: string | null;
  avatarUrl: string | null;
}

/** Whether Meta should be asked who this customer is. */
export function profileIsStale(
  fetchedAt: string | null | undefined,
  now: Date,
): boolean {
  // Never asked.
  if (!fetchedAt) return true;

  const asked = new Date(fetchedAt);
  if (Number.isNaN(asked.getTime())) return true;

  const days = (now.getTime() - asked.getTime()) / 86_400_000;
  return days >= PROFILE_REFRESH_DAYS;
}

/**
 * Where to ask.
 *
 * Messenger and Instagram answer at the same endpoint with the same token, but
 * not for the same fields: `username` is an Instagram idea and asking a
 * Messenger id for it fails the whole call, because Graph rejects a request
 * naming a field it does not know rather than omitting it.
 */
export function profileRequest(
  platform: Platform,
  customerExternalId: string,
  accessToken: string,
): string {
  const fields = platform === "instagram"
    ? "name,username,profile_pic"
    : "name,profile_pic";

  return `${GRAPH}/${encodeURIComponent(customerExternalId)}` +
    `?fields=${fields}&access_token=${encodeURIComponent(accessToken)}`;
}

/**
 * What Meta said, or null if it said nothing usable.
 *
 * A customer whose name we cannot read is a normal outcome, not a failure:
 * Meta withholds it depending on the person's own settings and on what the app
 * has been approved for. That case returns a profile with null fields rather
 * than null, so that the attempt is still recorded and not repeated on every
 * message the customer sends.
 */
export function readProfile(body: unknown): CustomerProfile | null {
  const answer = body as {
    name?: unknown;
    username?: unknown;
    first_name?: unknown;
    last_name?: unknown;
    profile_pic?: unknown;
    error?: unknown;
  } | null;

  if (!answer || typeof answer !== "object") return null;

  // An error means we did not get an answer about this customer at all, which
  // is different from being told they have no name. Worth retrying later.
  if (answer.error) return null;

  return {
    name: pickName(answer),
    avatarUrl: text(answer.profile_pic),
  };
}

function pickName(answer: {
  name?: unknown;
  username?: unknown;
  first_name?: unknown;
  last_name?: unknown;
}): string | null {
  // `name` on Messenger, `username` on Instagram where a person may have no
  // display name at all. The two halves are the fallback for an account that
  // returns them without a joined `name`.
  const joined = [text(answer.first_name), text(answer.last_name)]
    .filter((part) => part !== null)
    .join(" ")
    .trim();

  return text(answer.name) ?? text(answer.username) ?? (joined || null);
}

/** A non-empty string, or null. Meta sends "" as readily as it omits a field. */
function text(value: unknown): string | null {
  if (typeof value !== "string") return null;

  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}
