import { strict as assert } from "node:assert";
import { test } from "node:test";

import {
  type PendingEvent,
  sweep,
  SWEEP_AFTER_MS,
  SWEEP_BATCH,
  SWEEP_MAX_ATTEMPTS,
  type SweepStore,
} from "../functions/meta-webhook/sweep.ts";

const NOW = new Date("2026-09-24T12:00:00Z");

interface Row extends PendingEvent {
  receivedAt: string;
  processed: boolean;
}

/** Holds webhook_events the way the table does, and filters the same way. */
class FakeEvents implements SweepStore {
  rows: Row[] = [];

  add(id: number, minutesAgo: number, { attempts = 0, processed = false } = {}): void {
    this.rows.push({
      id,
      payload: { id },
      attempts,
      processed,
      receivedAt: new Date(NOW.getTime() - minutesAgo * 60_000).toISOString(),
    });
  }

  pending(before: string, maxAttempts: number, limit: number): Promise<PendingEvent[]> {
    return Promise.resolve(
      this.rows
        .filter((r) => !r.processed && r.receivedAt < before && r.attempts < maxAttempts)
        .sort((a, b) => a.receivedAt.localeCompare(b.receivedAt))
        .slice(0, limit)
        // Copies, as a query result is: a later claim must not change what an
        // earlier read already handed out.
        .map(({ id, payload, attempts }) => ({ id, payload, attempts })),
    );
  }

  claim(id: number, attempts: number): Promise<boolean> {
    const row = this.rows.find((r) => r.id === id);
    if (!row || row.processed || row.attempts !== attempts) return Promise.resolve(false);
    row.attempts++;
    return Promise.resolve(true);
  }
}

test("an old unprocessed event is retried, and a fresh one is left to its own run", async () => {
  // A fresh event is almost certainly still being processed — the debounce and
  // the model call take most of a minute. Retrying it would process it twice.
  const events = new FakeEvents();
  events.add(1, 10);
  events.add(2, 1);

  const seen: number[] = [];
  const retried = await sweep(events, (id) => {
    seen.push(id);
    return Promise.resolve();
  }, NOW);

  assert.deepEqual(retried, [1]);
  assert.deepEqual(seen, [1]);
  assert.equal(events.rows[0].attempts, 1, "the attempt was not counted");
});

test("a processed event is never retried", async () => {
  const events = new FakeEvents();
  events.add(1, 60, { processed: true });

  assert.deepEqual(await sweep(events, () => Promise.resolve(), NOW), []);
});

test("an event that has failed too often is left alone", async () => {
  const events = new FakeEvents();
  events.add(1, 60, { attempts: SWEEP_MAX_ATTEMPTS });
  events.add(2, 60, { attempts: SWEEP_MAX_ATTEMPTS - 1 });

  assert.deepEqual(await sweep(events, () => Promise.resolve(), NOW), [2]);
});

test("the cut-off is the age, not a hair either side of it", async () => {
  const events = new FakeEvents();
  events.add(1, SWEEP_AFTER_MS / 60_000 + 0.1);
  events.add(2, SWEEP_AFTER_MS / 60_000 - 0.1);

  assert.deepEqual(await sweep(events, () => Promise.resolve(), NOW), [1]);
});

test("oldest first, and no more than a batch per delivery", async () => {
  const events = new FakeEvents();
  for (let i = 1; i <= SWEEP_BATCH + 3; i++) events.add(i, 100 - i);

  const retried = await sweep(events, () => Promise.resolve(), NOW);

  assert.equal(retried.length, SWEEP_BATCH);
  assert.deepEqual(retried, [1, 2, 3, 4, 5].slice(0, SWEEP_BATCH));
});

test("two sweeps at once retry each event once between them", async () => {
  // Two deliveries arriving together both sweep. Without the conditional
  // claim, both would read the same pending list and process it twice.
  const events = new FakeEvents();
  events.add(1, 10);
  events.add(2, 10);

  const seen: number[] = [];
  const retry = (id: number) => {
    seen.push(id);
    return Promise.resolve();
  };

  await Promise.all([sweep(events, retry, NOW), sweep(events, retry, NOW)]);

  assert.deepEqual(seen.sort(), [1, 2]);
});
