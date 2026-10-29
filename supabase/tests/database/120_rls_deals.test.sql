-- Access: deals, targets and card offers.
begin;
select plan(26);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;
create temp table extra as select
  tests.make_deal((select brand_a from w), 'published') as expired,
  tests.make_deal((select brand_a from w), 'published') as future,
  tests.make_deal((select brand_a from w), 'draft', 'local') as local_draft,
  tests.make_area((select city from w)) as area;
update public.deals set status = 'expired' where id = (select expired from extra);
update public.deals set starts_at = now() + interval '2 days' where id = (select future from extra);
grant select on extra to anon, authenticated;
insert into public.deal_targets (deal_id, city_id) select local_draft, (select city from w) from extra;

create function pg_temp.visible() returns text[] language sql as $$
  select array(
    select case d.id when w.live_a then 'live_a' when w.draft_a then 'draft_a'
                     when w.review_a then 'review_a' when w.live_b then 'live_b'
                     when e.expired then 'expired' when e.future then 'future'
                     when e.local_draft then 'local_draft' end
    from public.deals d, w, extra e order by 1);
$$;
grant execute on function pg_temp.visible() to anon, authenticated;

-- Who sees what
select tests.authenticate_as_anon();
select is(pg_temp.visible(), array['expired', 'live_a', 'live_b'],
  'anon sees live and expired deals that have started');
select tests.authenticate_as((select shopper from w));
select is(pg_temp.visible(), array['expired', 'live_a', 'live_b'], 'so does a shopper');
select tests.authenticate_as((select other_owner from w));
select is(pg_temp.visible(), array['expired', 'live_a', 'live_b'],
  'another business does not see A''s drafts');
select tests.authenticate_as((select editor from w));
select is(pg_temp.visible(),
  array['draft_a', 'expired', 'future', 'live_a', 'live_b', 'local_draft', 'review_a'],
  'members see every deal of their brands');

-- Shoppers and anon write nothing.
select tests.authenticate_as_anon();
select throws_ok($$ update public.deals set title_en = 'x' where true $$, '42501', null,
  'anon cannot update deals');
select tests.authenticate_as((select shopper from w));
select is(tests.affected($$ update public.deals set title_en = 'Hacked deal' where true returning 1 $$), 0,
  'a shopper updates no deal');
select throws_ok($$ select tests.make_deal((select brand_a from w)) $$, '42501', null,
  'a shopper cannot add deals');

-- Members
select tests.authenticate_as((select editor from w));
select lives_ok($$
  insert into public.deals (brand_id, category_id, kind, scope, source, title_en, offer_kind, percent)
  select brand_a, (select category_id from public.brands where id = brand_a), 'food_deal',
         'nationwide', 'business', 'BBQ night', 'percent_off', 20 from w
$$, 'a member writes a draft');
select throws_ok($$
  insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, offer_kind, percent)
  select brand_a, (select category_id from public.brands where id = brand_a), 'food_deal',
         'nationwide', 'published', 'business', 'BBQ night', 'percent_off', 20 from w
$$, '42501', null, 'a member cannot publish directly');
select throws_ok($$
  insert into public.deals (brand_id, category_id, kind, scope, source, title_en, offer_kind, percent)
  select brand_b, (select category_id from public.brands where id = brand_b), 'food_deal',
         'nationwide', 'business', 'Fake deal', 'percent_off', 20 from w
$$, '42501', null, 'a member cannot write deals for another business');
select throws_ok($$
  insert into public.deals (brand_id, category_id, kind, scope, source, title_en, offer_kind, percent)
  select brand_a, (select category_id from public.brands where id = brand_a), 'food_deal',
         'nationwide', 'staff', 'BBQ night', 'percent_off', 20 from w
$$, '42501', null, 'a member cannot pose as staff');
select lives_ok($$ update public.deals set status = 'pending_review' where id = (select draft_a from w) $$,
  'a member sends a draft for review');
select throws_ok($$ update public.deals set status = 'published' where id = (select review_a from w) $$,
  '42501', null, 'a member cannot publish');
select throws_ok($$ update public.deals set title_en = 'Edited live deal' where id = (select live_a from w) $$,
  '42501', null, 'a member cannot edit a live deal in place');
select throws_ok($$ update public.deals set verified_at = now() where id = (select review_a from w) $$,
  '42501', null, 'a member cannot mark a deal verified');
select lives_ok($$ update public.deals set status = 'draft' where id = (select live_a from w) $$,
  'a member takes a live deal back to draft');
select lives_ok($$ update public.deals set title_en = 'Edited deal' where id = (select live_a from w) $$,
  'and then edits it');
select is(tests.affected($$ delete from public.deals where id = (select expired from extra) returning 1 $$), 0,
  'a member deletes drafts only');

-- Targets follow their deal.
select lives_ok($$ insert into public.deal_targets (deal_id, city_id, area_id)
  select local_draft, (select city from w), area from extra $$,
  'a member adds targets to a draft');
select throws_ok($$ insert into public.card_offers (deal_id, bank_id)
  select live_b, tests.make_bank() from w $$, '42501', null,
  'a member cannot add card offers to someone else''s deal');
select tests.authenticate_as_anon();
select is((select count(*)::int from public.deal_targets where deal_id = (select local_draft from extra)), 0,
  'targets of a draft are hidden');

-- Moderators (with MFA) publish and reject.
select tests.authenticate_as((select moderator from w));
select is(tests.affected($$ update public.deals set status = 'published' where id = (select review_a from w) returning 1 $$), 0,
  'without MFA a moderator cannot even see deals in review');
select tests.staff((select moderator from w));
select lives_ok($$ update public.deals set status = 'published', verified_at = now() where id = (select review_a from w) $$,
  'a moderator publishes');
select lives_ok($$ update public.deals set status = 'rejected' where id = (select draft_a from w) $$,
  'a moderator rejects');
select is(tests.affected($$ delete from public.deals where id = (select live_b from w) returning 1 $$), 0,
  'moderators do not delete deals (admins do)');
select tests.staff((select admin from w));
select is(tests.affected($$ delete from public.deals where id = (select live_b from w) returning 1 $$), 1,
  'an admin deletes a deal');

select * from finish();
rollback;
