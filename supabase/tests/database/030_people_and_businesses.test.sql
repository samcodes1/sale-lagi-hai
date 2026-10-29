begin;
select plan(11);

create temp table u as select tests.create_user('ayesha@example.com') as id;

select is((select count(*)::int from public.profiles where id = (select id from u)), 1,
  'a profile is created for a new user');
select is((select count(*)::int from public.alert_prefs where user_id = (select id from u)), 1,
  'alert preferences are created for a new user');
select is((select push_enabled from public.alert_prefs where user_id = (select id from u)), false,
  'push is off until the user turns it on');

insert into auth.users (id, email, raw_user_meta_data)
values ('00000000-0000-4000-8000-000000000001', 'm@example.com',
        '{"display_name": "Admin", "role": "admin"}');
select is((select display_name from public.profiles
           where id = '00000000-0000-4000-8000-000000000001'), null,
  'user_metadata is never copied into the profile');

select throws_ok($$
  update public.profiles set locale = 'fr' where id = (select id from u)
$$, '23514', null, 'only en and ur locales');

select throws_ok($$
  insert into public.businesses (name, status) values ('Kolachi', 'verified')
$$, '23514', null, 'a verified business needs verified_at');
select throws_ok($$
  insert into public.businesses (name, contact_phone) values ('Kolachi', '03001234567')
$$, '23514', null, 'phone numbers are stored in +92 format');

-- An outlet's area must belong to the outlet's city.
create temp table places as
  select tests.make_city('karachi') as karachi, tests.make_city('lahore') as lahore;
create temp table b as select tests.make_brand() as id;
select throws_ok($$
  insert into public.outlets (brand_id, city_id, area_id, name, address, location)
  values ((select id from b), (select lahore from places),
          tests.make_area((select karachi from places)),
          'Do Darya', 'Do Darya, Phase 8, DHA', 'SRID=4326;POINT(67.04 24.78)')
$$, '23503', null, 'an outlet cannot be in an area of another city');
select lives_ok($$
  insert into public.outlets (brand_id, city_id, area_id, name, address, location)
  values ((select id from b), (select karachi from places),
          tests.make_area((select karachi from places)),
          'Do Darya', 'Do Darya, Phase 8, DHA', 'SRID=4326;POINT(67.04 24.78)')
$$, 'an outlet in an area of its own city is accepted');

-- Deleting the account deletes the profile and memberships.
insert into public.business_members (business_id, user_id, role)
values (tests.make_business(), (select id from u), 'owner');
delete from auth.users where id = (select id from u);
select is((select count(*)::int from public.profiles where id = (select id from u)), 0,
  'the profile goes with the account');
select is((select count(*)::int from public.business_members where user_id = (select id from u)), 0,
  'memberships go with the account');

select * from finish();
rollback;
