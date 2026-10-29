-- QA (sub-phase 2.1): constraint checks the developer's tests don't cover.
-- "QA BUG" assertions state the expected behaviour and FAIL until the bug
-- in docs/qa/2.1.md is fixed; TODO assertions are S4 findings.
begin;
select plan(17);

create temp table w as select * from tests.make_world();

-- A deal row with the given offer fields (as staff would write it).
create function pg_temp.offer(kind text, pct int, amount int, price int, original int) returns text
language plpgsql as $$
begin
  insert into public.deals (brand_id, category_id, kind, scope, source, title_en,
                            offer_kind, percent, amount_off_pkr, price_pkr, original_price_pkr)
  select brand_a, (select category_id from public.brands where id = brand_a), 'brand_sale',
         'nationwide', 'staff', 'Offer probe', kind::public.offer_kind, pct, amount, price, original
  from w;
  return 'ok';
exception when others then
  return sqlstate;
end $$;

-- SQLSTATE of a statement.
create function pg_temp.state(statement text) returns text language plpgsql as $$
begin
  execute statement;
  return 'ok';
exception when others then
  return sqlstate;
end $$;

-- The rule the developer tested: percent_off with two prices.
select is(pg_temp.offer('percent_off', 41, null, 2999, 4999), '23514', '41% on Rs 4,999 to Rs 2,999 is rejected');
select is(pg_temp.offer('percent_off', 40, null, 2999, 4999), 'ok', '40% on Rs 4,999 to Rs 2,999 is accepted');

-- ---------------------------------------------------------------------------
-- QA BUG 2.1-C1 (S2): "real discounts only" holds for percent_off alone.
-- The deal card shows price and old price for every offer kind, so these
-- display a discount the prices don't support. Expected: 23514.
-- ---------------------------------------------------------------------------
select is(pg_temp.offer('flat_percent_off', 50, null, 900, 1000), '23514',
  'QA BUG 2.1-C1: "Flat 50% off" next to Rs 1,000 to Rs 900 is rejected');
select is(pg_temp.offer('up_to_percent_off', 70, null, 999, 1000), '23514',
  'QA BUG 2.1-C1: "Up to 70% off" next to Rs 1,000 to Rs 999 is rejected');
select is(pg_temp.offer('amount_off', null, 500, 900, 1000), '23514',
  'QA BUG 2.1-C1: "Rs 500 off" next to Rs 1,000 to Rs 900 is rejected');
select is(pg_temp.offer('amount_off', null, 500, 200, 300), '23514',
  'QA BUG 2.1-C1: "Rs 500 off" an item that cost Rs 300 is rejected');

-- Status graph.
create temp table g as select tests.make_deal((select brand_a from w), 'draft') as id;
select is(pg_temp.state($$ update public.deals set status = 'expired' where id = (select id from g) $$), '23514',
  'a draft cannot jump to expired');
update public.deals set status = 'published' where id = (select id from g);
select is(pg_temp.state($$ update public.deals set status = 'pending_review' where id = (select id from g) $$), '23514',
  'a live deal cannot go back to review');
select is(pg_temp.state($$ update public.deals set status = 'rejected' where id = (select id from g) $$), '23514',
  'a live deal cannot be rejected');
select is(pg_temp.state($$ update public.deals set status = 'published', ends_at = now() - interval '1 minute',
  starts_at = now() - interval '1 day' where id = (select draft_a from w) $$), '23514',
  'an ended deal cannot be published');

-- Deferred rules: checked at commit, so test them with immediate checking.
select is(pg_temp.state($$
  with d as (insert into public.deals (brand_id, category_id, kind, scope, source, title_en, offer_kind, percent, status)
             select brand_a, (select category_id from public.brands where id = brand_a), 'food_deal', 'local', 'staff',
                    'Local deal, target in the same statement', 'percent_off', 10, 'published' from w returning id)
  insert into public.deal_targets (deal_id, city_id) select d.id, (select city from w) from d $$), 'ok',
  'a local deal and its target can be written together');
savepoint before_immediate;
select pg_temp.state($$ insert into public.deals (brand_id, category_id, kind, scope, source, title_en, offer_kind, percent, status)
  select brand_a, (select category_id from public.brands where id = brand_a), 'food_deal', 'local', 'staff',
         'Local deal without a target', 'percent_off', 10, 'published' from w $$) as inserted \gset
select pg_temp.state('set constraints all immediate') as at_commit \gset
rollback to before_immediate;
select is(:'at_commit'::text, '23514', 'a published local deal without a target fails at commit');

-- Places stay consistent; reference rows in use can't be deleted.
select is(pg_temp.state($$ insert into public.deal_targets (deal_id, city_id, area_id)
  select (select id from public.deals where title_en = 'Local deal, target in the same statement'),
         (select id from public.cities where slug = 'karachi'), (select id from public.areas where slug = 'gulberg') $$),
  '23503', 'a target cannot pair a Lahore area with Karachi');
select is(pg_temp.state($$ delete from public.categories where slug = 'fashion' $$), '23503',
  'a category in use cannot be deleted');
select is(pg_temp.state($$ delete from public.cities where slug = 'lahore' $$), '23503',
  'a city with areas cannot be deleted');

-- ---------------------------------------------------------------------------
-- S4 findings (TODO).
-- ---------------------------------------------------------------------------
select todo('QA 2.1-C2 (S4): the percentage check overflows int4 on big prices (22003 instead of a decision)', 1);
select is(pg_temp.offer('percent_off', 30, null, 70000000, 100000000), 'ok',
  'a real 30% off Rs 10 crore is accepted');

select todo('QA 2.1-C3 (S4): republishing keeps the first published_at, so a renewed deal stays buried in the feed', 1);
update public.deals set status = 'published', published_at = now() - interval '30 days' where id = (select draft_a from w);
update public.deals set status = 'draft' where id = (select draft_a from w);
update public.deals set status = 'published' where id = (select draft_a from w);
select ok((select published_at > now() - interval '1 day' from public.deals where id = (select draft_a from w)),
  'publishing again stamps a fresh published_at');

select * from finish();
rollback;
