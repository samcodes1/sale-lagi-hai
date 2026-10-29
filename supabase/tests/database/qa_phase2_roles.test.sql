-- QA, Phase 2 full-phase gate: every RPC and view in `public`, called by
-- every role. The table-level sweep is in qa_rls.test.sql. This file
-- fails if a new public function appears, so the next RPC gets the same
-- review.
begin;
select plan(4);

create temp table w as select * from tests.make_world();
update public.brands set is_active = true;
grant select on w to anon, authenticated;

select is(
  (select array_agg(p.proname::text order by p.proname) from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.prokind = 'f'),
  -- 4.2 added prepare_account_deletion (service role only) and
  -- sync_guest_preferences (signed-in users), reviewed in
  -- 800_accounts.test.sql; QA re-checks them in the 4.2 gate.
  -- 4.3 added ending_soon_deals (810_home.test.sql).
  -- 4.6 added brand_suggestions and replaced search_deals' signature
  -- (830_search.test.sql).
  -- 4.7 added deals_for_cards, open to guests (840_my_cards.test.sql).
  -- 4.8 added mark_alerts_read and unread_alert_count, signed-in only
  -- (850_inbox.test.sql).
  -- 4.9 added my_alert_prefs and update_alert_prefs, signed-in only
  -- (860_settings.test.sql).
  array['approve_submission', 'brand_deals', 'brand_suggestions', 'custom_access_token_hook', 'deals_for_cards', 'deals_for_my_cards',
        'ending_soon_deals', 'featured_deals', 'feed', 'mark_alerts_read', 'mark_submission_duplicate', 'my_alert_prefs', 'nearby_deals',
        'prepare_account_deletion', 'register_push_token',
        'reject_submission', 'search_deals', 'submission_duplicates', 'sync_guest_preferences',
        'trending_deals', 'unread_alert_count', 'update_alert_prefs'],
  'the public RPC surface is exactly the reviewed set');

-- One pending submission per staff action, so each call has work to do.
create temp table subs (g int, id uuid);
insert into public.submissions (submitter_id, kind, brand_name, title)
  select (select shopper from w), 'other', 'Brand', 'Submission ' || g from generate_series(1, 12) g;
insert into subs select row_number() over (order by length(title), title), id from public.submissions where title like 'Submission %';
grant select on subs to anon, authenticated;

create temp table calls (who text, rpc text, code text);
grant all on calls to anon, authenticated;
create function pg_temp.call_all(who text, n int) returns void language plpgsql as $$
declare
  r record;
  code text;
  sub uuid := (select id from subs where g = n);
begin
  for r in select * from (values
    ('feed', 'select count(*) from public.feed(null, null, true)'),
    ('featured_deals', 'select count(*) from public.featured_deals(''home_featured'')'),
    ('trending_deals', 'select count(*) from public.trending_deals()'),
    -- 4.3; QA added it to this matrix in the 4.3 gate (docs/qa/4.3.md).
    ('ending_soon_deals', 'select count(*) from public.ending_soon_deals()'),
    ('nearby_deals', 'select count(*) from public.nearby_deals(24.86, 67.0, 3000)'),
    ('search_deals', 'select count(*) from public.search_deals(''winter'')'),
    ('search_filters', 'select count(*) from public.search_deals(null, min_percent => 10, ending_within_hours => 72)'),
    ('brand_suggestions', 'select count(*) from public.brand_suggestions(''kol'')'),
    ('brand_deals', 'select count(*) from public.brand_deals(''kolachi'')'),
    ('deals_for_my_cards', 'select count(*) from public.deals_for_my_cards()'),
    ('deals_for_cards', 'select count(*) from public.deals_for_cards(array[gen_random_uuid()])'),
    ('mark_alerts_read', 'select public.mark_alerts_read()'),
    ('unread_alert_count', 'select public.unread_alert_count()'),
    ('my_alert_prefs', 'select count(*) from public.my_alert_prefs()'),
    ('update_alert_prefs', 'select count(*) from public.update_alert_prefs(my_city => true)'),
    ('register_push_token', format('select public.register_push_token(%L, ''android'')', who || '-device-0000000000000000')),
    ('custom_access_token_hook', 'select public.custom_access_token_hook(''{"user_id": null}'')'),
    ('submission_duplicates', format('select count(*) from public.submission_duplicates(%L)', sub)),
    ('approve_submission', format('select public.approve_submission(%L, %L::jsonb)', sub,
       jsonb_build_object('brand_id', (select brand_b from w), 'category_id',
         (select category_id from public.brands where id = (select brand_b from w)),
         'kind', 'other', 'scope', 'nationwide', 'title_en', 'Approved by ' || who,
         'offer_kind', 'text', 'offer_text_en', 'Deal'))),
    ('reject_submission', format('select public.reject_submission(%L, ''not a real deal'')',
       (select id from subs where g = n + 6))),
    ('moderation_queue', 'select count(*) from public.moderation_queue'),
    ('stale_deals', 'select count(*) from public.stale_deals'),
    ('deal_cards', 'select count(*) from public.deal_cards')
  ) v(rpc, q) loop
    begin
      execute r.q;
      code := 'ok';
    exception when others then
      code := sqlstate;
    end;
    insert into calls values (who, r.rpc, code);
  end loop;
end $$;
grant execute on function pg_temp.call_all(text, int) to anon, authenticated;

select tests.authenticate_as_anon(); select pg_temp.call_all('anon', 1); select tests.clear_authentication();
select tests.authenticate_as((select shopper from w)); select pg_temp.call_all('shopper', 2); select tests.clear_authentication();
select tests.authenticate_as((select owner from w)); select pg_temp.call_all('owner', 3); select tests.clear_authentication();
select tests.authenticate_as((select moderator from w)); select pg_temp.call_all('moderator_aal1', 4); select tests.clear_authentication();
select tests.staff((select moderator from w)); select pg_temp.call_all('moderator_aal2', 5); select tests.clear_authentication();
select tests.staff((select admin from w)); select pg_temp.call_all('admin_aal2', 6); select tests.clear_authentication();

-- What each role may call. Reads are open to all; my-cards, devices and
-- submission tools need a session; staff actions need MFA; the token hook
-- is for supabase_auth_admin only.
create temp table expected (who text, rpc text, code text);
insert into expected
select who, rpc, case
    when rpc = 'custom_access_token_hook' then '42501'
    when who = 'anon' and rpc in ('deals_for_my_cards', 'register_push_token', 'submission_duplicates',
                                  'mark_alerts_read', 'unread_alert_count', 'my_alert_prefs',
                                  'update_alert_prefs',
                                  'approve_submission', 'reject_submission', 'moderation_queue', 'stale_deals') then '42501'
    when rpc in ('approve_submission', 'reject_submission')
         and who not in ('moderator_aal2', 'admin_aal2') then '42501'
    else 'ok' end
from unnest(array['anon', 'shopper', 'owner', 'moderator_aal1', 'moderator_aal2', 'admin_aal2']) who,
     (select distinct rpc from calls) r;

select is(
  (select string_agg(format('%s/%s: %s (want %s)', c.who, c.rpc, c.code, e.code), '; ' order by c.who, c.rpc)
   from calls c join expected e using (who, rpc) where c.code <> e.code),
  null, 'every role gets exactly the expected answer from every RPC and view');
select is((select count(*) from calls), 138::bigint, 'six roles called twenty-three RPCs and views');

-- What non-staff see in the staff views.
select tests.authenticate_as((select shopper from w));
select is((select count(*) from public.stale_deals), 0::bigint, 'shoppers see no stale-deal list');
select tests.clear_authentication();

select * from finish();
rollback;
