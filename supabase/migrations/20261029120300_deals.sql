-- Deals, where they apply (targets) and which cards they need (card offers).

create type public.deal_kind as enum (
  'brand_sale',      -- a brand's sale: "Khaadi: up to 50% off"
  'food_deal',       -- restaurants and cafés
  'card_offer',      -- needs a bank card; has card_offers rows
  'telecom_bundle',  -- Jazz, Zong, Telenor, Ufone
  'promo_code',      -- online codes; promo_code is set
  'service_deal',    -- salons, gyms, clinics
  'event',           -- cinema, events
  'other'
);

create type public.deal_status as enum (
  'draft',           -- being written
  'pending_review',  -- waiting for a moderator
  'published',       -- live
  'rejected',        -- a moderator said no
  'expired',         -- ended (set by the expiry job)
  'removed'          -- taken down
);

create type public.deal_scope as enum (
  'nationwide',      -- everywhere in Pakistan, in store
  'online',          -- online only; needs a link
  'local'            -- only in the cities and areas in deal_targets
);

-- Mirrors the app's DealOffer (lib/design_system/models/deal_offer.dart).
create type public.offer_kind as enum (
  'percent_off',        -- "-40%"
  'up_to_percent_off',  -- "Up to 50% off"
  'flat_percent_off',   -- "Flat 30% off"
  'amount_off',         -- "Rs 500 off"
  'fixed_price',        -- "Rs 999"
  'text'                -- "Buy 1 Get 1"
);

create type public.deal_source as enum (
  'business', 'user_submission', 'ingestion', 'staff'
);

create table public.deals (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references public.brands on delete cascade,
  category_id uuid not null references public.categories on delete restrict,
  kind public.deal_kind not null,
  scope public.deal_scope not null,
  status public.deal_status not null default 'draft',
  source public.deal_source not null,

  title_en text not null
    check (length(title_en) between 3 and 140 and title_en = btrim(title_en)),
  title_ur text
    check (length(title_ur) between 3 and 140 and title_ur = btrim(title_ur)),
  description_en text check (length(description_en) <= 2000),
  description_ur text check (length(description_ur) <= 2000),
  terms_en text check (length(terms_en) <= 2000),
  terms_ur text check (length(terms_ur) <= 2000),

  offer_kind public.offer_kind not null,
  percent smallint check (percent between 1 and 99),
  amount_off_pkr public.pkr check (amount_off_pkr > 0),
  price_pkr public.pkr,
  original_price_pkr public.pkr,
  offer_text_en text check (length(offer_text_en) between 1 and 60),
  offer_text_ur text check (length(offer_text_ur) between 1 and 60),

  promo_code text check (promo_code ~ '^[A-Za-z0-9_-]{2,40}$'),
  url public.https_url,
  image_path public.storage_path,

  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  verified_at timestamptz,
  published_at timestamptz,

  -- Ingestion: a stable hash of the source deal, for de-duplication, and
  -- where it was found.
  fingerprint text unique check (fingerprint ~ '^[a-f0-9]{16,128}$'),
  source_url public.https_url,

  created_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- English (and Roman Urdu) and Urdu text, without stemming: 'simple'
  -- treats both alike. Brand names are searched through brands.name.
  search_vector tsvector generated always as (
    setweight(to_tsvector('simple'::regconfig, coalesce(title_en, '')), 'A') ||
    setweight(to_tsvector('simple'::regconfig, coalesce(title_ur, '')), 'A') ||
    setweight(to_tsvector('simple'::regconfig,
      coalesce(description_en, '') || ' ' || coalesce(description_ur, '')), 'B')
  ) stored,

  check (ends_at is null or ends_at > starts_at),
  check (status <> 'published' or published_at is not null),

  -- The offer fields match the offer kind.
  check ((offer_kind in ('percent_off', 'up_to_percent_off', 'flat_percent_off'))
         = (percent is not null)),
  check ((offer_kind = 'amount_off') = (amount_off_pkr is not null)),
  check (offer_kind <> 'fixed_price' or price_pkr is not null),
  check (offer_kind <> 'text' or offer_text_en is not null),
  check (offer_text_ur is null or offer_text_en is not null),
  check (original_price_pkr is null or
         (price_pkr is not null and original_price_pkr > price_pkr)),
  -- Never a fake discount: a percentage shown next to two prices must be
  -- the real one, rounded down (as DealOffer.fromPrices does).
  check (offer_kind <> 'percent_off' or price_pkr is null
         or original_price_pkr is null
         or percent = ((original_price_pkr - price_pkr) * 100) / original_price_pkr),

  check (kind <> 'promo_code' or promo_code is not null),
  check (scope <> 'online' or url is not null)
);
create index deals_brand_idx on public.deals (brand_id);
create index deals_category_idx on public.deals (category_id);
create index deals_created_by_idx on public.deals (created_by);
create index deals_live_idx on public.deals (published_at desc)
  where status = 'published';
create index deals_status_ends_idx on public.deals (status, ends_at);
create index deals_search_idx on public.deals using gin (search_vector);
create index deals_title_trgm_idx on public.deals
  using gin (title_en extensions.gin_trgm_ops);

create trigger deals_touch before update on public.deals
  for each row execute function private.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Status changes follow one graph. Who may make each change is up to RLS.
-- ---------------------------------------------------------------------------
create function private.check_deal_status() returns trigger
language plpgsql set search_path = '' as $$
declare
  allowed boolean;
begin
  if tg_op = 'UPDATE' and new.status is distinct from old.status then
    allowed := case old.status
      when 'draft' then new.status in ('pending_review', 'published', 'removed')
      when 'pending_review' then new.status in ('draft', 'published', 'rejected')
      when 'published' then new.status in ('expired', 'removed', 'draft')
      when 'rejected' then new.status in ('draft', 'removed')
      when 'expired' then new.status in ('published', 'removed')
      when 'removed' then new.status in ('draft', 'published')
    end;
    if not allowed then
      raise exception 'a deal cannot go from % to %', old.status, new.status
        using errcode = '23514';
    end if;
  end if;

  if new.status = 'published' and
     (tg_op = 'INSERT' or old.status is distinct from 'published') then
    if new.ends_at is not null and new.ends_at <= now() then
      raise exception 'a deal that has ended cannot be published'
        using errcode = '23514';
    end if;
    new.published_at := coalesce(new.published_at, now());
  end if;
  return new;
end $$;
create trigger deals_status before insert or update on public.deals
  for each row execute function private.check_deal_status();

-- ---------------------------------------------------------------------------
-- Targets: the cities, or areas within a city, where a local deal applies.
-- ---------------------------------------------------------------------------
create table public.deal_targets (
  id bigint generated always as identity primary key,
  deal_id uuid not null references public.deals on delete cascade,
  city_id uuid not null references public.cities on delete restrict,
  -- Null: the whole city.
  area_id uuid,
  foreign key (area_id, city_id) references public.areas (id, city_id)
    on delete cascade,
  unique nulls not distinct (deal_id, city_id, area_id)
);
create index deal_targets_city_area_idx on public.deal_targets (city_id, area_id);

-- ---------------------------------------------------------------------------
-- Card offers: which cards a card_offer deal needs, and its conditions.
-- ---------------------------------------------------------------------------
alter table public.card_products add unique (id, bank_id);

create table public.card_offers (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid not null references public.deals on delete cascade,
  bank_id uuid not null references public.banks on delete restrict,
  -- Null: any card of this bank (optionally only one kind or network).
  card_product_id uuid,
  card_kind public.card_kind,
  card_network public.card_network,
  -- ISO weekdays (1 = Monday) the offer runs on; null means every day.
  days_of_week smallint[] check (
    cardinality(days_of_week) between 1 and 7
    and days_of_week <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]),
  min_spend_pkr public.pkr,
  max_discount_pkr public.pkr check (max_discount_pkr > 0),
  foreign key (card_product_id, bank_id)
    references public.card_products (id, bank_id) on delete cascade,
  -- A specific product already fixes the kind and network.
  check (card_product_id is null or (card_kind is null and card_network is null)),
  unique nulls not distinct (deal_id, bank_id, card_product_id, card_kind, card_network)
);
create index card_offers_deal_idx on public.card_offers (deal_id);
create index card_offers_bank_idx on public.card_offers (bank_id);
create index card_offers_product_idx on public.card_offers (card_product_id, bank_id);

-- ---------------------------------------------------------------------------
-- Rules that span tables, checked at commit so a deal and its rows can be
-- written in one transaction:
-- - targets only on local deals, card offers only on card_offer deals;
-- - a published local deal has at least one target;
-- - a published card_offer deal has at least one card offer.
-- ---------------------------------------------------------------------------
-- Security definer: the rule must see every row, whatever the caller's RLS.
create function private.check_deal_children(deal uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  d record;
begin
  select id, kind, scope, status into d from public.deals where id = deal;
  if not found then
    return;  -- deleted; children cascade
  end if;
  if d.scope <> 'local' and exists (
    select 1 from public.deal_targets t where t.deal_id = d.id
  ) then
    raise exception 'only local deals have targets' using errcode = '23514';
  end if;
  if d.kind <> 'card_offer' and exists (
    select 1 from public.card_offers c where c.deal_id = d.id
  ) then
    raise exception 'only card_offer deals have card offers' using errcode = '23514';
  end if;
  if d.status = 'published' and d.scope = 'local' and not exists (
    select 1 from public.deal_targets t where t.deal_id = d.id
  ) then
    raise exception 'a published local deal needs at least one city or area'
      using errcode = '23514';
  end if;
  if d.status = 'published' and d.kind = 'card_offer' and not exists (
    select 1 from public.card_offers c where c.deal_id = d.id
  ) then
    raise exception 'a published card offer needs at least one card'
      using errcode = '23514';
  end if;
end $$;

create function private.check_deal_children_trigger() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_name = 'deals' then
    perform private.check_deal_children(new.id);
  else
    perform private.check_deal_children(
      case when tg_op = 'DELETE' then old.deal_id else new.deal_id end);
    if tg_op = 'UPDATE' and new.deal_id is distinct from old.deal_id then
      perform private.check_deal_children(old.deal_id);
    end if;
  end if;
  return null;
end $$;

revoke execute on function private.check_deal_children(uuid) from public;

create constraint trigger deals_children after insert or update of kind, scope, status
  on public.deals deferrable initially deferred
  for each row execute function private.check_deal_children_trigger();
create constraint trigger deal_targets_rules after insert or update or delete
  on public.deal_targets deferrable initially deferred
  for each row execute function private.check_deal_children_trigger();
create constraint trigger card_offers_rules after insert or update or delete
  on public.card_offers deferrable initially deferred
  for each row execute function private.check_deal_children_trigger();

alter table public.deals enable row level security;
alter table public.deal_targets enable row level security;
alter table public.card_offers enable row level security;
