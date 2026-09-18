// Tying the connection flow back to the seller, and back to the application.
//
// The state parameter carries two things through Meta and home again:
//
//   - which workspace the browser that started the flow belongs to
//   - where that browser is sent once the account is connected
//
// Signing it with the app secret means no table and no cleanup job: a forged
// state cannot be produced without the secret, and a replayed one can only ever
// reach the workspace it was issued for.
//
// Deliberately free of Deno-specific APIs so the same code runs in Supabase
// Edge Functions and in the test harness.

import { hmacSha256Hex, timingSafeEqual } from "../meta-webhook/signature.ts";
import { APP_ORIGINS } from "../_shared/origins.ts";

/**
 * The index to record for a requested return origin, or null if it is not one
 * we are willing to send a seller to.
 *
 * Checked here, at the start of the flow, so a rejected origin never reaches
 * the point of being signed.
 */
export function returnOriginIndex(requested: string | null | undefined): number | null {
  if (!requested) return 0;

  const index = APP_ORIGINS.indexOf(requested);
  return index < 0 ? null : index;
}

/** A workspace id is a uuid and nothing else. It is also a trust boundary. */
export function isWorkspaceId(value: string | null | undefined): boolean {
  return !!value &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
}

export async function signState(
  appSecret: string,
  workspaceId: string,
  originIndex: number,
): Promise<string> {
  const body = `${workspaceId}.${originIndex}.${crypto.randomUUID()}`;
  return `${body}.${await hmacSha256Hex(appSecret, body)}`;
}

/**
 * The workspace and the resolved return origin, or null if the state is not
 * one we issued.
 *
 * Returns the origin itself rather than the index, so that a caller cannot
 * reach a destination without having come through this check.
 */
export async function readState(
  appSecret: string,
  state: string | null | undefined,
): Promise<{ workspaceId: string; returnOrigin: string } | null> {
  if (!state || !appSecret) return null;

  const parts = state.split(".");
  if (parts.length !== 4) return null;

  const [workspaceId, index, nonce, signature] = parts;
  const expected = await hmacSha256Hex(appSecret, `${workspaceId}.${index}.${nonce}`);

  if (!timingSafeEqual(signature, expected)) return null;

  // Past the signature, the index is a value we wrote ourselves. It is still
  // parsed strictly and bounds-checked: an index that has fallen off the end of
  // a shortened list must fail rather than resolve to whatever now sits at that
  // position, and Number() is too forgiving to be asked — Number("") is 0, so
  // an empty field would quietly become the first origin on the list.
  if (!/^\d+$/.test(index)) return null;

  const returnOrigin = APP_ORIGINS[Number(index)];
  if (returnOrigin === undefined) return null;

  return { workspaceId, returnOrigin };
}
