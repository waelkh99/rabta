import { strict as assert } from "node:assert";
import { test } from "node:test";

import {
  hmacSha256Hex,
  verifyMetaSignature,
} from "../functions/meta-webhook/signature.ts";

const SECRET = "test-app-secret";
const BODY = JSON.stringify({ object: "page", entry: [] });

async function sign(body: string, secret = SECRET): Promise<string> {
  return `sha256=${await hmacSha256Hex(secret, body)}`;
}

test("accepts a correctly signed body", async () => {
  assert.equal(await verifyMetaSignature(BODY, await sign(BODY), SECRET), true);
});

test("rejects a body that has been altered in transit", async () => {
  const signature = await sign(BODY);
  const tampered = JSON.stringify({ object: "page", entry: [{ id: "injected" }] });

  assert.equal(await verifyMetaSignature(tampered, signature, SECRET), false);
});

test("rejects a signature made with a different secret", async () => {
  const forged = await sign(BODY, "attacker-guess");

  assert.equal(await verifyMetaSignature(BODY, forged, SECRET), false);
});

test("rejects a missing signature header", async () => {
  assert.equal(await verifyMetaSignature(BODY, null, SECRET), false);
  assert.equal(await verifyMetaSignature(BODY, undefined, SECRET), false);
  assert.equal(await verifyMetaSignature(BODY, "", SECRET), false);
});

test("rejects a signature without the sha256 prefix", async () => {
  const bare = await hmacSha256Hex(SECRET, BODY);

  assert.equal(await verifyMetaSignature(BODY, bare, SECRET), false);
});

test("rejects everything when the app secret is not configured", async () => {
  // A misconfigured deployment must fail closed. Failing open would leave the
  // endpoint accepting anything.
  assert.equal(await verifyMetaSignature(BODY, await sign(BODY), ""), false);
});

test("signature covers the exact bytes, not the parsed value", async () => {
  // Re-serialised JSON with identical meaning but different bytes must fail.
  // This is the mistake that makes verification silently useless.
  const original = '{"object":"page","entry":[]}';
  const reserialised = JSON.stringify(JSON.parse(original), null, 2);
  const signature = await sign(original);

  assert.equal(await verifyMetaSignature(original, signature, SECRET), true);
  assert.equal(await verifyMetaSignature(reserialised, signature, SECRET), false);
});
