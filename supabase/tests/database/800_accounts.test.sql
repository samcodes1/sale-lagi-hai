-- Accounts: guest sync and account-deletion preparation.
begin;
select plan(11);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated, service_role;
create temp table hidden as select tests.make_brand(null, 'test-hidden-brand') as id;
update public.brands set is_active = false where id = (select id from hidden);
grant select on hidden to authenticated;

-- Guest sync
select tests.authenticate_as_anon();
select throws_ok($$ select public.sync_guest_preferences(null, 'ur', '{}') $$, '42501', null,
  'anon cannot call it');
select tests.authenticate_as((select shopper from w));
select lives_ok($$ select public.sync_guest_preferences(
  (select city from w), 'ur', array[(select brand_a from w), (select id from hidden)]) $$,
  'a shopper syncs their city, language and brands');
select is((select (home_city_id, locale)::text from public.profiles where id = (select shopper from w)),
  (select (city, 'ur')::text from w), 'city and language are copied');
select is((select array_agg(brand_id) from public.follows where user_id = (select shopper from w)),
  (select array[brand_a] from w), 'active brands are followed; hidden ones are skipped');
select lives_ok($$ select public.sync_guest_preferences(null, null, array[(select brand_a from w)]) $$,
  'syncing again is a no-op, not an error');
select is((select (home_city_id, locale)::text from public.profiles where id = (select shopper from w)),
  (select (city, 'ur')::text from w), 'nulls keep what the account has');
select throws_ok($$ select public.sync_guest_preferences(null, 'fr', '{}') $$, '23514', null,
  'only supported languages');
select throws_ok($$ select public.sync_guest_preferences(null, null,
  array(select gen_random_uuid() from generate_series(1, 201))) $$, '22023', null,
  'at most 200 brands at once');
select tests.clear_authentication();

-- Deletion preparation
insert into storage.objects (bucket_id, name, owner, owner_id) values
  ('avatars', (select shopper from w)::text || '/me.jpg', (select shopper from w), (select shopper from w)::text),
  ('submission-photos', (select shopper from w)::text || '/receipt.jpg', (select shopper from w), (select shopper from w)::text),
  ('deal-images', (select biz_a from w)::text || '/x/deal.jpg', (select shopper from w), (select shopper from w)::text),
  ('avatars', (select editor from w)::text || '/other.jpg', (select editor from w), (select editor from w)::text);

select tests.authenticate_as((select shopper from w));
select throws_ok($$ select * from public.prepare_account_deletion((select shopper from w)) $$, '42501', null,
  'users cannot call it (service role only)');
select tests.clear_authentication();

set local role service_role;
select is((select array_agg(bucket_id || ':' || split_part(name, '/', 2)) from public.prepare_account_deletion((select shopper from w))),
  array['avatars:me.jpg', 'submission-photos:receipt.jpg'],
  'it lists the person''s private files only');
reset role;
select is((select owner_id from storage.objects where bucket_id = 'deal-images'), null,
  'business images stay, no longer owned by the person');

select * from finish();
rollback;
