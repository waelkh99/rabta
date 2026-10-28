import { strict as assert } from "node:assert";
import { test } from "node:test";

import {
  assetsFromScopes,
  chosenBusinessAccounts,
  chosenNumbers,
  numberSetup,
  whatsappName,
} from "../functions/meta-oauth/assets.ts";

test("Pages, Instagram accounts and WhatsApp accounts are told apart by scope", () => {
  const granted = assetsFromScopes([
    { scope: "pages_messaging", target_ids: ["p1"] },
    { scope: "pages_show_list", target_ids: ["p1"] },
    { scope: "instagram_manage_messages", target_ids: ["ig1"] },
    { scope: "whatsapp_business_management", target_ids: ["waba1"] },
    { scope: "whatsapp_business_messaging", target_ids: ["waba1", "waba2"] },
    { scope: "public_profile" },
  ]);

  assert.deepEqual(granted, {
    pageIds: ["p1"],
    instagramIds: ["ig1"],
    whatsappIds: ["waba1", "waba2"],
  });
});

test("a WhatsApp-only connection grants no Page, which is not a failure", () => {
  // The callback picks the WhatsApp path on exactly this.
  const granted = assetsFromScopes([{ scope: "whatsapp_business_management", target_ids: [123] }]);
  assert.deepEqual(granted.pageIds, []);
  assert.deepEqual(granted.whatsappIds, ["123"]);
});

test("nothing usable is an empty answer, not a crash", () => {
  for (const scopes of [undefined, null, "x", [null], [{}]]) {
    assert.deepEqual(assetsFromScopes(scopes), { pageIds: [], instagramIds: [], whatsappIds: [] });
  }
});

test("a WhatsApp number is named by its business name and number", () => {
  assert.equal(
    whatsappName({ verified_name: "Test Number", display_phone_number: "+1 555-633-5647" }),
    "Test Number (+1 555-633-5647)",
  );
  assert.equal(whatsappName({ display_phone_number: "+962 7 9000 0000" }), "+962 7 9000 0000");
  assert.equal(whatsappName({}), null);
});

test("the business account the browser names counts only if the token was granted it", () => {
  assert.deepEqual(chosenBusinessAccounts(["w1", "w2"], "w2"), ["w2"]);
  // Someone else's account named from the browser: fall back to what was granted.
  assert.deepEqual(chosenBusinessAccounts(["w1"], "stranger"), ["w1"]);
  assert.deepEqual(chosenBusinessAccounts(["w1", "w2"], undefined), ["w1", "w2"]);
});

test("the number the signup named is the one connected, when it is there", () => {
  const numbers = [{ id: "a" }, { id: "b" }];
  assert.deepEqual(chosenNumbers(numbers, "b"), [{ id: "b" }]);
  assert.deepEqual(chosenNumbers(numbers, "gone"), numbers);
  assert.deepEqual(chosenNumbers(numbers, undefined), numbers);
});

test("a Business app number syncs, a new one registers, a connected one is left alone", () => {
  assert.equal(numberSetup("FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING", "CONNECTED"), "sync");
  assert.equal(numberSetup("FINISH", "PENDING"), "register");
  assert.equal(numberSetup("FINISH", undefined), "register");
  assert.equal(numberSetup("FINISH", "CONNECTED"), "none");
  assert.equal(numberSetup(undefined, "CONNECTED"), "none");
});
