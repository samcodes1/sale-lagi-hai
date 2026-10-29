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
};

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

  await pool(claimed, concurrency, async (row) => {
    const result = await deps.send({
      token: row.token,
      title: row.title,
      body: row.body,
      dealId: row.deal_id,
    });
    if (result.kind === 'dead-token') deadTokens.push(row.token);
    const list = results.get(row.outbox_id) ?? [];
    list.push(result);
    results.set(row.outbox_id, list);
  });

  // An outbox row is done when one device got it, or none can (all dead,
  // or our request was rejected). Rows with only retryable failures stay
  // claimed and come back after the claim expires.
  const done: number[] = [];
  let retried = 0;
  let failed = 0;
  for (const [id, list] of results) {
    if (list.some((r) => r.kind === 'sent') || list.every((r) => r.kind !== 'retry')) {
      done.push(id);
    } else {
      retried++;
    }
    failed += list.filter((r) => r.kind === 'failed').length;
  }

  if (done.length > 0) await deps.markSent(done);
  if (deadTokens.length > 0) await deps.dropTokens(deadTokens);

  return {
    claimed: results.size,
    sent: [...results.values()].filter((l) => l.some((r) => r.kind === 'sent')).length,
    deadTokens: deadTokens.length,
    retried,
    failed,
  };
}
