// What the service did, written twice: to the function log as one JSON line,
// and to `ops_log`, which the admin screen reads. The dashboard's logs expire
// in a day or a week and cannot be searched by seller; the table is what lets
// an admin see, inside the app, that one shop's token died on Tuesday.
//
// Only events worth an admin's attention go to the table: failures, dead
// tokens, accounts connected and removed, hand-overs. Routine traffic stays in
// the function log.
//
// Logging must never break the thing it describes, so nothing here throws.

export type Level = "info" | "warn" | "error";

export interface LogLine {
  source: string;
  level: Level;
  event: string;
  workspace_id: string | null;
  detail: Record<string, unknown>;
}

/** An error as something JSON can carry. */
export function describe(cause: unknown): string {
  if (cause instanceof Error) return cause.message;
  if (typeof cause === "string") return cause;
  try {
    return JSON.stringify(cause);
  } catch {
    return String(cause);
  }
}

export function logLine(
  source: string,
  level: Level,
  event: string,
  detail: Record<string, unknown> = {},
  workspaceId: string | null = null,
): LogLine {
  return { source, level, event, workspace_id: workspaceId, detail };
}

/** The slice of supabase-js this module uses. */
interface SupabaseLike {
  from(table: string): any;
}

export type Log = (
  level: Level,
  event: string,
  detail?: Record<string, unknown>,
  workspaceId?: string | null,
) => Promise<void>;

export function createLog(client: SupabaseLike, source: string): Log {
  return async (level, event, detail = {}, workspaceId = null) => {
    const line = logLine(source, level, event, detail, workspaceId);
    const text = JSON.stringify(line);
    if (level === "error") console.error(text);
    else if (level === "warn") console.warn(text);
    else console.log(text);

    try {
      await client.from("ops_log").insert({
        level,
        source,
        event,
        workspace_id: workspaceId,
        detail,
      });
    } catch {
      // The console line above is the record of last resort.
    }
  };
}
