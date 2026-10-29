-- Jobs: rate limits, expiry, freshness, push tokens and the alert planner.
begin;
select plan(38);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Rate limits
-- ---------------------------------------------------------------------------
create temp table many as select tests.make_deal((select brand_b from w), 'published') as id
  from generate_series(1, 11);
grant select on many to authenticated, service_role;
select tests.authenticate_as((select shopper from w));
select lives_ok($$ insert into public.reports (deal_id, reason) select id, 'expired' from many limit 10 $$,
  'ten reports in an hour are fine');
select throws_ok($$ insert into public.reports (deal_id, reason)
  select id, 'expired' from many offset 10 $$, 'PT429', null,
  'the eleventh report in an hour is rate limited (HTTP 429)');
select lives_ok($$ insert into public.submissions (kind, brand_name, title)
  select 'food_deal', 'Brand', 'Deal number ' || i from generate_series(1, 5) i $$,
  'five submissions in an hour are fine');
select throws_ok($$ insert into public.submissions (kind, brand_name, title)
  values ('food_deal', 'Brand', 'One too many') $$, 'PT429', null, 'the sixth is rate limited');
select tests.clear_authentication();
set local role service_role;
select lives_ok($$ insert into public.submissions (submitter_id, kind, brand_name, title)
  select shopper, 'food_deal', 'Brand', 'Imported ' || i from w, generate_series(1, 10) i $$,
  'the service role is not rate limited');
reset role;

-- ---------------------------------------------------------------------------
-- Expiry and placements
-- ---------------------------------------------------------------------------
update public.deals set starts_at = now() - interval '3 days', ends_at = now() - interval '1 minute'
  where id = (select live_a from w);
insert into public.placements (business_id, deal_id, slot, starts_at, ends_at, status) values
  ((select biz_b from w), (select live_b from w), 'home_featured', now() - interval '1 hour', now() + interval '1 day', 'scheduled'),
  ((select biz_b from w), (select live_b from w), 'search_top', now() - interval '2 days', now() - interval '1 hour', 'active');
select ok(private.expire_deals() >= 1, 'expire_deals expires ended deals');
select is((select status::text from public.deals where id = (select live_a from w)), 'expired',
  'the ended deal is now expired');
select is((select array_agg(status::text order by slot) from public.placements where business_id = (select biz_b from w)),
  array['active', 'ended'], 'placements start and end on time');
select ok(exists (select 1 from public.audit_log where row_id = (select live_a from w)::text and actor_id is null),
  'the expiry is audited as a system change');

-- ---------------------------------------------------------------------------
-- Freshness
-- ---------------------------------------------------------------------------
create temp table fr as select tests.make_deal(status => 'published') as fresh,
  tests.make_deal(status => 'published') as reported, tests.make_deal(status => 'published') as unverified;
update public.deals set verified_at = now() - interval '1 hour' where id in (select fresh from fr union select reported from fr);
insert into public.reports (deal_id, reporter_id, reason)
  select reported, tests.create_user(), 'expired' from fr, generate_series(1, 2);
select ok(private.refresh_freshness() >= 3, 'refresh_freshness rescores live deals');
select results_eq($$ select (select freshness from public.deals where id = fresh), (select freshness from public.deals where id = reported),
                            (select freshness from public.deals where id = unverified) from fr $$,
  $$ values (100::smallint, 70::smallint, 40::smallint) $$,
  'verified today 100, minus 15 per open report, never verified 40');

-- ---------------------------------------------------------------------------
-- Push tokens and time zones
-- ---------------------------------------------------------------------------
select tests.authenticate_as((select shopper from w));
select lives_ok($$ select public.register_push_token(repeat('a', 40), 'android') $$, 'a user registers a device');
select tests.authenticate_as((select owner from w));
select lives_ok($$ select public.register_push_token(repeat('a', 40), 'android') $$,
  'the same device signing in as someone else takes the token over');
select is((select count(*)::int from public.push_tokens), 1, 'and now it is theirs');
select tests.authenticate_as((select shopper from w));
select is((select count(*)::int from public.push_tokens), 0, 'the previous owner no longer sees it');
select throws_ok($$ select public.register_push_token('short', 'android') $$, '23514', null, 'tokens are validated');
select throws_ok($$ update public.alert_prefs set time_zone = 'Mars/Phobos' where user_id = (select shopper from w) $$,
  '23514', null, 'unknown time zones are rejected');
select tests.authenticate_as_anon();
select throws_ok($$ select public.register_push_token(repeat('b', 40), 'android') $$, '42501', null,
  'anon cannot register devices');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- The alert planner
-- ---------------------------------------------------------------------------
-- Five followers of a new brand: awake, in quiet hours, push off, topic
-- off, and an Urdu speaker.
create temp table f as select tests.make_brand(slug => 'test-alkaram') as brand,
  tests.create_user() as awake, tests.create_user() as asleep, tests.create_user() as push_off,
  tests.create_user() as topic_off, tests.create_user() as urdu;
update public.brands set name_ur = 'الکرم' where id = (select brand from f);
insert into public.follows (user_id, brand_id)
  select u, (select brand from f) from f, unnest(array[awake, asleep, push_off, topic_off, urdu]) u;
insert into public.push_tokens (token, user_id, platform)
  select 'token-' || u, u, 'android' from f, unnest(array[awake, asleep, push_off, urdu]) u;
-- Quiet hours relative to now in Karachi: the awake ones are outside
-- theirs, the sleeper inside.
create temp table k as select (now() at time zone 'Asia/Karachi')::time as t;
update public.alert_prefs set push_enabled = true,
  quiet_start = (select t from k) + interval '3 hours', quiet_end = (select t from k) + interval '4 hours'
  where user_id in (select awake from f union select urdu from f union select topic_off from f);
update public.alert_prefs set push_enabled = true,
  quiet_start = (select t from k) - interval '1 hour', quiet_end = (select t from k) + interval '1 hour'
  where user_id = (select asleep from f);
update public.alert_prefs set followed_brands = false where user_id = (select topic_off from f);
update public.profiles set locale = 'ur' where id = (select urdu from f);

create temp table d1 as select tests.make_deal((select brand from f), 'published') as id;
select ok(exists (select 1 from private.alert_queue where deal_id = (select id from d1)),
  'publishing a deal queues its alerts');
select ok(not exists (select 1 from private.alert_queue q join public.deals d on d.id = q.deal_id where d.status = 'draft'),
  'drafts are never queued');
select is(private.plan_alerts(), 3, 'three pushes planned: awake, asleep (deferred) and the Urdu speaker');
select is((select array_agg(u order by u) from (
    select case n.user_id when f.awake then 'awake' when f.asleep then 'asleep' when f.push_off then 'push_off'
                          when f.topic_off then 'topic_off' when f.urdu then 'urdu' end as u
    from public.notifications n, f where n.deal_id = (select id from d1)) x),
  array['asleep', 'awake', 'push_off', 'urdu'],
  'in-app alerts for every follower with the topic on (push or not)');
select ok((select send_at <= now() from private.push_outbox where user_id = (select awake from f)),
  'the awake follower is pushed now');
select is((select (send_at at time zone 'Asia/Karachi')::time from private.push_outbox where user_id = (select asleep from f)),
  (select quiet_end from public.alert_prefs where user_id = (select asleep from f)),
  'the sleeper''s push waits until their quiet hours end');
select is((select title from private.push_outbox where user_id = (select awake from f)), 'Kolachi: 40% off',
  'the push title is the brand and the offer');
select is((select title from private.push_outbox where user_id = (select urdu from f)),
  'الکرم: ' || chr(8294) || '40%' || chr(8297) || ' رعایت', 'Urdu speakers get Urdu, with the number isolated');
select is(private.plan_alerts(), 0, 'a second run plans nothing new');

-- Republishing doesn't alert again; a second deal of the same brand is
-- inbox-only today (one push per brand per day).
update public.deals set status = 'removed' where id = (select id from d1);
update public.deals set status = 'published' where id = (select id from d1);
select is(private.plan_alerts(), 0, 'republishing does not alert again');
create temp table d2 as select tests.make_deal((select brand from f), 'published') as id;
select is(private.plan_alerts(), 0, 'one push per brand per day');
select ok(exists (select 1 from public.notifications where deal_id = (select id from d2) and user_id = (select awake from f)),
  'but the second deal still reaches the inbox');

-- Daily cap: "low" allows one push a day across brands.
update public.alert_prefs set frequency = 'low' where user_id = (select awake from f);
create temp table other_brand as select tests.make_brand(slug => 'test-gul-ahmed') as id;
insert into public.follows (user_id, brand_id) select awake, (select id from other_brand) from f;
select tests.make_deal((select id from other_brand), 'published');
select is(private.plan_alerts(), 0, 'a "low" user gets one push a day, across brands');

-- The dispatcher's side
select is((select count(*)::int from private.claim_due_pushes()), 2,
  'claiming returns the due pushes (not the deferred one), one per device');
select is((select count(*)::int from private.claim_due_pushes()), 0, 'claimed pushes are not handed out twice');
select is(private.mark_pushes_sent(array(select id from private.push_outbox where send_at <= now())), 2,
  'pushes are marked sent');
select is(private.drop_push_tokens(array['token-' || (select awake from f)]), 1, 'dead tokens are dropped');

-- Nobody but the database owner runs the jobs.
select tests.authenticate_as((select shopper from w));
select throws_ok('select private.plan_alerts()', '42501', null, 'users cannot run the planner');
select throws_ok('select * from private.claim_due_pushes()', '42501', null, 'or claim pushes');
select tests.clear_authentication();
select ok((select count(*) from cron.job where jobname in
  ('expire-deals', 'refresh-freshness', 'plan-alerts', 'cleanup-old-rows')) = 4, 'the jobs are scheduled');

select * from finish();
rollback;
