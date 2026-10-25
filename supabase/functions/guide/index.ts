// Saving the seller's guide for the assistant.
//
//   POST /guide   { "guide": "always ask which size first…" }
//
// Reads the guide into steps with one model call, then saves the words and the
// steps together, so the diagram the seller sees is always the reading of the
// words that are saved. An empty guide clears both. A reading that fails saves
// nothing: the seller keeps what they had and is told to try again.
//
// Called with the seller's own session, and the shop row is written through it,
// so row level security decides whose shop this is — not anything in the body.

import { createClient } from "jsr:@supabase/supabase-js@2.116.0";

import { corsHeaders } from "../_shared/origins.ts";
import { createLog, describe } from "../_shared/log.ts";
import { MODEL, usageCost } from "../meta-webhook/ai.ts";
import { askGuide, GUIDE_LIMIT } from "./guide.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const ANTHROPIC_WORKSPACE_ID = Deno.env.get("ANTHROPIC_WORKSPACE_ID") ?? "";

const service = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
const log = createLog(service, "guide");

type Refusal = "not_signed_in" | "too_long" | "failed";

Deno.serve(async (request: Request) => {
  const cors = corsHeaders(request.headers.get("Origin"));

  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (request.method !== "POST") return refuse("failed", 405, cors);

  const authorization = request.headers.get("Authorization") ?? "";
  if (!authorization) return refuse("not_signed_in", 401, cors);

  const caller = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authorization } },
  });

  const { data: identity, error: whoError } = await caller.auth.getUser();
  if (whoError || !identity?.user) return refuse("not_signed_in", 401, cors);

  let body: { guide?: unknown };
  try {
    body = await request.json();
  } catch {
    return refuse("failed", 400, cors);
  }

  const guide = typeof body.guide === "string" ? body.guide.trim() : "";
  if (guide.length > GUIDE_LIMIT) return refuse("too_long", 400, cors);

  const workspace = await caller.from("workspaces").select("id").single();
  if (workspace.error || !workspace.data) {
    await log("error", "guide_no_workspace", { user: identity.user.id, error: workspace.error?.message });
    return refuse("failed", 500, cors);
  }
  const workspaceId = workspace.data.id as string;

  let steps = null;
  if (guide) {
    const reading = await askGuide(ANTHROPIC_API_KEY, guide, { workspaceId: ANTHROPIC_WORKSPACE_ID });
    if (reading.status === "failed") {
      await log("error", "guide_unread", { detail: reading.detail }, workspaceId);
      return refuse("failed", 502, cors);
    }
    steps = reading.steps;

    // Never allowed to fail the save it describes.
    try {
      await service.from("ai_usage").insert({
        workspace_id: workspaceId,
        kind: "guide",
        model: MODEL,
        input_tokens: reading.usage.inputTokens,
        output_tokens: reading.usage.outputTokens,
        cache_read: reading.usage.cacheReadTokens,
        cache_write: reading.usage.cacheWriteTokens,
        cost_usd: usageCost(MODEL, reading.usage),
      });
    } catch (error) {
      await log("warn", "guide_usage_unrecorded", { error: describe(error) }, workspaceId);
    }
  }

  const saved = await caller.from("shop").upsert({
    workspace_id: workspaceId,
    guide: guide || null,
    guide_steps: steps,
    updated_at: new Date().toISOString(),
  });

  if (saved.error) {
    await log("error", "guide_unsaved", { error: saved.error.message }, workspaceId);
    return refuse("failed", 500, cors);
  }

  return json({ steps }, 200, cors);
});

function refuse(reason: Refusal, status: number, cors: Record<string, string>): Response {
  return json({ reason }, status, cors);
}

function json(body: unknown, status: number, cors: Record<string, string>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "content-type": "application/json; charset=utf-8" },
  });
}
