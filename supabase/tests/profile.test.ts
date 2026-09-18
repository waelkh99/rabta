// Who the customer is.
//
// Meta sends an opaque id and nothing else, so without this every row in the
// inbox reads "Customer" and the list the product is built around cannot be
// scanned. The cases that matter are the ones where Meta answers with less
// than we hoped.

import { strict as assert } from "node:assert";
import { test } from "node:test";

import {
  PROFILE_REFRESH_DAYS,
  profileIsStale,
  profileRequest,
  readProfile,
} from "../functions/meta-webhook/profile.ts";

const NOW = new Date("2026-09-18T12:00:00.000Z");
const daysAgo = (days: number) =>
  new Date(NOW.getTime() - days * 86_400_000).toISOString();

// ---------------------------------------------------------------------------
// When to ask
// ---------------------------------------------------------------------------

test("a customer we have never asked about is asked about", () => {
  assert.equal(profileIsStale(null, NOW), true);
  assert.equal(profileIsStale(undefined, NOW), true);
  assert.equal(profileIsStale("", NOW), true);
});

test("a profile fetched recently is not asked for again", () => {
  // Otherwise every message from a chatty customer costs a Graph call.
  assert.equal(profileIsStale(daysAgo(0), NOW), false);
  assert.equal(profileIsStale(daysAgo(1), NOW), false);
  assert.equal(profileIsStale(daysAgo(PROFILE_REFRESH_DAYS - 1), NOW), false);
});

test("a profile is refreshed before its picture URL expires", () => {
  // The URL measured on 18 September lasted about 30 days. Refreshing at 25
  // replaces it while the conversation is still active rather than after the
  // picture has already broken.
  assert.ok(PROFILE_REFRESH_DAYS < 30, "refresh must beat the 30 day expiry");

  assert.equal(profileIsStale(daysAgo(PROFILE_REFRESH_DAYS), NOW), true);
  assert.equal(profileIsStale(daysAgo(40), NOW), true);
});

test("an unreadable timestamp is treated as never asked", () => {
  // Failing closed here costs one Graph call. Failing open would leave a
  // conversation stuck on "Customer" forever.
  assert.equal(profileIsStale("not a date", NOW), true);
});

// ---------------------------------------------------------------------------
// What to ask for
// ---------------------------------------------------------------------------

test("Messenger is not asked for a username", () => {
  // Graph rejects a request naming a field it does not know rather than
  // omitting it, so asking a Messenger id for `username` loses the name too.
  const url = profileRequest("messenger", "28847995138118550", "tok");

  assert.ok(url.includes("fields=name,profile_pic"), url);
  assert.ok(!url.includes("username"), "asked Messenger for a username");
});

test("Instagram is asked for a username, where a person may have no name", () => {
  const url = profileRequest("instagram", "17841401424316998", "tok");

  assert.ok(url.includes("username"), url);
});

test("the customer id is in the path and the token is escaped", () => {
  const url = profileRequest("messenger", "123/../456", "tok en&x=1");

  assert.ok(!url.includes("123/../456"), "customer id went in unescaped");
  assert.ok(!url.includes("tok en&x=1"), "token went in unescaped");
});

// ---------------------------------------------------------------------------
// What came back
// ---------------------------------------------------------------------------

test("a Messenger profile gives a name and a picture", () => {
  // The exact shape returned by Graph on 18 September for the real test
  // customer, with the picture URL shortened.
  assert.deepEqual(
    readProfile({
      name: "Wael K. Saleh",
      first_name: "Wael",
      last_name: "Saleh",
      profile_pic: "https://platform-lookaside.fbsbx.com/platform/profilepic/?psid=1",
      id: "28847995138118550",
    }),
    {
      name: "Wael K. Saleh",
      avatarUrl: "https://platform-lookaside.fbsbx.com/platform/profilepic/?psid=1",
    },
  );
});

test("an Instagram profile falls back to the username", () => {
  assert.deepEqual(readProfile({ username: "djangus_w", profile_pic: "https://x/p.jpg" }), {
    name: "djangus_w",
    avatarUrl: "https://x/p.jpg",
  });
});

test("split names are joined when there is no whole one", () => {
  assert.equal(readProfile({ first_name: "Wael", last_name: "Saleh" })?.name, "Wael Saleh");
  assert.equal(readProfile({ first_name: "Wael" })?.name, "Wael");
});

test("a customer whose name Meta withholds is still a recorded answer", () => {
  // This is the case that decides whether the lookup runs once or on every
  // message forever. Meta withholds names depending on the person's own
  // settings, so "no name" is a normal answer and must be recorded as one.
  const profile = readProfile({ id: "28847995138118550" });

  assert.notEqual(profile, null, "treated a withheld name as a failure");
  assert.deepEqual(profile, { name: null, avatarUrl: null });
});

test("empty strings are not names", () => {
  // Meta sends "" as readily as it omits a field, and an empty name would
  // render as a blank row rather than falling back to "Customer".
  assert.deepEqual(readProfile({ name: "   ", username: "", profile_pic: "" }), {
    name: null,
    avatarUrl: null,
  });
});

test("an error is not an answer, and is worth retrying", () => {
  // Distinct from a withheld name: nothing is recorded, so the next message
  // asks again.
  assert.equal(
    readProfile({ error: { message: "Unsupported get request", code: 100 } }),
    null,
  );
});

test("a response that is not an object at all is refused", () => {
  for (const nonsense of [null, undefined, "", "a string", 42]) {
    assert.equal(readProfile(nonsense), null, `accepted ${JSON.stringify(nonsense)}`);
  }
});

test("Arabic names survive being read", () => {
  assert.equal(readProfile({ name: "وائل صالح" })?.name, "وائل صالح");
});
