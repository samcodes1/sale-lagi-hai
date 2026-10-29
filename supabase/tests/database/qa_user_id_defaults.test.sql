-- QA, sub-phases 4.4/4.5 round 2 (docs/qa/4.4.md): with user_id now
-- defaulting to auth.uid() on saves, follows and user_cards, a row still
-- can't be written in someone else's name, and the default is the caller.
begin;
select plan(7);

create temp table w as select * from tests.make_world();
update public.brands set is_active = true;
create temp table x as select tests.make_card_product(tests.make_bank('qa-bank')) as card;
grant select on w, x to authenticated;

select tests.authenticate_as((select shopper from w));
select lives_ok($$insert into public.saves (deal_id) select live_a from w$$, 'a save without user_id');
select is((select user_id from public.saves), (select shopper from w), '... is the caller''s');
select throws_ok($$insert into public.saves (user_id, deal_id) select owner, live_b from w$$,
  '42501', null, 'not in someone else''s name (saves)');
select throws_ok($$insert into public.follows (user_id, brand_id) select owner, brand_b from w$$,
  '42501', null, 'nor follows');
select throws_ok($$insert into public.user_cards (user_id, card_product_id) select owner, card from w, x$$,
  '42501', null, 'nor cards');
select lives_ok($$insert into public.user_cards (card_product_id) select card from x$$, 'a card without user_id');
select tests.clear_authentication();

select tests.authenticate_as_anon();
select throws_ok($$insert into public.saves (deal_id) select live_a from w$$,
  '42501', null, 'a guest cannot save on the server');
select tests.clear_authentication();

select * from finish();
rollback;
