import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { IngestStore, NormalizedDeal, Source } from '../_shared/ingest/types.ts';
import { type BatchDeps, handle, MAX_DEALS, type NewBrand } from './handler.ts';

const SECRET = 's'.repeat(48);
const env = { get: (k: string) => (k === 'INGEST_BATCH_SECRET' ? SECRET : undefined) };
const post = (body: unknown, headers: Record<string, string> = { 'x-ingest-secret': SECRET }) =>
  new Request('https://x.example/functions/v1/ingest-batch', {
    method: 'POST',
    headers,
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });

const source: Source = { id: 'src', slug: 'hbl-deals', kind: 'agent', baseUrl: 'https://hbl.example', brandSlug: 'hbl', config: {} };

const deal = (id: string, over: Record<string, unknown> = {}) => ({
  externalId: id,
  title: 'Flat 20% off with HBL cards',
  titleUr: 'ایچ بی ایل کارڈز پر 20 فیصد رعایت',
  url: 'https://hbl.example/deals/' + id,
  brand: 'kfc',
  offer: { kind: 'flat_percent_off', percent: 20 },
  cards: [{ bank: 'hbl', kind: 'credit' }],
  cities: ['karachi'],
  endsAt: '2099-12-31T19:00:00Z',
  ...over,
});

function fakes() {
  const upserted: NormalizedDeal[] = [];
  const brands: NewBrand[] = [];
  let ended: string[] | null = null;
  const store: IngestStore = {
    startRun: async () => 'run',
    upsertDeal: async (_, d) => {
      upserted.push(d);
      return 'created';
    },
    endMissing: async (_, seen) => {
      ended = seen;
      return 0;
    },
    finishRun: async () => {},
  };
  const deps = (over: Partial<BatchDeps> = {}): BatchDeps => ({
    agentSources: async () => [{
      slug: source.slug, brand: 'hbl', baseUrl: source.baseUrl, pages: [source.baseUrl], notes: null, lastRunAt: null,
    }],
    agentSource: async (slug) => (slug === source.slug ? source : null),
    ensureBrand: async (_, b) => {
      if (b.category === 'nope') throw new Error('unknown category nope');
      brands.push(b);
    },
    store,
    ...over,
  });
  return { upserted, brands, deps, ended: () => ended };
}

test('needs the ingest secret', async () => {
  const { deps } = fakes();
  assert.equal((await handle(post({}, {}), env, deps)).status, 401);
  assert.equal((await handle(post({}, { 'x-ingest-secret': 'wrong' }), env, deps)).status, 401);
  assert.equal((await handle(post({}), { get: () => undefined }, deps)).status, 500);
  assert.equal((await handle(new Request('https://x.example', { method: 'PUT' }), env, deps)).status, 405);
  assert.equal((await handle(new Request('https://x.example', { method: 'GET' }), env, deps)).status, 401);
});

test('rejects a malformed or oversized body', async () => {
  const { deps } = fakes();
  assert.equal((await handle(post('{nope'), env, deps)).status, 400);
  assert.equal((await handle(post({ deals: [] }), env, deps)).status, 400);
  const many = Array.from({ length: MAX_DEALS + 1 }, (_, i) => deal(String(i)));
  assert.equal((await handle(post({ source: 'hbl-deals', deals: many }), env, deps)).status, 413);
});

test('only an enabled agent source', async () => {
  const { deps } = fakes();
  assert.equal((await handle(post({ source: 'other', deals: [] }), env, deps)).status, 404);
});

test('adds brands, validates and upserts deals, with Urdu and dates', async () => {
  const f = fakes();
  const res = await handle(post({
    source: 'hbl-deals',
    brands: [{ slug: 'kfc', name: 'KFC', nameUr: 'کے ایف سی', category: 'fast-food' }],
    deals: [deal('1'), deal('2', { offer: { kind: 'flat_percent_off', percent: 120 } })],
  }), env, f.deps);
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.created, 1);
  assert.equal(body.rejected, 1);
  assert.equal(body.status, 'partial');
  assert.deepEqual(f.brands.map((b) => b.slug), ['kfc']);
  const d = f.upserted[0];
  assert.equal(d.brand, 'kfc');
  assert.equal(d.titleUr, 'ایچ بی ایل کارڈز پر 20 فیصد رعایت');
  assert.ok(d.endsAt instanceof Date);
  assert.deepEqual(d.cards, [{ bank: 'hbl', kind: 'credit' }]);
  assert.equal(f.ended()?.length, 1);
});

test('a bad brand is reported, not fatal', async () => {
  const f = fakes();
  const body = await (await handle(post({
    source: 'hbl-deals',
    brands: [{ slug: 'x', name: 'X', category: 'nope' }, { slug: 'y' }],
    deals: [deal('1')],
  }), env, f.deps)).json();
  assert.equal(body.created, 1);
  assert.match(body.errors[0], /unknown category/);
  assert.match(body.errors[1], /expected/);
});

test('bad dates and bad brand slugs are rejected by the runner', async () => {
  const f = fakes();
  const body = await (await handle(post({
    source: 'hbl-deals',
    deals: [deal('1', { endsAt: 'soon' }), deal('2', { brand: 'Not A Slug' })],
  }), env, f.deps)).json();
  assert.equal(body.rejected, 2);
  assert.equal(body.status, 'failed');
  assert.deepEqual(body.errors, ['rejected 1: bad date', 'rejected 2: brand slug']);
});

test('an empty list ends deals only when the caller says it is complete', async () => {
  const f = fakes();
  await handle(post({ source: 'hbl-deals', deals: [] }), env, f.deps);
  assert.equal(f.ended(), null);
  await handle(post({ source: 'hbl-deals', deals: [], complete: true }), env, f.deps);
  assert.deepEqual(f.ended(), []);
});

test('a store failure is a 500 with no details', async () => {
  const f = fakes();
  const res = await handle(post({ source: 'hbl-deals', deals: [] }), env, () =>
    f.deps({ agentSource: async () => { throw new Error('db down'); } }));
  assert.equal(res.status, 500);
  assert.deepEqual(await res.json(), { error: 'ingest_failed' });
});

test('GET lists the enabled agent sources', async () => {
  const { deps } = fakes();
  const res = await handle(new Request('https://x.example', { method: 'GET', headers: { 'x-ingest-secret': SECRET } }), env, deps);
  assert.equal(res.status, 200);
  assert.deepEqual((await res.json()).sources.map((s: { slug: string }) => s.slug), ['hbl-deals']);
});
