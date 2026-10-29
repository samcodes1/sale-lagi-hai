// One dispatcher run: claim due pushes, send them, report back. The
// decisions (who, when, how many) were made in SQL by private.plan_alerts;
// this only moves bytes.
import type { Push, SendResult } from '../_shared/fcm.ts';

export type ClaimedPush = {
  outbox_id: number;
  token: string;
  platform: string;
  title: string;
  body: string | null;
  deal_id: string | null;
};

export type DispatchDeps = {
  claim: (batch: number) => Promise<ClaimedPush[]>;
  markSent: (outboxIds: number[]) => Promise<number>;
  dropTokens: (tokens: string[]) => Promise<number>;
  send: (push: Push) => Promise<SendResult>;
};

export type DispatchSummary = {
  claimed: number;
  sent: number;
  deadTokens: number;
  retried: number;
  failed: number;
  /** Most sends came back "dead token": a configuration problem, so
   * nothing was dropped (see [DEAD_TOKEN_BREAKER]). */
  breakerTripped: boolean;
};

/**
 * Circuit breaker for dead tokens. Devices go stale a few at a time; when
 * at least [min] sends in one run, and at least [share] of them, say
 * "dead", the cause is our side (a service account from another Firebase
 * project answers SENDER_ID_MISMATCH for every token). Then no token is
 * dropped and those pushes are retried, so a bad deploy can't wipe every
 * user's devices in one minute.
 */
export const DEAD_TOKEN_BREAKER = { min: 10, share: 0.5 };

/** Runs `tasks` with at most `limit` in flight. */
async function pool<T>(items: T[], limit: number, task: (item: T) => Promise<void>) {
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) await task(items[next++]);
  });
  await Promise.all(workers);
}

export async function dispatch(
  deps: DispatchDeps,
  { batch = 500, concurrency = 20 } = {},
): Promise<DispatchSummary> {
  const claimed = await deps.claim(batch);
  const results = new Map<number, SendResult[]>();
  const deadTokens: string[] = [];
  const mismatchTokens: string[] = [];

  await pool(claimed, concurrency, async (row) => {
    const result = await deps.send({
      token: row.token,
      title: row.title,
      body: row.body,
      dealId: row.deal_id,
    });
    if (result.kind === 'dead-token') {
      (result.reason === 'sender-mismatch' ? mismatchTokens : deadTokens).push(row.token);
    }
    const list = results.get(row.outbox_id) ?? [];
    list.push(result);
    results.set(row.outbox_id, list);
  });

  // An outbox row is done when one device got it, or none can (all dead,
  // or our request was rejected). Rows with only retryable failures stay
  // claimed and come back after the claim expires.
  const sends = [...results.values()].reduce((n, l) => n + l.length, 0);
  // SENDER_ID_MISMATCH counts only when this run proved our credentials
  // work (some send succeeded); otherwise it may be our key, at any run
  // size, so those pushes wait for a later run.
  const anySent = [...results.values()].some((l) => l.some((r) => r.kind === 'sent'));
  if (anySent) deadTokens.push(...mismatchTokens);
  const breakerTripped =
    deadTokens.length >= DEAD_TOKEN_BREAKER.min && deadTokens.length >= sends * DEAD_TOKEN_BREAKER.share;
  const dropping = !breakerTripped;
  // A dead token we won't drop means "try again later".
  const settled = (r: SendResult) =>
    r.kind !== 'retry' &&
    !(r.kind === 'dead-token' && (!dropping || (r.reason === 'sender-mismatch' && !anySent)));

  const done: number[] = [];
  let retried = 0;
  let failed = 0;
  for (const [id, list] of results) {
    if (list.some((r) => r.kind === 'sent') || list.every(settled)) {
      done.push(id);
    } else {
      retried++;
    }
    failed += list.filter((r) => r.kind === 'failed').length;
  }

  if (done.length > 0) await deps.markSent(done);
  if (deadTokens.length > 0 && dropping) await deps.dropTokens(deadTokens);

  return {
    claimed: results.size,
    sent: [...results.values()].filter((l) => l.some((r) => r.kind === 'sent')).length,
    deadTokens: breakerTripped ? 0 : deadTokens.length,
    retried,
    failed,
    breakerTripped,
  };
}
