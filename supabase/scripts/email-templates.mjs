// The emails Supabase sends for Inboxara: an invitation, a password reset, and a
// sign-in link. Arabic first, English under it.
//
//   RABTA_ENV=prod npm run email-templates            pushes them to production
//   npm run email-templates -- --preview <folder>     writes them as .html files
//
// Bilingual rather than one language per seller, because the template cannot
// know which language someone reads: an invited seller has never opened Inboxara.
//
// Replaced Supabase's stock English emails on 26 September 2026. Those never
// named Inboxara and read like every "click this link" email people are taught to
// distrust. Everything is inline-styled tables, because that is what email
// clients render; there are no images, because many clients block them.
//
// Needs SUPABASE_ACCESS_TOKEN (the Management API) and SUPABASE_URL.

import { readFile, writeFile, mkdir } from "node:fs/promises";

// RABTA_ENV=prod reads the production file and nothing else, so a command
// meant for production can never pick up a staging key, or the reverse.
const envFiles =
  process.env.RABTA_ENV === "prod" ? ["../.env.prod"] : ["../.env", "../.env.local"];
const env = {};
for (const file of envFiles) {
  let contents;
  try {
    contents = await readFile(new URL(file, import.meta.url), "utf8");
  } catch {
    continue;
  }
  for (const line of contents.split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Z0-9_]+)\s*=\s*"?([^"]*)"?\s*$/);
    if (match) env[match[1]] = match[2];
  }
}

// The palette of lib/theme.dart.
const INK = "#1D1626";
const MUTED = "#6A6272";
const SAND = "#F5F0E8";
const PAPER = "#FFFDF9";
const VIOLET = "#5B16C8";
const SAFFRON = "#FFB42E";

const ARABIC = "Tahoma, 'Segoe UI', Arial, sans-serif";
const LATIN = "'Segoe UI', Helvetica, Arial, sans-serif";

function block({ dir, font, title, body, button, note }) {
  const align = dir === "rtl" ? "right" : "left";
  return `
<tr><td dir="${dir}" style="padding:28px 32px 8px;text-align:${align};font-family:${font};">
  <h1 style="margin:0 0 12px;font-size:22px;line-height:1.4;color:${INK};">${title}</h1>
  <p style="margin:0 0 22px;font-size:15px;line-height:1.8;color:${INK};">${body}</p>
  <a href="{{ .ConfirmationURL }}" style="display:inline-block;background:${VIOLET};color:#ffffff;text-decoration:none;font-weight:bold;font-size:15px;padding:13px 26px;border-radius:12px;border:1.5px solid ${INK};">${button}</a>
  <p style="margin:18px 0 0;font-size:13px;line-height:1.7;color:${MUTED};">${note}</p>
</td></tr>`;
}

function page({ ar, en }) {
  return `<!doctype html>
<html><body style="margin:0;padding:0;background:${SAND};">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:${SAND};padding:32px 12px;">
<tr><td align="center">
<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background:${PAPER};border:1.5px solid ${INK};border-radius:18px;">
<tr><td style="padding:24px 32px 0;font-family:${LATIN};font-size:20px;font-weight:bold;color:${INK};" dir="ltr">
  Inbox<span style="color:${VIOLET};">ara</span>
</td></tr>
${block({ dir: "rtl", font: ARABIC, ...ar })}
<tr><td style="padding:20px 32px 0;"><div style="border-top:1px solid #EBE3D6;"></div></td></tr>
${block({ dir: "ltr", font: LATIN, ...en })}
<tr><td style="padding:24px 32px 28px;font-family:${LATIN};font-size:12px;line-height:1.7;color:${MUTED};" dir="ltr">
  <span dir="rtl" style="font-family:${ARABIC};">إذا لم يعمل الزر، انسخ هذا الرابط إلى المتصفح:</span><br>
  If the button does not work, copy this link into your browser:<br>
  <a href="{{ .ConfirmationURL }}" style="color:${VIOLET};word-break:break-all;">{{ .ConfirmationURL }}</a>
</td></tr>
</table>
<p style="margin:16px 0 0;font-family:${LATIN};font-size:12px;color:${MUTED};">inboxara.app</p>
</td></tr></table>
</body></html>`;
}

const templates = {
  invite: {
    subject: "دعوة إلى إنبوكسارا · You're invited to Inboxara",
    html: page({
      ar: {
        title: "تمت دعوتك إلى إنبوكسارا",
        body: "إنبوكسارا مكان واحد لكل رسائل زبائنك من إنستغرام وماسنجر. اضغط الزر لتختار كلمة المرور وتبدأ.",
        button: "قبول الدعوة",
        note: "الرابط يعمل مرة واحدة ولفترة محدودة. إذا لم تكن تتوقع هذه الدعوة، تجاهل الرسالة.",
      },
      en: {
        title: "You're invited to Inboxara",
        body: "Inboxara is one place for all your customer messages from Instagram and Messenger. Press the button to choose your password and get started.",
        button: "Accept invitation",
        note: "The link works once, for a limited time. If you were not expecting this, you can ignore this email.",
      },
    }),
  },
  recovery: {
    subject: "إعادة تعيين كلمة المرور · Reset your Inboxara password",
    html: page({
      ar: {
        title: "إعادة تعيين كلمة المرور",
        body: "وصلنا طلب لإعادة تعيين كلمة مرور حسابك في إنبوكسارا. اضغط الزر لتختار كلمة مرور جديدة.",
        button: "اختر كلمة مرور جديدة",
        note: "الرابط يعمل مرة واحدة ولفترة محدودة. إذا لم تطلب ذلك، تجاهل الرسالة؛ كلمة مرورك لم تتغير.",
      },
      en: {
        title: "Reset your password",
        body: "We received a request to reset the password for your Inboxara account. Press the button to choose a new one.",
        button: "Choose a new password",
        note: "The link works once, for a limited time. If you did not ask for this, ignore this email; your password has not changed.",
      },
    }),
  },
  magic_link: {
    subject: "رابط الدخول إلى إنبوكسارا · Your Inboxara sign-in link",
    html: page({
      ar: {
        title: "رابط الدخول",
        body: "اضغط الزر للدخول إلى إنبوكسارا.",
        button: "الدخول",
        note: "الرابط يعمل مرة واحدة ولفترة قصيرة. إذا لم تطلبه، تجاهل الرسالة.",
      },
      en: {
        title: "Your sign-in link",
        body: "Press the button to sign in to Inboxara.",
        button: "Sign in",
        note: "The link works once, for a short time. If you did not ask for it, ignore this email.",
      },
    }),
  },
};

const args = process.argv.slice(2);
const previewAt = args.includes("--preview") ? args[args.indexOf("--preview") + 1] : null;

if (previewAt) {
  await mkdir(previewAt, { recursive: true });
  for (const [name, t] of Object.entries(templates)) {
    await writeFile(`${previewAt}/${name}.html`, t.html);
  }
  console.log(`wrote ${Object.keys(templates).length} previews to ${previewAt}`);
} else {
  const ref = env.SUPABASE_URL?.match(/https:\/\/([a-z0-9]+)\.supabase\.co/)?.[1];
  if (!ref || !env.SUPABASE_ACCESS_TOKEN) {
    console.error("Missing SUPABASE_URL or SUPABASE_ACCESS_TOKEN.");
    process.exit(1);
  }
  const body = {};
  for (const [name, t] of Object.entries(templates)) {
    body[`mailer_subjects_${name}`] = t.subject;
    body[`mailer_templates_${name}_content`] = t.html;
  }
  const response = await fetch(`https://api.supabase.com/v1/projects/${ref}/config/auth`, {
    method: "PATCH",
    headers: {
      Authorization: `Bearer ${env.SUPABASE_ACCESS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    console.error(`Supabase refused: ${response.status} ${await response.text()}`);
    process.exit(1);
  }
  console.log(`Pushed ${Object.keys(templates).length} email templates to ${ref}.`);
}
