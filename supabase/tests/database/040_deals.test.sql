begin;
select plan(33);

create temp table f as select tests.make_brand() as brand;
create function pg_temp.deal(offer text, extra text default '') returns text
language sql as $$
  select format($q$
    insert into public.deals (brand_id, category_id, kind, scope, source, title_en, %s)
    select f.brand, b.category_id, 'brand_sale', 'nationwide', 'staff', 'Winter sale', %s
    from f join public.brands b on b.id = f.brand $q$,
    split_part(offer, '|', 1), split_part(offer, '|', 2)) || extra;
$$;

-- Offer fields match the offer kind.
select lives_ok(pg_temp.deal($$offer_kind, percent|'percent_off', 40$$), 'percent_off with a percent');
select throws_ok(pg_temp.deal($$offer_kind|'percent_off'$$), '23514', null, 'percent_off needs a percent');
select throws_ok(pg_temp.deal($$offer_kind, percent|'percent_off', 100$$), '23514', null, 'percent is 1-99');
select throws_ok(pg_temp.deal($$offer_kind, percent|'text', 40$$), '23514', null, 'text offers carry no percent');
select lives_ok(pg_temp.deal($$offer_kind, offer_text_en|'text', 'Buy 1 Get 1'$$), 'a text offer');
select throws_ok(pg_temp.deal($$offer_kind|'text'$$), '23514', null, 'a text offer needs its text');
select lives_ok(pg_temp.deal($$offer_kind, amount_off_pkr|'amount_off', 500$$), 'Rs 500 off');
select throws_ok(pg_temp.deal($$offer_kind, amount_off_pkr|'amount_off', 0$$), '23514', null, 'Rs 0 off is not an offer');
select lives_ok(pg_temp.deal($$offer_kind, price_pkr|'fixed_price', 999$$), 'a fixed price');
select throws_ok(pg_temp.deal($$offer_kind|'fixed_price'$$), '23514', null, 'a fixed price needs the price');
select throws_ok(pg_temp.deal($$offer_kind, price_pkr|'fixed_price', -1$$), '23514', null, 'prices are not negative');
select throws_ok(pg_temp.deal($$offer_kind, price_pkr, original_price_pkr|'fixed_price', 999, 999$$),
  '23514', null, 'the original price must be higher');
select throws_ok(pg_temp.deal($$offer_kind, original_price_pkr, offer_text_en|'text', 999, 'BOGO'$$),
  '23514', null, 'an original price needs a current price');

-- Never a fake discount.
select lives_ok(pg_temp.deal($$offer_kind, percent, price_pkr, original_price_pkr|'percent_off', 40, 2999, 4999$$),
  'Rs 4,999 → Rs 2,999 is 40% (rounded down)');
select throws_ok(pg_temp.deal($$offer_kind, percent, price_pkr, original_price_pkr|'percent_off', 41, 2999, 4999$$),
  '23514', null, 'claiming 41% for Rs 4,999 → Rs 2,999 is rejected');
select throws_ok(pg_temp.deal($$offer_kind, percent, price_pkr, original_price_pkr|'percent_off', 50, 2999, 4999$$),
  '23514', null, 'an inflated percentage is rejected');

-- Dates and kind-specific fields.
create temp table d0 as select tests.make_deal() as id;
select throws_ok(pg_temp.deal($$offer_kind, percent, starts_at, ends_at|'percent_off', 40, now(), now() - interval '1 day'$$),
  '23514', null, 'a deal cannot end before it starts');
select throws_ok($$
  update public.deals set kind = 'promo_code' where id = (select id from d0)
$$, '23514', null, 'a promo_code deal needs its code');
select throws_ok($$
  update public.deals set scope = 'online', url = null where id = (select id from d0)
$$, '23514', null, 'an online deal needs a link');
select throws_ok(pg_temp.deal($$offer_kind, percent, fingerprint|'percent_off', 40, 'NOT-A-HASH'$$),
  '23514', null, 'fingerprints are lower-case hex');

-- Status graph and publishing.
create temp table d as select tests.make_deal() as id;
update public.deals set status = 'published' where id = (select id from d);
select isnt((select published_at from public.deals where id = (select id from d)), null,
  'publishing sets published_at');
select throws_ok($$ update public.deals set status = 'pending_review' where id = (select id from d) $$,
  '23514', null, 'a published deal cannot go back to review');
select lives_ok($$ update public.deals set status = 'expired' where id = (select id from d) $$,
  'a published deal can expire');
select throws_ok($$
  update public.deals set status = 'draft', ends_at = now() + interval '1 day'
  where id = (select id from d)
$$, '23514', null, 'an expired deal cannot become a draft');
select throws_ok($$
  insert into public.deals (brand_id, category_id, kind, scope, source, title_en, offer_kind,
                            percent, status, starts_at, ends_at)
  select brand, (select category_id from public.brands where id = brand), 'brand_sale',
         'nationwide', 'staff', 'Old sale', 'percent_off', 30, 'published',
         now() - interval '10 days', now() - interval '1 day'
  from f
$$, '23514', null, 'a deal that has ended cannot be published');

-- Cross-table rules, checked at commit (forced here with set constraints).
savepoint s1;
create temp table local_deal as select tests.make_deal(scope => 'local', status => 'published') as id;
select throws_ok('set constraints all immediate', '23514', null,
  'a published local deal needs a city or area');
rollback to savepoint s1;
set constraints all deferred;

savepoint s2;
create temp table local_ok as select tests.make_deal(scope => 'local', status => 'published') as id;
insert into public.deal_targets (deal_id, city_id) select id, tests.make_city() from local_ok;
select lives_ok('set constraints all immediate', 'with a target it is valid');
rollback to savepoint s2;
set constraints all deferred;

savepoint s3;
insert into public.deal_targets (deal_id, city_id) select tests.make_deal(), tests.make_city();
select throws_ok('set constraints all immediate', '23514', null, 'only local deals have targets');
rollback to savepoint s3;
set constraints all deferred;

savepoint s4;
create temp table card_deal as select tests.make_deal(kind => 'card_offer', status => 'published') as id;
select throws_ok('set constraints all immediate', '23514', null,
  'a published card offer needs a card');
rollback to savepoint s4;
set constraints all deferred;

savepoint s5;
create temp table cd as
  select tests.make_deal(kind => 'card_offer') as id, tests.make_bank() as hbl,
         tests.make_bank() as ubl;
select throws_ok($$
  insert into public.card_offers (deal_id, bank_id, card_product_id)
  select id, hbl, tests.make_card_product(ubl) from cd
$$, '23503', null, 'a card offer cannot name another bank''s card');
select throws_ok($$
  insert into public.card_offers (deal_id, bank_id, days_of_week) select id, hbl, '{0}' from cd
$$, '23514', null, 'weekdays are 1-7');
rollback to savepoint s5;
set constraints all deferred;

savepoint s6;
create temp table pl as select tests.make_deal(scope => 'local') as id, tests.make_city() as city;
insert into public.deal_targets (deal_id, city_id) select id, city from pl;
update public.deals set status = 'published' where id = (select id from pl);
set constraints all immediate;
set constraints all deferred;
delete from public.deal_targets where deal_id = (select id from pl);
select throws_ok('set constraints all immediate', '23514', null,
  'the last target of a published local deal cannot be removed');
rollback to savepoint s6;
set constraints all deferred;

-- Search covers English and Urdu titles.
update public.deals set title_ur = 'سردیوں کی سیل' where id = (select id from d);
select ok((select search_vector @@ to_tsquery('simple', 'سیل') from public.deals where id = (select id from d)),
  'the Urdu title is searchable');

select * from finish();
rollback;
