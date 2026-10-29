-- QA (sub-phase 2.2): adversarial checks of the role matrix in
-- docs/backend/ACCESS.md. Written by QA, not the developer.
--
-- Assertions marked "QA BUG" state the expected behaviour and FAIL until
-- the bug in docs/qa/2.2.md is fixed. Those marked TODO are S4 findings
-- that are reported but don't fail the run.
begin;
select plan(21);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated, service_role, supabase_auth_admin;

-- SQLSTATE of a statement run as the current role ('ok' when it succeeds).
create function pg_temp.state(statement text) returns text language plpgsql as $$
begin
  execute statement;
  return 'ok';
exception when others then
  return sqlstate;
end $$;
grant execute on function pg_temp.state(text) to anon, authenticated, service_role;

-- Every role can query every public table and view: grants deny cleanly
-- (42501) and no policy recurses (42P17) or errors in a helper.
create temp table sweep_errors (who text, rel text, code text);
grant all on sweep_errors to anon, authenticated, service_role;
create function pg_temp.sweep(who text) returns void language plpgsql as $$
declare r record; code text;
begin
  for r in select c.relname from pg_class c join pg_namespace s on s.oid = c.relnamespace
           where s.nspname = 'public' and c.relkind in ('r', 'v') loop
    code := pg_temp.state(format('select count(*) from public.%I', r.relname));
    if code not in ('ok', '42501') then
      insert into sweep_errors values (who, r.relname, code);
    end if;
  end loop;
end $$;
grant execute on function pg_temp.sweep(text) to anon, authenticated, service_role;

select tests.authenticate_as_anon(); select pg_temp.sweep('anon'); select tests.clear_authentication();
select tests.authenticate_as((select shopper from w)); select pg_temp.sweep('shopper'); select tests.clear_authentication();
select tests.authenticate_as((select editor from w)); select pg_temp.sweep('editor'); select tests.clear_authentication();
select tests.authenticate_as((select owner from w)); select pg_temp.sweep('owner'); select tests.clear_authentication();
select tests.authenticate_as((select moderator from w)); select pg_temp.sweep('moderator aal1'); select tests.clear_authentication();
select tests.staff((select moderator from w)); select pg_temp.sweep('moderator aal2'); select tests.clear_authentication();
select tests.authenticate_as((select admin from w)); select pg_temp.sweep('admin aal1'); select tests.clear_authentication();
select tests.staff((select admin from w)); select pg_temp.sweep('admin aal2'); select tests.clear_authentication();
set local role service_role; select pg_temp.sweep('service_role'); reset role;
select is((select count(*) from sweep_errors), 0::bigint,
  'every role reads every public table and view without recursion or helper errors');

-- Anon sees only what ACCESS.md lists as public.
select tests.authenticate_as_anon();
select is(
  (select array_agg(c.relname::text order by c.relname) from pg_class c
   join pg_namespace s on s.oid = c.relnamespace
   where s.nspname = 'public' and c.relkind in ('r', 'v')
     and has_table_privilege('anon', c.oid, 'select')),
  array['areas', 'banks', 'brands', 'card_offers', 'card_products', 'categories', 'cities',
        'deal_cards', 'deal_targets', 'deals', 'outlets', 'placements'],
  'anon can select only the public catalogue, deals and live placements');
select tests.clear_authentication();

-- RETURNING never reveals rows the caller can't see.
select tests.authenticate_as((select shopper from w));
select is(tests.affected($$ update public.deals set title_en = title_en
  where id = (select draft_a from w) returning title_en $$), 0,
  'update ... returning on a hidden draft returns nothing');
select is(tests.affected($$ delete from public.business_members returning user_id $$), 0,
  'delete ... returning on other teams returns nothing');
select tests.clear_authentication();

-- The token hook overwrites a user_roles claim the client might inject.
set local role supabase_auth_admin;
select public.custom_access_token_hook(jsonb_build_object(
    'user_id', (select shopper from w),
    'claims', jsonb_build_object('sub', (select shopper from w), 'user_roles', '["admin"]'::jsonb)))
  -> 'claims' ->> 'user_roles' as hook_roles \gset
reset role;
select is(:'hook_roles'::text, '[]'::text, 'the token hook replaces an injected user_roles claim');

-- Definer helpers return public rows only.
update public.deals set title_en = 'Secret draft zebra' where id = (select draft_a from w);
update public.brands set is_active = true;
select tests.authenticate_as_anon();
select is((select count(*) from private.search_hits('zebra')), 0::bigint,
  'search_hits never returns drafts');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- QA BUG 2.2-B1 (S2): members can rename a verified brand. The guard
-- protects slug, owner, bank, verified and active but not the name, so a
-- business gets any name approved, then shows "McDonald's" with the
-- verified badge. Expected: refused, or the badge is withdrawn.
-- ---------------------------------------------------------------------------
update public.brands set is_verified = true where id = (select brand_a from w);
select tests.authenticate_as((select editor from w));
select pg_temp.state($$ update public.brands set name = 'McDonald''s' where id = (select brand_a from w) $$) as rename \gset
select tests.clear_authentication();
select ok(:'rename' = '42501'
          or not (select is_verified from public.brands where id = (select brand_a from w)),
  'QA BUG 2.2-B1: renaming a verified brand is refused or withdraws the verified badge');

-- ---------------------------------------------------------------------------
-- QA BUG 2.2-B2 (S2): members edit a deal's content while it is in review
-- (ACCESS.md: "edit content only as a draft"). The moderator approves one
-- text and publishes another. Expected: 42501 unless it goes back to draft.
-- ---------------------------------------------------------------------------
select tests.authenticate_as((select editor from w));
select is(pg_temp.state($$ update public.deals set title_en = 'Bait and switch', percent = 90
  where id = (select review_a from w) $$), '42501',
  'QA BUG 2.2-B2: a deal in review cannot be edited by its business');
-- Taking it back to draft first still works.
select is(pg_temp.state($$ update public.deals set status = 'draft', title_en = 'Edited as a draft'
  where id = (select review_a from w) $$), 'ok',
  'a member takes a deal in review back to draft and edits it');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- QA BUG 2.2-B3 (S3): suspending a business has no effect. Its members
-- keep adding outlets (public at once for an active brand), sending deals
-- to review and drafting placements. Expected: 42501 while suspended.
-- ---------------------------------------------------------------------------
update public.businesses set status = 'suspended' where id = (select biz_a from w);
update public.brands set is_active = true where id = (select brand_a from w);
select tests.authenticate_as((select owner from w));
select is(pg_temp.state($$ insert into public.outlets (brand_id, city_id, name, address, location)
  select brand_a, city, 'Suspended outlet', 'Some street 12', 'SRID=4326;POINT(67.03 24.81)' from w $$),
  '42501', 'QA BUG 2.2-B3: a suspended business cannot add outlets');
select is(pg_temp.state($$ update public.deals set status = 'pending_review' where id = (select draft_a from w) $$),
  '42501', 'QA BUG 2.2-B3: a suspended business cannot send deals for review');
select tests.clear_authentication();
update public.businesses set status = 'pending' where id = (select biz_a from w);

-- ---------------------------------------------------------------------------
-- QA BUG 2.2-B4 (S3): an owner can add anyone as an owner without their
-- consent, then leave; the victim is now the last owner and can never
-- leave. Expected: a user added by someone else can always leave.
-- ---------------------------------------------------------------------------
select tests.authenticate_as((select owner from w));
select is(pg_temp.state($$ insert into public.business_members (business_id, user_id, role)
  select biz_a, shopper, 'owner' from w $$), 'ok', 'an owner adds another owner');
select is(pg_temp.state($$ delete from public.business_members
  where business_id = (select biz_a from w) and user_id = (select owner from w) $$), 'ok',
  'the original owner leaves');
select tests.clear_authentication();
select tests.authenticate_as((select shopper from w));
select is(pg_temp.state($$ delete from public.business_members
  where business_id = (select biz_a from w) and user_id = (select shopper from w) $$), 'ok',
  'QA BUG 2.2-B4: a user made owner without consent can leave the business');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- QA BUG 2.2-B5 (S3): owners change a verified business's name and
-- registration number; it stays verified. Expected: refused, or the
-- business goes back to pending.
-- ---------------------------------------------------------------------------
insert into public.business_members values ((select biz_a from w), (select owner from w), 'owner');
update public.businesses set status = 'verified', verified_at = now(), registration_no = '1234567'
  where id = (select biz_a from w);
select tests.authenticate_as((select owner from w));
select pg_temp.state($$ update public.businesses set registration_no = '7654321', name = 'Someone Else'
  where id = (select biz_a from w) $$) as reg \gset
select tests.clear_authentication();
select ok(:'reg' = '42501'
          or (select status from public.businesses where id = (select biz_a from w)) <> 'verified',
  'QA BUG 2.2-B5: changing a verified business''s registration details is refused or re-verified');

-- ---------------------------------------------------------------------------
-- QA BUG 2.2-B6 (S3): any business reserves a canonical brand slug with a
-- hidden brand, so staff and ingestion can't create the real brand there
-- (and an ingestion upsert on slug would land on the squatter's row).
-- Expected: business-added brands can't take a bare slug before staff
-- approve it.
-- ---------------------------------------------------------------------------
select tests.authenticate_as((select owner from w));
select pg_temp.state($$ insert into public.brands (slug, name, business_id, category_id, is_active)
  select 'nishat-linen', 'Nishat Linen', biz_a, (select category_id from public.brands where id = brand_a), false
  from w $$) as squat \gset
select tests.clear_authentication();
select ok(:'squat' <> 'ok' or not exists (select 1 from public.brands where slug = 'nishat-linen'),
  'QA BUG 2.2-B6: a business cannot reserve a canonical brand slug with a hidden brand');

-- ---------------------------------------------------------------------------
-- Account deletion: every row of the user goes; reports and submissions
-- stay without the id.
-- ---------------------------------------------------------------------------
create temp table gone as select tests.create_user('leaver@example.com') as uid;
insert into public.follows (user_id, brand_id) select uid, (select brand_b from w) from gone;
insert into public.saves (user_id, deal_id) select uid, (select live_b from w) from gone;
insert into public.user_cards select uid, (select id from public.card_products limit 1) from gone;
insert into public.notifications (user_id, kind, title) select uid, 'system', 'Hi' from gone;
insert into public.reports (deal_id, reporter_id, reason) select (select live_b from w), uid, 'spam' from gone;
insert into public.submissions (submitter_id, kind, brand_name, title) select uid, 'other', 'Brand', 'A title' from gone;
insert into public.push_tokens (token, user_id, platform) select repeat('q', 30), uid, 'android' from gone;
insert into private.push_outbox (user_id, local_day, title, send_at) select uid, current_date, 'T', now() from gone;
insert into public.user_roles (user_id, role) select uid, 'moderator' from gone;
insert into public.business_members values ((select biz_b from w), (select uid from gone), 'editor');
insert into storage.objects (bucket_id, name, owner) select 'avatars', uid::text || '/me.jpg', uid from gone;
delete from auth.users where id = (select uid from gone);
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
  0::bigint, 'deleting an account removes every row that belongs to the user');
select is((select count(*) from public.reports where reporter_id is null)
          + (select count(*) from public.submissions where submitter_id is null), 2::bigint,
  'their report and submission stay, without their id');
select todo('QA 2.2-B9 (S4): avatars and submission photos outlive the account until a delete-account flow removes them', 1);
select is((select count(*) from storage.objects where owner = (select uid from gone)), 0::bigint,
  'the deleted user''s private files are removed');

-- ---------------------------------------------------------------------------
-- S4 findings (TODO, reported in docs/qa/2.2.md).
-- ---------------------------------------------------------------------------
select todo('QA 2.2-B7 (S4): brands.is_active defaults to true, so a member insert without it fails', 1);
select tests.authenticate_as((select owner from w));
select is(pg_temp.state($$ insert into public.brands (slug, name, business_id, category_id)
  select 'qa-default-brand', 'QA', biz_a, (select category_id from public.brands where id = brand_a) from w $$),
  'ok', 'a member adds a brand without spelling out is_active = false');
select tests.clear_authentication();

select todo('QA 2.2-B8 (S4): the creator keeps reading the business after being removed', 1);
insert into public.business_members values ((select biz_a from w), (select other_owner from w), 'owner');
update public.businesses set created_by = (select owner from w) where id = (select biz_a from w);
delete from public.business_members
  where business_id = (select biz_a from w) and user_id = (select owner from w);
select tests.authenticate_as((select owner from w));
select is((select count(*) from public.businesses where id = (select biz_a from w)), 0::bigint,
  'a removed creator no longer reads the business''s contact details');
select tests.clear_authentication();

select * from finish();
rollback;
