// Runs one source: fetch with its adapter, validate each deal, upsert it,
// end the ones the source no longer lists, and log the run. One bad item
// never stops the rest; a failed fetch fails the run without ending
// anything (a site being down is not every deal ending).
import { normalize } from './normalize.ts';
import type { Adapter, Fetcher, IngestStore, RunResult, Source } from './types.ts';

const MAX_DEALS_PER_RUN = 2000;

export async function runSource(
  source: Source,
  adapter: Adapter,
  fetcher: Fetcher,
  store: IngestStore,
  now: () => Date = () => new Date(),
): Promise<RunResult> {
  const runId = await store.startRun(source.id);
  const result: RunResult = { status: 'ok', fetched: 0, created: 0, updated: 0, ended: 0, rejected: 0, errors: [] };

  let scraped;
  try {
    scraped = await adapter.fetchDeals(source, fetcher);
  } catch (error) {
    result.status = 'failed';
    result.errors.push(`fetch: ${describe(error)}`);
    await store.finishRun(runId, result);
    return result;
  }

  result.fetched = scraped.length;
  if (scraped.length > MAX_DEALS_PER_RUN) {
    result.errors.push(`source listed ${scraped.length} deals; only the first ${MAX_DEALS_PER_RUN} were read`);
    scraped = scraped.slice(0, MAX_DEALS_PER_RUN);
  }

  const seen = new Set<string>();
  for (const raw of scraped) {
    try {
      const checked = await normalize(source, raw, now());
      if ('rejected' in checked) {
        result.rejected++;
        if (result.errors.length < 50) result.errors.push(`rejected ${raw.externalId}: ${checked.rejected}`);
        continue;
      }
      if (seen.has(checked.deal.fingerprint)) continue; // listed twice in one run
      seen.add(checked.deal.fingerprint);
      const outcome = await store.upsertDeal(source.id, checked.deal);
      if (outcome === 'created') result.created++;
      else if (outcome === 'updated') result.updated++;
    } catch (error) {
      result.rejected++;
      if (result.errors.length < 50) result.errors.push(`item ${raw.externalId}: ${describe(error)}`);
    }
  }

  // Ending deals only makes sense when the source answered with a list; an
  // empty answer from a source that had deals is suspicious, not a sale end.
  const emptyIsMeaningful = adapter.emptyIsMeaningful === true || source.config.allowEmpty === true;
  if (seen.size > 0 || (scraped.length === 0 && emptyIsMeaningful)) {
    result.ended = await store.endMissing(source.id, [...seen]);
  }
  if (result.rejected > 0) result.status = seen.size > 0 ? 'partial' : 'failed';
  await store.finishRun(runId, result);
  return result;
}

// Error text for run logs: the message only, never response bodies.
function describe(error: unknown): string {
  return error instanceof Error ? `${error.name}: ${error.message}`.slice(0, 300) : 'unknown error';
}
