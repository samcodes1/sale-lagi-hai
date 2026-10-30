-- QA, sub-phase 4.8 round 2 (docs/qa/4.8.md): sync_guest_items beyond
-- 870_guest_items.test.sql: deals under review, nulls, the exact caps,
-- two shoppers at once, and that it runs as the caller.
begin;
select plan(9);

create temp table w as select * from tests.make_world();
create temp table c as select tests.make_bank() as bank;
alter table c add column card uuid;
update c set card = tests.make_card_product(bank);
grant select on w, c to anon, authenticated;
create temp table second as
  select tests.create_user('qa-second-shopper@example.com') as id;
grant select on second to authenticated;

select is((select prosecdef from pg_proc where proname = 'sync_guest_items'), false,
  'security invoker: the RLS of saves and deals applies');

select tests.authenticate_as((select shopper from w));
select lives_ok($$ select public.sync_guest_items(array[(select review_a from w)]) $$,
  'a deal under review is not refused as a whole');
select is((select count(*)::int from public.saves), 0, 'but a shopper cannot save a deal under review');
select lives_ok($$ select public.sync_guest_items(null, null) $$, 'nulls for both lists add nothing');
select lives_ok($$ select public.sync_guest_items(array[null::uuid, (select live_a from w)], array[null::uuid]) $$,
  'a null id is skipped, not an error');
select lives_ok($$ select public.sync_guest_items(
  array(select gen_random_uuid() from generate_series(1, 499)) || (select live_b from w),
  array(select gen_random_uuid() from generate_series(1, 19)) || (select card from c)) $$,
  'exactly 500 deals and 20 cards are accepted');
select is((select count(*)::int from public.saves), 2, 'the live deals are in');
select tests.clear_authentication();

select tests.authenticate_as((select id from second));
select public.sync_guest_items(array[(select live_a from w)], array[(select card from c)]);
select is((select count(*)::int from public.saves), 1, 'a second shopper sees only their own save');
select tests.clear_authentication();

select is(
  (select count(*)::int from public.saves where deal_id = (select live_a from w)),
  2, 'each shopper has their own row for the same deal');

select * from finish();
rollback;
