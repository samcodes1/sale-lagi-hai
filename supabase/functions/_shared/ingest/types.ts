// The contract between ingestion adapters and the runner.

export type OfferKind =
  | 'percent_off'
  | 'up_to_percent_off'
  | 'flat_percent_off'
  | 'amount_off'
  | 'fixed_price'
  | 'text';

/** One deal as an adapter found it, before validation. */
export type ScrapedDeal = {
  /** Stable id at the source (product id, offer slug); used for de-duplication. */
  externalId: string;
  title: string;
  url: string;
  offer: {
    kind: OfferKind;
    percent?: number;
    amountOffPkr?: number;
    pricePkr?: number;
    originalPricePkr?: number;
    text?: string;
  };
  description?: string;
  startsAt?: Date;
  endsAt?: Date;
  imageUrl?: string;
  /** Card offers: bank slugs and optional card kind. */
  cards?: { bank: string; kind?: 'credit' | 'debit' | 'prepaid' }[];
  /** City slugs for local deals; empty or absent means nationwide/online. */
  cities?: string[];
};

/** A registered source (public.ingest_sources). */
export type Source = {
  id: string;
  slug: string;
  kind: string;
  baseUrl: string;
  brandSlug: string;
  config: Record<string, unknown>;
};

export type Fetcher = {
  getText(url: string, accept?: string): Promise<string>;
  getJson<T>(url: string): Promise<T>;
};

export type Adapter = {
  kind: string;
  fetchDeals(source: Source, fetcher: Fetcher): Promise<ScrapedDeal[]>;
};

/** A validated deal, ready for private.ingest_upsert_deal. */
export type NormalizedDeal = ScrapedDeal & { fingerprint: string };

/** Where the runner writes (the database in production, memory in tests). */
export type IngestStore = {
  startRun(sourceId: string): Promise<string>;
  upsertDeal(sourceId: string, deal: NormalizedDeal): Promise<'created' | 'updated' | 'unchanged'>;
  /** Ends deals from this source that were not seen in this run. */
  endMissing(sourceId: string, seenFingerprints: string[]): Promise<number>;
  finishRun(runId: string, result: RunResult): Promise<void>;
};

export type RunResult = {
  status: 'ok' | 'partial' | 'failed';
  fetched: number;
  created: number;
  updated: number;
  ended: number;
  rejected: number;
  errors: string[];
};
