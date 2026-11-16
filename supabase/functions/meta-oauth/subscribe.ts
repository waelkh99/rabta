// Subscribing a Page to the webhook — the step that makes messages arrive.
//
// Meta answers this call with a transient error now and then ("An unexpected
// error has occurred. Please retry your request later.", code 2,
// is_transient: true) — seen on production on 16 November 2026, on a connect
// that otherwise succeeded. The seller was sent back as connected and no
// message would ever have reached them. So a transient answer is tried once
// more, and whatever is still a failure after that is returned for the
// callback to tell the seller about.

/** POSTs to the URL and returns Meta's parsed answer. */
export type Post = (url: string) => Promise<unknown>;

export type Subscribed = { ok: true } | { ok: false; answer: unknown };

const RETRY_AFTER_MS = 1500;

export async function subscribePage(
  post: Post,
  url: string,
  wait: (ms: number) => Promise<void> = (ms) => new Promise((r) => setTimeout(r, ms)),
): Promise<Subscribed> {
  let answer = await post(url).catch((error) => ({ error: String(error) }));
  if (succeeded(answer)) return { ok: true };

  if (transient(answer)) {
    await wait(RETRY_AFTER_MS);
    answer = await post(url).catch((error) => ({ error: String(error) }));
    if (succeeded(answer)) return { ok: true };
  }

  return { ok: false, answer };
}

function succeeded(answer: unknown): boolean {
  return (answer as { success?: unknown })?.success === true;
}

function transient(answer: unknown): boolean {
  const error = (answer as { error?: { is_transient?: unknown; code?: unknown } })?.error;
  if (typeof error !== "object" || error === null) return false;
  // Meta marks these itself; codes 1 and 2 are its "unknown" and "service"
  // errors, which it documents as worth retrying even when the flag is absent.
  return error.is_transient === true || error.code === 1 || error.code === 2;
}

/**
 * What the seller reads when a Page could not be subscribed. Both languages,
 * Arabic first: this page is served by the function, outside the app, so it
 * cannot know which language the seller chose. HTML rather than plain text,
 * because plain text lays Arabic out left to right with its full stop at the
 * wrong end, in a monospace font too small to read on a phone.
 *
 * `back` is the application's origin, already checked against the allowlist.
 */
export function notSubscribedPage(back: string): string {
  const href = escape(`${back.replace(/\/$/, "")}/`);
  return `<!doctype html>
<html lang="ar">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Inboxara</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Almarai:wght@400;700&family=Rubik:wght@600;800&display=swap" rel="stylesheet">
<style>
  /* The app's own palette (lib/theme.dart, RabtaColors) and type: Rubik for
     the wordmark and titles, Almarai for everything read. */
  :root { --ground:#F5F0E8; --surface:#FFFDF9; --line:#EBE3D6; --edge:#DCCFBC;
          --ink:#1D1626; --muted:#6A6272; --accent:#5B16C8; --on-accent:#FFFFFF;
          --urgent:#CF2F55; --shadow:#1D1626; }
  @media (prefers-color-scheme: dark) {
    :root { --ground:#15111B; --surface:#1E1826; --line:#2F2739; --edge:#443A52;
            --ink:#F3EEE6; --muted:#A39AAE; --accent:#A77BF5; --on-accent:#15111B;
            --urgent:#FF8098; --shadow:#0E0B12; }
  }
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; padding: 28px 16px 48px; color: var(--ink);
         background: var(--ground) radial-gradient(var(--edge) 1.1px, transparent 1.2px) 0 0 / 22px 22px;
         font: 16px/1.7 Almarai, system-ui, "Segoe UI", Tahoma, sans-serif; }
  .wordmark { display: block; max-width: 520px; margin: 0 auto 28px; text-align: center;
              font: 800 26px/1 Rubik, system-ui, sans-serif; color: var(--ink); text-decoration: none; }
  .wordmark span { color: var(--accent); }
  .card { max-width: 520px; margin: 0 auto; background: var(--surface);
          border: 2px solid var(--ink); border-radius: 18px; box-shadow: 6px 6px 0 var(--shadow); }
  section { padding: 28px 28px 30px; }
  section + section { border-top: 1px solid var(--line); }
  .flag { width: 40px; height: 40px; border-radius: 12px; display: grid; place-items: center;
          background: color-mix(in srgb, var(--urgent) 14%, transparent); color: var(--urgent);
          margin-bottom: 14px; }
  h1 { font: 800 22px/1.3 Rubik, system-ui, sans-serif; margin: 0 0 8px; }
  p { margin: 0 0 22px; color: var(--muted); }
  .button { display: inline-block; padding: 12px 24px; border-radius: 12px;
            background: var(--accent); color: var(--on-accent); text-decoration: none;
            font: 600 16px/1.2 Rubik, system-ui, sans-serif;
            box-shadow: 3px 3px 0 var(--shadow); transition: transform .1s, box-shadow .1s; }
  [dir="rtl"] .button { box-shadow: -3px 3px 0 var(--shadow); }
  .button:active { transform: translate(2px, 2px); box-shadow: 1px 1px 0 var(--shadow); }
  @media (max-width: 480px) { section { padding: 22px 20px 24px; } .button { display: block; text-align: center; } }
</style>
</head>
<body>
<a class="wordmark" href="${href}" dir="ltr">Inbox<span>ara</span></a>
<div class="card">
  <section dir="rtl" lang="ar">
    <div class="flag" aria-hidden="true">${LINK_OFF}</div>
    <h1>لم يكتمل الربط</h1>
    <p>تم ربط حسابك، لكن ميتا لم تؤكد أن الرسائل ستصل إلى إنبوكسارا. ارجع إلى إنبوكسارا واضغط «الربط مع ميتا» مرة أخرى.</p>
    <a class="button" href="${href}">العودة إلى إنبوكسارا</a>
  </section>
  <section dir="ltr" lang="en">
    <h1>Not quite connected</h1>
    <p>Your account was linked, but Meta did not confirm that messages will reach Inboxara. Go back to Inboxara and press “Connect with Meta” again.</p>
    <a class="button" href="${href}">Back to Inboxara</a>
  </section>
</div>
</body>
</html>`;
}

// The same broken-link mark the inbox's "stopped receiving" banner uses
// (Material's link_off), so the two read as the same problem.
const LINK_OFF =
  `<svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor"><path d="M17 7h-4v1.9h4c1.71 0 3.1 1.39 3.1 3.1 0 1.43-.98 2.63-2.31 2.98l1.46 1.46C20.88 15.61 22 13.95 22 12c0-2.76-2.24-5-5-5zm-1 4h-2.19l2 2H16zM2 4.27l3.11 3.11C3.29 8.12 2 9.91 2 12c0 2.76 2.24 5 5 5h4v-1.9H7c-1.71 0-3.1-1.39-3.1-3.1 0-1.59 1.21-2.9 2.76-3.07L8.73 11H8v2h2.73L13 15.27V17h1.73l4.01 4L20 19.74 3.27 3 2 4.27z"/></svg>`;

function escape(value: string): string {
  return value.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}
