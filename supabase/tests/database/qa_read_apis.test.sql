-- QA (sub-phase 2.3): read API correctness under ties, hostile input and
-- the city rollout. "QA BUG" assertions FAIL until the bug in
-- docs/qa/2.3.md is fixed; TODO assertions are S4 findings.
begin;
select plan(18);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;
update public.brands set is_active = true;

-- 45 deals published in one statement share one published_at (an
-- ingestion batch does this).
insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, offer_kind, percent)
select (select brand_b from w), (select category_id from public.brands where id = (select brand_b from w)),
       'brand_sale', 'nationwide', 'published', 'staff', 'Tie deal ' || g, 'percent_off', 10
from generate_series(1, 45) g;

select tests.authenticate_as_anon();
create temp table seen (id uuid);
grant all on seen to anon;
do $$
declare pa timestamptz; pid uuid; r record; n int; pages int := 0;
begin
  loop
    n := 0;
    for r in select * from public.feed(null, null, false, pa, pid, 7) loop
      insert into seen values (r.id);
      pa := r.published_at; pid := r.id; n := n + 1;
    end loop;
    pages := pages + 1;
    exit when n = 0 or pages > 20;
  end loop;
end $$;
select is((select count(*) from seen), (select count(*) from public.deals where status = 'published'),
  'paging the feed by 7 visits every live deal');
select is((select count(distinct id) from seen), (select count(*) from seen), 'and none twice');

-- Clamps.
select is((select count(*) from public.feed(null, null, false, null, null, 1000)), 47::bigint,
  'a huge page_size still returns at most 50 rows');
select is((select count(*) from public.feed(null, null, false, null, null, -5)), 1::bigint,
  'a negative page_size returns one row');
-- (4.6: search pages by keyset; the 250-hit cap still bounds it.)
select is((select count(*) from public.search_deals('tie deal', after_id => gen_random_uuid(), page_size => 50)), 0::bigint,
  'a search page after a deal not in the results is empty');

-- Hostile search input never errors and never leaks drafts.
create temp table bad_queries (q text);
grant select on bad_queries to anon;
insert into bad_queries values ($$'; drop table public.deals; --$$), ($$\' or 1=1 --$$),
  ($$%' union select null --$$), ('"unterminated'), ('!!!:*&|'), ('$q$ %L %s %I'),
  (repeat('x', 100)), (repeat('x', 5000)), (repeat('ب', 100)), (E'tab\there'), (null), (''), ('a');
create function pg_temp.search_errors() returns bigint language plpgsql as $$
declare r record; n bigint := 0;
begin
  for r in select q from bad_queries loop
    begin
      perform count(*) from public.search_deals(r.q);
    exception when others then n := n + 1;
    end;
  end loop;
  return n;
end $$;
grant execute on function pg_temp.search_errors() to anon;
select is(pg_temp.search_errors(), 0::bigint, 'hostile search strings return results or nothing, never an error');
select tests.clear_authentication();
select is((select count(*) from public.deals), 49::bigint, 'and the deals table is still there');

-- Hostile coordinates.
select tests.authenticate_as_anon();
select is((select count(*) from public.nearby_deals('NaN', 'NaN', 1000)), 0::bigint, 'NaN coordinates find nothing');
select is((select count(*) from public.nearby_deals('Infinity', '-Infinity', 1000)), 0::bigint,
  'infinite coordinates find nothing');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- QA BUG 2.3-R1 (S3): nearby_deals ignores cities.is_live. A local deal in
-- a city that isn't live is hidden from the feed but shown in "Near me".
-- ---------------------------------------------------------------------------
create temp table dark as select tests.make_city('qa-dark-city', false) as city,
  tests.make_brand(null, 'qa-dark-brand') as brand;
grant select on dark to anon;
insert into public.outlets (brand_id, city_id, name, address, location)
  select brand, city, 'Dark outlet', 'Street 1, dark city', 'SRID=4326;POINT(74.35 31.52)' from dark;
create temp table dark_deal as select tests.make_deal((select brand from dark), 'draft', 'local') as id;
grant select on dark_deal to anon;
insert into public.deal_targets (deal_id, city_id) select (select id from dark_deal), city from dark;
update public.deals set status = 'published' where id = (select id from dark_deal);
select tests.authenticate_as_anon();
select is((select count(*) from public.feed((select city from dark)) where id = (select id from dark_deal)), 0::bigint,
  'the feed hides local deals of a city that is not live');
select is((select count(*) from public.nearby_deals(31.52, 74.35, 1000) where id = (select id from dark_deal)), 0::bigint,
  'QA BUG 2.3-R1: so does nearby_deals');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- QA BUG 2.3-R2 (S3): following_only disagrees with the alert planner.
-- - Following a city makes every deal shown in that city "followed"
--   (nationwide ones too), so the filter does nothing. The planner only
--   alerts city followers about local deals targeting the city.
-- - Following a parent category misses its subcategories' deals; the
--   planner and category pages include them.
-- ---------------------------------------------------------------------------
create temp table cats as select tests.make_category('qa-parent') as parent;
alter table cats add column child uuid;
update cats set child = tests.make_category('qa-child', parent);
create temp table sub_deal as select tests.make_deal((select brand_b from w), 'draft') as id;
update public.deals set category_id = (select child from cats), status = 'published' where id = (select id from sub_deal);
grant select on cats, sub_deal to authenticated;

insert into public.follows (user_id, city_id) select shopper, city from w;
select tests.authenticate_as((select shopper from w));
select is((select count(*) from public.feed((select city from w), null, true) where scope <> 'local'), 0::bigint,
  'QA BUG 2.3-R2: following a city does not turn every nationwide deal into a followed one');
select tests.clear_authentication();
delete from public.follows;
insert into public.follows (user_id, category_id) select shopper, parent from w, cats;
select tests.authenticate_as((select shopper from w));
select is((select count(*) from public.feed(null, null, true) where id = (select id from sub_deal)), 1::bigint,
  'QA BUG 2.3-R2: following a category includes its subcategories');
select tests.clear_authentication();

-- ===========================================================================
-- Round 2 (commit 50a4ac6).
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- QA BUG 2.3-R8 (S2, regression from the R5 fix): search_hits keeps the
-- best 250 hits before search_deals applies the city and category
-- filters, so a filtered search misses matches whenever 250 better ones
-- exist elsewhere. Expected: the filters apply before the cap.
-- ---------------------------------------------------------------------------
create temp table r8 as select tests.make_category('qa-r8-a') as a, tests.make_category('qa-r8-b') as b,
  tests.make_city('qa-r8-other', true) as other_city;
grant select on r8 to anon;
-- 300 strong matches in category A; 10 weaker ones in category B.
insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, offer_kind, percent)
select (select brand_b from w), (select a from r8), 'brand_sale', 'nationwide', 'published', 'staff',
       'Zebra zebra print sale ' || g, 'percent_off', 10 from generate_series(1, 300) g;
insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, offer_kind, percent, description_en)
select (select brand_b from w), (select b from r8), 'brand_sale', 'nationwide', 'published', 'staff',
       'Striped scarf ' || g, 'percent_off', 10, 'with a zebra pattern' from generate_series(1, 10) g;
-- 300 strong local matches in another live city; 5 weaker ones in ours.
insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, offer_kind, percent)
select (select brand_b from w), (select a from r8), 'food_deal', 'local', 'draft', 'staff',
       'Karahi karahi night ' || g, 'percent_off', 10 from generate_series(1, 300) g;
insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, offer_kind, percent, description_en)
select (select brand_b from w), (select a from r8), 'food_deal', 'local', 'draft', 'staff',
       'Dinner deal ' || g, 'percent_off', 10, 'karahi for two' from generate_series(1, 5) g;
insert into public.deal_targets (deal_id, city_id)
  select id, (select other_city from r8) from public.deals where title_en like 'Karahi karahi night%';
insert into public.deal_targets (deal_id, city_id)
  select id, (select city from w) from public.deals where title_en like 'Dinner deal%';
update public.deals set status = 'published'
  where status = 'draft' and (title_en like 'Karahi karahi night%' or title_en like 'Dinner deal%');
set constraints all immediate;
select tests.authenticate_as_anon();
select is((select count(*) from public.search_deals('zebra', null, array[(select b from r8)], page_size => 50)), 10::bigint,
  'QA BUG 2.3-R8: a category-filtered search finds all 10 matches in the category');
select is((select count(*) from public.search_deals('karahi', (select city from w), null, page_size => 50)), 5::bigint,
  'QA BUG 2.3-R8: a city search finds the city''s 5 local matches');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- QA BUG 2.3-R9 (S3, regression from the R5 fix): trending and nearby
-- rank and LIMIT on deals, then join deal_cards, which also drops deals
-- whose category is inactive. If the top-ranked deals are in a category
-- staff switched off, the page comes back short or empty.
-- ---------------------------------------------------------------------------
create temp table r9 as select tests.make_category('qa-r9-off') as off_cat;
grant select on r9 to anon;
insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, offer_kind, percent)
select (select brand_b from w), (select off_cat from r9), 'brand_sale', 'nationwide', 'published', 'staff',
       'Hidden category deal ' || g, 'percent_off', 10 from generate_series(1, 30) g;
insert into public.saves (user_id, deal_id)
  select u, d.id from public.deals d, (select tests.create_user() as u from generate_series(1, 3)) x
  where d.title_en like 'Hidden category deal%';
update public.categories set is_active = false where id = (select off_cat from r9);
select tests.authenticate_as_anon();
select is((select count(*) from public.trending_deals(null, 7, 20)), 20::bigint,
  'QA BUG 2.3-R9: trending still fills its page when its top deals are in an inactive category');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- Round 1 S4 findings, fixed in round 2 (kept as regression checks).
-- ---------------------------------------------------------------------------
-- QA 2.3-R3 (S4, fixed in round 2): a deal with two live placements is featured once.
insert into public.placements (business_id, deal_id, slot, starts_at, ends_at, status, city_id)
  select biz_b, live_b, 'home_featured', now() - interval '1 hour', now() + interval '1 hour', 'active', c
  from w, unnest(array[null, (select city from w)]) c;
select tests.authenticate_as_anon();
select is((select count(*) - count(distinct id) from public.featured_deals('home_featured', (select city from w))),
  0::bigint, 'featured_deals lists each deal once');
select tests.clear_authentication();

-- QA 2.3-R4 (S4, fixed in round 2): an empty category list means no filter.
select tests.authenticate_as_anon();
select is((select count(*) from public.feed(null, '{}')), (select count(*) from public.feed(null, null)),
  'category_ids = {} means no filter');
select tests.clear_authentication();

select * from finish();
rollback;
