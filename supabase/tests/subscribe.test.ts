import { strict as assert } from "node:assert";
import { test } from "node:test";

import { notSubscribedPage, subscribePage } from "../functions/meta-oauth/subscribe.ts";

// Meta's answer on production, 16 November 2026, fbtrace id dropped.
const TRANSIENT = {
  error: {
    message: "An unexpected error has occurred. Please retry your request later.",
    type: "OAuthException",
    is_transient: true,
    code: 2,
  },
};
const PERMANENT = {
  error: { message: "(#200) Permissions error", type: "OAuthException", code: 200 },
};

/** A stand-in for Meta that gives the answers in order and counts the calls. */
function meta(...answers: unknown[]) {
  const calls: string[] = [];
  const post = (url: string) => {
    calls.push(url);
    const answer = answers[Math.min(calls.length - 1, answers.length - 1)];
    return answer instanceof Error ? Promise.reject(answer) : Promise.resolve(answer);
  };
  return { post, calls };
}
const noWait = () => Promise.resolve();

test("a subscription Meta accepts is done in one call", async () => {
  const { post, calls } = meta({ success: true });
  assert.deepEqual(await subscribePage(post, "u", noWait), { ok: true });
  assert.equal(calls.length, 1);
});

test("a transient failure is tried again, and the second answer counts", async () => {
  const { post, calls } = meta(TRANSIENT, { success: true });
  assert.deepEqual(await subscribePage(post, "u", noWait), { ok: true });
  assert.deepEqual(calls, ["u", "u"]);
});

test("a transient failure twice is a failure, carrying Meta's answer", async () => {
  const { post, calls } = meta(TRANSIENT, TRANSIENT);
  assert.deepEqual(await subscribePage(post, "u", noWait), { ok: false, answer: TRANSIENT });
  assert.equal(calls.length, 2);
});

test("a permanent failure is not retried", async () => {
  const { post, calls } = meta(PERMANENT, { success: true });
  assert.deepEqual(await subscribePage(post, "u", noWait), { ok: false, answer: PERMANENT });
  assert.equal(calls.length, 1);
});

test("code 2 without the flag still counts as transient", async () => {
  const { post } = meta({ error: { code: 2 } }, { success: true });
  assert.deepEqual(await subscribePage(post, "u", noWait), { ok: true });
});

test("a network failure is a failure, not a crash, and is not retried", async () => {
  const { post, calls } = meta(new Error("connection reset"));
  const result = await subscribePage(post, "u", noWait);
  assert.equal(result.ok, false);
  assert.equal(calls.length, 1);
});

test("anything but success: true is not success", async () => {
  for (const answer of [{}, null, { success: false }, { success: "true" }]) {
    const { post } = meta(answer);
    assert.equal((await subscribePage(post, "u", noWait)).ok, false, JSON.stringify(answer));
  }
});

test("the retry waits before asking again", async () => {
  const waited: number[] = [];
  const { post } = meta(TRANSIENT, { success: true });
  await subscribePage(post, "u", (ms) => (waited.push(ms), Promise.resolve()));
  assert.equal(waited.length, 1);
  assert.ok(waited[0] >= 1000, `waited ${waited[0]}ms`);
});

test("the seller is told in both languages to press Connect again, with a way back", () => {
  const page = notSubscribedPage("https://inboxara.app");
  assert.match(page, /<section dir="rtl" lang="ar">[\s\S]*الربط مع ميتا/);
  assert.match(page, /<section dir="ltr" lang="en">[\s\S]*Connect with Meta/);
  assert.match(page, /class="button" href="https:\/\/inboxara\.app\/">العودة إلى إنبوكسارا/);
  assert.match(page, /class="button" href="https:\/\/inboxara\.app\/">Back to Inboxara/);
});

test("the way back cannot break out of its attribute", () => {
  const page = notSubscribedPage(`https://x"><script>alert(1)</script>`);
  assert.doesNotMatch(page, /<script>/);
});
