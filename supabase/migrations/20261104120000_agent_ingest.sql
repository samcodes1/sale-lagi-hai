-- Agent ingestion: a scheduled Claude session reads deal pages and posts
-- what it found to the ingest-batch Edge Function, which validates it with
-- the same runner as the adapters. See docs/scraping/DAILY_RUN.md.
--
-- An `agent` source can list many merchants' deals (a bank's offers page),
-- so each deal may name its brand; unknown brands are added unverified.
-- Deals also carry Urdu titles and offer text, which the agent translates.

alter type public.ingest_kind add value if not exists 'agent';

create or replace function private.ingest_upsert_deal(source uuid, deal jsonb) returns text
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
  -- An agent source reads pages that list many merchants (a bank's offers):
  -- each deal names its brand, which must exist (see ingest_ensure_brand).
  if src.kind::text = 'agent' and deal ? 'brand' then
    select * into brand from public.brands where slug = deal ->> 'brand';
    if brand.id is null then
      raise exception 'unknown brand %', deal ->> 'brand' using errcode = '22023';
    end if;
  else
    select * into brand from public.brands where id = src.brand_id;
  end if;

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
      brand_id, category_id, kind, scope, status, source, title_en, title_ur, description_en,
      offer_kind, percent, amount_off_pkr, price_pkr, original_price_pkr, offer_text_en,
      offer_text_ur, url, image_path, starts_at, ends_at, verified_at, fingerprint, source_url)
    values (
      brand.id, brand.category_id,
      case when is_card then 'card_offer' else coalesce(src.config ->> 'deal_kind', 'brand_sale') end::public.deal_kind,
      deal_scope, 'draft', 'ingestion', deal ->> 'title', deal ->> 'titleUr', deal ->> 'description',
      (offer ->> 'kind')::public.offer_kind, (offer ->> 'percent')::smallint,
      (offer ->> 'amountOffPkr')::integer, (offer ->> 'pricePkr')::integer,
      (offer ->> 'originalPricePkr')::integer, offer ->> 'text',
      offer ->> 'textUr', deal ->> 'url', null, coalesce((deal ->> 'startsAt')::timestamptz, now()),
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

  changed := (existing.title_en, existing.title_ur, existing.description_en, existing.offer_kind, existing.percent,
              existing.amount_off_pkr, existing.price_pkr, existing.original_price_pkr,
              existing.offer_text_en, existing.offer_text_ur, existing.url, existing.ends_at)
     is distinct from (deal ->> 'title', deal ->> 'titleUr', deal ->> 'description', (offer ->> 'kind')::public.offer_kind,
              (offer ->> 'percent')::smallint, (offer ->> 'amountOffPkr')::integer,
              (offer ->> 'pricePkr')::integer, (offer ->> 'originalPricePkr')::integer,
              offer ->> 'text', offer ->> 'textUr', deal ->> 'url', (deal ->> 'endsAt')::timestamptz);

  -- Staff removed or rejected it: leave it alone, just note we saw it.
  if existing.status in ('removed', 'rejected') then
    update private.ingest_items set last_seen_at = now(), ended_at = null
    where source_id = source and fingerprint = fp;
    return 'unchanged';
  end if;

  update public.deals set
    title_en = deal ->> 'title',
    title_ur = deal ->> 'titleUr',
    description_en = deal ->> 'description',
    offer_kind = (offer ->> 'kind')::public.offer_kind,
    percent = (offer ->> 'percent')::smallint,
    amount_off_pkr = (offer ->> 'amountOffPkr')::integer,
    price_pkr = (offer ->> 'pricePkr')::integer,
    original_price_pkr = (offer ->> 'originalPricePkr')::integer,
    offer_text_en = offer ->> 'text',
    offer_text_ur = offer ->> 'textUr',
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

-- The cron-driven ingest function has no adapter for agent sources: leave
-- them out, so they never crowd out sources it can run.
create or replace function private.ingest_due_sources(max_sources integer default 10)
returns setof public.ingest_sources
language sql stable security definer set search_path = '' as $$
  select * from public.ingest_sources s
  where s.enabled and s.kind::text <> 'agent'
    and (s.last_run_at is null or s.last_run_at < now() - s.min_interval)
  order by s.last_run_at nulls first
  limit least(greatest(max_sources, 1), 50);
$$;

-- The enabled agent source with this slug, for ingest-batch.
create function private.ingest_agent_source(source_slug text)
returns setof public.ingest_sources
language sql stable security definer set search_path = '' as $$
  select * from public.ingest_sources s
  where s.slug = source_slug and s.enabled and s.kind::text = 'agent';
$$;

-- Every enabled agent source, for the daily run's list.
create function private.ingest_agent_sources()
returns setof public.ingest_sources
language sql stable security definer set search_path = '' as $$
  select * from public.ingest_sources s
  where s.enabled and s.kind::text = 'agent'
  order by s.last_run_at nulls first, s.slug;
$$;

-- Adds a brand an agent source found, unverified, if it is not known yet.
-- Returns its id. Existing brands are never changed.
create function private.ingest_ensure_brand(
  source uuid, brand_slug text, brand_name text, brand_name_ur text, category_slug text
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  src public.ingest_sources;
  found uuid;
  category uuid;
begin
  select * into src from public.ingest_sources where id = source;
  if src.id is null or not src.enabled or src.kind::text <> 'agent' then
    raise exception 'unknown, disabled or non-agent source %', source using errcode = '22023';
  end if;
  select id into found from public.brands where slug = brand_slug;
  if found is not null then return found; end if;
  select id into category from public.categories where slug = category_slug;
  if category is null then
    raise exception 'unknown category %', category_slug using errcode = '22023';
  end if;
  insert into public.brands (slug, name, name_ur, category_id, is_verified)
  values (brand_slug, brand_name, nullif(brand_name_ur, ''), category, false)
  on conflict (slug) do nothing
  returning id into found;
  return coalesce(found, (select id from public.brands where slug = brand_slug));
end $$;

revoke all on function private.ingest_agent_sources() from public;
revoke all on function private.ingest_agent_source(text) from public;
revoke all on function private.ingest_ensure_brand(uuid, text, text, text, text) from public;
