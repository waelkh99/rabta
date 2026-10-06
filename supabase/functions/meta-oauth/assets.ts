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
