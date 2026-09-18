// Which origins the application is served from, and what the browser is told.
//
// A missing header here is invisible to every test that uses curl, because
// curl does not enforce CORS. The first run in a real browser had the reply
// sent and refused correctly and the seller shown neither.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { APP_ORIGINS, corsHeaders } from "../functions/_shared/origins.ts";

test("the page's own origin is allowed to read the answer", () => {
  for (const origin of APP_ORIGINS) {
    const headers = corsHeaders(origin);

    assert.equal(headers["access-control-allow-origin"], origin);
    assert.match(headers["access-control-allow-headers"], /authorization/);
    assert.match(headers["access-control-allow-methods"], /POST/);
  }
});

test("the preflight allows the headers supabase-js actually sends", () => {
  // Leave one out and the browser blocks the request before it is made, which
  // looks like the function being broken rather than the preflight.
  const allowed = corsHeaders(APP_ORIGINS[0])["access-control-allow-headers"];

  for (const header of ["authorization", "content-type", "apikey", "x-client-info"]) {
    assert.ok(allowed.includes(header), `${header} is not allowed`);
  }
});

test("an origin we do not serve is told nothing", () => {
  // Returning no headers is the safe failure: the browser then refuses to hand
  // the response to a page we have never heard of.
  for (const hostile of [
    "https://evil.example",
    "http://localhost:5354",
    "http://localhost:5353.evil.com",
    "null",
    "",
    null,
    undefined,
  ]) {
    assert.deepEqual(corsHeaders(hostile), {}, `answered ${hostile}`);
  }
});

test("the answer varies by origin, so a cache cannot cross them", () => {
  assert.equal(corsHeaders(APP_ORIGINS[0])["vary"], "Origin");
});

test("no origin is allowed with a wildcard", () => {
  // A wildcard would let any page on the internet call this with a seller's
  // token if it ever got hold of one.
  for (const origin of APP_ORIGINS) {
    assert.notEqual(corsHeaders(origin)["access-control-allow-origin"], "*");
  }
});
