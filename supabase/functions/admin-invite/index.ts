// Creating a Rabta account, for someone who is allowed to create them.
//
//   POST /admin-invite   { "email": "them@example.com" }
//
// Public sign-up is off, so this is the only door into the product. It is open
// to us and not to sellers: a seller signed into their own inbox must not be
// able to mint accounts on the platform.
//
// The check is made here, on the server, from the user record rather than from
// the token's claims. Reading it from the record means revoking someone takes
// effect at once instead of whenever their hour-old token happens to expire,
// and it means the client's own idea of who is an admin — which only decides
// whether a button is drawn — is never what is trusted.

import { createClient } from "jsr:@supabase/supabase-js@2.116.0";

import { corsHeaders } from "../_shared/origins.ts";
import {
  checkEmail,
  type InviteRefusal,
  isAdmin,
  readInviteError,
} from "./admin.ts";
import { createLog } from "../_shared/log.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const log = createLog(
  createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } }),
  "admin-invite",
);

Deno.serve(async (request: Request) => {
  const cors = corsHeaders(request.headers.get("Origin"));

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors });
  }

  if (request.method !== "POST") return refuse("failed", 405, cors);

  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization) return refuse("not_signed_in", 401, cors);

  // Validates the token against the server and returns the user as it stands
  // now, including app_metadata. A decoded JWT would be enough to identify
  // them and would also be an hour out of date about their permissions.
  const caller = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });

  const { data: identity, error: whoError } = await caller.auth.getUser();
  if (whoError || !identity?.user) return refuse("not_signed_in", 401, cors);

  if (!isAdmin(identity.user)) {
    // Logged, because a seller's inbox reaching this endpoint is either a bug
    // in the interface or someone trying it by hand.
    await log("warn", "invite_not_admin", { user: identity.user.id });
    return refuse("not_admin", 403, cors);
  }

  let body: { email?: string; returnTo?: string };
  try {
    body = await request.json();
  } catch {
    return refuse("failed", 400, cors);
  }

  const email = (body.email ?? "").trim();
  const wrongEmail = checkEmail(email);
  if (wrongEmail) return refuse(wrongEmail, 400, cors);

  // Where the invitation lands. Taken from the allowlist rather than the
  // request, for the same reason the OAuth callback is: this link signs
  // whoever opens it in.
  const origin = request.headers.get("Origin");
  const redirectTo = Object.keys(cors).length > 0 && origin
    ? origin
    : undefined;

  const response = await fetch(`${SUPABASE_URL}/auth/v1/admin/generate_link`, {
    method: "POST",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      type: "invite",
      email,
      // A top-level field. Nested under `options` it is silently ignored and
      // the link falls back to the project's Site URL.
      ...(redirectTo ? { redirect_to: redirectTo } : {}),
    }),
  });

  const answer = await response.json().catch(() => null);

  if (!response.ok) {
    await log("error", "invite_refused", { status: response.status, answer });
    return refuse(readInviteError(response.status, answer), 400, cors);
  }

  const link = (answer as { action_link?: string } | null)?.action_link;
  if (!link) {
    await log("error", "invite_no_link", { answer });
    return refuse("failed", 502, cors);
  }

  await log("info", "invited", { email, by: identity.user.id });

  // The link is returned rather than emailed. Supabase's built-in sender is
  // rate limited and not for production, so until custom SMTP exists the
  // honest thing is to hand it over and let it be sent deliberately.
  return json({ link, email }, 200, cors);
});

function refuse(
  reason: InviteRefusal,
  status: number,
  cors: Record<string, string>,
): Response {
  return json({ reason }, status, cors);
}

function json(
  body: unknown,
  status: number,
  cors: Record<string, string>,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json; charset=utf-8" },
  });
}
