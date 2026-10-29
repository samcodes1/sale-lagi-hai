-- Read APIs (sub-phase 2.3): the queries the apps run, as RPCs.
--
-- - All are SECURITY INVOKER: RLS decides what each caller sees, so a
--   shopper gets live deals and a business member also their drafts where
--   that makes sense. They add filtering, ordering and paging only.
-- - Pages hold at most 50 rows. Long lists use keyset cursors (the last
--   row's sort values), never offsets, so deep pages stay cheap and
--   scraping is slow.
-- - Every RPC returns public.deal_card rows, the app's DealCardData.
-- - They are plain SQL without SET options, so the planner inlines them
--   into the caller's query (filters and LIMIT reach the indexes). As
--   invoker functions with fully qualified names they need no pinned
--   search_path, and the API roles cannot create objects in public.

-- One row per deal, in the shape the deal card needs.
create view public.deal_cards with (security_invoker = true) as
select
  d.id, d.brand_id, b.slug::text as brand_slug, b.name::text as brand_name,
  b.name_ur::text as brand_name_ur, b.logo_path::text as brand_logo_path,
  b.is_verified as brand_is_verified,
  d.category_id, c.slug::text as category_slug,
  d.kind, d.scope, d.status,
  d.title_en, d.title_ur, d.offer_kind, d.percent,
  d.amount_off_pkr::int as amount_off_pkr, d.price_pkr::int as price_pkr,
  d.original_price_pkr::int as original_price_pkr,
  d.offer_text_en, d.offer_text_ur, d.promo_code, d.url::text as url,
  d.image_path::text as image_path,
  d.starts_at, d.ends_at, d.verified_at, d.published_at,
  -- Banks whose cards the deal needs ("HBL", "Meezan"), for the card chips.
  coalesce((
    select array_agg(distinct bk.short_name order by bk.short_name)
    from public.card_offers co join public.banks bk on bk.id = co.bank_id
    where co.deal_id = d.id
  ), '{}') as card_banks
from public.deals d
join public.brands b on b.id = d.brand_id
join public.categories c on c.id = d.category_id;

grant select on public.deal_cards to anon, authenticated;

-- A deal card plus what a list adds: Featured, and distance for "near me".
create type public.deal_card as (
  id uuid, brand_id uuid, brand_slug text, brand_name text, brand_name_ur text,
  brand_logo_path text, brand_is_verified boolean,
  category_id uuid, category_slug text,
  kind public.deal_kind, scope public.deal_scope, status public.deal_status,
  title_en text, title_ur text, offer_kind public.offer_kind, percent smallint,
  amount_off_pkr int, price_pkr int, original_price_pkr int,
  offer_text_en text, offer_text_ur text, promo_code text, url text, image_path text,
  starts_at timestamptz, ends_at timestamptz, verified_at timestamptz,
  published_at timestamptz, card_banks text[],
  is_featured boolean, distance_m integer
);

-- ---------------------------------------------------------------------------
-- Shared filters. They are plain SQL without SET options so the planner
-- inlines them into the calling query (and can use indexes). They are
-- security invoker and qualify every name, so they need no pinned
-- search_path.
-- ---------------------------------------------------------------------------

-- Live: published, started and not ended. Takes columns, not the row, so
-- it inlines without computing the whole card.
create function private.is_live(
  status public.deal_status, starts_at timestamptz, ends_at timestamptz
) returns boolean language sql stable as $$
  select status = 'published' and starts_at <= now()
     and (ends_at is null or ends_at > now());
$$;

-- Shown in a city: nationwide and online deals everywhere; local deals in
-- the cities and areas they target, once the city is live.
create function private.shown_in_city(deal uuid, scope public.deal_scope, city uuid)
returns boolean language sql stable as $$
  select scope <> 'local' or (
    city is not null
    and exists (select 1 from public.cities ci where ci.id = city and ci.is_live)
    and exists (select 1 from public.deal_targets t where t.deal_id = deal and t.city_id = city)
  );
$$;

-- In one of these categories, or their subcategories. Null or empty: any.
create function private.in_categories(category uuid, wanted uuid[])
returns boolean language sql stable as $$
  select wanted is null or cardinality(wanted) = 0 or category = any(wanted) or exists (
    select 1 from public.categories c where c.id = category and c.parent_id = any(wanted)
  );
$$;

-- What the current user follows (nothing for anon). Security definer so
-- anon can call feed (follows is not readable by anon); it only ever reads
-- the caller's own follows. The feed uses it only in uncorrelated
-- subqueries, which run once per call (hashed), never once per row.
create function private.my_follows()
returns table (brand_id uuid, category_id uuid, bank_id uuid, city_id uuid)
language sql stable security definer set search_path = '' rows 20 as $$
  select f.brand_id, f.category_id, f.bank_id, f.city_id
  from public.follows f
  where f.user_id = (select auth.uid());
$$;

-- Saves per deal in the last `days` days (1-30). Counts only, never who
-- saved: saves are private (RLS), so trending reads them through this.
create function private.recent_save_counts(days integer)
returns table (deal_id uuid, saves bigint)
language sql stable security definer set search_path = '' as $$
  select s.deal_id, count(*)
  from public.saves s
  where s.created_at > now() - make_interval(days => least(greatest(days, 1), 30))
  group by s.deal_id;
$$;

create function private.page_size(requested integer) returns integer
language sql immutable as $$
  select least(greatest(coalesce(requested, 20), 1), 50);
$$;

grant execute on function private.is_live(public.deal_status, timestamptz, timestamptz),
  private.shown_in_city(uuid, public.deal_scope, uuid),
  private.in_categories(uuid, uuid[]), private.page_size(integer),
  private.my_follows(), private.recent_save_counts(integer)
  to anon, authenticated, service_role;

-- Index lookups that RLS would block. Postgres applies RLS policies before
-- any non-leakproof condition, and full-text (@@), fuzzy (<%) and spatial
-- (st_dwithin) matching are all non-leakproof, so under RLS they can't use
-- their indexes. These helpers run the lookup as the owner and return only
-- rows that are public anyway (live deals and active outlets of active
-- brands). The calling RPC then reads the cards with RLS as usual.

-- Live deals matching a query, ranked: full text, fuzzy title and fuzzy
-- brand name, each through its own index. The city and category filters
-- apply here, before the cap, so a filtered search never loses matches to
-- unfiltered ones. Only rows anyone may see: live deals of active brands
-- in active categories.
-- PL/pgSQL with EXECUTE so each search is planned with its actual words:
-- a generic plan can't estimate an unknown query's selectivity and scans.
create function private.search_hits(query text, city uuid default null, categories uuid[] default null)
returns table (id uuid, rank real)
language plpgsql stable security definer
set search_path = ''
-- Forgives one or two wrong letters ("biriyani" for "biryani").
set pg_trgm.word_similarity_threshold = '0.45'
rows 50
as $$
declare
  text_query text := btrim(query);
begin
  if text_query is null or length(text_query) not between 2 and 100 then
    return;
  end if;
  -- The words go in as a quoted literal (format %L, so no injection) rather
  -- than a parameter: only a literal lets every condition use its index.
  return query execute format($q$
    with hits as (
      select raw.id from public.deals raw
      where raw.search_vector @@ websearch_to_tsquery('simple', %1$L)
      union
      select raw.id from public.deals raw
      where raw.title_en operator(extensions.%%>) %1$L
      union
      select raw.id from public.deals raw
      where raw.brand_id in (
        select b.id from public.brands b where b.name operator(extensions.%%>) %1$L)
    )
    select d.id, greatest(ts_rank(d.search_vector, websearch_to_tsquery('simple', %1$L)),
                          extensions.word_similarity(%1$L, d.title_en),
                          extensions.word_similarity(%1$L, b.name))::real
    from hits h
    join public.deals d on d.id = h.id
    join public.brands b on b.id = d.brand_id
    join public.categories c on c.id = d.category_id
    where b.is_active and c.is_active and private.is_live(d.status, d.starts_at, d.ends_at)
      and private.shown_in_city(d.id, d.scope, %2$L::uuid)
      and private.in_categories(d.category_id, %3$L::uuid[])
    -- The best 250: search shows at most 5 pages of 50.
    order by 2 desc, d.id
    limit 250
  $q$, text_query, city, categories);
end $$;

-- Active outlets of active brands within radius_m (100 m to 20 km).
create function private.outlets_near(lat double precision, lng double precision, radius_m integer)
returns table (brand_id uuid, city_id uuid, area_id uuid, distance double precision)
language sql stable security definer set search_path = '' as $$
  with here as (
    select extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography as g
    where lat between -90 and 90 and lng between -180 and 180
  )
  select o.brand_id, o.city_id, o.area_id, extensions.st_distance(o.location, here.g)
  from here, public.outlets o
  join public.brands b on b.id = o.brand_id
  where o.is_active and b.is_active
    and extensions.st_dwithin(o.location, here.g, least(greatest(radius_m, 100), 20000));
$$;

-- ---------------------------------------------------------------------------
-- Feed: newest live deals for a city, optionally by category or only from
-- what the user follows. Page with the last row's (published_at, id).
-- ---------------------------------------------------------------------------
create function public.feed(
  city_id uuid default null,
  category_ids uuid[] default null,
  following_only boolean default false,
  after_published_at timestamptz default null,
  after_id uuid default null,
  page_size integer default 20
) returns setof public.deal_card
language sql stable security invoker as $$
  select d.*, false, null::integer
  from public.deal_cards d
  where private.is_live(d.status, d.starts_at, d.ends_at)
    and private.shown_in_city(d.id, d.scope, feed.city_id)
    and private.in_categories(d.category_id, feed.category_ids)
    -- Followed, by the alert planner's rules: the brand; the category or
    -- its parent; a bank whose cards it needs; or, for local deals, a city
    -- it targets. Every subquery is uncorrelated: each runs once per call.
    and (not following_only
         or d.brand_id in (select f.brand_id from private.my_follows() f)
         or d.category_id in (
              select c.id from public.categories c
              where c.id in (select f.category_id from private.my_follows() f)
                 or c.parent_id in (select f.category_id from private.my_follows() f))
         or d.id in (
              select co.deal_id from public.card_offers co
              where co.bank_id in (select f.bank_id from private.my_follows() f))
         or (d.scope = 'local' and d.id in (
              select t.deal_id from public.deal_targets t
              where t.city_id in (select f.city_id from private.my_follows() f))))
    and (after_published_at is null
         or (d.published_at, d.id) < (after_published_at, coalesce(after_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
  order by d.published_at desc, d.id desc
  limit private.page_size(page_size);
$$;

-- ---------------------------------------------------------------------------
-- Featured: live paid placements for a slot (city and category aware),
-- highest priority first. Always shown with the "Featured" label.
-- ---------------------------------------------------------------------------
create function public.featured_deals(
  slot public.placement_slot,
  city_id uuid default null,
  category_id uuid default null,
  page_size integer default 5
) returns setof public.deal_card
language sql stable security invoker as $$
  with best as (
    -- A deal with several matching placements is listed once, at its best.
    select distinct on (p.deal_id) p.deal_id, p.priority, p.starts_at
    from public.placements p
    where p.slot = featured_deals.slot
      and p.status = 'active' and now() >= p.starts_at and now() < p.ends_at
      and (p.city_id is null or p.city_id = featured_deals.city_id)
      and (featured_deals.category_id is null or p.category_id = featured_deals.category_id)
    order by p.deal_id, p.priority desc, p.starts_at
  )
  select d.*, true, null::integer
  from best p
  join public.deal_cards d on d.id = p.deal_id
  where private.is_live(d.status, d.starts_at, d.ends_at)
    and private.shown_in_city(d.id, d.scope, featured_deals.city_id)
  order by p.priority desc, p.starts_at, d.id
  limit least(private.page_size(page_size), 10);
$$;

-- ---------------------------------------------------------------------------
-- Trending: live deals saved most in the last `days` days, recent ones
-- weighted up. One page (top 50 at most); not paged.
-- ---------------------------------------------------------------------------
create function public.trending_deals(
  city_id uuid default null,
  days integer default 7,
  page_size integer default 20
) returns setof public.deal_card
language sql stable security invoker as $$
  -- Rank ids on the deals table first; build cards for the page only.
  with ranked as (
    select d.id, d.published_at,
           coalesce(recent.saves, 0) / (1 + extract(epoch from now() - d.published_at) / 86400.0) as score
    from public.deals d
    -- The same joins as deal_cards (under RLS), so no ranked deal is lost
    -- after the LIMIT (inactive brand or category).
    join public.brands b on b.id = d.brand_id
    join public.categories c on c.id = d.category_id
    left join private.recent_save_counts(trending_deals.days) recent on recent.deal_id = d.id
    where private.is_live(d.status, d.starts_at, d.ends_at)
      -- shown_in_city, written out: the city check runs once per call.
      and (d.scope <> 'local' or (
        exists (select 1 from public.cities ci where ci.id = trending_deals.city_id and ci.is_live)
        and exists (select 1 from public.deal_targets t
                    where t.deal_id = d.id and t.city_id = trending_deals.city_id)))
    order by score desc, d.published_at desc, d.id desc
    limit private.page_size(page_size)
  )
  select d.*, false, null::integer
  from ranked r
  join public.deal_cards d on d.id = r.id
  order by r.score desc, r.published_at desc, r.id desc;
$$;

-- ---------------------------------------------------------------------------
-- Near me: live deals with an active outlet within radius_m (at most
-- 20 km), nearest first, with the distance to the nearest outlet. The
-- location is used for this query only and never stored.
-- ---------------------------------------------------------------------------
create function public.nearby_deals(
  lat double precision,
  lng double precision,
  radius_m integer default 3000,
  page_size integer default 20
) returns setof public.deal_card
language sql stable security invoker as $$
  -- Rank (deal, nearest outlet) on deal ids first; build cards for the
  -- page only. Nationwide deals take their brand's nearest outlet (one row
  -- per brand, not per outlet); local deals their nearest outlet in a
  -- live target city and area.
  with near as (
    select * from private.outlets_near(lat, lng, radius_m)
  ),
  brand_near as (
    select n.brand_id, min(n.distance) as distance from near n group by n.brand_id
  ),
  candidates as (
    select d.id, bn.distance
    from public.deals d
    join brand_near bn on bn.brand_id = d.brand_id
    join public.categories c on c.id = d.category_id
    where d.scope = 'nationwide' and private.is_live(d.status, d.starts_at, d.ends_at)
    union all
    select d.id, min(n.distance)
    from public.deals d
    join public.categories c on c.id = d.category_id
    join near n on n.brand_id = d.brand_id
    join public.deal_targets t on t.deal_id = d.id and t.city_id = n.city_id
      and (t.area_id is null or t.area_id = n.area_id)
    join public.cities ci on ci.id = t.city_id and ci.is_live
    where d.scope = 'local' and private.is_live(d.status, d.starts_at, d.ends_at)
    group by d.id
  ),
  ranked as (
    select cand.id, cand.distance from candidates cand
    order by cand.distance, cand.id
    limit private.page_size(page_size)
  )
  select d.*, false, round(r.distance)::integer
  from ranked r
  join public.deal_cards d on d.id = r.id
  order by r.distance, r.id;
$$;

-- ---------------------------------------------------------------------------
-- Deals for my cards: live card offers that match a card product the user
-- added (the exact product, or any card of the bank, optionally limited to
-- a kind or network).
-- ---------------------------------------------------------------------------
create function public.deals_for_my_cards(
  city_id uuid default null,
  after_published_at timestamptz default null,
  after_id uuid default null,
  page_size integer default 20
) returns setof public.deal_card
language sql stable security invoker as $$
  select d.*, false, null::integer
  from public.deal_cards d
  where d.kind = 'card_offer'
    and private.is_live(d.status, d.starts_at, d.ends_at)
    and private.shown_in_city(d.id, d.scope, deals_for_my_cards.city_id)
    and exists (
      select 1
      from public.card_offers co
      join public.user_cards uc on uc.user_id = (select auth.uid())
      join public.card_products cp on cp.id = uc.card_product_id
      where co.deal_id = d.id and co.bank_id = cp.bank_id
        and (co.card_product_id is null or co.card_product_id = cp.id)
        and (co.card_kind is null or co.card_kind = cp.kind)
        and (co.card_network is null or co.card_network = cp.network))
    and (after_published_at is null
         or (d.published_at, d.id) < (after_published_at, coalesce(after_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
  order by d.published_at desc, d.id desc
  limit private.page_size(page_size);
$$;

-- ---------------------------------------------------------------------------
-- Search: full-text on deal titles and descriptions, plus fuzzy matching
-- on titles and brand names (typos, Roman Urdu spellings). Queries are 2 to
-- 100 characters. Best matches first; at most 5 pages.
-- ---------------------------------------------------------------------------
create function public.search_deals(
  query text,
  city_id uuid default null,
  category_ids uuid[] default null,
  page integer default 0,
  page_size integer default 20
) returns setof public.deal_card
language sql stable security invoker as $$
  select d.*, false, null::integer
  from private.search_hits(query, search_deals.city_id, search_deals.category_ids) h
  join public.deal_cards d on d.id = h.id
  where private.is_live(d.status, d.starts_at, d.ends_at)
    and private.shown_in_city(d.id, d.scope, search_deals.city_id)
    and private.in_categories(d.category_id, search_deals.category_ids)
  order by h.rank desc, d.published_at desc, d.id desc
  limit private.page_size(page_size)
  offset private.page_size(page_size) * least(greatest(coalesce(page, 0), 0), 4);
$$;

-- ---------------------------------------------------------------------------
-- A brand's page: its live deals, newest first. (The brand itself comes
-- from the brands table; category pages use feed with category_ids.)
-- ---------------------------------------------------------------------------
create function public.brand_deals(
  brand_slug text,
  city_id uuid default null,
  after_published_at timestamptz default null,
  after_id uuid default null,
  page_size integer default 20
) returns setof public.deal_card
language sql stable security invoker as $$
  select d.*, false, null::integer
  from public.deal_cards d
  where d.brand_id = (select b.id from public.brands b where b.slug = brand_deals.brand_slug)
    and private.is_live(d.status, d.starts_at, d.ends_at)
    and private.shown_in_city(d.id, d.scope, brand_deals.city_id)
    and (after_published_at is null
         or (d.published_at, d.id) < (after_published_at, coalesce(after_id, 'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
  order by d.published_at desc, d.id desc
  limit private.page_size(page_size);
$$;

revoke execute on function
  public.feed(uuid, uuid[], boolean, timestamptz, uuid, integer),
  public.featured_deals(public.placement_slot, uuid, uuid, integer),
  public.trending_deals(uuid, integer, integer),
  public.nearby_deals(double precision, double precision, integer, integer),
  public.deals_for_my_cards(uuid, timestamptz, uuid, integer),
  public.search_deals(text, uuid, uuid[], integer, integer),
  public.brand_deals(text, uuid, timestamptz, uuid, integer)
  from public;
grant execute on function
  public.feed(uuid, uuid[], boolean, timestamptz, uuid, integer),
  public.featured_deals(public.placement_slot, uuid, uuid, integer),
  public.trending_deals(uuid, integer, integer),
  public.nearby_deals(double precision, double precision, integer, integer),
  public.search_deals(text, uuid, uuid[], integer, integer),
  public.brand_deals(text, uuid, timestamptz, uuid, integer)
  to anon, authenticated, service_role;
-- Needs a signed-in user's cards.
grant execute on function public.deals_for_my_cards(uuid, timestamptz, uuid, integer)
  to authenticated, service_role;

-- Search and trending access paths.
create index saves_recent_idx on public.saves (deal_id, created_at);
drop index public.saves_deal_idx;  -- saves_recent_idx covers it
-- Search indexes skip GIN's pending list: deals are read far more than
-- written, and a pending list (after an ingestion burst, until autovacuum)
-- makes the planner fall back to scanning.
alter index public.deals_search_idx set (fastupdate = off);
alter index public.deals_title_trgm_idx set (fastupdate = off);
alter index public.brands_name_trgm_idx set (fastupdate = off);
-- Brand pages: one brand's deals, newest first (also serves the FK).
create index deals_brand_published_idx on public.deals (brand_id, published_at desc);
drop index public.deals_brand_idx;

grant execute on function private.search_hits(text, uuid, uuid[]),
  private.outlets_near(double precision, double precision, integer)
  to anon, authenticated, service_role;
