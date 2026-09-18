// Who may create an account on the platform.
//
// Public sign-up is off, so this check is the only door. Getting it wrong does
// not break a screen — it lets any signed-in seller mint accounts — which is
// why the flag is tested against every shape it could plausibly arrive in.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import {
  ADMIN_FLAG,
  checkEmail,
  isAdmin,
  readInviteError,
} from "../functions/admin-invite/admin.ts";

test("an admin is one we marked as one", () => {
  assert.equal(isAdmin({ app_metadata: { [ADMIN_FLAG]: true } }), true);
});

test("an ordinary seller is not an admin", () => {
  // The shape GoTrue gives every account: provider details and nothing else.
  assert.equal(
    isAdmin({ app_metadata: { provider: "email", providers: ["email"] } }),
    false,
  );
});

test("nobody is an admin by default", () => {
  for (const nobody of [null, undefined, {}, { app_metadata: null }, { app_metadata: {} }]) {
    assert.equal(isAdmin(nobody), false, `admitted ${JSON.stringify(nobody)}`);
  }
});

test("only the boolean true opens the door", () => {
  // "false" is a truthy string, and 1 is a truthy number. A loose check here
  // would be the whole of the vulnerability.
  for (const notTrue of ["true", "false", 1, 0, "1", {}, [], "yes", "admin"]) {
    assert.equal(
      isAdmin({ app_metadata: { [ADMIN_FLAG]: notTrue } }),
      false,
      `admitted ${JSON.stringify(notTrue)}`,
    );
  }
});

test("the flag is not GoTrue's own role field", () => {
  // Every signed-in account carries role "authenticated". Reading authority
  // from that field would make every seller an admin.
  assert.equal(isAdmin({ app_metadata: { role: "authenticated" } }), false);
  assert.equal(isAdmin({ app_metadata: { role: "admin" } }), false);
  assert.notEqual(ADMIN_FLAG, "role");
});

test("the flag lives where a user cannot write to it", () => {
  // user_metadata is writable by the account it belongs to. A seller could
  // set it on themselves, so it must never be what is read.
  const sellerWhoTried = {
    app_metadata: { provider: "email" },
    user_metadata: { [ADMIN_FLAG]: true },
  } as { app_metadata: Record<string, unknown> };

  assert.equal(isAdmin(sellerWhoTried), false);
});

// ---------------------------------------------------------------------------
// The address being invited
// ---------------------------------------------------------------------------

test("a plausible address is accepted", () => {
  for (const email of [
    "them@example.com",
    "first.last@shop.co.uk",
    "seller+rabta@gmail.com",
    "someone@rabta.local",
  ]) {
    assert.equal(checkEmail(email), null, `refused ${email}`);
  }
});

test("an empty address is refused before anything is created", () => {
  for (const nothing of [null, undefined, "", "   "]) {
    assert.equal(checkEmail(nothing), "empty_email");
  }
});

test("something that is not an address is refused", () => {
  for (const bad of ["them", "them@", "@example.com", "them@example", "a b@c.com"]) {
    assert.equal(checkEmail(bad), "invalid_email", `accepted ${bad}`);
  }
});

// ---------------------------------------------------------------------------
// What GoTrue said
// ---------------------------------------------------------------------------

test("an address that already has an account says so", () => {
  // Different from a failure: whoever is inviting needs to know the account
  // exists, not that something went wrong.
  assert.equal(
    readInviteError(422, { error_code: "email_exists", msg: "Email address already registered" }),
    "already_exists",
  );
});

test("anything else is a plain failure", () => {
  assert.equal(readInviteError(500, { msg: "internal error" }), "failed");
  assert.equal(readInviteError(400, null), "failed");
  assert.equal(readInviteError(429, { msg: "rate limit exceeded" }), "failed");
});
