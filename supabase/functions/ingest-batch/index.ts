// Edge Function entry point (Deno): takes one agent source's deals from the
// daily Claude run (verify_jwt = false; it checks x-ingest-secret itself).
// Writes through the private ingestion functions over SUPABASE_DB_URL.
import postgres from 'npm:postgres@3.4.7';
import type { IngestStore, Source } from '../_shared/ingest/types.ts';
import { type AgentSourceInfo, handle } from './handler.ts';

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

Deno.serve((request) =>
  handle(request, Deno.env, () => ({
    agentSources: async () =>
      (await sql`
        select s.slug, b.slug as brand, s.base_url as "baseUrl",
               case when jsonb_typeof(s.config -> 'pages') = 'array' and jsonb_array_length(s.config -> 'pages') > 0
                 then array(select jsonb_array_elements_text(s.config -> 'pages'))
                 else array[s.base_url::text] end as pages,
               s.notes, s.last_run_at as "lastRunAt"
        from private.ingest_agent_sources() s join public.brands b on b.id = s.brand_id`) as unknown as AgentSourceInfo[],
    agentSource: async (slug) =>
      ((await sql`
        select id, slug, kind::text as kind, base_url as "baseUrl", config,
               (select slug from public.brands b where b.id = s.brand_id) as "brandSlug"
        from private.ingest_agent_source(${slug}) s`) as unknown as Source[])[0] ?? null,
    ensureBrand: async (sourceId, b) => {
      await sql`select private.ingest_ensure_brand(${sourceId}, ${b.slug}, ${b.name}, ${b.nameUr ?? ''}, ${b.category})`;
    },
    store,
  })));
