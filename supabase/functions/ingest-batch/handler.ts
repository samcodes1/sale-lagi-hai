// HTTP handling for ingest-batch, separate from Deno for tests.
//
// The daily Claude run (docs/scraping/DAILY_RUN.md) reads deal pages and
// posts each source's full list here, once per run. The deals go through the
// same runner as the adapters: validation, the real-discount rule,
// de-duplication by fingerprint, and ending deals the source stopped
// listing. Whether they go live or wait for a moderator is the source's
// review_mode, never the caller's choice.
import { secretsMatch } from '../_shared/secret.ts';
import { runSource } from '../_shared/ingest/runner.ts';
import type { Adapter, Fetcher, IngestStore, RunResult, ScrapedDeal, Source } from '../_shared/ingest/types.ts';

export type Env = { get(name: string): string | undefined };

/** A brand the agent found that may not exist yet. */
export type NewBrand = { slug: string; name: string; nameUr?: string; category: string };

/** What the daily run reads first: the enabled agent sources. */
export type AgentSourceInfo = {
  slug: string;
  brand: string;
  baseUrl: string;
  /** The pages to read; the base URL when the source lists none. */
  pages: string[];
  notes: string | null;
  lastRunAt: string | null;
};

export type BatchDeps = {
  /** Every enabled agent source, for GET. */
  agentSources: () => Promise<AgentSourceInfo[]>;
  /** The enabled agent source with this slug, or null. */
  agentSource: (slug: string) => Promise<Source | null>;
  /** Adds the brand unverified if it is new. Throws for an unknown category. */
  ensureBrand: (sourceId: string, brand: NewBrand) => Promise<void>;
  store: IngestStore;
};

/** The most deals one post may carry, and the largest body accepted. */
export const MAX_DEALS = 500;
export const MAX_BODY_BYTES = 1_000_000;
const MAX_BRANDS = 200;

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

const isObject = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null && !Array.isArray(v);
const str = (v: unknown) => (typeof v === 'string' ? v : undefined);
const date = (v: unknown) => (typeof v === 'string' ? new Date(v) : undefined);

/** JSON from the caller, as a ScrapedDeal for the runner to validate. Dates
 * arrive as ISO strings; anything malformed is left for the runner to
 * reject, so it shows up in the run's errors. */
function toDeal(v: Record<string, unknown>): ScrapedDeal {
  const offer = isObject(v.offer) ? v.offer : {};
  const cards = Array.isArray(v.cards) ? v.cards.filter(isObject) : undefined;
  return {
    externalId: str(v.externalId) ?? '',
    title: str(v.title) ?? '',
    titleUr: str(v.titleUr),
    url: str(v.url) ?? '',
    description: str(v.description),
    brand: str(v.brand),
    scope: v.scope === 'online' ? 'online' : undefined,
    startsAt: date(v.startsAt),
    endsAt: date(v.endsAt),
    imageUrl: str(v.imageUrl),
    cities: Array.isArray(v.cities) ? v.cities.filter((c): c is string => typeof c === 'string') : undefined,
    cards: cards?.map((c) => ({
      bank: str(c.bank) ?? '',
      kind: c.kind === 'credit' || c.kind === 'debit' || c.kind === 'prepaid' ? c.kind : undefined,
    })),
    offer: {
      kind: (str(offer.kind) ?? 'text') as ScrapedDeal['offer']['kind'],
      percent: typeof offer.percent === 'number' ? offer.percent : undefined,
      amountOffPkr: typeof offer.amountOffPkr === 'number' ? offer.amountOffPkr : undefined,
      pricePkr: typeof offer.pricePkr === 'number' ? offer.pricePkr : undefined,
      originalPricePkr: typeof offer.originalPricePkr === 'number' ? offer.originalPricePkr : undefined,
      text: str(offer.text),
      textUr: str(offer.textUr),
    },
  };
}

const noFetcher: Fetcher = {
  getText: () => Promise.reject(new Error('ingest-batch does not fetch')),
  getJson: () => Promise.reject(new Error('ingest-batch does not fetch')),
};

export async function handle(request: Request, env: Env, deps: () => BatchDeps): Promise<Response> {
  if (request.method !== 'POST' && request.method !== 'GET') return json(405, { error: 'method_not_allowed' });
  const expected = env.get('INGEST_BATCH_SECRET') ?? '';
  if (expected.length < 32) return json(500, { error: 'not_configured' });
  if (!secretsMatch(request.headers.get('x-ingest-secret'), expected)) {
    return json(401, { error: 'unauthorized' });
  }
  if (request.method === 'GET') {
    try {
      return json(200, { sources: await deps().agentSources() });
    } catch (error) {
      console.error('ingest-batch sources failed', error instanceof Error ? error.name : 'error');
      return json(500, { error: 'sources_failed' });
    }
  }

  const text = await request.text();
  if (new TextEncoder().encode(text).length > MAX_BODY_BYTES) return json(413, { error: 'too_large' });
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return json(400, { error: 'invalid_json' });
  }
  if (!isObject(body) || typeof body.source !== 'string' || !Array.isArray(body.deals)) {
    return json(400, { error: 'expected {source, deals, brands?}' });
  }
  if (body.deals.length > MAX_DEALS) return json(413, { error: `at most ${MAX_DEALS} deals per post` });
  const brands = Array.isArray(body.brands) ? body.brands : [];
  if (brands.length > MAX_BRANDS) return json(413, { error: `at most ${MAX_BRANDS} brands per post` });

  const d = deps();
  try {
    const source = await d.agentSource(body.source);
    if (!source) return json(404, { error: 'unknown_source' });

    const brandErrors: string[] = [];
    for (const b of brands) {
      if (!isObject(b) || typeof b.slug !== 'string' || typeof b.name !== 'string' || typeof b.category !== 'string') {
        brandErrors.push('brand: expected {slug, name, category, nameUr?}');
        continue;
      }
      try {
        await d.ensureBrand(source.id, { slug: b.slug, name: b.name, nameUr: str(b.nameUr), category: b.category });
      } catch (error) {
        brandErrors.push(`brand ${b.slug}: ${error instanceof Error ? error.message.slice(0, 200) : 'error'}`);
      }
    }

    const deals = body.deals.filter(isObject).map(toDeal);
    // Allow an empty list to end every deal only when the caller says the
    // source really lists nothing now.
    const adapter: Adapter = {
      kind: 'agent',
      emptyIsMeaningful: body.complete === true,
      fetchDeals: async () => deals,
    };
    const result: RunResult = await runSource(source, adapter, noFetcher, d.store);
    return json(200, { ...result, errors: [...brandErrors, ...result.errors].slice(0, 50) });
  } catch (error) {
    console.error('ingest-batch failed', error instanceof Error ? error.name : 'error');
    return json(500, { error: 'ingest_failed' });
  }
}
