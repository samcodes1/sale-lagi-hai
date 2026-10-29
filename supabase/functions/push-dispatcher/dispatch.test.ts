import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { SendResult } from '../_shared/fcm.ts';
import { type ClaimedPush, dispatch, type DispatchDeps } from './dispatch.ts';
import { handle } from './handler.ts';

const row = (outbox_id: number, token: string): ClaimedPush => ({
  outbox_id, token, platform: 'android', title: 'Khaadi: 40% off', body: 'Winter sale', deal_id: 'd1',
});

function fakeDeps(rows: ClaimedPush[], results: Record<string, SendResult>) {
  const calls = { marked: [] as number[], dropped: [] as string[], sent: [] as string[] };
  const deps: DispatchDeps = {
    claim: async () => rows,
    markSent: async (ids) => { calls.marked.push(...ids); return ids.length; },
    dropTokens: async (tokens) => { calls.dropped.push(...tokens); return tokens.length; },
    send: async (push) => { calls.sent.push(push.token); return results[push.token] ?? { kind: 'sent' }; },
  };
  return { deps, calls };
}

test('sends every claimed push and marks them sent', async () => {
  const { deps, calls } = fakeDeps([row(1, 'a'), row(2, 'b')], {});
  const summary = await dispatch(deps);
  assert.deepEqual(calls.sent.sort(), ['a', 'b']);
  assert.deepEqual(calls.marked.sort(), [1, 2]);
  assert.deepEqual(summary, { claimed: 2, sent: 2, deadTokens: 0, retried: 0, failed: 0, breakerTripped: false });
});

test('a push reaching one of two devices is done; dead tokens are dropped', async () => {
  const { deps, calls } = fakeDeps([row(1, 'phone'), row(1, 'old-phone')], { 'old-phone': { kind: 'dead-token' } });
  const summary = await dispatch(deps);
  assert.deepEqual(calls.marked, [1]);
  assert.deepEqual(calls.dropped, ['old-phone']);
  assert.equal(summary.deadTokens, 1);
});

test('only retryable failures leave the push for a later run', async () => {
  const { deps, calls } = fakeDeps([row(1, 'a'), row(2, 'b')], { a: { kind: 'retry' } });
  const summary = await dispatch(deps);
  assert.deepEqual(calls.marked, [2]);
  assert.equal(summary.retried, 1);
});

test('a push no device can take (all dead or rejected) is closed, not retried forever', async () => {
  const { deps, calls } = fakeDeps([row(1, 'dead'), row(2, 'bad')], {
    dead: { kind: 'dead-token' }, bad: { kind: 'failed', status: 403 },
  });
  const summary = await dispatch(deps);
  assert.deepEqual(calls.marked.sort(), [1, 2]);
  assert.equal(summary.failed, 1);
});

test('a run where most tokens come back dead drops none and retries', async () => {
  const rows = Array.from({ length: 12 }, (_, i) => row(i, `t${i}`));
  const dead = Object.fromEntries(rows.slice(0, 10).map((r) => [r.token, { kind: 'dead-token' as const }]));
  const { deps, calls } = fakeDeps(rows, dead);
  const summary = await dispatch(deps);
  assert.equal(summary.breakerTripped, true);
  assert.deepEqual(calls.dropped, []);
  assert.deepEqual(calls.marked.sort((a, b) => a - b), [10, 11], 'only the delivered pushes are closed');
  assert.equal(summary.retried, 10);
});

test('a few dead tokens among many sends are still dropped', async () => {
  const rows = Array.from({ length: 30 }, (_, i) => row(i, `t${i}`));
  const dead = Object.fromEntries(rows.slice(0, 10).map((r) => [r.token, { kind: 'dead-token' as const }]));
  const { deps, calls } = fakeDeps(rows, dead);
  const summary = await dispatch(deps);
  assert.equal(summary.breakerTripped, false);
  assert.equal(calls.dropped.length, 10);
});

test('SENDER_ID_MISMATCH alone never drops tokens; next to a success it does', async () => {
  const mismatch = { kind: 'dead-token' as const, reason: 'sender-mismatch' as const };
  const alone = fakeDeps([row(1, 'a'), row(2, 'b')], { a: mismatch, b: mismatch });
  const summary = await dispatch(alone.deps);
  assert.deepEqual(alone.calls.dropped, []);
  assert.deepEqual(alone.calls.marked, [], 'left for a later run');
  assert.equal(summary.retried, 2);

  const proven = fakeDeps([row(1, 'a'), row(2, 'ok')], { a: mismatch });
  await dispatch(proven.deps);
  assert.deepEqual(proven.calls.dropped, ['a']);
});

test('nothing due: nothing marked or dropped', async () => {
  const { deps, calls } = fakeDeps([], {});
  assert.deepEqual(await dispatch(deps), { claimed: 0, sent: 0, deadTokens: 0, retried: 0, failed: 0, breakerTripped: false });
  assert.deepEqual(calls, { marked: [], dropped: [], sent: [] });
});

test('sending respects the concurrency limit', async () => {
  let inFlight = 0;
  let peak = 0;
  const rows = Array.from({ length: 50 }, (_, i) => row(i, `t${i}`));
  const deps: DispatchDeps = {
    claim: async () => rows,
    markSent: async (ids) => ids.length,
    dropTokens: async () => 0,
    send: async () => {
      inFlight++; peak = Math.max(peak, inFlight);
      await new Promise((r) => setTimeout(r, 1));
      inFlight--;
      return { kind: 'sent' };
    },
  };
  await dispatch(deps, { concurrency: 5 });
  assert.ok(peak <= 5, `peak ${peak}`);
});

// ---------------------------------------------------------------------------
// The HTTP handler: only pg_cron, with the shared secret, can trigger a run.
// ---------------------------------------------------------------------------
const SECRET = 's'.repeat(48);
const env = (secret?: string) => ({ get: (k: string) => (k === 'DISPATCHER_SECRET' ? secret : undefined) });
const request = (headers: Record<string, string> = {}, method = 'POST') =>
  new Request('https://x.supabase.co/functions/v1/push-dispatcher', { method, headers });

test('no secret header: 401, and nothing runs', async () => {
  let ran = false;
  const res = await handle(request(), env(SECRET), () => { ran = true; return fakeDeps([], {}).deps; });
  assert.equal(res.status, 401);
  assert.equal(ran, false);
});

test('a wrong secret or a user JWT: 401', async () => {
  for (const headers of [{ 'x-dispatcher-secret': 'nope' }, { authorization: 'Bearer eyJhbGciOi.fake.jwt' }]) {
    const res = await handle(request(headers), env(SECRET), () => fakeDeps([], {}).deps);
    assert.equal(res.status, 401);
  }
});

test('fails closed when the secret is not configured (or too short)', async () => {
  for (const secret of [undefined, 'short']) {
    const res = await handle(request({ 'x-dispatcher-secret': secret ?? '' }), env(secret), () => fakeDeps([], {}).deps);
    assert.equal(res.status, 500);
  }
});

test('only POST', async () => {
  const res = await handle(request({ 'x-dispatcher-secret': SECRET }, 'GET'), env(SECRET), () => fakeDeps([], {}).deps);
  assert.equal(res.status, 405);
});

test('the right secret runs a dispatch and returns counts only', async () => {
  const res = await handle(request({ 'x-dispatcher-secret': SECRET }), env(SECRET), () => fakeDeps([row(1, 'a')], {}).deps);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.deepEqual(body, { claimed: 1, sent: 1, deadTokens: 0, retried: 0, failed: 0, breakerTripped: false });
  assert.ok(!JSON.stringify(body).includes('Khaadi'), 'no message content in the response');
});

test('a failing run returns a generic error', async () => {
  const deps = { ...fakeDeps([], {}).deps, claim: async () => { throw new Error('connection refused to db.internal:5432'); } };
  const original = console.error;
  console.error = () => {};
  try {
    const res = await handle(request({ 'x-dispatcher-secret': SECRET }), env(SECRET), () => deps);
    assert.equal(res.status, 500);
    assert.deepEqual(await res.json(), { error: 'dispatch_failed' });
  } finally {
    console.error = original;
  }
});
