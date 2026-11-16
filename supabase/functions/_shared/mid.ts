// One spelling for each Instagram message id.
//
// The echo of a reply we sent is recognised as ours because its id equals the
// id the Send API returned, and `messages.mid` is unique. On Instagram the two
// are not the same string: seen on production on 16 November 2026, the Send
// API answered
//
//   bmV3X2lnX2RtX2l0ZAW06MTpJR01lc3NhZA2VJRDox…  ("new_ig_dm_item:1:IGMessageID:…")
//
// and the echo of that same message carried
//
//   aWdfZAG1faXRlbToxOklHTWVzc2FnZAUlEOjE3ODQx…  ("ig_dm_item:1:IGMessageID:…")
//
// so every Instagram reply was stored twice — once as ours, once as an echo.
// Both are base64 with Meta's own escaping ("ZA" for a literal Z, "ZD" for the
// padding "="), and decode to the same id apart from the "new_" prefix.
//
// The decoded id, without the prefix, is what we store. It is never sent back
// to Meta, so it does not need to be in Meta's spelling. Anything that is not
// recognisably an Instagram message id — Messenger's "m_…", WhatsApp's
// "wamid.…", or an Instagram id in some other shape — is returned unchanged.

export function canonicalMid(mid: string): string {
  // "new_ig" and "ig_" encoded: a cheap test before decoding anything.
  if (!mid.startsWith("bmV3X2ln") && !mid.startsWith("aWdf")) return mid;

  let decoded: string;
  try {
    decoded = atob(mid.replace(/Z[AD]/g, (pair) => (pair === "ZA" ? "Z" : "=")));
  } catch {
    return mid;
  }

  const match = /^(?:new_)?(ig_[a-z_]+:\d+:IGMessageID:[0-9:]+)$/.exec(decoded);
  return match ? match[1] : mid;
}
