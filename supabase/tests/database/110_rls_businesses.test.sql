-- Access: businesses, members, brands and outlets.
begin;
select plan(26);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;

-- A shopper registers a business and becomes its owner.
select tests.authenticate_as((select shopper from w));
select lives_ok($$ insert into public.businesses (name) values ('Chai Wala') returning id $$,
  'a shopper registers a business (and can read it back)');
select is((select role::text from public.business_members bm
           join public.businesses b on b.id = bm.business_id where b.name = 'Chai Wala'),
  'owner', 'the registering user becomes its owner');
select throws_ok($$ insert into public.businesses (name, status, verified_at)
  values ('Fake Verified', 'verified', now()) $$, '42501', null,
  'a business cannot register itself as verified');
select is((select count(*)::int from public.businesses where id = (select biz_a from w)), 0,
  'other businesses are invisible to a shopper');

-- Editor (member of A)
select tests.authenticate_as((select editor from w));
select is((select count(*)::int from public.businesses where id in ((select biz_a from w), (select biz_b from w))), 1,
  'a member sees their business only');
select is(tests.affected($$ update public.businesses set name = 'Kolachi 2' where id = (select biz_a from w) returning 1 $$), 0,
  'editors cannot change business details');
select lives_ok($$ delete from public.business_members where user_id = (select editor from w) $$,
  'a member can leave');

-- Owner of A
select tests.authenticate_as((select owner from w));
select is(tests.affected($$ update public.businesses set name = 'Kolachi Restaurant' where id = (select biz_a from w) returning 1 $$), 1,
  'owners change business details');
select throws_ok($$ update public.businesses set status = 'verified', verified_at = now() where id = (select biz_a from w) $$,
  '42501', null, 'owners cannot verify their own business');
select lives_ok($$ insert into public.business_members (business_id, user_id, role)
  values ((select biz_a from w), (select shopper from w), 'editor') $$, 'owners add members');
select throws_ok($$ update public.business_members set role = 'editor' where user_id = (select owner from w) $$,
  '23514', null, 'the last owner cannot hand back ownership without a successor');

-- Owner of B cannot touch A.
select tests.authenticate_as((select other_owner from w));
select throws_ok($$ insert into public.business_members (business_id, user_id, role)
  values ((select biz_a from w), (select other_owner from w), 'owner') $$,
  '42501', null, 'nobody joins another business on their own');
select is(tests.affected($$ update public.brands set name = 'Hijacked' where id = (select brand_a from w) returning 1 $$), 0,
  'another business cannot edit a brand');
select throws_ok($$ insert into public.outlets (brand_id, city_id, name, address, location)
  values ((select brand_a from w), (select city from w), 'Fake', 'Somewhere in Karachi', 'SRID=4326;POINT(67 24.8)') $$,
  '42501', null, 'another business cannot add outlets to a brand');

-- Brands
select tests.authenticate_as((select owner from w));
select throws_ok($$ insert into public.brands (slug, name, business_id, category_id)
  values ('test-khaadi', 'Khaadi', (select biz_a from w), (select category_id from public.brands where slug = 'kolachi')) $$,
  '42501', null, 'a business cannot add a brand that goes live immediately');
select throws_ok($$ insert into public.brands (slug, name, business_id, category_id, is_active)
  values ('test-khaadi-2', 'Khaadi', (select biz_a from w),
          (select category_id from public.brands where slug = 'kolachi'), false) $$,
  '42501', null, 'a business cannot pick a brand''s public address');
select lives_ok($$ insert into public.brands (slug, name, business_id, category_id, is_active)
  values ('pending-kolachi-express', 'Kolachi Express', (select biz_a from w),
          (select category_id from public.brands where slug = 'kolachi'), false) $$,
  'a business adds a brand, hidden until staff check it');
select throws_ok($$ update public.brands set is_active = true where slug = 'pending-kolachi-express' $$,
  '42501', null, 'a business cannot activate its own brand');
select throws_ok($$ update public.brands set is_verified = true where id = (select brand_a from w) $$,
  '42501', null, 'a business cannot mark its brand verified');
select lives_ok($$ update public.brands set website = 'https://kolachi.pk' where id = (select brand_a from w) $$,
  'a business edits its brand details');
select lives_ok($$ insert into public.outlets (brand_id, city_id, name, address, location)
  values ((select brand_a from w), (select city from w), 'Do Darya', 'Do Darya, DHA Phase 8', 'SRID=4326;POINT(67.04 24.78)') $$,
  'a business adds an outlet');

select tests.authenticate_as_anon();
select is((select count(*)::int from public.brands where slug in ('kolachi', 'pending-kolachi-express')), 1,
  'anon sees active brands only');
select is((select count(*)::int from public.outlets where brand_id = (select brand_a from w)), 1,
  'anon sees active outlets');

-- Staff
select tests.staff((select moderator from w));
select lives_ok($$ update public.businesses set status = 'verified', verified_at = now() where id = (select biz_a from w) $$,
  'a moderator verifies a business');
select lives_ok($$ update public.brands set slug = 'kolachi-express', is_active = true, is_verified = true
  where slug = 'pending-kolachi-express' $$,
  'a moderator gives a brand its address, activates and verifies it');

-- Anyone may leave, even the last owner; staff then reassign the business.
select tests.authenticate_as((select owner from w));
select lives_ok($$ delete from public.business_members where user_id = (select owner from w) $$,
  'the last owner can still leave');

select * from finish();
rollback;
