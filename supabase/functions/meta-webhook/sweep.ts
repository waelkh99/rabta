// Retrying events that failed processing.
//
// Every delivery is stored before it is processed, and one that fails is left
// with processed_at null so it can be tried again. Until this existed nothing
// did try again: a database hiccup at the wrong moment lost a customer's
// message from the inbox for good, with the raw event sitting unread beside it.
//
// ponytail: runs after each delivery rather than on a schedule — no pg_cron,
// which the PGlite harness cannot load. Quiet traffic means little is failing,
// so this is enough for launch. Move it to a scheduled function if events are
// ever seen stuck on an account that has gone quiet.

/** Old enough that nothing is still working on it. Processing takes ~40s. */
export const SWEEP_AFTER_MS = 5 * 60_000;

/** Tries per event. An event that fails this often needs a person. */
export const SWEEP_MAX_ATTEMPTS = 5;

/** Per delivery, so one bad batch cannot hold a fresh delivery up for long. */
export const SWEEP_BATCH = 5;

export interface PendingEvent {
  id: number;
  payload: unknown;
  attempts: number;
}

export interface SweepStore {
  /** Unprocessed, older than `before`, under the attempt cap, oldest first. */
  pending(before: string, maxAttempts: number, limit: number): Promise<PendingEvent[]>;

  /**
   * Takes an event for one retry by moving its attempt count on from exactly
   * `attempts`. A conditional update, so two sweeps running at once cannot
   * both take the same event: the second finds the count already moved.
   */
  claim(id: number, attempts: number): Promise<boolean>;
}

/** Retries what is due, and returns the ids it retried. */
export async function sweep(
  store: SweepStore,
  retry: (id: number, payload: unknown) => Promise<void>,
  now: Date = new Date(),
): Promise<number[]> {
  const before = new Date(now.getTime() - SWEEP_AFTER_MS).toISOString();
  const due = await store.pending(before, SWEEP_MAX_ATTEMPTS, SWEEP_BATCH);

  const retried: number[] = [];
  for (const event of due) {
    if (!await store.claim(event.id, event.attempts)) continue;
    await retry(event.id, event.payload);
    retried.push(event.id);
  }
  return retried;
}

/** The slice of supabase-js this module uses. */
interface SupabaseLike {
  from(table: string): any;
}

export function createSweepStore(client: SupabaseLike): SweepStore {
  return {
    async pending(before, maxAttempts, limit) {
      const { data, error } = await client
        .from("webhook_events")
        .select("id, payload, attempts")
        .is("processed_at", null)
        .lt("received_at", before)
        .lt("attempts", maxAttempts)
        .order("received_at", { ascending: true })
        .limit(limit);

      if (error) throw new Error(`sweep read failed: ${error.message}`);
      return data ?? [];
    },

    async claim(id, attempts) {
      const { data, error } = await client
        .from("webhook_events")
        .update({ attempts: attempts + 1 })
        .eq("id", id)
        .eq("attempts", attempts)
        .is("processed_at", null)
        .select("id");

      if (error) throw new Error(`sweep claim failed: ${error.message}`);
      return Array.isArray(data) && data.length > 0;
    },
  };
}
