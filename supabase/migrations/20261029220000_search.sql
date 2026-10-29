-- Search and filters (sub-phase 4.6). Replaces the 2.3 search with one
-- that also filters by area, bank, discount and "ending soon", works
-- without words (filters only), and pages by keyset like every other
-- list, so the app pages it the same way and never shows a deal twice.

drop function public.search_deals(text, uuid, uuid[], integer, integer);
drop function private.search_hits(text, uuid, uuid[]);

-- The filters search adds to the feed's (city, categories). Null or empty
-- means "any".
-- - area: local deals for that area or for its whole city. Nationwide and
--   online deals are available in every area, so they stay.
-- - banks: card offers of one of these banks.
-- - min_percent: a percentage off of at least this (1 to 99); other kinds
--   of offer are left out.
-- - ending_within_hours: ends within this many hours (1 to 336).
create function private.matches_search_filters(
  deal uuid, scope public.deal_scope, percent smallint, ends_at timestamptz,
  area uuid, banks uuid[], min_percent integer, ending_within_hours integer
) returns boolean language sql stable as $$
  select (area is null or scope <> 'local' or exists (
            select 1 from public.deal_targets t
            join public.areas a on a.id = area and a.city_id = t.city_id
            where t.deal_id = deal and (t.area_id is null or t.area_id = area)))
     and (banks is null or cardinality(banks) = 0 or exists (
            select 1 from public.card_offers co
            where co.deal_id = deal and co.bank_id = any(banks)))
     and (min_percent is null or percent >= least(greatest(min_percent, 1), 99))
     and (ending_within_hours is null or ends_at <= now()
            + make_interval(hours => least(greatest(ending_within_hours, 1), 336)));
$$;

-- Live deals matching a query, ranked: full text, fuzzy title and fuzzy
-- brand name, each through its own index. Every filter applies here,
-- before the cap, so a filtered search never loses matches to unfiltered
-- ones. Only rows anyone may see: live deals of active brands in active
-- categories.
-- PL/pgSQL with EXECUTE so each search is planned with its actual words:
-- a generic plan can't estimate an unknown query's selectivity and scans.
create function private.search_hits(
  query text,
  city uuid default null,
  categories uuid[] default null,
  area uuid default null,
  banks uuid[] default null,
  min_percent integer default null,
  ending_within_hours integer default null
)
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
      and private.matches_search_filters(d.id, d.scope, d.percent, d.ends_at,
            %4$L::uuid, %5$L::uuid[], %6$L::integer, %7$L::integer)
    -- The best 250: search shows at most 5 pages of 50.
    order by 2 desc, d.id
    limit 250
  $q$, text_query, city, categories, area, banks, min_percent, ending_within_hours);
end $$;

-- ---------------------------------------------------------------------------
-- Search: with words (2 to 100 characters), the best matches first; with
-- none, the newest deals that pass the filters (the app asks only when at
-- least one filter is set). Page with the last row's id: the next page
-- starts after it in the same order. An `after_id` that is no longer in
-- the results (it ended, or was hidden) ends the list.
-- ---------------------------------------------------------------------------
create function public.search_deals(
  query text default null,
  city_id uuid default null,
  category_ids uuid[] default null,
  area_id uuid default null,
  bank_ids uuid[] default null,
  min_percent integer default null,
  ending_within_hours integer default null,
  after_id uuid default null,
  page_size integer default 20
) returns setof public.deal_card
language plpgsql stable security invoker
set search_path = ''
as $$
declare
  words text := nullif(btrim(search_deals.query), '');
begin
  if words is not null then
    return query
    with hits as materialized (
      select h.id, h.rank from private.search_hits(
        words, search_deals.city_id, search_deals.category_ids, search_deals.area_id,
        search_deals.bank_ids, search_deals.min_percent, search_deals.ending_within_hours) h
    ), ranked as materialized (
      select h.rank, d.* from hits h join public.deal_cards d on d.id = h.id
    )
    select r.id, r.brand_id, r.brand_slug, r.brand_name, r.brand_name_ur,
      r.brand_logo_path, r.brand_is_verified, r.category_id, r.category_slug,
      r.kind, r.scope, r.status, r.title_en, r.title_ur, r.offer_kind, r.percent,
      r.amount_off_pkr, r.price_pkr, r.original_price_pkr, r.offer_text_en,
      r.offer_text_ur, r.promo_code, r.url, r.image_path, r.starts_at, r.ends_at,
      r.verified_at, r.published_at, r.card_banks, false, null::integer
    from ranked r
    where search_deals.after_id is null
       or (r.rank, r.published_at, r.id) < (
            select k.rank, k.published_at, k.id from ranked k where k.id = search_deals.after_id)
    order by r.rank desc, r.published_at desc, r.id desc
    limit private.page_size(search_deals.page_size);
  else
    return query
    select d.*, false, null::integer
    from public.deal_cards d
    where private.is_live(d.status, d.starts_at, d.ends_at)
      and private.shown_in_city(d.id, d.scope, search_deals.city_id)
      and private.in_categories(d.category_id, search_deals.category_ids)
      and private.matches_search_filters(d.id, d.scope, d.percent, d.ends_at,
            search_deals.area_id, search_deals.bank_ids, search_deals.min_percent,
            search_deals.ending_within_hours)
      and (search_deals.after_id is null or (d.published_at, d.id) < (
            select a.published_at, a.id from public.deals a where a.id = search_deals.after_id))
    order by d.published_at desc, d.id desc
    limit private.page_size(search_deals.page_size);
  end if;
end $$;

grant execute on function
  private.matches_search_filters(uuid, public.deal_scope, smallint, timestamptz, uuid, uuid[], integer, integer)
  to anon, authenticated, service_role;
grant execute on function
  private.search_hits(text, uuid, uuid[], uuid, uuid[], integer, integer)
  to anon, authenticated, service_role;
revoke execute on function
  public.search_deals(text, uuid, uuid[], uuid, uuid[], integer, integer, uuid, integer)
  from public;
grant execute on function
  public.search_deals(text, uuid, uuid[], uuid, uuid[], integer, integer, uuid, integer)
  to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Brand suggestions while typing: active brands whose English name starts
-- with, or fuzzily matches, the words (or whose Urdu name starts with
-- them). 1 to 60 characters; at most 10.
-- The matching runs in a private security-definer helper over active
-- brands only (RLS would keep the non-leakproof LIKE and trigram operators
-- off the indexes); the RPC then reads the brands under RLS.
-- ---------------------------------------------------------------------------
create index brands_name_ur_trgm_idx on public.brands
  using gin (name_ur extensions.gin_trgm_ops) with (fastupdate = off);

create function private.brand_hits(query text, page_size integer)
returns table (id uuid, rank integer)
language plpgsql stable security definer
set search_path = ''
set pg_trgm.word_similarity_threshold = '0.45'
-- At most 10: lets the caller join brands by primary key.
rows 10
as $$
declare
  words text := btrim(query);
  -- The words as a LIKE prefix, with LIKE's own characters escaped.
  prefix text := replace(replace(replace(btrim(query), '\', '\\'), '%', '\%'), '_', '\_') || '%';
begin
  if words is null or length(words) not between 1 and 60 then
    return;
  end if;
  -- Literals (format %L, so no injection), as in search_hits: only a
  -- literal pattern lets each condition use its trigram index.
  return query execute format($q$
    with hits as (
      select b.id, b.name from public.brands b where b.is_active and b.name ilike %1$L
      union
      select b.id, b.name from public.brands b where b.is_active and b.name operator(extensions.%%>) %2$L
      union
      select b.id, b.name from public.brands b where b.is_active and b.name_ur like %1$L
    )
    select h.id, (row_number() over (
             order by (h.name ilike %1$L) desc, extensions.word_similarity(%2$L, h.name) desc, h.name
           ))::integer
    from hits h
    order by 2
    limit %3$s
  $q$, prefix, words, least(greatest(coalesce(page_size, 6), 1), 10));
end $$;

create function public.brand_suggestions(query text, page_size integer default 6)
returns table (id uuid, slug text, name text, name_ur text, category_id uuid,
               logo_path text, is_verified boolean)
language sql stable security invoker
set search_path = ''
as $$
  select b.id, b.slug::text, b.name::text, b.name_ur::text, b.category_id,
         b.logo_path::text, b.is_verified
  from private.brand_hits(query, page_size) h
  join public.brands b on b.id = h.id
  order by h.rank;
$$;
grant execute on function private.brand_hits(text, integer)
  to anon, authenticated, service_role;
revoke execute on function public.brand_suggestions(text, integer) from public;
grant execute on function public.brand_suggestions(text, integer)
  to anon, authenticated, service_role;
