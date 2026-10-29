// Fixtures in ../fixtures are synthetic stores in Shopify's products.json
// shape (no real store's data is committed).
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runSource } from '../runner.ts';
import type { Fetcher, IngestStore, NormalizedDeal, Source } from '../types.ts';
import { productDiscount, shopifyAdapter, summarize } from './shopify.ts';

const fixture = (name: string) =>
  JSON.parse(readFileSync(new URL(`../fixtures/${name}.json`, import.meta.url), 'utf8'));

const source: Source = {
  id: 's', slug: 'demo-lawn', kind: 'shopify', baseUrl: 'https://lawn.example.pk',
  brandSlug: 'demo-lawn', config: {},
};

/** Serves one fixture as page 1 (and empty pages after), recording URLs. */
function fetcherFor(name: string | { products: unknown[] }) {
  const urls: string[] = [];
  const fetcher: Fetcher = {
    getText: async () => '',
    getJson: async <T>(url: string) => {
      urls.push(url);
      const page = Number(new URL(url).searchParams.get('page'));
      const body = typeof name === 'string' ? fixture(name) : name;
      return (page === 1 ? body : { products: [] }) as T;
    },
  };
  return { fetcher, urls };
}

test('a product\'s discount is its best available variant, rounded down', () => {
  assert.equal(productDiscount({ variants: [{ price: '2999.00', compare_at_price: '4999.00' }] }), 40);
  assert.equal(productDiscount({ variants: [
    { price: '2999', compare_at_price: '4999', available: false },
    { price: '4000', compare_at_price: '5000' },
  ] }), 20, 'sold-out variants do not count');
  assert.equal(productDiscount({ variants: [{ price: '5000', compare_at_price: '4000' }] }), 0, 'a higher "compare at" only');
  assert.equal(productDiscount({ variants: [{ price: 'abc', compare_at_price: '1000' }] }), 0, 'bad prices are ignored');
  assert.equal(productDiscount({}), 0);
  assert.equal(productDiscount({ variants: [{ price: '0.00', compare_at_price: '1000' }] }), 99, 'free caps at 99');
});

test('no sale: a handful of discounted products is not a sale', async () => {
  const { fetcher } = fetcherFor('shopify_no_sale');
  assert.deepEqual(await shopifyAdapter.fetchDeals(source, fetcher), []);
});

test('a sale: "up to" the real best discount, ignoring a single typo', async () => {
  const { fetcher } = fetcherFor('shopify_sale');
  const [deal] = await shopifyAdapter.fetchDeals(source, fetcher);
  assert.equal(deal.offer.kind, 'up_to_percent_off');
  assert.equal(deal.offer.percent, 50, 'the 95% typo and the sold-out 80% are ignored');
  assert.equal(deal.title, 'Sale: up to 50% off');
  assert.equal(deal.url, 'https://lawn.example.pk/collections/sale');
  assert.match(deal.description!, /^61 of 200 products are discounted\.$/);
});

test('a storewide flat discount reads "Flat 30% off"', async () => {
  const { fetcher } = fetcherFor('shopify_flat');
  const [deal] = await shopifyAdapter.fetchDeals(source, fetcher);
  assert.deepEqual(deal.offer, { kind: 'flat_percent_off', percent: 30 });
});

test('three or more extreme discounts are believed', () => {
  const p = (price: string) => ({ variants: [{ price, compare_at_price: '1000' }] });
  const products = [...Array(10)].map(() => p('500')).concat([p('50'), p('60'), p('70')]);
  assert.equal(summarize(products)!.percent, 95);
});

test('thresholds come from the source config', () => {
  const p = (d: boolean) => ({ variants: [{ price: d ? '500' : '1000', compare_at_price: '1000' }] });
  const few = [...Array(4)].map(() => p(true)).concat([...Array(16)].map(() => p(false)));
  assert.equal(summarize(few), null);
  assert.equal(summarize(few, { minProducts: 3, minShare: 0.1 })!.percent, 50);
});

test('pages until a short page, within maxPages', async () => {
  const full = { products: Array.from({ length: 250 }, (_, i) => ({ id: i, variants: [] })) };
  const urls: string[] = [];
  const fetcher: Fetcher = {
    getText: async () => '',
    getJson: async <T>(url: string) => { urls.push(url); return full as T; },
  };
  await shopifyAdapter.fetchDeals({ ...source, config: { maxPages: 3 } }, fetcher);
  assert.equal(urls.length, 3);
  assert.equal(urls[0], 'https://lawn.example.pk/products.json?limit=250&page=1');
});

test('malformed feeds are treated as no products, not crashes', async () => {
  const { fetcher } = fetcherFor({ products: 'nope' as unknown as unknown[] });
  assert.deepEqual(await shopifyAdapter.fetchDeals(source, fetcher), []);
});

// End to end through the runner: sale starts, its percentage changes, it ends.
test('sale start, price change and sale end through the runner', async () => {
  const deals = new Map<string, NormalizedDeal>();
  const expired = new Set<string>();
  const store: IngestStore = {
    startRun: async () => 'r',
    upsertDeal: async (_s, d) => {
      const before = deals.get(d.fingerprint);
      deals.set(d.fingerprint, d);
      expired.delete(d.fingerprint);
      return before ? (before.offer.percent === d.offer.percent ? 'unchanged' : 'updated') : 'created';
    },
    endMissing: async (_s, seen) => {
      let n = 0;
      for (const fp of deals.keys()) if (!seen.includes(fp) && !expired.has(fp)) { expired.add(fp); n++; }
      return n;
    },
    finishRun: async () => {},
  };
  let r = await runSource(source, shopifyAdapter, fetcherFor('shopify_sale').fetcher, store);
  assert.equal(r.created, 1, 'the sale starts');
  r = await runSource(source, shopifyAdapter, fetcherFor('shopify_flat').fetcher, store);
  assert.equal(r.updated, 1, 'the discount changes');
  r = await runSource(source, shopifyAdapter, fetcherFor('shopify_no_sale').fetcher, store);
  assert.equal(r.ended, 1, 'the sale ends');
});
