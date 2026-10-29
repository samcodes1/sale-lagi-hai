import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { Adapter, IngestStore, Source } from '../_shared/ingest/types.ts';
import { BUDGET_MS, handle, type IngestDeps } from './handler.ts';

const SECRET = 'k'.repeat(48);
const env = { get: (k: string) => (k === 'DISPATCHER_SECRET' ? SECRET : undefined) };
const post = (headers: Record<string, string> = { 'x-dispatcher-secret': SECRET }) =>
  new Request('https://x.supabase.co/functions/v1/ingest', { method: 'POST', headers });

const source = (slug: string, kind = 'test'): Source =>
  ({ id: slug, slug, kind, baseUrl: 'https://s.example.pk', brandSlug: 'b', config: {} });
const store: IngestStore = {
  startRun: async () => 'r',
  upsertDeal: async () => 'created',
  endMissing: async () => 0,
  finishRun: async () => {},
};
const adapter: Adapter = {
  kind: 'test',
  fetchDeals: async () => [{
    externalId: '1', title: 'Winter sale', url: 'https://s.example.pk/sale',
    offer: { kind: 'up_to_percent_off', percent: 40 },
  }],
};
const deps = (over: Partial<IngestDeps> = {}): IngestDeps => ({
  dueSources: async () => [source('a'), source('b')],
  store, fetcher: { getText: async () => '', getJson: async () => ({}) as never },
  adapters: { test: adapter }, now: () => 0, ...over,
});

test('needs the shared secret', async () => {
  assert.equal((await handle(post({}), env, () => deps())).status, 401);
  assert.equal((await handle(post({ 'x-dispatcher-secret': 'wrong' }), env, () => deps())).status, 401);
  assert.equal((await handle(post(), { get: () => undefined }, () => deps())).status, 500);
});

test('runs every due source and reports counts', async () => {
  const res = await handle(post(), env, () => deps());
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.deepEqual(body.runs.map((r: { source: string; status: string; created: number }) => [r.source, r.status, r.created]),
    [['a', 'ok', 1], ['b', 'ok', 1]]);
});

test('sources without an adapter are skipped', async () => {
  const body = await (await handle(post(), env, () => deps({ dueSources: async () => [source('x', 'unknown')] }))).json();
  assert.equal(body.runs[0].status, 'skipped');
});

test('stops starting new sources once the time budget is used', async () => {
  let t = 0;
  const body = await (await handle(post(), env, () => deps({
    now: () => t,
    store: { ...store, finishRun: async () => { t += BUDGET_MS + 1; } },
  }))).json();
  assert.deepEqual(body.runs.map((r: { status: string }) => r.status), ['ok', 'skipped']);
});

test('a store failure fails that source only', async () => {
  let calls = 0;
  const flaky: IngestStore = { ...store, startRun: async () => { if (calls++ === 0) throw new Error('db down'); return 'r'; } };
  const original = console.error;
  console.error = () => {};
  try {
    const body = await (await handle(post(), env, () => deps({ store: flaky }))).json();
    assert.deepEqual(body.runs.map((r: { status: string }) => r.status), ['failed', 'ok']);
  } finally {
    console.error = original;
  }
});
