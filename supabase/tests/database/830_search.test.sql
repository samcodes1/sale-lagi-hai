-- Search and filters (4.6): search_deals with words or filters only,
-- the area, bank, discount and ending-soon filters, keyset paging.
begin;
select plan(19);

create temp table w as select * from tests.make_world();
update public.brands set is_active = true;

create temp table s as select
  tests.make_area((select city from w), 'clifton') as clifton,
  tests.make_area((select city from w), 'gulshan') as gulshan,
  tests.make_bank() as hbl,
  tests.make_bank() as meezan,
  tests.make_deal((select brand_a from w), 'published', 'local') as in_clifton,
  tests.make_deal((select brand_a from w), 'published', 'local') as citywide,
  tests.make_deal((select brand_a from w), 'published', 'local') as in_gulshan,
  tests.make_deal((select brand_b from w), 'published', 'online', 'card_offer') as hbl_card;
grant select on w, s to anon;

update public.deals set title_en = 'Karahi night Clifton', percent = 40, published_at = now() - interval '4 minutes'
  where id = (select in_clifton from s);
update public.deals set title_en = 'Karahi night citywide', percent = 20, published_at = now() - interval '3 minutes'
  where id = (select citywide from s);
update public.deals set title_en = 'Karahi night Gulshan', percent = 50, published_at = now() - interval '2 minutes'
  where id = (select in_gulshan from s);
update public.deals set title_en = 'Karahi online with HBL cards', percent = 15,
  ends_at = now() + interval '10 hours', published_at = now() - interval '1 minute'
  where id = (select hbl_card from s);
insert into public.deal_targets (deal_id, city_id, area_id)
  select in_clifton, (select city from w), clifton from s
  union all select citywide, (select city from w), null from s
  union all select in_gulshan, (select city from w), gulshan from s;
insert into public.card_offers (deal_id, bank_id) select hbl_card, hbl from s;
set constraints all immediate;

-- Ours only: the world has other live deals.
create temp view ours as
  select unnest(array[in_clifton, citywide, in_gulshan, hbl_card]) as id from s;
grant select on ours to anon;

select tests.authenticate_as_anon();

select is((select array_agg(d.id order by d.id) from public.search_deals('karahi', (select city from w),
             area_id => (select clifton from s)) d where d.id in (select id from ours)),
  (select array_agg(x order by x) from s, unnest(array[in_clifton, citywide, hbl_card]) x),
  'an area: its own and city-wide local deals, plus online ones; not another area''s');
select is((select array_agg(d.id) from public.search_deals('karahi', (select city from w),
             bank_ids => array[(select hbl from s)]) d where d.id in (select id from ours)),
  (select array[hbl_card] from s), 'a bank: only card offers of that bank');
select is((select count(*)::int from public.search_deals('karahi', (select city from w),
             bank_ids => array[(select meezan from s)]) d where d.id in (select id from ours)),
  0, 'another bank: none');
select is((select array_agg(d.id order by d.id) from public.search_deals('karahi', (select city from w),
             min_percent => 40) d where d.id in (select id from ours)),
  (select array_agg(x order by x) from s, unnest(array[in_clifton, in_gulshan]) x),
  'a minimum discount');
select is((select array_agg(d.id) from public.search_deals('karahi', (select city from w),
             ending_within_hours => 24) d where d.id in (select id from ours)),
  (select array[hbl_card] from s), 'ending within a day');
select is((select count(*)::int from public.search_deals('karahi', (select city from w),
             min_percent => 1000) d where d.id in (select id from ours)),
  0, 'the minimum discount is capped at 99%');

-- No words: the newest deals that pass the filters.
select is((select array_agg(d.id) from public.search_deals(null, (select city from w),
             min_percent => 50) d where d.id in (select id from ours)),
  (select array[in_gulshan] from s), 'filters alone, without words');
select is((select array_agg(d.id) from public.search_deals('   ', (select city from w),
             area_id => (select gulshan from s)) d where d.id in (select id from ours)),
  (select array[hbl_card, in_gulshan, citywide] from s), 'blank words are no words: newest first');

-- Keyset paging: one row a page reaches every result once, in order.
select is(
  (with recursive pages(n, id) as (
     select 1, (select id from public.search_deals('karahi', (select city from w), page_size => 1))
     union all
     select n + 1, (select x.id from public.search_deals('karahi', (select city from w),
                      after_id => p.id, page_size => 1) x)
     from pages p where p.id is not null and n < 50)
   select array_agg(id order by n) from pages where id is not null),
  (select array_agg(id order by n) from public.search_deals('karahi', (select city from w), page_size => 50)
     with ordinality as t(id, brand_id, brand_slug, brand_name, brand_name_ur, brand_logo_path,
       brand_is_verified, category_id, category_slug, kind, scope, status, title_en, title_ur,
       offer_kind, percent, amount_off_pkr, price_pkr, original_price_pkr, offer_text_en,
       offer_text_ur, promo_code, url, image_path, starts_at, ends_at, verified_at, published_at,
       card_banks, is_featured, distance_m, n)),
  'search pages by keyset: every match once, best first');
select is(
  (with recursive pages(n, id) as (
     select 1, (select id from public.search_deals(null, (select city from w), min_percent => 20, page_size => 1))
     union all
     select n + 1, (select x.id from public.search_deals(null, (select city from w), min_percent => 20,
                      after_id => p.id, page_size => 1) x)
     from pages p where p.id is not null and n < 50)
   select array_agg(id order by n) from pages where id in (select id from ours)),
  (select array[in_gulshan, citywide, in_clifton] from s),
  'filters alone page by keyset too, newest first');
select tests.clear_authentication();

-- Every filter applies before the 250-hit cap.
insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, offer_kind, percent, url)
  select (select brand_a from w), (select category_id from public.brands where id = (select brand_a from w)),
         'brand_sale', 'nationwide', 'published', 'staff', 'Zebra print sale ' || g, 'percent_off',
         case when g <= 5 then 60 else 10 end, 'https://example.com/zebra'
  from generate_series(1, 300) g;
select tests.authenticate_as_anon();
select is((select count(*)::int from public.search_deals('zebra', min_percent => 60, page_size => 50)), 5,
  'a filtered search finds all its matches, however many others match the words');
select tests.clear_authentication();

select ok(to_regprocedure('public.search_deals(text, uuid, uuid[], integer, integer)') is null,
  'the 2.3 search signature is gone');
select ok(has_function_privilege('anon',
  'public.search_deals(text, uuid, uuid[], uuid, uuid[], integer, integer, uuid, integer)', 'execute'),
  'anon can search');

-- Brand suggestions.
update public.brands set name = 'Zaiqa House', name_ur = 'ذائقہ ہاؤس' where id = (select brand_a from w);
update public.brands set name = 'Kolachi_50%', is_active = true where id = (select brand_b from w);
insert into public.brands (slug, name, category_id, is_active)
  select 'hidden-zaib', 'Zaib Hidden', category_id, false from public.brands where id = (select brand_a from w);
select tests.authenticate_as_anon();
select is((select array_agg(name) from public.brand_suggestions('zai')), array['Zaiqa House'],
  'brands whose name starts with the words; hidden brands never');
select is((select name from public.brand_suggestions('zaika house') limit 1), 'Zaiqa House', 'a typo still finds the brand');
select is((select name from public.brand_suggestions('ذائ') limit 1), 'Zaiqa House', 'Urdu names match too');
select is((select count(*)::int from public.brand_suggestions('%')), 0, 'LIKE wildcards are plain characters');
select is((select array_agg(name) from public.brand_suggestions('kolachi_5')), array['Kolachi_50%'],
  'an underscore is matched as itself');
select is((select count(*)::int from public.brand_suggestions(repeat('k', 61))), 0, 'over 60 characters: nothing');
select tests.clear_authentication();

select * from finish();
rollback;
