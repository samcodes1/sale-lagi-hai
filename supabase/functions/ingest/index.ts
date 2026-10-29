// Edge Function entry point (Deno): runs due ingestion sources. pg_cron
// calls it with x-dispatcher-secret (verify_jwt = false). The store writes
// through the private ingestion functions over SUPABASE_DB_URL.
import postgres from 'npm:postgres@3.4.7';
import { shopifyAdapter } from '../_shared/ingest/adapters/shopify.ts';
import { PoliteFetcher } from '../_shared/ingest/fetcher.ts';
import type { Adapter, IngestStore, Source } from '../_shared/ingest/types.ts';
import { handle } from './handler.ts';

const sql = postgres(Deno.env.get('SUPABASE_DB_URL') ?? '', { max: 2, prepare: false });

const store: IngestStore = {
  startRun: async (sourceId) => (await sql`select private.ingest_start_run(${sourceId}) as id`)[0].id as string,
  upsertDeal: async (sourceId, deal) =>
    (await sql`select private.ingest_upsert_deal(${sourceId}, ${sql.json(deal)}) as r`)[0].r,
  endMissing: async (sourceId, seen) =>
    (await sql`select private.ingest_end_missing(${sourceId}, ${seen}::text[]) as n`)[0].n as number,
  finishRun: async (runId, result) => {
    await sql`select private.ingest_finish_run(${runId}, ${sql.json(result)})`;
  },
};

// Adapters by source kind; each sub-phase adds its own (3.2 Shopify, 3.3
// bank offers, 3.4 telecom bundles).
const adapters: Record<string, Adapter> = {
  shopify: shopifyAdapter,
};

Deno.serve((request) =>
  handle(request, Deno.env, () => ({
    dueSources: async (max) =>
      (await sql`
        select id, slug, kind::text as kind, base_url as "baseUrl", config,
               (select slug from public.brands b where b.id = s.brand_id) as "brandSlug"
        from private.ingest_due_sources(${max}) s`) as unknown as Source[],
    store,
    fetcher: new PoliteFetcher(),
    adapters,
    now: () => Date.now(),
  })));
