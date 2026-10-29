-- QA (sub-phase 4.2 gate): accounts. Guest sync abuse cases, the grants
-- on the two new functions, and account deletion end to end: a user with
-- a row in every table that references auth.users is deleted the way the
-- Auth server does it (as supabase_auth_admin, the owner of auth.users),
-- after prepare_account_deletion. Nothing may block it, and every row is
-- either removed or kept without the user's id.
begin;
select plan(40);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated, service_role, supabase_auth_admin;

-- ---------------------------------------------------------------------------
-- Grants: who can reach the two functions at all.
-- ---------------------------------------------------------------------------
select ok(not has_function_privilege('anon', 'public.prepare_account_deletion(uuid)', 'execute'),
  'anon cannot execute prepare_account_deletion');
select ok(not has_function_privilege('authenticated', 'public.prepare_account_deletion(uuid)', 'execute'),
  'authenticated cannot execute prepare_account_deletion');
select ok(has_function_privilege('service_role', 'public.prepare_account_deletion(uuid)', 'execute'),
  'service_role can execute prepare_account_deletion');
select ok(not exists (
    select 1 from pg_proc p, aclexplode(p.proacl) a
    where p.oid = 'public.prepare_account_deletion(uuid)'::regprocedure and a.grantee = 0),
  'PUBLIC has no execute grant on prepare_account_deletion');
select ok(not has_function_privilege('anon', 'public.sync_guest_preferences(uuid, text, uuid[], uuid[])', 'execute'),
  'anon cannot execute sync_guest_preferences');
select ok(has_function_privilege('authenticated', 'public.sync_guest_preferences(uuid, text, uuid[], uuid[])', 'execute'),
  'authenticated can execute sync_guest_preferences');
select is((select prosecdef from pg_proc where oid = 'public.sync_guest_preferences(uuid, text, uuid[], uuid[])'::regprocedure),
  false, 'sync_guest_preferences runs as the caller (RLS applies)');
select is((select proconfig from pg_proc where oid = 'public.prepare_account_deletion(uuid)'::regprocedure),
  array['search_path=""'], 'prepare_account_deletion pins an empty search_path');

-- ---------------------------------------------------------------------------
-- sync_guest_preferences: abuse and edge cases.
-- ---------------------------------------------------------------------------
create temp table hidden as select tests.make_brand(null, 'qa-hidden-brand') as id;
update public.brands set is_active = false where id = (select id from hidden);
grant select on hidden to authenticated;
-- The editor's profile, before the shopper syncs.
create temp table editor_before as
  select home_city_id, locale from public.profiles where id = (select editor from w);
grant select on editor_before to authenticated;

select tests.authenticate_as((select shopper from w));
select lives_ok($$ select public.sync_guest_preferences((select city from w), 'ur', null) $$,
  'a null brand list is an empty one');
select lives_ok($$ select public.sync_guest_preferences(null, null,
    array[null, (select brand_a from w), (select brand_a from w)]::uuid[]) $$,
  'nulls and duplicates in the brand list are ignored');
select is((select count(*) from public.follows where user_id = (select shopper from w)), 1::bigint,
  'one follow for a brand listed twice');
select lives_ok($$ select public.sync_guest_preferences(null, null,
    array[[(select brand_b from w), (select id from hidden)]]::uuid[]) $$,
  'a two-dimensional array does not error');
select is((select count(*) from public.follows f where f.user_id = (select shopper from w)
           and f.brand_id = (select id from hidden)), 0::bigint,
  'a hidden brand is never followed, however the array is shaped');
select lives_ok($$ select public.sync_guest_preferences(null, null,
    array(select gen_random_uuid() from generate_series(1, 200))) $$,
  'exactly 200 unknown brand ids are accepted (and follow nothing)');
select is((select count(*) from public.follows where user_id = (select shopper from w)), 2::bigint,
  'unknown brand ids follow nothing');
select throws_ok($$ select public.sync_guest_preferences(gen_random_uuid(), null, '{}') $$, '23503', null,
  'an unknown city is refused by the foreign key, not stored');
select throws_ok($$ select public.sync_guest_preferences(null, '', '{}') $$, '23514', null,
  'an empty language is refused');
select is((select count(*) from public.follows where user_id <> (select shopper from w)
           and brand_id = (select brand_b from w)), 0::bigint,
  'nothing is followed on anyone else''s behalf');
select tests.clear_authentication();
select is((select (home_city_id, locale)::text from public.profiles where id = (select editor from w)),
  (select (home_city_id, locale)::text from editor_before),
  'another user''s profile is untouched by the shopper''s sync');

-- ---------------------------------------------------------------------------
-- prepare_account_deletion: reachability.
-- ---------------------------------------------------------------------------
select tests.authenticate_as((select shopper from w));
select throws_ok($$ select * from public.prepare_account_deletion((select editor from w)) $$, '42501', null,
  'a signed-in user cannot prepare someone else''s deletion');
select tests.clear_authentication();
select tests.authenticate_as_anon();
select throws_ok($$ select * from public.prepare_account_deletion((select shopper from w)) $$, '42501', null,
  'anon cannot call prepare_account_deletion');
select tests.clear_authentication();
select tests.authenticate_as((select moderator from w), '{"aal": "aal2"}');
select throws_ok($$ select * from public.prepare_account_deletion((select shopper from w)) $$, '42501', null,
  'even a moderator with MFA cannot call prepare_account_deletion');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- A leaver with a row in every table that references auth.users.
-- They are the LAST OWNER of a business they created, which staff later
-- suspended; they granted a role, resolved a report, reviewed a submission,
-- created a deal and a placement, and have shopper data and files.
-- ---------------------------------------------------------------------------
create temp table gone as select tests.create_user('qa-leaver@example.com') as uid;
grant select on gone to anon, authenticated, service_role, supabase_auth_admin;
create temp table biz as select tests.make_business('Leaver Foods') as id;
grant select on biz to supabase_auth_admin, service_role;
update public.businesses set created_by = (select uid from gone) where id = (select id from biz);
insert into public.business_members (business_id, user_id, role)
  values ((select id from biz), (select uid from gone), 'owner'),
         ((select biz_a from w), (select uid from gone), 'editor');
update public.businesses set status = 'suspended' where id = (select id from biz);
create temp table bb as select tests.make_brand((select id from biz), 'qa-leaver-brand') as id;
create temp table dd as select tests.make_deal((select id from bb), 'published') as id;
update public.deals set created_by = (select uid from gone) where id = (select id from dd);
insert into public.user_roles (user_id, role, granted_by)
  values ((select uid from gone), 'moderator', null), ((select shopper from w), 'business_owner', (select uid from gone));
insert into public.follows (user_id, brand_id) values ((select uid from gone), (select brand_a from w));
insert into public.saves (user_id, deal_id) values ((select uid from gone), (select live_a from w));
insert into public.user_cards select (select uid from gone), id from public.card_products limit 1;
insert into public.notifications (user_id, kind, title) values ((select uid from gone), 'system', 'Hi');
insert into public.reports (deal_id, reporter_id, reason) values ((select live_b from w), (select uid from gone), 'spam');
insert into public.reports (deal_id, reporter_id, reason, status, resolved_by, resolved_at)
  values ((select live_a from w), (select shopper from w), 'expired', 'resolved', (select uid from gone), now());
insert into public.submissions (submitter_id, kind, brand_name, title, image_path)
  values ((select uid from gone), 'other', 'Brand', 'A pending title', (select uid from gone)::text || '/receipt.jpg');
insert into public.submissions (submitter_id, kind, brand_name, title, status, reviewer_id, reviewed_at, reject_reason)
  values ((select shopper from w), 'other', 'Brand', 'Reviewed title', 'rejected', (select uid from gone), now(), 'Not a deal');
insert into public.placements (business_id, deal_id, slot, starts_at, ends_at, created_by)
  values ((select id from biz), (select id from dd), 'home_featured', now(), now() + interval '7 days', (select uid from gone));
insert into public.push_tokens (token, user_id, platform) values (repeat('z', 30), (select uid from gone), 'android');
insert into private.push_outbox (user_id, local_day, title, send_at)
  values ((select uid from gone), current_date, 'T', now());
insert into storage.objects (bucket_id, name, owner, owner_id) values
  ('avatars', (select uid from gone)::text || '/me.jpg', (select uid from gone), (select uid from gone)::text),
  ('submission-photos', (select uid from gone)::text || '/receipt.jpg', (select uid from gone), (select uid from gone)::text),
  ('deal-images', (select id from biz)::text || '/' || (select id from dd)::text || '/hero.jpg',
   (select uid from gone), (select uid from gone)::text),
  ('brand-logos', (select id from biz)::text || '/' || (select id from bb)::text || '/logo.png',
   (select uid from gone), (select uid from gone)::text),
  ('deal-images', (select biz_a from w)::text || '/x/other.jpg', (select owner from w), (select owner from w)::text);

-- Step 3 of the function: hand business files over, list private ones.
set local role service_role;
create temp table listed as select * from public.prepare_account_deletion((select uid from gone));
reset role;
select is((select array_agg(bucket_id || ':' || split_part(name, '/', 2) order by bucket_id) from listed),
  array['avatars:me.jpg', 'submission-photos:receipt.jpg'],
  'only the leaver''s private files are listed for deletion');
select is((select count(*) from storage.objects where bucket_id in ('deal-images', 'brand-logos')
           and owner_id is null and owner is null), 2::bigint,
  'both public business files (deal image and brand logo) are handed over');
select is((select owner_id from storage.objects where name like '%/x/other.jpg'), (select owner::text from w),
  'someone else''s business file keeps its owner');
-- Step 3b: the Storage API deletes the listed files.
delete from storage.objects o using listed l where o.bucket_id = l.bucket_id and o.name = l.name;

-- Step 4: the Auth server deletes the user, as the owner of auth.users.
alter table auth.users owner to supabase_auth_admin;
create temp table deletion (error text);
grant all on deletion to supabase_auth_admin;
set local role supabase_auth_admin;
do $$
begin
  delete from auth.users where id = (select uid from gone);
  insert into deletion values (null);
exception when others then
  insert into deletion values (sqlstate || ' ' || sqlerrm);
end $$;
reset role;
select is((select error from deletion), null,
  'deleting the last owner of a suspended business they created is not blocked');

select is(
  (select count(*) from public.profiles where id = (select uid from gone))
  + (select count(*) from public.alert_prefs where user_id = (select uid from gone))
  + (select count(*) from public.follows where user_id = (select uid from gone))
  + (select count(*) from public.saves where user_id = (select uid from gone))
  + (select count(*) from public.user_cards where user_id = (select uid from gone))
  + (select count(*) from public.notifications where user_id = (select uid from gone))
  + (select count(*) from public.push_tokens where user_id = (select uid from gone))
  + (select count(*) from private.push_outbox where user_id = (select uid from gone))
  + (select count(*) from public.user_roles where user_id = (select uid from gone))
  + (select count(*) from public.business_members where user_id = (select uid from gone)),
  0::bigint, 'every row owned by the leaver is gone');
select is((select count(*) from storage.objects where owner_id = (select uid::text from gone)
           or owner = (select uid from gone)), 0::bigint,
  'no storage object is still owned by the leaver');
select is((select created_by from public.businesses where id = (select id from biz)), null,
  'businesses.created_by is cleared');
select is((select status::text from public.businesses where id = (select id from biz)), 'suspended',
  'the business itself stays (suspended), now without an owner for staff to reassign');
select is((select count(*) from public.business_members where business_id = (select id from biz)), 0::bigint,
  'the ownerless business has no members left');
select is((select created_by from public.deals where id = (select id from dd)), null,
  'deals.created_by is cleared; the deal stays');
select is((select created_by from public.placements where deal_id = (select id from dd)), null,
  'placements.created_by is cleared; the placement stays');
select is((select granted_by from public.user_roles where user_id = (select shopper from w) and role = 'business_owner'), null,
  'user_roles.granted_by is cleared; the role they granted stays');
select is((select count(*) from public.reports where reporter_id is null and deal_id = (select live_b from w)), 1::bigint,
  'their report stays without their id');
select is((select resolved_by from public.reports where deal_id = (select live_a from w)), null,
  'reports.resolved_by is cleared');
select is((select reviewer_id from public.submissions where title = 'Reviewed title'), null,
  'submissions.reviewer_id is cleared');
select is((select submitter_id from public.submissions where title = 'A pending title'), null,
  'their pending submission stays without their id');

-- A moderator can still act on the orphaned pending submission (the
-- notify trigger skips a null submitter).
select tests.authenticate_as((select moderator from w), '{"aal": "aal2"}');
select lives_ok($$ select public.reject_submission(
    (select id from public.submissions where title = 'A pending title'), 'Not a deal') $$,
  'a moderator can still reject a submission whose submitter deleted their account');
select tests.clear_authentication();

-- Recorded, not asserted as a bug: the audit log keeps the leaver's id in
-- old_data for the role and membership rows the cascade removed
-- (pseudonymous; see docs/qa/4.2.md recommendations).
select cmp_ok((select count(*) from public.audit_log
               where action = 'delete' and old_data ->> 'user_id' = (select uid::text from gone)), '>=', 3::bigint,
  'the audit log records the removed role and memberships (keeps the id in old_data)');

select * from finish();
rollback;
