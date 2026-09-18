// Who is allowed to create a Rabta account, and for whom.
//
// This is the decision that lets someone into the product at all, so it is
// kept here on its own and tested rather than living inline in a handler. The
// failure mode is not subtle: getting it wrong lets any signed-in seller mint
// accounts on the platform.
//
// Deliberately free of Deno-specific APIs so the same code runs in Supabase
// Edge Functions and in the test harness.

/**
 * The flag that marks one of us, as opposed to a seller.
 *
 * It lives in `app_metadata`, which a user cannot change — `user_metadata` is
 * writable by the account it belongs to, so a seller could simply make
 * themselves an admin if this were kept there.
 *
 * `rabta_admin` rather than `role`, because GoTrue already puts `role` on the
 * user (every signed-in account is `authenticated`) and overloading it invites
 * exactly the kind of confusion this check cannot afford.
 */
export const ADMIN_FLAG = "rabta_admin";

export interface UserLike {
  app_metadata?: Record<string, unknown> | null;
}

/**
 * Whether this user may invite others.
 *
 * Strictly `true`, not merely truthy. A string, a number or an object left in
 * that field by some future migration must not open the door, and the string
 * "false" is truthy.
 */
export function isAdmin(user: UserLike | null | undefined): boolean {
  if (!user) return false;

  const metadata = user.app_metadata;
  if (!metadata || typeof metadata !== "object") return false;

  return metadata[ADMIN_FLAG] === true;
}

export type InviteRefusal =
  | "not_signed_in"
  | "not_admin"
  | "empty_email"
  | "invalid_email"
  | "already_exists"
  | "failed";

/**
 * Whether this is an address worth sending an invitation to.
 *
 * Deliberately shallow. The real test of an email address is whether the
 * invitation arrives, and a stricter pattern here would reject valid addresses
 * — which, for a product being handed to a paying customer, is the more
 * expensive mistake.
 */
export function checkEmail(email: string | null | undefined): InviteRefusal | null {
  if (!email || email.trim().length === 0) return "empty_email";

  const trimmed = email.trim();

  // One @, something either side, a dot in the domain, and no spaces.
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed) ? null : "invalid_email";
}

/** What Meta-style answer GoTrue gave back, as something the client can act on. */
export function readInviteError(status: number, body: unknown): InviteRefusal {
  const error = body as { error_code?: string; msg?: string; message?: string } | null;
  const text = `${error?.error_code ?? ""} ${error?.msg ?? error?.message ?? ""}`
    .toLowerCase();

  // An address that already has an account. Worth its own answer: the person
  // inviting needs to know the account exists rather than that something broke.
  if (
    status === 422 &&
    (text.includes("already") || text.includes("exists") || text.includes("registered"))
  ) {
    return "already_exists";
  }

  return "failed";
}
