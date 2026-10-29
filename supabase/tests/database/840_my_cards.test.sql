-- My Cards (4.7): deals for a set of cards (guests too), the signed-in
-- list built on it, and the privacy rule: a card is a product, never a
-- number.
begin;
select plan(12);

create temp table w as select * from tests.make_world();
update public.brands set is_active = true;

create temp table c as select
  tests.make_bank() as bank, tests.make_bank() as other_bank;
alter table c add column visa_credit uuid, add column paypak_debit uuid, add column retired uuid,
  add column other_card uuid;
update c set visa_credit = tests.make_card_product(bank), other_card = tests.make_card_product(other_bank);
insert into public.card_products (bank_id, slug, name, network, kind)
  select bank, 'paypak-debit', 'PayPak Debit', 'paypak', 'debit' from c;
insert into public.card_products (bank_id, slug, name, network, kind, is_active)
  select bank, 'retired-card', 'Retired Gold', 'visa', 'credit', false from c;
update c set paypak_debit = (select id from public.card_products where slug = 'paypak-debit' and bank_id = c.bank),
             retired = (select id from public.card_products where slug = 'retired-card' and bank_id = c.bank);
grant select on w, c to anon, authenticated;

-- Four card offers: any card of the bank, its credit cards, one product,
-- and another bank's.
create temp table o as select
  tests.make_deal((select brand_a from w), 'published', 'nationwide', 'card_offer') as any_card,
  tests.make_deal((select brand_a from w), 'published', 'nationwide', 'card_offer') as credit_only,
  tests.make_deal((select brand_a from w), 'published', 'nationwide', 'card_offer') as one_product,
  tests.make_deal((select brand_b from w), 'published', 'nationwide', 'card_offer') as other_bank;
grant select on o to anon, authenticated;
insert into public.card_offers (deal_id, bank_id, card_product_id, card_kind)
  select any_card, (select bank from c), null::uuid, null::public.card_kind from o
  union all select credit_only, (select bank from c), null, 'credit' from o
  union all select one_product, (select bank from c), (select paypak_debit from c), null from o
  union all select other_bank, (select other_bank from c), null, null from o;
set constraints all immediate;

create function pg_temp.ids(cards uuid[]) returns uuid[] language sql as $$
  select coalesce(array_agg(d.id order by d.id), '{}')
  from public.deals_for_cards(cards) d
  where d.id in (select unnest(array[any_card, credit_only, one_product, other_bank]) from o)
$$;
grant execute on function pg_temp.ids(uuid[]) to anon, authenticated;

select tests.authenticate_as_anon();
select is(pg_temp.ids(array[(select visa_credit from c)]),
  (select array(select unnest(array[any_card, credit_only]) x order by x) from o),
  'a guest''s Visa credit card gets the any-card and credit-card offers');
select is(pg_temp.ids(array[(select paypak_debit from c)]),
  (select array(select unnest(array[any_card, one_product]) x order by x) from o),
  'a PayPak debit card gets the any-card offer and its own product''s');
select is(pg_temp.ids(array[(select retired from c)]), '{}'::uuid[], 'an inactive card product matches nothing');
select is(pg_temp.ids(null), '{}'::uuid[], 'no cards, no deals');
select is(pg_temp.ids(array(select gen_random_uuid() from generate_series(1, 20)) || (select visa_credit from c)),
  '{}'::uuid[], 'only the first 20 cards count');
select tests.clear_authentication();

-- Signed in: the same rule over the user's own cards.
insert into public.user_cards (user_id, card_product_id)
  select (select shopper from w), paypak_debit from c
  union all select (select owner from w), visa_credit from c;
select tests.authenticate_as((select shopper from w));
select is((select array_agg(d.id order by d.id) from public.deals_for_my_cards() d
           where d.id in (select unnest(array[any_card, credit_only, one_product, other_bank]) from o)),
  pg_temp.ids(array[(select paypak_debit from c)]),
  'my cards are deals_for_cards over my own cards');
select is((select count(*)::int from public.user_cards), 1, 'a shopper sees only their own cards');
select tests.clear_authentication();

select tests.authenticate_as_anon();
select throws_ok($$ select * from public.user_cards $$, '42501', null, 'anon cannot read anyone''s cards');
select ok(has_function_privilege('anon',
  'public.deals_for_cards(uuid[], uuid, timestamptz, uuid, integer)', 'execute'), 'guests can ask for card deals');
select tests.clear_authentication();

-- Privacy: a card is a product. Nothing stores a number.
select is((select array_agg(column_name::text order by column_name) from information_schema.columns
           where table_schema = 'public' and table_name = 'user_cards'),
  array['card_product_id', 'created_at', 'user_id'], 'user_cards holds only who and which product');
select is((select count(*)::int from information_schema.columns
           where table_schema in ('public', 'private')
             and column_name ~* '(card_?num|pan$|^pan_|cvv|cvc|expiry_(month|year)|iban|account_?no)'),
  0, 'no table has a card-number, CVV, expiry or account-number column');
select is((select array_agg(column_name::text order by column_name) from information_schema.columns
           where table_schema = 'public' and table_name = 'card_products'
             and column_name not in ('id', 'bank_id', 'slug', 'name', 'network', 'kind', 'tier',
                                     'is_active', 'created_at', 'updated_at')),
  null, 'card products describe a product, nothing more');

select * from finish();
rollback;
