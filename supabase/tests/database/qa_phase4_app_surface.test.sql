-- QA, Phase 4 gate (docs/qa/phase-4.md): the whole database surface the
-- consumer app uses (lib/**: every TableQuery, insert, delete and rpc),
-- checked per role in one place:
-- 1. RLS is on for every table the app touches; the deal_cards view runs as
--    the caller.
-- 2. Execute grants: the read RPCs are open to anon; the account RPCs are
--    not; no app RPC is callable by PUBLIC.
-- 3. Two shoppers on the same server: neither sees, deletes nor writes the
--    other's saves, follows, cards, alerts or alert preferences, through
--    tables or through the RPCs.
-- 4. Anon sees no drafts or reviews through any read path the app uses.
begin;
select plan(54);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated, service_role;
create temp table other as select tests.create_user('second@example.com') as uid;
grant select on other to anon, authenticated, service_role;
create temp table card as select tests.make_card_product(tests.make_bank('qa-p4-bank')) as id;
grant select on card to anon, authenticated, service_role;

-- --------------------------------------------------------------- 1. RLS ---
select ok((select bool_and(c.relrowsecurity) from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname in ('cities', 'areas', 'categories', 'banks', 'card_products',
    'brands', 'deals', 'deal_targets', 'outlets', 'follows', 'saves', 'user_cards', 'notifications',
    'reports', 'alert_prefs', 'profiles')),
  'RLS is enabled on every table the app reads or writes');
select is((select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname in ('cities', 'areas', 'categories', 'banks', 'card_products',
    'brands', 'deals', 'deal_targets', 'outlets', 'follows', 'saves', 'user_cards', 'notifications',
    'reports', 'alert_prefs', 'profiles')), 16, 'all 16 of those tables exist');
select ok((select coalesce('security_invoker=true' = any(c.reloptions), false) from pg_class c
  join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = 'deal_cards'),
  'deal_cards runs with the caller''s rights');

-- ------------------------------------------------------ 2. execute grants ---
select ok(bool_and(has_function_privilege('anon', p.oid, 'execute')),
  'anon may call every read RPC the app uses')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('feed', 'featured_deals', 'trending_deals', 'nearby_deals',
  'deals_for_cards', 'search_deals', 'ending_soon_deals', 'brand_deals', 'brand_suggestions');
select is(count(*)::int, 0, 'anon may call none of the account RPCs')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('sync_guest_items', 'sync_guest_preferences', 'my_alert_prefs',
  'update_alert_prefs', 'mark_alerts_read', 'unread_alert_count', 'deals_for_my_cards')
  and has_function_privilege('anon', p.oid, 'execute');
select ok(bool_and(has_function_privilege('authenticated', p.oid, 'execute')),
  'a signed-in shopper may call every RPC the app uses')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('feed', 'featured_deals', 'trending_deals', 'nearby_deals',
  'deals_for_cards', 'search_deals', 'ending_soon_deals', 'brand_deals', 'brand_suggestions',
  'sync_guest_items', 'sync_guest_preferences', 'my_alert_prefs', 'update_alert_prefs',
  'mark_alerts_read', 'unread_alert_count', 'deals_for_my_cards');
select is(count(*)::int, 0, 'no app RPC is executable by PUBLIC')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname in ('feed', 'featured_deals', 'trending_deals', 'nearby_deals',
  'deals_for_cards', 'search_deals', 'ending_soon_deals', 'brand_deals', 'brand_suggestions',
  'sync_guest_items', 'sync_guest_preferences', 'my_alert_prefs', 'update_alert_prefs',
  'mark_alerts_read', 'unread_alert_count', 'deals_for_my_cards')
  and exists (select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
    where a.grantee = 0 and a.privilege_type = 'EXECUTE');
select is(count(*)::int, 0, 'every security definer function the app calls pins search_path')
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prosecdef and p.proname in ('feed', 'featured_deals', 'trending_deals',
  'nearby_deals', 'deals_for_cards', 'search_deals', 'ending_soon_deals', 'brand_deals', 'brand_suggestions',
  'sync_guest_items', 'sync_guest_preferences', 'my_alert_prefs', 'update_alert_prefs',
  'mark_alerts_read', 'unread_alert_count', 'deals_for_my_cards')
  and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%');

-- ------------------------------------------------ 3. shopper A's account ---
select tests.authenticate_as((select shopper from w));
select lives_ok($$ insert into public.saves (user_id, deal_id) select shopper, live_a from w $$, 'A saves a deal');
select lives_ok($$ insert into public.follows (user_id, brand_id) select shopper, brand_a from w $$, 'A follows a brand');
select lives_ok($$ insert into public.user_cards (user_id, card_product_id) select shopper, id from w, card $$, 'A adds a card');
select lives_ok($$ select * from public.update_alert_prefs(push_enabled => true, frequency => 'high') $$,
  'A changes alert preferences');
select tests.clear_authentication();
-- An alert for A (written by the planner, as the service role would).
insert into public.notifications (user_id, kind, title) select shopper, 'system', 'For A' from w;

-- --------------------------------------------------------- anon, then B ---
select tests.authenticate_as_anon();
select throws_ok($$ select * from public.saves $$, '42501', null, 'anon cannot read saves');
select throws_ok($$ select * from public.follows $$, '42501', null, 'anon cannot read follows');
select throws_ok($$ select * from public.user_cards $$, '42501', null, 'anon cannot read cards');
select throws_ok($$ select * from public.notifications $$, '42501', null, 'anon cannot read alerts');
select throws_ok($$ insert into public.saves (user_id, deal_id) select shopper, live_b from w $$,
  '42501', null, 'anon cannot save in A''s name');
select throws_ok($$ insert into public.reports (deal_id, reason) select live_b, 'expired' from w $$,
  '42501', null, 'anon cannot report');
select throws_ok($$ select public.sync_guest_items(array[(select live_b from w)]) $$, '42501', null,
  'anon cannot call sync_guest_items');
select throws_ok($$ select * from public.deals_for_my_cards() $$, '42501', null,
  'anon cannot call deals_for_my_cards');
select tests.clear_authentication();

select tests.authenticate_as((select uid from other));
select is((select count(*)::int from public.saves), 0, 'B sees none of A''s saves');
select is((select count(*)::int from public.follows), 0, 'B sees none of A''s follows');
select is((select count(*)::int from public.user_cards), 0, 'B sees none of A''s cards');
select is((select count(*)::int from public.notifications), 0, 'B sees none of A''s alerts');
select is((select count(*)::int from public.alert_prefs), 1, 'B sees only its own alert_prefs row');
select is((select (push_enabled, frequency::text) from public.my_alert_prefs()), (false, 'normal'::text),
  'B''s my_alert_prefs are B''s defaults, not A''s');
select is(public.unread_alert_count(), 0, 'B''s unread count leaves out A''s alert');
select is(public.mark_alerts_read((select array_agg(id) from public.notifications)), 0,
  'B marks nothing read');
select is(public.mark_alerts_read(), 0, 'B''s "mark all" touches none of A''s');
select is((select count(*)::int from public.deals_for_my_cards()), 0,
  'deals_for_my_cards for B does not use A''s card');
-- Deletes the app sends (user_id + key) in A's name do nothing.
select is(tests.affected($$ delete from public.saves where user_id = (select shopper from w) returning 1 $$), 0,
  'B cannot delete A''s save');
select is(tests.affected($$ delete from public.follows where user_id = (select shopper from w) returning 1 $$), 0,
  'B cannot delete A''s follow');
select is(tests.affected($$ delete from public.user_cards where user_id = (select shopper from w) returning 1 $$), 0,
  'B cannot delete A''s card');
select is(tests.affected($$ update public.notifications set read_at = now() returning 1 $$), 0,
  'B cannot mark A''s alert read directly');
-- Inserts in A's name are refused.
select throws_ok($$ insert into public.saves (user_id, deal_id) select shopper, live_b from w $$,
  '42501', null, 'B cannot save in A''s name');
select throws_ok($$ insert into public.follows (user_id, brand_id) select shopper, brand_b from w $$,
  '42501', null, 'B cannot follow in A''s name');
select throws_ok($$ insert into public.user_cards (user_id, card_product_id) select shopper, id from w, card $$,
  '42501', null, 'B cannot add a card in A''s name');
-- The sync RPCs write as B only.
select lives_ok($$ select public.sync_guest_items(array[(select live_b from w)], array[(select id from card)]) $$,
  'B syncs a save and a card');
select lives_ok($$ select public.sync_guest_preferences(brand_ids => array[(select brand_b from w)]) $$,
  'B syncs a follow');
select is((select count(*)::int from public.saves), 1, 'B now sees exactly its own save');
select is((select count(*)::int from public.user_cards), 1, 'B now sees exactly its own card');
select is((select count(*)::int from public.follows), 1, 'B now sees exactly its own follow');
select ok((select count(*) from public.deals_for_my_cards()) >= 0, 'deals_for_my_cards works for B');
select tests.clear_authentication();

-- A is untouched by everything B did.
select tests.authenticate_as((select shopper from w));
select is((select array_agg(deal_id) from public.saves), array[(select live_a from w)], 'A still has only its save');
select is((select array_agg(brand_id) from public.follows), array[(select brand_a from w)], 'A still has only its follow');
select is((select count(*)::int from public.user_cards), 1, 'A still has its one card');
select is(public.unread_alert_count(), 1, 'A''s alert is still unread');
select is((select (push_enabled, frequency::text) from public.my_alert_prefs()), (true, 'high'::text),
  'A''s preferences are still A''s');
select tests.clear_authentication();

-- ---------------------------------------- 4. anon sees live deals only ---
select tests.authenticate_as_anon();
select is((select count(*)::int from public.deal_cards where id in ((select draft_a from w), (select review_a from w))), 0,
  'deal_cards hides drafts and reviews from anon');
select is((select count(*)::int from public.deals where id in ((select draft_a from w), (select review_a from w))), 0,
  'deals hides drafts and reviews from anon');
select is((select count(*)::int from public.feed(page_size => 50) f where f.id in ((select draft_a from w), (select review_a from w))), 0,
  'feed never returns a draft or a review');
select is((select count(*)::int from public.search_deals('', page_size => 50) f where f.id in ((select draft_a from w), (select review_a from w))), 0,
  'search_deals never returns a draft or a review');
select is((select count(*)::int from public.brand_deals('kolachi', page_size => 50) f where f.id in ((select draft_a from w), (select review_a from w))), 0,
  'brand_deals never returns a draft or a review');
select ok((select count(*) from public.feed(page_size => 50) f where f.id = (select live_a from w)) = 1,
  'the live deal is in the feed (the checks above are not vacuous)');
select tests.clear_authentication();

select * from finish();
rollback;
