-- Ingestion (sub-phase 3.1): the source registry, run logs and the
-- functions the ingestion runner writes through. The runner
-- (supabase/functions/_shared/ingest/) fetches politely and validates; these
-- functions map a validated deal onto the schema, de-duplicate by
-- fingerprint and end deals a source stops listing.

create type public.ingest_kind as enum ('shopify', 'bank_offers', 'telecom_bundles', 'web_page');

-- One row per site we read. Staff add sources disabled, check the site's
-- robots.txt and terms, then enable them.
create table public.ingest_sources (
  id uuid primary key default gen_random_uuid(),
  slug public.slug not null unique,
  kind public.ingest_kind not null,
  brand_id uuid not null references public.brands on delete cascade,
  base_url public.https_url not null,
  config jsonb not null default '{}' check (jsonb_typeof(config) = 'object'),
  enabled boolean not null default false,
  -- auto: deals go live straight away; review: they wait for a moderator.
  review_mode text not null default 'review' check (review_mode in ('auto', 'review')),
  min_interval interval not null default '6 hours'
    check (min_interval between interval '1 hour' and interval '7 days'),
  last_run_at timestamptz,
  notes text check (length(notes) <= 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index ingest_sources_brand_idx on public.ingest_sources (brand_id);
create trigger ingest_sources_touch before update on public.ingest_sources
  for each row execute function private.touch_updated_at();

create table public.ingest_runs (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references public.ingest_sources on delete cascade,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running' check (status in ('running', 'ok', 'partial', 'failed')),
  fetched integer not null default 0 check (fetched >= 0),
  created integer not null default 0 check (created >= 0),
  updated integer not null default 0 check (updated >= 0),
  ended integer not null default 0 check (ended >= 0),
  rejected integer not null default 0 check (rejected >= 0),
  -- At most 50 short messages: no response bodies.
  errors jsonb not null default '[]' check (jsonb_typeof(errors) = 'array' and jsonb_array_length(errors) <= 50),
  check ((status = 'running') = (finished_at is null))
);
create index ingest_runs_source_idx on public.ingest_runs (source_id, started_at desc);

-- What each source last listed, for de-duplication and ending deals.
create table private.ingest_items (
  source_id uuid not null references public.ingest_sources on delete cascade,
  fingerprint text not null check (fingerprint ~ '^[a-f0-9]{64}$'),
  deal_id uuid not null references public.deals on delete cascade,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  ended_at timestamptz,
  primary key (source_id, fingerprint)
);
create index ingest_items_deal_idx on private.ingest_items (deal_id);

alter table public.ingest_sources enable row level security;
alter table public.ingest_runs enable row level security;

-- Staff only: moderators read, admins manage sources.
grant select on public.ingest_sources, public.ingest_runs to authenticated;
grant insert, update, delete on public.ingest_sources to authenticated;
create policy "ingest sources: staff read" on public.ingest_sources
  for select to authenticated using ((select private.is_moderator()));
create policy "ingest sources: admins insert" on public.ingest_sources
  for insert to authenticated with check ((select private.is_admin()));
create policy "ingest sources: admins update" on public.ingest_sources
  for update to authenticated using ((select private.is_admin()))
  with check ((select private.is_admin()));
create policy "ingest sources: admins delete" on public.ingest_sources
  for delete to authenticated using ((select private.is_admin()));
create policy "ingest runs: staff read" on public.ingest_runs
  for select to authenticated using ((select private.is_moderator()));

-- ---------------------------------------------------------------------------
-- Writing deals. `deal` is the runner's NormalizedDeal as JSON:
-- {fingerprint, externalId, title, url, description?, offer: {kind, percent?,
--  amountOffPkr?, pricePkr?, originalPricePkr?, text?}, startsAt?, endsAt?,
--  imageUrl?, cards?: [{bank, kind?}], cities?: [slug], scope?}
-- Returns 'created', 'updated' or 'unchanged'.
-- ---------------------------------------------------------------------------
create function private.ingest_upsert_deal(source uuid, deal jsonb) returns text
language plpgsql security definer set search_path = '' as $$
declare
  src public.ingest_sources;
  brand public.brands;
  existing public.deals;
  item private.ingest_items;
  fp text := deal ->> 'fingerprint';
  offer jsonb := deal -> 'offer';
  cities text[] := array(select jsonb_array_elements_text(coalesce(deal -> 'cities', '[]')));
  cards jsonb := coalesce(deal -> 'cards', '[]');
  is_card boolean;
  deal_scope public.deal_scope;
  live_status public.deal_status;
  deal_id uuid;
  changed boolean;
begin
  select * into src from public.ingest_sources where id = source;
  if src.id is null or not src.enabled then
    raise exception 'unknown or disabled source %', source using errcode = '22023';
  end if;
  select * into brand from public.brands where id = src.brand_id;

  -- Only banks and cities we know count: a deal naming none of them is a
  -- plain nationwide deal, not a card offer or local deal with no cards or
  -- places (which could never be published).
  is_card := exists (select 1 from jsonb_array_elements(cards) card
                     join public.banks b on b.slug = card ->> 'bank');
  deal_scope := case
    when exists (select 1 from public.cities c where c.slug = any(cities)) then 'local'
    when deal ->> 'scope' = 'online' then 'online'
    else 'nationwide'
  end;
  live_status := case src.review_mode when 'auto' then 'published' else 'pending_review' end;

  select i.* into item from private.ingest_items i where i.source_id = source and i.fingerprint = fp;
  if item.deal_id is not null then
    select * into existing from public.deals d where d.id = item.deal_id;
  end if;

  if existing.id is null then
    insert into public.deals (
      brand_id, category_id, kind, scope, status, source, title_en, description_en,
      offer_kind, percent, amount_off_pkr, price_pkr, original_price_pkr, offer_text_en,
      url, image_path, starts_at, ends_at, verified_at, fingerprint, source_url)
    values (
      brand.id, brand.category_id,
      case when is_card then 'card_offer' else coalesce(src.config ->> 'deal_kind', 'brand_sale') end::public.deal_kind,
      deal_scope, 'draft', 'ingestion', deal ->> 'title', deal ->> 'description',
      (offer ->> 'kind')::public.offer_kind, (offer ->> 'percent')::smallint,
      (offer ->> 'amountOffPkr')::integer, (offer ->> 'pricePkr')::integer,
      (offer ->> 'originalPricePkr')::integer, offer ->> 'text',
      deal ->> 'url', null, coalesce((deal ->> 'startsAt')::timestamptz, now()),
      (deal ->> 'endsAt')::timestamptz, now(), fp, deal ->> 'url')
    returning id into deal_id;

    insert into public.deal_targets (deal_id, city_id)
    select deal_id, c.id from public.cities c where c.slug = any(cities)
    on conflict do nothing;
    insert into public.card_offers (deal_id, bank_id, card_kind)
    select deal_id, b.id, (card ->> 'kind')::public.card_kind
    from jsonb_array_elements(cards) card join public.banks b on b.slug = card ->> 'bank'
    on conflict do nothing;

    update public.deals set status = live_status where id = deal_id;
    insert into private.ingest_items (source_id, fingerprint, deal_id) values (source, fp, deal_id);
    update public.ingest_sources set last_run_at = now() where id = source;
    return 'created';
  end if;

  changed := (existing.title_en, existing.description_en, existing.offer_kind, existing.percent,
              existing.amount_off_pkr, existing.price_pkr, existing.original_price_pkr,
              existing.offer_text_en, existing.url, existing.ends_at)
     is distinct from (deal ->> 'title', deal ->> 'description', (offer ->> 'kind')::public.offer_kind,
              (offer ->> 'percent')::smallint, (offer ->> 'amountOffPkr')::integer,
              (offer ->> 'pricePkr')::integer, (offer ->> 'originalPricePkr')::integer,
              offer ->> 'text', deal ->> 'url', (deal ->> 'endsAt')::timestamptz);

  -- Staff removed or rejected it: leave it alone, just note we saw it.
  if existing.status in ('removed', 'rejected') then
    update private.ingest_items set last_seen_at = now(), ended_at = null
    where source_id = source and fingerprint = fp;
    return 'unchanged';
  end if;

  update public.deals set
    title_en = deal ->> 'title',
    description_en = deal ->> 'description',
    offer_kind = (offer ->> 'kind')::public.offer_kind,
    percent = (offer ->> 'percent')::smallint,
    amount_off_pkr = (offer ->> 'amountOffPkr')::integer,
    price_pkr = (offer ->> 'pricePkr')::integer,
    original_price_pkr = (offer ->> 'originalPricePkr')::integer,
    offer_text_en = offer ->> 'text',
    url = deal ->> 'url',
    ends_at = (deal ->> 'endsAt')::timestamptz,
    verified_at = now(),
    -- An ended deal that the source lists again is live again.
    status = case when existing.status = 'expired' then live_status else existing.status end
  where id = existing.id;
  update private.ingest_items set last_seen_at = now(), ended_at = null
  where source_id = source and fingerprint = fp;
  return case when changed or existing.status = 'expired' then 'updated' else 'unchanged' end;
end $$;

-- Ends this source's live deals that the latest run did not list.
create function private.ingest_end_missing(source uuid, seen text[]) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  n integer;
begin
  with gone as (
    update private.ingest_items i set ended_at = now()
    where i.source_id = source and i.ended_at is null and not (i.fingerprint = any(seen))
    returning i.deal_id
  )
  update public.deals d set status = 'expired'
  from gone where d.id = gone.deal_id and d.status = 'published';
  get diagnostics n = row_count;
  return n;
end $$;

create function private.ingest_start_run(source uuid) returns uuid
language sql volatile security definer set search_path = '' as $$
  insert into public.ingest_runs (source_id) values (source) returning id;
$$;

create function private.ingest_finish_run(run uuid, result jsonb) returns void
language sql volatile security definer set search_path = '' as $$
  update public.ingest_runs set
    finished_at = now(),
    status = result ->> 'status',
    fetched = (result ->> 'fetched')::integer,
    created = (result ->> 'created')::integer,
    updated = (result ->> 'updated')::integer,
    ended = (result ->> 'ended')::integer,
    rejected = (result ->> 'rejected')::integer,
    errors = coalesce((select jsonb_agg(e) from (
      select left(e, 300) as e from jsonb_array_elements_text(coalesce(result -> 'errors', '[]')) e limit 50) x), '[]')
  where id = run;
  update public.ingest_sources set last_run_at = now()
  where id = (select source_id from public.ingest_runs where id = run);
$$;

-- Sources due for a run (enabled, past their interval), oldest first.
create function private.ingest_due_sources(max_sources integer default 10)
returns setof public.ingest_sources
language sql stable security definer set search_path = '' as $$
  select * from public.ingest_sources s
  where s.enabled and (s.last_run_at is null or s.last_run_at < now() - s.min_interval)
  order by s.last_run_at nulls first
  limit least(greatest(max_sources, 1), 50);
$$;
