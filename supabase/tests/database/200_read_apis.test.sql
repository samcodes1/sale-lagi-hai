-- Read APIs: what each RPC returns, in which order, and how it pages.
begin;
select plan(34);

-- Fixture: one live city, one not yet live, and deals in every state.
create temp table x as select
  tests.make_city('karachi', true) as karachi,
  tests.make_city('lahore', false) as lahore,
  tests.make_category('food') as food,
  tests.make_bank('hbl') as hbl,
  tests.make_bank('ubl') as ubl,
  tests.create_user() as shopper,
  tests.create_user() as other;
alter table x add column bbq uuid, add column brand uuid, add column brand2 uuid;
update x set bbq = tests.make_category('bbq', food);
update x set brand = tests.make_brand(slug => 'kolachi'), brand2 = tests.make_brand(slug => 'student-biryani');
update public.brands set category_id = (select food from x) where slug = 'kolachi';
update public.brands set name = 'Student Biryani' where slug = 'student-biryani';

create function pg_temp.deal(title text, brand uuid, status public.deal_status default 'published',
  scope public.deal_scope default 'nationwide', published timestamptz default now() - interval '1 hour',
  kind public.deal_kind default 'brand_sale', category uuid default null) returns uuid
language plpgsql as $$
declare d uuid;
begin
  insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en,
                            offer_kind, percent, url, starts_at, published_at)
  values (brand, coalesce(category, (select category_id from public.brands where id = brand)),
          kind, scope, status, 'staff', title, 'percent_off', 30, 'https://example.com',
          published - interval '1 day', published)
  returning id into d;
  return d;
end $$;

create temp table d as select
  pg_temp.deal('Old nationwide sale', (select brand from x), published => now() - interval '3 days') as old_nat,
  pg_temp.deal('New nationwide sale', (select brand from x), published => now() - interval '1 hour') as new_nat,
  pg_temp.deal('Karachi BBQ night', (select brand from x), 'published', 'local', now() - interval '2 hours', category => (select bbq from x)) as karachi_local,
  pg_temp.deal('Lahore only deal', (select brand from x), 'published', 'local') as lahore_local,
  pg_temp.deal('Draft deal', (select brand from x), 'draft') as draft,
  pg_temp.deal('Ended deal', (select brand from x)) as ended,
  pg_temp.deal('Future deal', (select brand from x)) as future,
  pg_temp.deal('Chicken biryani family pack', (select brand2 from x), published => now() - interval '5 hours') as biryani,
  pg_temp.deal('HBL credit card dining', (select brand from x), 'published', 'nationwide', now() - interval '4 hours', 'card_offer') as card_deal,
  pg_temp.deal('UBL debit Fridays', (select brand from x), 'published', 'nationwide', now() - interval '6 hours', 'card_offer') as ubl_deal;
insert into public.deal_targets (deal_id, city_id) values
  ((select karachi_local from d), (select karachi from x)),
  ((select lahore_local from d), (select lahore from x));
insert into public.card_offers (deal_id, bank_id, card_kind) values
  ((select card_deal from d), (select hbl from x), 'credit'),
  ((select ubl_deal from d), (select ubl from x), 'debit');
update public.deals set starts_at = now() - interval '10 days', ends_at = now() - interval '1 day'
  where id = (select ended from d);
update public.deals set starts_at = now() + interval '1 day' where id = (select future from d);
insert into public.user_cards (user_id, card_product_id)
  select shopper, tests.make_card_product(hbl) from x;
grant select on x, d to anon, authenticated;
set constraints all immediate;

create function pg_temp.titles(cards public.deal_card[]) returns text[] language sql as $$
  select array(select c.title_en from unnest(cards) c);
$$;
grant execute on function pg_temp.titles(public.deal_card[]) to anon, authenticated;

-- The card type matches the view, plus Featured and distance.
select is(
  (select array_agg(attname::text order by attnum) from pg_attribute
   where attrelid = 'public.deal_card'::regclass and attnum > 0),
  (select array_agg(attname::text order by attnum) from pg_attribute
   where attrelid = 'public.deal_cards'::regclass and attnum > 0) || array['is_featured', 'distance_m'],
  'deal_card is deal_cards plus is_featured and distance_m');

-- Feed
select tests.authenticate_as_anon();
select is(pg_temp.titles(array(select f from public.feed((select karachi from x)) f)),
  array['New nationwide sale', 'Karachi BBQ night', 'HBL credit card dining',
        'Chicken biryani family pack', 'UBL debit Fridays', 'Old nationwide sale'],
  'the Karachi feed: live nationwide and Karachi deals, newest first');
select ok(not ('Lahore only deal' = any(pg_temp.titles(array(select f from public.feed((select lahore from x)) f)))),
  'local deals wait until their city is live');
select is(pg_temp.titles(array(select f from public.feed() f)),
  array['New nationwide sale', 'HBL credit card dining', 'Chicken biryani family pack',
        'UBL debit Fridays', 'Old nationwide sale'],
  'without a city, only nationwide and online deals');

create temp table p1 as select * from public.feed((select karachi from x), page_size => 2);
select is((select count(*)::int from p1), 2, 'page_size limits the page');
select is(pg_temp.titles(array(select f from public.feed((select karachi from x),
    after_published_at => (select published_at from p1 order by published_at limit 1),
    after_id => (select id from p1 order by published_at limit 1), page_size => 2) f)),
  array['HBL credit card dining', 'Chicken biryani family pack'],
  'the cursor continues where the page ended, without overlap');
select is(pg_temp.titles(array(select f from public.feed((select karachi from x),
    category_ids => array[(select food from x)]) f)),
  array['New nationwide sale', 'Karachi BBQ night', 'HBL credit card dining',
        'UBL debit Fridays', 'Old nationwide sale'],
  'a category includes its subcategories');
select is(pg_temp.titles(array(select f from public.feed((select karachi from x),
    category_ids => array[(select bbq from x)]) f)),
  array['Karachi BBQ night'], 'a subcategory alone');

-- Following
select tests.clear_authentication();
insert into public.follows (user_id, brand_id) select shopper, brand2 from x;
select tests.authenticate_as((select shopper from x));
select is(pg_temp.titles(array(select f from public.feed((select karachi from x), following_only => true) f)),
  array['Chicken biryani family pack'], 'following_only shows followed brands');
select tests.authenticate_as((select other from x));
select is(pg_temp.titles(array(select f from public.feed((select karachi from x), following_only => true) f)),
  '{}'::text[], 'someone who follows nothing gets an empty following feed');

-- Featured
select tests.clear_authentication();
create temp table biz as select tests.make_business() as id;
update public.brands set business_id = (select id from biz) where slug = 'kolachi';
insert into public.placements (business_id, deal_id, slot, city_id, starts_at, ends_at, status, priority)
values ((select id from biz), (select old_nat from d), 'home_featured', null, now() - interval '1 day', now() + interval '1 day', 'active', 5),
       ((select id from biz), (select karachi_local from d), 'home_featured', (select karachi from x), now() - interval '1 day', now() + interval '1 day', 'active', 9),
       ((select id from biz), (select new_nat from d), 'home_featured', null, now() - interval '1 day', now() + interval '1 day', 'draft', 50),
       ((select id from biz), (select card_deal from d), 'home_featured', null, now() + interval '1 day', now() + interval '2 days', 'active', 99);
select tests.authenticate_as_anon();
select is(pg_temp.titles(array(select f from public.featured_deals('home_featured', (select karachi from x)) f)),
  array['Karachi BBQ night', 'Old nationwide sale'],
  'featured: live placements only, highest priority first');
select ok((select bool_and(is_featured) from public.featured_deals('home_featured', (select karachi from x))),
  'featured rows are marked featured');
select is(pg_temp.titles(array(select f from public.featured_deals('home_featured', (select lahore from x)) f)),
  array['Old nationwide sale'], 'city placements only show in their city');
select ok((select bool_and(not is_featured) from public.feed((select karachi from x))),
  'the plain feed does not mark deals featured');

-- A business member can read their drafts, but the feed shows live deals only.
select tests.clear_authentication();
insert into public.business_members (business_id, user_id, role) select (select id from biz), other, 'editor' from x;
select tests.authenticate_as((select other from x));
select ok(exists (select 1 from public.deal_cards where title_en = 'Draft deal')
          and not exists (select 1 from public.feed((select karachi from x)) where title_en = 'Draft deal'),
  'members see their drafts in deal_cards, never in the feed');
select tests.authenticate_as_anon();

-- Trending
select tests.clear_authentication();
insert into public.saves (user_id, deal_id)
  select tests.create_user(), (select old_nat from d) from generate_series(1, 5);
insert into public.saves (user_id, deal_id) select tests.create_user(), (select biryani from d);
select tests.authenticate_as_anon();
select is((select title_en from public.trending_deals((select karachi from x)) limit 1),
  'Old nationwide sale', 'the most-saved deal trends first');
select ok(not exists (select 1 from public.trending_deals((select karachi from x)) where title_en = 'Draft deal'),
  'trending shows live deals only');

-- Nearby
select tests.clear_authentication();
insert into public.outlets (brand_id, city_id, name, address, location) values
  ((select brand from x), (select karachi from x), 'Kolachi Do Darya', 'Do Darya, DHA Phase 8', 'SRID=4326;POINT(67.0500 24.7800)'),
  ((select brand2 from x), (select karachi from x), 'Student Biryani Saddar', 'Saddar, Karachi', 'SRID=4326;POINT(67.0300 24.8600)');
select tests.authenticate_as_anon();
create temp table near as select * from public.nearby_deals(24.7810, 67.0510, 2000);
select ok((select count(*) from near) > 0 and (select max(distance_m) from near) < 2000,
  'deals with an outlet within the radius, with distances');
select ok(not exists (select 1 from near where title_en = 'Chicken biryani family pack'),
  'outlets outside the radius are not included');
select ok(exists (select 1 from near where title_en = 'Karachi BBQ night'),
  'a local deal shows at an outlet in its target city');
select is((select count(*)::int from public.nearby_deals(95, 67, 2000)), 0, 'invalid coordinates return nothing');
select ok((select count(*) from public.nearby_deals(24.8600, 67.0300, 1000000)) > 0
          and (select max(distance_m) from public.nearby_deals(24.8600, 67.0300, 1000000)) <= 20000,
  'the radius is capped at 20 km');

-- Deals for my cards
select throws_ok($$ select * from public.deals_for_my_cards() $$, '42501', null,
  'anon cannot ask for card deals');
select tests.authenticate_as((select shopper from x));
select is(pg_temp.titles(array(select f from public.deals_for_my_cards((select karachi from x)) f)),
  array['HBL credit card dining'], 'only offers matching the user''s cards (bank and kind)');
select tests.authenticate_as((select other from x));
select is((select count(*)::int from public.deals_for_my_cards()), 0, 'no cards, no card deals');

-- Search
select tests.authenticate_as_anon();
select is((select title_en from public.search_deals('biryani') limit 1), 'Chicken biryani family pack',
  'full-text search finds a title word');
select is((select title_en from public.search_deals('biriyani') limit 1), 'Chicken biryani family pack',
  'fuzzy search forgives a spelling');
select ok(exists (select 1 from public.search_deals('student biryani') where brand_name = 'Student Biryani'),
  'brand names are searchable');
select is((select count(*)::int from public.search_deals('b')), 0, 'one-letter queries return nothing');
select is((select count(*)::int from public.search_deals(repeat('a', 101))), 0, 'queries over 100 characters return nothing');
select ok(not exists (select 1 from public.search_deals('draft')), 'search shows live deals only');
select lives_ok($$ select * from public.search_deals('sale & | ! ( :*', page => 99) $$,
  'odd characters and huge page numbers are safe');

-- Brand page
select is(pg_temp.titles(array(select f from public.brand_deals('student-biryani') f)),
  array['Chicken biryani family pack'], 'a brand page lists that brand''s live deals');

-- Page size is capped at 50.
select tests.clear_authentication();
select pg_temp.deal('Bulk ' || i, (select brand from x)) from generate_series(1, 60) i;
select tests.authenticate_as_anon();
select is((select count(*)::int from public.feed(page_size => 1000)), 50, 'pages hold at most 50 deals');

select * from finish();
rollback;
