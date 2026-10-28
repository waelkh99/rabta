// What a connection was granted, read from debug_token's granular scopes.
//
// Every pages_* scope is granted against the same Page ids, every instagram_*
// scope against the same Instagram ids, and every whatsapp_* scope against the
// same WhatsApp Business Account ids, so the union of the target ids under
// each prefix is the answer.
//
// Free of Deno-specific APIs so the same code runs under test.

export interface Granted {
  pageIds: string[];
  instagramIds: string[];
  /** WhatsApp Business Accounts. Their numbers are listed separately. */
  whatsappIds: string[];
}

export function assetsFromScopes(scopes: unknown): Granted {
  const found = { pages_: new Set<string>(), instagram_: new Set<string>(), whatsapp_: new Set<string>() };

  for (const scope of Array.isArray(scopes) ? scopes : []) {
    const name = String((scope as { scope?: unknown })?.scope ?? "");
    const prefix = (Object.keys(found) as (keyof typeof found)[]).find((p) => name.startsWith(p));
    if (!prefix) continue;
    for (const id of (scope as { target_ids?: unknown[] }).target_ids ?? []) found[prefix].add(String(id));
  }

  return {
    pageIds: [...found.pages_],
    instagramIds: [...found.instagram_],
    whatsappIds: [...found.whatsapp_],
  };
}

/** How a WhatsApp number reads on the Accounts page: "Shop (+962 7…)". */
export function whatsappName(phone: { verified_name?: string; display_phone_number?: string }): string | null {
  const name = phone.verified_name?.trim();
  const number = phone.display_phone_number?.trim();
  if (name && number) return `${name} (${number})`;
  return name || number || null;
}

/**
 * The business accounts to connect after WhatsApp's signup. The browser names
 * the one the seller chose, but the browser is not trusted: the name counts
 * only when the token was actually granted that account. Otherwise every
 * granted account, which is what the token proves the seller may connect.
 */
export function chosenBusinessAccounts(granted: string[], named: unknown): string[] {
  return typeof named === "string" && granted.includes(named) ? [named] : granted;
}

/** Of a business account's numbers, the one the signup named if it is there. */
export function chosenNumbers<T extends { id: string }>(numbers: T[], named: unknown): T[] {
  const match = numbers.filter((phone) => phone.id === named);
  return match.length > 0 ? match : numbers;
}

/**
 * What a number needs before it can receive.
 *
 * - A number brought over from the WhatsApp Business app (Coexistence) is
 *   already registered, and Meta gives 24 hours to start its contact and
 *   history sync before the seller has to be onboarded again — so `sync`.
 * - Any other number not yet CONNECTED has to be registered with a PIN.
 */
export function numberSetup(event: unknown, status: unknown): "sync" | "register" | "none" {
  if (event === "FINISH_WHATSAPP_BUSINESS_APP_ONBOARDING") return "sync";
  return status === "CONNECTED" ? "none" : "register";
}
