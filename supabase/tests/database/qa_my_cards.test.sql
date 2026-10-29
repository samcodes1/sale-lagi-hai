-- QA (sub-phase 4.7 gate): My Cards. The matching rule's edges (network,
-- kind, product, draft and hidden offers), the 20-card cap, user_cards RLS
-- per role, what a guest's product ids can reach, the alert planner's
-- agreement with deals_for_cards, and where a card number could still be
-- stored. "QA BUG" assertions fail until the bug in docs/qa/4.7.md is
-- fixed; S4 ones are todo.
begin;
select plan(25);

create temp table w as select * from tests.make_world();
update public.brands set is_active = true;
create temp table c as select tests.make_bank() as bank, tests.make_bank() as other_bank;
insert into public.card_products (bank_id, slug, name, network, kind) select bank, 'qa-visa-credit', 'Visa Credit', 'visa', 'credit' from c;
insert into public.card_products (bank_id, slug, name, network, kind) select bank, 'qa-mc-credit', 'Mastercard Credit', 'mastercard', 'credit' from c;
insert into public.card_products (bank_id, slug, name, network, kind) select bank, 'qa-visa-debit', 'Visa Debit', 'visa', 'debit' from c;
insert into public.card_products (bank_id, slug, name, network, kind, is_active) select bank, 'qa-retired', 'Retired', 'visa', 'credit', false from c;
create temp table p as select
  (select id from public.card_products where slug = 'qa-visa-credit') as visa_credit,
  (select id from public.card_products where slug = 'qa-mc-credit') as mc_credit,
  (select id from public.card_products where slug = 'qa-visa-debit') as visa_debit,
  (select id from public.card_products where slug = 'qa-retired') as retired;
grant select on w, c, p to anon, authenticated;

-- Offers: Visa only; debit only; Mastercard credit product only; a draft;
-- one from a hidden brand.
create temp table o as select
  tests.make_deal((select brand_a from w), 'published', 'nationwide', 'card_offer') as visa_only,
  tests.make_deal((select brand_a from w), 'published', 'nationwide', 'card_offer') as debit_only,
  tests.make_deal((select brand_a from w), 'published', 'nationwide', 'card_offer') as mc_product,
  tests.make_deal((select brand_a from w), 'draft', 'nationwide', 'card_offer') as draft,
  tests.make_deal((select brand_b from w), 'published', 'nationwide', 'card_offer') as hidden_brand;
grant select on o to anon, authenticated;
insert into public.card_offers (deal_id, bank_id, card_product_id, card_kind, card_network)
  select visa_only, (select bank from c), null::uuid, null::public.card_kind, 'visa'::public.card_network from o
  union all select debit_only, (select bank from c), null, 'debit', null from o
  union all select mc_product, (select bank from c), (select mc_credit from p), null, null from o
  union all select draft, (select bank from c), null, null, null from o
  union all select hidden_brand, (select bank from c), null, null, null from o;
set constraints all immediate;
update public.brands set is_active = false where id = (select brand_b from w);

create function pg_temp.got(cards uuid[]) returns uuid[] language sql as $$
  select coalesce(array_agg(d.id order by d.id), '{}')
  from public.deals_for_cards(cards, page_size => 50) d
  where d.id in (select unnest(array[visa_only, debit_only, mc_product, draft, hidden_brand]) from o)
$$;
grant execute on function pg_temp.got(uuid[]) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- The matching rule.
-- ---------------------------------------------------------------------------
select tests.authenticate_as_anon();
select is(pg_temp.got(array[(select visa_credit from p)]), (select array[visa_only] from o),
  'Visa credit: the Visa offer only (not debit-only, not the Mastercard product)');
select is(pg_temp.got(array[(select visa_debit from p)]),
  (select array(select unnest(array[visa_only, debit_only]) x order by x) from o),
  'Visa debit: the Visa offer and the debit offer');
select is(pg_temp.got(array[(select mc_credit from p)]), (select array[mc_product] from o),
  'Mastercard credit: its own product offer, not the Visa one');
select ok(not ((select draft from o) = any(pg_temp.got(array[(select visa_debit from p), (select mc_credit from p)]))),
  'a draft card offer is never returned');
select ok(not ((select hidden_brand from o) = any(pg_temp.got(array[(select visa_debit from p)]))),
  'a hidden brand''s card offer is never returned');
select is(pg_temp.got(array[(select retired from p)]), '{}'::uuid[], 'a retired product matches nothing');
select is(pg_temp.got(array[null, (select visa_credit from p), null]::uuid[]), (select array[visa_only] from o),
  'nulls in the list are ignored');
select is(pg_temp.got(array(select (select visa_credit from p) from generate_series(1, 25))), (select array[visa_only] from o),
  'the same card 25 times is one card');

-- QA BUG 4.7-C1 (S4): the 20-card cap slices only the first dimension, so
-- a two-dimensional array passes 20 rows of any length (my_cards.sql:24).
select is(pg_temp.got(array[array(select gen_random_uuid() from generate_series(1, 20)),
                            array(select gen_random_uuid() from generate_series(1, 19)) || (select visa_credit from p)]),
  '{}'::uuid[], 'QA BUG 4.7-C1: only the first 20 card ids count, however the array is shaped');
select lives_ok($$ select count(*) from public.deals_for_cards(
    array(select gen_random_uuid() from generate_series(1, 5000)), page_size => 50) $$,
  'a huge list of ids is not an error (only 20 are read)');
select is((select count(*)::int from public.deals_for_cards(array[(select visa_debit from p)], page_size => 1000)), 2,
  'page_size is clamped, and nothing else leaks in');
select tests.clear_authentication();

-- What a guest's ids can't reach: they read card products, which anon can
-- read anyway (active only).
select tests.authenticate_as_anon();
select is((select count(*)::int from public.card_products where id = (select retired from p)), 0,
  'anon cannot read a retired card product');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- user_cards RLS, per role.
-- ---------------------------------------------------------------------------
insert into public.user_cards (user_id, card_product_id) values
  ((select editor from w), (select visa_credit from p));

select tests.authenticate_as_anon();
select throws_ok($$ insert into public.user_cards (user_id, card_product_id)
                    values ((select editor from w), (select mc_credit from p)) $$, '42501', null,
  'anon cannot add a card');
select tests.clear_authentication();

select tests.authenticate_as((select shopper from w));
select lives_ok($$ insert into public.user_cards (card_product_id) values ((select visa_debit from p)) $$,
  'a shopper adds a card; user_id defaults to them');
select is((select user_id from public.user_cards where card_product_id = (select visa_debit from p)), (select shopper from w),
  'and it is theirs');
select throws_ok($$ insert into public.user_cards (user_id, card_product_id)
                    values ((select editor from w), (select mc_credit from p)) $$, '42501', null,
  'a shopper cannot add a card to someone else');
select is((select count(*)::int from public.user_cards), 1, 'a shopper sees only their own cards');
select is(tests.affected($$ delete from public.user_cards where user_id = (select editor from w) returning 1 $$), 0,
  'a shopper cannot remove someone else''s card');
select throws_ok($$ update public.user_cards set card_product_id = (select mc_credit from p) $$, '42501', null,
  'cards are never edited in place (no update grant)');
select throws_ok($$ insert into public.user_cards (card_product_id) values ((select visa_debit from p)) $$, '23505', null,
  'adding the same card twice is a duplicate, which the app treats as already synced');
select tests.clear_authentication();

select tests.authenticate_as((select moderator from w), '{"aal": "aal2"}');
select is((select count(*)::int from public.user_cards), 0, 'even staff do not read shoppers'' cards');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- The alert planner agrees with deals_for_cards.
-- ---------------------------------------------------------------------------
-- QA BUG 4.7-C2 (S4): the planner matches user_cards without checking
-- that the product is active (jobs.sql:315-321), so a retired card still
-- brings alerts for offers that My Cards no longer lists.
insert into public.user_cards (user_id, card_product_id) values ((select owner from w), (select retired from p));
select private.plan_alerts(50);
select is((select count(*)::int from public.notifications
           where user_id = (select owner from w) and deal_id = (select visa_only from o)), 0,
  'QA BUG 4.7-C2: a retired card brings no alert, as it brings no deal in My Cards');
select is((select count(*)::int from public.notifications
           where user_id = (select shopper from w) and deal_id = (select visa_only from o)), 1,
  'control: the planner ran, and the shopper''s active Visa debit card brought the Visa offer');

-- ---------------------------------------------------------------------------
-- Where could a card number still be stored?
-- ---------------------------------------------------------------------------
-- QA BUG 4.7-P1 (S3): free text a shopper types (a report's note) takes a
-- full card number. My Cards never asks for one, but a shopper reporting a
-- card offer ("it didn't work with my card 4111 …") can store it, and
-- moderators then read it. No check refuses PAN-like digits.
create temp table pan_ok (ok boolean);
grant all on pan_ok to authenticated;
select tests.authenticate_as((select shopper from w));
do $$
begin
  insert into public.reports (deal_id, reason, note)
  values ((select visa_only from o), 'other', 'Did not work with my card 4111 1111 1111 1111 exp 12/29');
  insert into pan_ok values (true);
exception when others then
  insert into pan_ok values (false);
end $$;
select tests.clear_authentication();
select is((select ok from pan_ok), false,
  'QA BUG 4.7-P1: a report note with a card number (13-19 digits) is refused');
select is((select count(*)::int from information_schema.columns
           where table_schema in ('public', 'private')
             and column_name ~* '(last_?4|last_?four|bin$|card_?no|exp(iry|_month|_year)|security_code|pin_?code)'),
  0, 'no other card-like column (last 4, BIN, card no, expiry, security code)');

select * from finish();
rollback;
