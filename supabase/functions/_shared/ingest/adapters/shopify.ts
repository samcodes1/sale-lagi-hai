// Shopify sale detector (sub-phase 3.2). Reads a store's public product
// feed (/products.json) and reports one brand-wide deal while a sale is on:
// "Up to 50% off" (or "Flat 30% off" when nearly everything has the same
// discount). When the sale ends the deal is no longer listed, and the
// runner expires it.
//
// Source config (ingest_sources.config):
//   saleUrl      link shoppers open (default: <base>/collections/sale)
//   minProducts  discounted products needed to call it a sale (default 10)
//   minShare     ...and the share of all products (default 0.05)
//   maxPages     product pages to read, 250 each (default 20)
import type { Adapter, Fetcher, ScrapedDeal, Source } from '../types.ts';

type Variant = { price?: string | null; compare_at_price?: string | null; available?: boolean };
type Product = { id?: number; title?: string; variants?: Variant[] };

const toRupees = (value: string | null | undefined): number | null => {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 && n < 100_000_000 ? Math.round(n) : null;
};

/** The product's best real discount in whole percent (rounded down), or 0. */
export function productDiscount(product: Product): number {
  let best = 0;
  for (const v of product.variants ?? []) {
    if (v.available === false) continue;
    const price = toRupees(v.price);
    const was = toRupees(v.compare_at_price);
    if (price === null || was === null || was <= price || was === 0) continue;
    best = Math.max(best, Math.floor(((was - price) * 100) / was));
  }
  return Math.min(best, 99);
}

export type SaleSummary = {
  products: number;
  discounted: number;
  /** The headline percentage. */
  percent: number;
  flat: boolean;
};

/** Is a sale on, and what is its honest headline? Null when not on sale. */
export function summarize(
  products: Product[],
  { minProducts = 10, minShare = 0.05 }: { minProducts?: number; minShare?: number } = {},
): SaleSummary | null {
  const discounts = products.map(productDiscount);
  const on = discounts.filter((d) => d >= 1).sort((a, b) => b - a);
  if (on.length < minProducts || on.length < products.length * minShare) return null;

  // "Up to" must be real, not one mistyped compare-at price: discounts above
  // 90% count only when at least three products have them.
  const plausible = on.filter((d) => d <= 90);
  const extreme = on.filter((d) => d > 90);
  const percent = extreme.length >= 3 ? extreme[0] : plausible[0] ?? 0;
  if (percent < 1) return null;

  // Flat: nearly everything (90%+) is discounted, all by the same amount.
  const flat = on.length >= products.length * 0.9 && on.every((d) => d === on[0]);
  return { products: products.length, discounted: on.length, percent, flat };
}

async function allProducts(source: Source, fetcher: Fetcher): Promise<Product[]> {
  const maxPages = Math.min(Math.max(Number(source.config.maxPages ?? 20), 1), 40);
  const products: Product[] = [];
  for (let page = 1; page <= maxPages; page++) {
    const url = new URL('/products.json', source.baseUrl);
    url.searchParams.set('limit', '250');
    url.searchParams.set('page', String(page));
    const body = await fetcher.getJson<{ products?: Product[] }>(url.toString());
    const batch = Array.isArray(body?.products) ? body.products : [];
    products.push(...batch);
    if (batch.length < 250) break;
  }
  return products;
}

export const shopifyAdapter: Adapter = {
  kind: 'shopify',
  // No discounted products means the sale is over (a failed fetch throws
  // instead, so it never ends a sale by mistake).
  emptyIsMeaningful: true,
  async fetchDeals(source, fetcher): Promise<ScrapedDeal[]> {
    const products = await allProducts(source, fetcher);
    const sale = summarize(products, {
      minProducts: Number(source.config.minProducts ?? 10),
      minShare: Number(source.config.minShare ?? 0.05),
    });
    if (!sale) return [];
    const saleUrl = typeof source.config.saleUrl === 'string'
      ? source.config.saleUrl
      : new URL('/collections/sale', source.baseUrl).toString();
    return [{
      externalId: 'storewide-sale',
      title: sale.flat ? `Flat ${sale.percent}% off everything` : `Sale: up to ${sale.percent}% off`,
      url: saleUrl,
      offer: { kind: sale.flat ? 'flat_percent_off' : 'up_to_percent_off', percent: sale.percent },
      description: `${sale.discounted} of ${sale.products} products are discounted.`,
      // Online and in store, nationwide; the source's brand page says where.
      cities: [],
    }];
  },
};
