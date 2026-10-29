-- Query plans on realistic volume: the read APIs must not scan whole tables.
begin;
select plan(6);

-- 20,000 deals across 200 brands and 2 cities, 5,000 outlets, 20,000 saves.
create temp table x as select tests.make_city('test-karachi') as karachi, tests.make_category('food') as food;
insert into public.brands (slug, name, category_id)
  select 'brand-' || i, 'Brand ' || i, (select food from x) from generate_series(1, 200) i;
insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en,
                          offer_kind, percent, url, starts_at, published_at)
  select b.id, b.category_id, 'brand_sale', case when i % 3 = 0 then 'local' else 'nationwide' end::public.deal_scope,
         case when i % 10 = 0 then 'draft' else 'published' end::public.deal_status, 'staff',
         -- One deal in a thousand is a karahi deal; the rest vary.
         (array['Winter sale', 'Lawn collection', 'Weekend brunch', 'Gym membership',
                'Burger combo'])[1 + i % 5] || ' ' || i
           || case when i % 1000 = 1 then ' chicken karahi' else '' end,
         'percent_off', 1 + i % 90,
         'https://example.com', now() - interval '1 day' - (i || ' minutes')::interval,
         now() - (i || ' minutes')::interval
  from generate_series(1, 20000) i
  join lateral (select id, category_id from public.brands where slug = 'brand-' || (1 + i % 200)) b on true;
insert into public.deal_targets (deal_id, city_id)
  select id, (select karachi from x) from public.deals where scope = 'local';
insert into public.outlets (brand_id, city_id, name, address, location)
  select b.id, (select karachi from x), 'Outlet ' || i, 'Address ' || i || ', Karachi',
         extensions.st_setsrid(extensions.st_makepoint(66.9 + random() * 0.3, 24.8 + random() * 0.2), 4326)
  from generate_series(1, 5000) i
  join lateral (select id from public.brands where slug = 'brand-' || (1 + i % 200)) b on true;
set constraints all immediate;
analyze;

-- Sequential scans of a table so far in this transaction. Works through
-- function calls (unlike EXPLAIN on a non-inlined function).
create function pg_temp.seq_scans(rel text) returns bigint language sql as $$
  select coalesce(seq_scan, 0) from pg_stat_xact_user_tables
  where schemaname = 'public' and relname = rel;
$$;
create function pg_temp.scans_during(rel text, q text) returns bigint language plpgsql as $$
declare before bigint;
begin
  before := pg_temp.seq_scans(rel);
  execute 'select count(*) from (' || q || ') x';
  return pg_temp.seq_scans(rel) - before;
end $$;
grant execute on function pg_temp.seq_scans(text), pg_temp.scans_during(text, text) to anon;
grant select on x to anon;

select tests.authenticate_as_anon();
select is(pg_temp.scans_during('deals', $$ select * from public.feed((select karachi from x)) $$), 0::bigint,
  'feed reads deals through indexes');
select is(pg_temp.scans_during('deals', $$ select * from public.brand_deals('brand-7') $$), 0::bigint,
  'brand pages read deals through indexes');
select is(pg_temp.scans_during('outlets', $$ select * from public.nearby_deals(24.9, 67.0, 2000) $$), 0::bigint,
  'nearby finds outlets through the spatial index');
select is(pg_temp.scans_during('deals', $$ select * from public.search_deals('karahi') $$), 0::bigint,
  'search reads deals through indexes');
select is(pg_temp.scans_during('deals', $$ select * from public.search_deals('biriyani karhai') $$), 0::bigint,
  'fuzzy search too');
select ok((select count(*) from public.feed((select karachi from x))) = 20,
  'the feed still returns a full page');

select * from finish();
rollback;
