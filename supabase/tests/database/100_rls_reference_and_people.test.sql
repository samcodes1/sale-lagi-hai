-- Access: reference data, profiles, user roles and the access token hook.
begin;
select plan(21);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;
select tests.make_category('hidden');
update public.categories set is_active = false where slug = 'hidden';

-- anon
select tests.authenticate_as_anon();
select ok((select count(*) from public.cities) >= 1, 'anon reads cities');
select is((select (round(center_lat::numeric, 4), round(center_lng::numeric, 4)) from public.cities where slug = 'karachi'),
  (24.8607::numeric, 67.0011::numeric), 'cities expose their centre as numbers (nearest city on the phone)');
select is((select count(*)::int from public.categories where slug = 'hidden'), 0,
  'anon does not see inactive categories');
select throws_ok($$ insert into public.cities (slug, name_en, name_ur, province, center)
  values ('test-quetta', 'Quetta', 'کوئٹہ', 'balochistan', 'SRID=4326;POINT(66.99 30.18)') $$,
  '42501', null, 'anon cannot add cities');
select throws_ok('select * from public.profiles', '42501', null, 'anon cannot read profiles');

-- shopper
select tests.authenticate_as((select shopper from w));
select is((select count(*)::int from public.profiles), 1, 'a shopper reads only their own profile');
select lives_ok($$ update public.profiles set display_name = 'Ayesha' where id = (select shopper from w) $$,
  'a shopper updates their own profile');
select is(tests.affected($$
  update public.profiles set display_name = 'Hacked' where id = (select owner from w) returning 1 $$), 0,
  'a shopper cannot update another profile');
select throws_ok($$ update public.profiles set created_at = now() where id = (select shopper from w) $$,
  '42501', null, 'profile timestamps are not client-writable');
select throws_ok($$ insert into public.user_roles (user_id, role) values ((select shopper from w), 'admin') $$,
  '42501', null, 'a shopper cannot make themselves admin');
select throws_ok($$ insert into public.cities (slug, name_en, name_ur, province, center)
  values ('test-quetta', 'Quetta', 'کوئٹہ', 'balochistan', 'SRID=4326;POINT(66.99 30.18)') $$,
  '42501', null, 'a shopper cannot add cities');

-- moderator: staff powers only with MFA
select tests.authenticate_as((select moderator from w));
select is((select count(*)::int from public.profiles), 1,
  'without MFA a moderator is just a shopper');
select tests.staff((select moderator from w));
select ok((select count(*) from public.profiles) >= 6, 'with MFA a moderator reads all profiles');
select ok((select count(*) from public.categories where slug = 'hidden') = 1,
  'staff see inactive categories');

-- admin
select tests.authenticate_as((select admin from w));
select throws_ok($$ insert into public.cities (slug, name_en, name_ur, province, center)
  values ('test-quetta', 'Quetta', 'کوئٹہ', 'balochistan', 'SRID=4326;POINT(66.99 30.18)') $$,
  '42501', null, 'without MFA an admin cannot add cities');
select tests.staff((select admin from w));
select lives_ok($$ insert into public.cities (slug, name_en, name_ur, province, center)
  values ('test-quetta', 'Quetta', 'کوئٹہ', 'balochistan', 'SRID=4326;POINT(66.99 30.18)') $$,
  'an admin adds a city');
select lives_ok($$ insert into public.user_roles (user_id, role) values ((select shopper from w), 'moderator') $$,
  'an admin grants a role');
select is((select granted_by from public.user_roles where user_id = (select shopper from w)),
  (select admin from w), 'the grant records who made it');
select is(tests.affected($$
  delete from public.user_roles where user_id = (select admin from w) and role = 'admin' returning 1 $$), 0,
  'an admin cannot remove their own admin role');

-- Access token hook
select tests.clear_authentication();
select is(public.custom_access_token_hook(jsonb_build_object(
  'user_id', (select moderator from w), 'claims', '{"sub": "x"}'::jsonb)) -> 'claims' -> 'user_roles',
  '["moderator"]'::jsonb, 'the token hook adds the user''s roles');
select tests.authenticate_as((select shopper from w));
select throws_ok($$ select public.custom_access_token_hook('{}'::jsonb) $$, '42501', null,
  'users cannot call the token hook');

select * from finish();
rollback;
