// The OAuth state parameter, and where the callback is allowed to send a
// browser afterwards.
//
// This is the one endpoint in the system that handles an access token and then
// performs a redirect, so the tests that matter here are the ones that try to
// make it redirect somewhere it should not.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { hmacSha256Hex } from "../functions/meta-webhook/signature.ts";
import { APP_ORIGINS } from "../functions/_shared/origins.ts";
import {
  isWorkspaceId,
  readState,
  returnOriginIndex,
  signState,
} from "../functions/meta-oauth/state.ts";

const SECRET = "test-app-secret";
const WORKSPACE = "0c839c31-4a49-485b-a9f9-b2e4af479b8b";

/** Signs an arbitrary state body the way the real one is signed. */
async function forge(body: string, secret = SECRET): Promise<string> {
  return `${body}.${await hmacSha256Hex(secret, body)}`;
}

test("a state we issued reads back as the workspace and origin it was issued for", async () => {
  const state = await signState(SECRET, WORKSPACE, 0);

  assert.deepEqual(await readState(SECRET, state), {
    workspaceId: WORKSPACE,
    returnOrigin: APP_ORIGINS[0],
  });
});

test("two flows started at once do not produce the same state", async () => {
  // The nonce is what makes them different. Without it, a state is a pure
  // function of the workspace and would be guessable from one leaked link.
  const first = await signState(SECRET, WORKSPACE, 0);
  const second = await signState(SECRET, WORKSPACE, 0);

  assert.notEqual(first, second);
});

test("a state altered by one character is rejected", async () => {
  const state = await signState(SECRET, WORKSPACE, 0);
  const tampered = state.slice(0, -1) + (state.endsWith("a") ? "b" : "a");

  assert.equal(await readState(SECRET, tampered), null);
});

test("a state pointing at another workspace is rejected", async () => {
  // Changing the workspace is the whole point of forging one: it would attach
  // someone else's Meta account to your own inbox.
  const state = await signState(SECRET, WORKSPACE, 0);
  const [, index, nonce, signature] = state.split(".");
  const swapped = ["11111111-2222-3333-4444-555555555555", index, nonce, signature]
    .join(".");

  assert.equal(await readState(SECRET, swapped), null);
});

test("a state signed with a different secret is rejected", async () => {
  const forged = await forge(`${WORKSPACE}.0.nonce`, "attacker-guess");

  assert.equal(await readState(SECRET, forged), null);
});

test("a malformed state is rejected rather than throwing", async () => {
  for (const bad of [null, undefined, "", "...", "a.b", WORKSPACE, "a.b.c.d.e"]) {
    assert.equal(await readState(SECRET, bad), null, `accepted ${bad}`);
  }
});

test("state cannot be read when no app secret is configured", async () => {
  // A misconfigured deployment must fail closed, the same way the webhook
  // signature check does. Failing open here would accept any state at all.
  const state = await signState(SECRET, WORKSPACE, 0);

  assert.equal(await readState("", state), null);
});

// ---------------------------------------------------------------------------
// The open redirect, which is the reason any of this is signed
// ---------------------------------------------------------------------------

test("an origin that is not on the list cannot be requested", async () => {
  for (const hostile of [
    "https://rabta.example.evil",
    "http://localhost:5353.evil.com",
    "http://localhost:5354",
    "HTTP://LOCALHOST:5353",
    "http://localhost:5353/",
    "//evil.example",
    "javascript:alert(1)",
  ]) {
    assert.equal(returnOriginIndex(hostile), null, `accepted ${hostile}`);
  }
});

test("naming no origin falls back to the first on the list", () => {
  assert.equal(returnOriginIndex(null), 0);
  assert.equal(returnOriginIndex(undefined), 0);
  assert.equal(returnOriginIndex(""), 0);
});

test("an origin on the list is accepted and round-trips", async () => {
  for (const [expected, origin] of APP_ORIGINS.entries()) {
    const index = returnOriginIndex(origin);
    assert.equal(index, expected);

    const issued = await readState(SECRET, await signState(SECRET, WORKSPACE, index!));
    assert.equal(issued?.returnOrigin, origin);
  }
});

test("a signed state carrying an origin rather than an index resolves to nothing", async () => {
  // The state holds an index into the allowlist, so there is no way to write an
  // origin into it at all. This is the property the whole design rests on: even
  // an attacker holding the app secret cannot name a destination, because the
  // destination is looked up rather than read.
  const forged = await forge(`${WORKSPACE}.https://evil.example.nonce`);

  assert.equal(await readState(SECRET, forged), null);
});

test("an index off the end of the list resolves to nothing", async () => {
  // Shortening the allowlist must strand old states rather than silently
  // resolving them to whatever now sits at that position.
  for (const index of ["99", "-1", "1.5", "", " 0", "0x0", "NaN", "Infinity"]) {
    const forged = await forge(`${WORKSPACE}.${index}.nonce`);
    assert.equal(await readState(SECRET, forged), null, `resolved index ${index}`);
  }
});

test("every origin readState can return is on the allowlist", async () => {
  // The guarantee stated as itself, so that a future change returning an origin
  // from somewhere else fails here.
  for (let index = -2; index < APP_ORIGINS.length + 2; index++) {
    const issued = await readState(SECRET, await forge(`${WORKSPACE}.${index}.nonce`));
    if (issued) assert.ok(APP_ORIGINS.includes(issued.returnOrigin));
  }
});

// ---------------------------------------------------------------------------
// The workspace, which arrives on a public endpoint
// ---------------------------------------------------------------------------

test("a workspace id is a uuid and nothing else", () => {
  assert.equal(isWorkspaceId(WORKSPACE), true);
  assert.equal(isWorkspaceId(WORKSPACE.toUpperCase()), true);

  for (const bad of [
    null,
    undefined,
    "",
    "not-a-uuid",
    // A dot would split the state into more parts than it has fields, which is
    // how a loosely validated workspace turns into a forged one.
    `${WORKSPACE}.0.nonce`,
    `${WORKSPACE} `,
    `${WORKSPACE}x`,
  ]) {
    assert.equal(isWorkspaceId(bad), false, `accepted ${bad}`);
  }
});
