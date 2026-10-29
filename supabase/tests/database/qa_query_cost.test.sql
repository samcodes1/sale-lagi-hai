-- QA (sub-phase 2.3): work per call, measured as plan loops rather than
-- wall-clock time so the check is stable. "QA BUG" assertions FAIL until
-- the bug in docs/qa/2.3.md is fixed.
begin;
select plan(5);

-- 50 brands x 20 live deals, 1,000 outlets within 20 km of one point.
create temp table x as select tests.make_city('qa-cost-city') as city, tests.make_category('qa-cost-food') as food;
insert into public.brands (slug, name, category_id)
  select 'qa-cost-brand-' || i, 'Cost Brand ' || i, (select food from x) from generate_series(1, 50) i;
insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, offer_kind, percent)
  select b.id, b.category_id, 'brand_sale', 'nationwide', 'published', 'staff', 'Cost deal ' || g, 'percent_off', 10
  from public.brands b, generate_series(1, 20) g where b.slug like 'qa-cost-brand-%';
insert into public.outlets (brand_id, city_id, name, address, location)
  select b.id, (select city from x), 'Outlet ' || g, 'Address ' || g || ', Karachi',
         extensions.st_setsrid(extensions.st_makepoint(67.0 + (g % 40) * 0.002, 24.9 + (g / 40) * 0.002), 4326)
  from public.brands b, generate_series(1, 20) g where b.slug like 'qa-cost-brand-%';
analyze;

-- The largest "loops" of any plan node reading card_offers (the card_banks
-- column of deal_cards).
create function pg_temp.card_banks_loops(q text) returns bigint language plpgsql as $$
declare plan jsonb; worst bigint;
begin
  execute 'explain (analyze, format json, timing off) ' || q into plan;
  with recursive nodes(n) as (
    select plan -> 0 -> 'Plan'
    union all
    select child from nodes, jsonb_array_elements(coalesce(n -> 'Plans', '[]')) child
  )
  select max((n ->> 'Actual Loops')::bigint) into worst from nodes
  where n ->> 'Relation Name' = 'card_offers';
  return coalesce(worst, 0);
end $$;
grant execute on function pg_temp.card_banks_loops(text) to anon;
grant select on x to anon, authenticated;

select tests.authenticate_as_anon();
select is((select count(*) from public.nearby_deals(24.93, 67.04, 20000, 50)), 50::bigint,
  'nearby returns a full page');
-- 1,000 live deals are candidates; each should get its card once at most.
select cmp_ok(pg_temp.card_banks_loops('select * from public.nearby_deals(24.93, 67.04, 20000, 50)'), '<=', 1000::bigint,
  'QA BUG 2.3-R5: nearby_deals builds each candidate card once, not once per outlet');
select cmp_ok(pg_temp.card_banks_loops('select * from public.feed((select city from x))'), '<=', 50::bigint,
  'the feed builds cards for its page only');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- QA BUG 2.3-R10 (S3, round 2): the following-only feed got slower. The
-- new follows_deal isn't inlined (PostgreSQL never inlines a scalar SQL
-- function whose body has a subquery), so it runs per candidate row, and
-- each call runs my_follows() up to five times. At 20,000 deals it takes
-- 857 ms against 196 ms for the round-1 version. Expected, as the
-- migration says: my_follows() runs once per query.
-- ---------------------------------------------------------------------------
set local track_functions = 'all';
create temp table follower as select tests.create_user() as uid;
insert into public.follows (user_id, brand_id)
  select uid, (select id from public.brands where slug = 'qa-cost-brand-1') from follower;
select uid as follower_id from follower \gset
select tests.authenticate_as(:'follower_id');
select count(*) as followed_rows from public.feed((select city from x), null, true) \gset
select tests.clear_authentication();
select is(:'followed_rows'::bigint, 20::bigint, 'the following-only feed returns the followed brand''s 20 deals');
select cmp_ok(
  coalesce((select f.calls from pg_stat_xact_user_functions f join pg_proc p on p.oid = f.funcid
            where p.proname = 'my_follows'), 0), '<=', 5::bigint,
  'QA BUG 2.3-R10: my_follows() runs a bounded number of times per query, not per candidate deal');

select * from finish();
rollback;
