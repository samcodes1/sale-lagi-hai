-- Guest items into the account at sign-in (QA 4.8 BUG-3).
begin;
select plan(9);

create temp table w as select * from tests.make_world();
create temp table c as select tests.make_bank() as bank;
alter table c add column card uuid, add column retired uuid;
update c set card = tests.make_card_product(bank), retired = tests.make_card_product(bank);
update public.card_products set is_active = false where id = (select retired from c);
grant select on w, c to anon, authenticated;

select tests.authenticate_as_anon();
select throws_ok($$ select public.sync_guest_items(array[(select live_a from w)]) $$,
  '42501', null, 'guests cannot');
select tests.clear_authentication();

select tests.authenticate_as((select shopper from w));
select lives_ok($$ select public.sync_guest_items(
  array[(select live_a from w), (select live_b from w), (select draft_a from w), gen_random_uuid()],
  array[(select card from c), (select retired from c), gen_random_uuid()]) $$,
  'one call adds them');
select is((select array_agg(deal_id order by deal_id) from public.saves),
  (select array_agg(id order by id) from (values ((select live_a from w)), ((select live_b from w))) v(id)),
  'only deals the shopper can see are saved (no drafts, no unknown ids)');
select is((select array_agg(card_product_id) from public.user_cards),
  array[(select card from c)], 'only active card products are added');
select lives_ok($$ select public.sync_guest_items(array[(select live_a from w)], array[(select card from c)]) $$,
  'ones already in the account are skipped');
select is((select count(*)::int from public.saves), 2, 'no duplicates');
select throws_ok($$ select public.sync_guest_items(array(select gen_random_uuid() from generate_series(1, 501))) $$,
  '22023', null, 'at most 500 deals');
select throws_ok($$ select public.sync_guest_items('{}', array(select gen_random_uuid() from generate_series(1, 21))) $$,
  '22023', null, 'at most 20 cards');
select tests.clear_authentication();

select tests.authenticate_as((select owner from w));
select is((select count(*)::int from public.saves), 0, 'nothing went into another account');
select tests.clear_authentication();

select * from finish();
rollback;
