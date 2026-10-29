-- EXAMPLE plain-SQL RLS test (pairs with example_migration.sql). Pattern for real tests:
-- one file per table, allow AND deny cases, for anon, a plain user, a member/owner and staff roles.
-- Everything runs in one transaction and is rolled back.
begin;

-- Fixtures (as the table owner, before switching role).
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'owner@test.local'),
  ('22222222-2222-2222-2222-222222222222', 'stranger@test.local'),
  ('33333333-3333-3333-3333-333333333333', 'mod@test.local');
insert into public.user_roles values ('33333333-3333-3333-3333-333333333333', 'moderator');
insert into public.businesses (id, name) values ('aaaaaaaa-0000-0000-0000-000000000001', 'Khaadi Test');
insert into public.business_members values ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');
insert into public.deals (id, business_id, title, status) values
  ('dddddddd-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'Flat 40% off', 'published'),
  ('dddddddd-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'Secret draft', 'draft');

-- anon ---------------------------------------------------------------------
select qa.as_anon();
select qa.ok(qa.count('select * from public.deals') = 1, 'anon sees only the published deal');
select qa.throws($$insert into public.deals (business_id, title) values ('aaaaaaaa-0000-0000-0000-000000000001', 'x')$$,
                 '42501', 'anon cannot insert deals (no grant)');
select qa.throws($$insert into public.reports (deal_id, reason) values ('dddddddd-0000-0000-0000-000000000001', 'expired')$$,
                 '42501', 'anon cannot file reports');
select qa.throws($$select private.has_role('admin')$$, '42501', 'anon cannot call private helpers');

-- stranger (authenticated, no membership) ----------------------------------
reset role;
select qa.as_user('22222222-2222-2222-2222-222222222222');
select qa.ok(qa.count('select * from public.deals') = 1, 'stranger sees only published deals');
select qa.throws($$insert into public.deals (business_id, title) values ('aaaaaaaa-0000-0000-0000-000000000001', 'Fake deal')$$,
                 '42501', 'stranger cannot create a deal for someone else''s business');
select qa.ok(qa.dml_count($$update public.deals set title = 'hacked' returning 1$$) = 0,
             'stranger updates no deals (RLS filters rows silently)');
select qa.lives($$insert into public.reports (deal_id, reason) values ('dddddddd-0000-0000-0000-000000000001', 'expired')$$,
                'stranger can report a deal');
select qa.throws($$insert into public.reports (deal_id, reporter_id, reason)
                   values ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'expired')$$,
                 '42501', 'stranger cannot file a report as another user');

-- owner (business member) ----------------------------------------------------
reset role;
select qa.as_user('11111111-1111-1111-1111-111111111111');
select qa.ok(qa.count('select * from public.deals') = 2, 'owner sees published + own draft');
select qa.lives($$insert into public.deals (business_id, title) values ('aaaaaaaa-0000-0000-0000-000000000001', 'New draft')$$,
                'owner can create a draft for own business');
select qa.throws($$insert into public.deals (business_id, title, status) values ('aaaaaaaa-0000-0000-0000-000000000001', 'Skip review', 'published')$$,
                 '42501', 'owner cannot insert directly as published (moderation bypass)');
select qa.throws($$update public.deals set status = 'removed' where id = 'dddddddd-0000-0000-0000-000000000001'$$,
                 '42501', 'owner cannot set moderator-only status');
select qa.ok(qa.count('select * from public.reports') = 0, 'owner cannot read reports filed by others');

-- moderator --------------------------------------------------------------------
reset role;
select qa.as_user('33333333-3333-3333-3333-333333333333');
select qa.ok(qa.count('select * from public.deals') >= 2, 'moderator sees drafts');
select qa.ok(qa.count('select * from public.reports') = 1, 'moderator reads reports');

-- abuse: rate limit -----------------------------------------------------------
reset role;
select qa.as_user('22222222-2222-2222-2222-222222222222');
select qa.lives($$insert into public.reports (deal_id, reason)
                  select 'dddddddd-0000-0000-0000-000000000001', 'other' from generate_series(1, 9)$$,
                'stranger can file up to the hourly limit');
select qa.throws($$insert into public.reports (deal_id, reason) values ('dddddddd-0000-0000-0000-000000000001', 'other')$$,
                 'P0429', 'the 11th report within an hour is rejected');

rollback;
