import assert from 'node:assert/strict';
import { test } from 'node:test';
import { FetchRefused, PoliteFetcher, USER_AGENT } from './fetcher.ts';
import { fingerprint, normalize } from './normalize.ts';
import { isAllowed, parseRobots } from './robots.ts';
import { runSource } from './runner.ts';
import type { Adapter, IngestStore, NormalizedDeal, RunResult, ScrapedDeal, Source } from './types.ts';

// ---------------------------------------------------------------------------
// robots.txt
// ---------------------------------------------------------------------------
const ROBOTS = `
User-agent: *
Disallow: /cart
Disallow: /checkouts/
Disallow: /*?sort_by=
Allow: /cart/help$
Crawl-delay: 5

User-agent: BadBot
Disallow: /

User-agent: salelagihaibot
Disallow: /private
`;

test('robots: our own group wins over *', () => {
  const rules = parseRobots(ROBOTS, 'SaleLagiHaiBot');
  assert.equal(isAllowed(rules, '/cart'), true, 'our group does not disallow /cart');
  assert.equal(isAllowed(rules, '/private/x'), false);
});

test('robots: * group rules, wildcards, $ and longest match', () => {
  const rules = parseRobots(ROBOTS.replace(/User-agent: salelagihaibot[\s\S]*/, ''), 'SaleLagiHaiBot');
  assert.equal(isAllowed(rules, '/products.json?page=2'), true);
  assert.equal(isAllowed(rules, '/cart'), false);
  assert.equal(isAllowed(rules, '/cart/help'), true, 'a longer Allow beats Disallow');
  assert.equal(isAllowed(rules, '/cart/help/more'), false, '$ anchors the end');
  assert.equal(isAllowed(rules, '/collections/sale?sort_by=price'), false, '* matches anything');
  assert.equal(rules.crawlDelaySeconds, 5);
});

test('robots: empty or comment-only files allow everything', () => {
  assert.equal(isAllowed(parseRobots('', 'SaleLagiHaiBot'), '/anything'), true);
  assert.equal(isAllowed(parseRobots('# nothing here\n', 'SaleLagiHaiBot'), '/x'), true);
});

// ---------------------------------------------------------------------------
// Fetcher
// ---------------------------------------------------------------------------
type Route = (url: URL, init: RequestInit) => Response | Promise<Response>;

function fakeHttp(routes: Record<string, Route>) {
  const calls: { url: string; headers: Record<string, string> }[] = [];
  const http = (async (input: string | URL, init: RequestInit = {}) => {
    const url = new URL(String(input));
    calls.push({ url: url.pathname + url.search, headers: init.headers as Record<string, string> });
    const route = routes[url.pathname + url.search] ?? routes[url.pathname];
    if (!route) return new Response('not found', { status: 404 });
    return route(url, init);
  }) as typeof fetch;
  return { http, calls };
}

function fakeClock() {
  let now = 0;
  const sleeps: number[] = [];
  return {
    clock: { now: () => now, sleep: async (ms: number) => { sleeps.push(ms); now += ms; } },
    sleeps,
  };
}

test('fetcher: identifies itself and paces requests per host', async () => {
  const { http, calls } = fakeHttp({
    '/robots.txt': () => new Response('User-agent: *\nAllow: /\n'),
    '/a': () => new Response('A'),
    '/b': () => new Response('B'),
  });
  const { clock, sleeps } = fakeClock();
  const fetcher = new PoliteFetcher(http, clock, { minIntervalMs: 2000 });
  assert.equal(await fetcher.getText('https://shop.example.pk/a'), 'A');
  assert.equal(await fetcher.getText('https://shop.example.pk/b'), 'B');
  assert.equal(calls[1].headers['user-agent'], USER_AGENT);
  assert.ok(sleeps.reduce((a, b) => a + b, 0) >= 4000, `slept ${sleeps}`);
});

test('fetcher: obeys robots.txt and its crawl delay', async () => {
  const { http } = fakeHttp({
    '/robots.txt': () => new Response('User-agent: *\nDisallow: /cart\nCrawl-delay: 10\n'),
    '/products.json': () => new Response('[]'),
  });
  const { clock, sleeps } = fakeClock();
  const fetcher = new PoliteFetcher(http, clock, { minIntervalMs: 1000 });
  await assert.rejects(fetcher.getText('https://shop.example.pk/cart'), (e: FetchRefused) => e.reason === 'robots');
  await fetcher.getText('https://shop.example.pk/products.json');
  await fetcher.getText('https://shop.example.pk/products.json');
  assert.ok(sleeps.some((s) => s >= 10_000), 'crawl delay applied');
});

test('fetcher: no robots.txt allows; an unreachable one blocks', async () => {
  const ok = fakeHttp({ '/x': () => new Response('x') });
  assert.equal(await new PoliteFetcher(ok.http, fakeClock().clock).getText('https://a.example.pk/x'), 'x');
  const down = fakeHttp({ '/robots.txt': () => new Response('', { status: 503 }), '/x': () => new Response('x') });
  await assert.rejects(
    new PoliteFetcher(down.http, fakeClock().clock).getText('https://b.example.pk/x'),
    (e: FetchRefused) => e.reason === 'robots',
  );
});

test('fetcher: https only, including redirects; no redirects to other hosts', async () => {
  const { http } = fakeHttp({
    '/robots.txt': () => new Response(''),
    '/plain': () => new Response(null, { status: 301, headers: { location: 'http://shop.example.pk/x' } }),
    '/away': () => new Response(null, { status: 302, headers: { location: 'https://evil.example.com/x' } }),
    '/moved': () => new Response(null, { status: 301, headers: { location: '/hop1' } }),
    '/hop1': () => new Response(null, { status: 301, headers: { location: '/hop2' } }),
    '/hop2': () => new Response(null, { status: 301, headers: { location: '/new' } }),
    '/loop': () => new Response(null, { status: 302, headers: { location: '/loop' } }),
    '/new': () => new Response('new'),
  });
  const fetcher = new PoliteFetcher(http, fakeClock().clock);
  await assert.rejects(fetcher.getText('http://shop.example.pk/x'), (e: FetchRefused) => e.reason === 'not-https');
  await assert.rejects(fetcher.getText('https://shop.example.pk/plain'), (e: FetchRefused) => e.reason === 'not-https');
  await assert.rejects(fetcher.getText('https://shop.example.pk/away'), (e: FetchRefused) => e.reason === 'status');
  assert.equal(await fetcher.getText('https://shop.example.pk/moved'), 'new', 'three same-site hops are fine');
  await assert.rejects(fetcher.getText('https://shop.example.pk/loop'), /too many redirects/);
});

test('fetcher: retries 429 honouring Retry-After, then gives up', async () => {
  let n = 0;
  const { http } = fakeHttp({
    '/robots.txt': () => new Response(''),
    '/busy': () => (++n < 3 ? new Response('', { status: 429, headers: { 'retry-after': '30' } }) : new Response('ok')),
    '/down': () => new Response('', { status: 503 }),
  });
  const { clock, sleeps } = fakeClock();
  const fetcher = new PoliteFetcher(http, clock, { minIntervalMs: 0 });
  assert.equal(await fetcher.getText('https://shop.example.pk/busy'), 'ok');
  assert.ok(sleeps.filter((s) => s === 30_000).length === 2, `slept ${sleeps}`);
  await assert.rejects(fetcher.getText('https://shop.example.pk/down'), (e: FetchRefused) => e.status === 503);
});

test('fetcher: refuses oversized responses, declared or streamed', async () => {
  const big = 'x'.repeat(2000);
  const { http } = fakeHttp({
    '/robots.txt': () => new Response(''),
    '/declared': () => new Response(big, { headers: { 'content-length': '2000' } }),
    '/streamed': () => new Response(new ReadableStream({ start(c) { c.enqueue(new TextEncoder().encode(big)); c.close(); } })),
  });
  const fetcher = new PoliteFetcher(http, fakeClock().clock, { maxBytes: 1000 });
  await assert.rejects(fetcher.getText('https://s.example.pk/declared'), (e: FetchRefused) => e.reason === 'too-large');
  await assert.rejects(fetcher.getText('https://s.example.pk/streamed'), (e: FetchRefused) => e.reason === 'too-large');
});

// ---------------------------------------------------------------------------
// Normalization
// ---------------------------------------------------------------------------
const source: Source = { id: 's1', slug: 'demo-shop', kind: 'test', baseUrl: 'https://shop.example.pk', brandSlug: 'demo', config: {} };
const now = new Date('2026-10-29T12:00:00Z');
const deal = (over: Partial<ScrapedDeal> = {}): ScrapedDeal => ({
  externalId: 'p-1',
  title: '  Winter   sale  ',
  url: 'https://shop.example.pk/sale',
  offer: { kind: 'up_to_percent_off', percent: 50 },
  ...over,
});

test('fingerprints are stable per source and id', async () => {
  assert.equal(await fingerprint('a', 'P-1'), await fingerprint('a', ' p-1 '));
  assert.notEqual(await fingerprint('a', 'p-1'), await fingerprint('b', 'p-1'));
  assert.match(await fingerprint('a', 'p-1'), /^[a-f0-9]{64}$/);
});

test('normalize cleans text and accepts valid deals', async () => {
  const r = await normalize(source, deal(), now);
  assert.ok('deal' in r);
  assert.equal(r.deal.title, 'Winter sale');
});

test('normalize rejects what the database would (and fake discounts)', async () => {
  const cases: [Partial<ScrapedDeal>, string][] = [
    [{ title: 'ab' }, 'title length'],
    [{ url: 'http://shop.example.pk/sale' }, 'url must be https'],
    [{ url: 'javascript:alert(1)' }, 'url must be https'],
    [{ imageUrl: 'http://cdn.example.pk/x.jpg' }, 'image url must be https'],
    [{ endsAt: new Date('2026-10-28T00:00:00Z') }, 'already ended'],
    [{ offer: { kind: 'percent_off', percent: 100 } }, 'percent must be 1-99'],
    [{ offer: { kind: 'amount_off', amountOffPkr: 0 } }, 'amount off'],
    [{ offer: { kind: 'text', text: '   ' } }, 'offer text'],
    [{ offer: { kind: 'fixed_price', pricePkr: 999, originalPricePkr: 500 } }, 'original price must be above the price'],
    [{ offer: { kind: 'percent_off', percent: 50, pricePkr: 2999, originalPricePkr: 4999 } }, 'percent 50 is not the real 40'],
  ];
  for (const [over, reason] of cases) {
    const r = await normalize(source, deal(over), now);
    assert.deepEqual(r, { rejected: reason }, JSON.stringify(over));
  }
});

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------
function memoryStore() {
  const deals = new Map<string, NormalizedDeal>();
  const ended: string[] = [];
  const runs: RunResult[] = [];
  const store: IngestStore = {
    startRun: async () => 'run-1',
    upsertDeal: async (_s, d) => {
      const before = deals.get(d.fingerprint);
      deals.set(d.fingerprint, d);
      return before ? (JSON.stringify(before) === JSON.stringify(d) ? 'unchanged' : 'updated') : 'created';
    },
    endMissing: async (_s, seen) => {
      let n = 0;
      for (const fp of deals.keys()) {
        if (!seen.includes(fp) && !ended.includes(fp)) { ended.push(fp); n++; }
      }
      return n;
    },
    finishRun: async (_id, r) => { runs.push(r); },
  };
  return { store, deals, ended, runs };
}

const adapter = (deals: ScrapedDeal[] | Error): Adapter => ({
  kind: 'test',
  fetchDeals: async () => { if (deals instanceof Error) throw deals; return deals; },
});
const noFetch = { getText: async () => '', getJson: async () => ({}) as never };

test('runner: creates, then updates, then ends what disappeared', async () => {
  const mem = memoryStore();
  let r = await runSource(source, adapter([deal(), deal({ externalId: 'p-2', title: 'Shoes sale' })]), noFetch, mem.store, () => now);
  assert.deepEqual([r.status, r.created, r.updated, r.ended], ['ok', 2, 0, 0]);
  r = await runSource(source, adapter([deal({ title: 'Winter sale extended' })]), noFetch, mem.store, () => now);
  assert.deepEqual([r.created, r.updated, r.ended], [0, 1, 1]);
});

test('runner: bad items are isolated and counted', async () => {
  const mem = memoryStore();
  const r = await runSource(source, adapter([deal(), deal({ externalId: 'bad', url: 'http://x.pk' })]), noFetch, mem.store, () => now);
  assert.equal(r.status, 'partial');
  assert.equal(r.created, 1);
  assert.equal(r.rejected, 1);
  assert.match(r.errors[0], /rejected bad: url must be https/);
});

test('runner: a failed fetch fails the run and ends nothing', async () => {
  const mem = memoryStore();
  await runSource(source, adapter([deal()]), noFetch, mem.store, () => now);
  const r = await runSource(source, adapter(new Error('site down')), noFetch, mem.store, () => now);
  assert.equal(r.status, 'failed');
  assert.equal(mem.ended.length, 0);
});

test('runner: an empty answer does not end every deal (unless the source allows it)', async () => {
  const mem = memoryStore();
  await runSource(source, adapter([deal()]), noFetch, mem.store, () => now);
  await runSource(source, adapter([]), noFetch, mem.store, () => now);
  assert.equal(mem.ended.length, 0);
  await runSource({ ...source, config: { allowEmpty: true } }, adapter([]), noFetch, mem.store, () => now);
  assert.equal(mem.ended.length, 1);
});

test('runner: duplicates in one listing are written once', async () => {
  const mem = memoryStore();
  const r = await runSource(source, adapter([deal(), deal()]), noFetch, mem.store, () => now);
  assert.equal(r.created, 1);
  assert.equal(mem.deals.size, 1);
});
