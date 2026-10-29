// HTTP handling for the ingest function, separate from Deno for tests.
// Called by pg_cron with the shared dispatcher secret: runs the sources
// that are due, one after another, within a time budget.
import { secretsMatch } from '../_shared/secret.ts';
import { runSource } from '../_shared/ingest/runner.ts';
import type { Adapter, Fetcher, IngestStore, RunResult, Source } from '../_shared/ingest/types.ts';

export type Env = { get(name: string): string | undefined };

export type IngestDeps = {
  dueSources: (max: number) => Promise<Source[]>;
  store: IngestStore;
  fetcher: Fetcher;
  adapters: Record<string, Adapter>;
  now: () => number;
};

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

/** Wall-clock budget per invocation, below the platform's limit. */
export const BUDGET_MS = 120_000;

export async function handle(request: Request, env: Env, deps: () => IngestDeps): Promise<Response> {
  if (request.method !== 'POST') return json(405, { error: 'method_not_allowed' });
  const expected = env.get('DISPATCHER_SECRET') ?? '';
  if (expected.length < 32) return json(500, { error: 'not_configured' });
  if (!secretsMatch(request.headers.get('x-dispatcher-secret'), expected)) {
    return json(401, { error: 'unauthorized' });
  }

  const d = deps();
  const started = d.now();
  const runs: { source: string; status: RunResult['status'] | 'skipped'; created: number; updated: number; ended: number }[] = [];
  try {
    for (const source of await d.dueSources(10)) {
      if (d.now() - started > BUDGET_MS) {
        runs.push({ source: source.slug, status: 'skipped', created: 0, updated: 0, ended: 0 });
        continue;
      }
      const adapter = d.adapters[source.kind];
      if (!adapter) {
        runs.push({ source: source.slug, status: 'skipped', created: 0, updated: 0, ended: 0 });
        continue;
      }
      try {
        const r = await runSource(source, adapter, d.fetcher, d.store);
        runs.push({ source: source.slug, status: r.status, created: r.created, updated: r.updated, ended: r.ended });
      } catch (error) {
        // The store itself failed (database down): record and move on.
        console.error('ingest run failed', source.slug, error instanceof Error ? error.name : 'error');
        runs.push({ source: source.slug, status: 'failed', created: 0, updated: 0, ended: 0 });
      }
    }
  } catch (error) {
    console.error('ingest failed', error instanceof Error ? error.name : 'error');
    return json(500, { error: 'ingest_failed' });
  }
  return json(200, { runs });
}
