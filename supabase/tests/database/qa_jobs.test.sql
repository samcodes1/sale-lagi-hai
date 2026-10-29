-- QA (sub-phase 2.5): rate limits, the alert planner and push tokens.
-- "QA BUG" assertions FAIL until the bug in docs/qa/2.5.md is fixed.
begin;
select plan(9);

create temp table w as select * from tests.make_world();
grant select on w to authenticated;
update public.brands set is_active = true;
delete from private.alert_queue;

-- SQLSTATE of a statement run as the current role.
create function pg_temp.state(statement text) returns text language plpgsql as $$
begin
  execute statement;
  return 'ok';
exception when others then
  return sqlstate;
end $$;
grant execute on function pg_temp.state(text) to authenticated;

-- ---------------------------------------------------------------------------
-- QA BUG 2.5-J1 (S2): the rate limits count rows by created_at, which the
-- client may set (insert is granted on every column). Backdated rows
-- never count, so the limits don't hold.
-- ---------------------------------------------------------------------------
create temp table many as select tests.make_deal((select brand_b from w), 'published') as id from generate_series(1, 12);
grant select on many to authenticated;
select tests.authenticate_as((select shopper from w));
select is(pg_temp.state($$ insert into public.reports (deal_id, reason, created_at)
  select id, 'spam', '2000-01-01' from many $$), 'PT429',
  'QA BUG 2.5-J1: twelve backdated reports in one go are rate limited');
select is(pg_temp.state($$ insert into public.submissions (kind, brand_name, title, created_at)
  select 'other', 'Brand', 'Backdated submission ' || g, '2000-01-01' from generate_series(1, 6) g $$), 'PT429',
  'QA BUG 2.5-J1: six backdated submissions in an hour are rate limited');
-- Without backdating, a batch insert is counted row by row.
select is(pg_temp.state($$ insert into public.submissions (kind, brand_name, title)
  select 'other', 'Brand', 'Batch submission ' || g from generate_series(1, 6) g $$), 'PT429',
  'six submissions in one statement are rate limited');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- QA BUG 2.5-J2 (S2): a deal that isn't live when the planner first sees
-- it (it starts later, or its brand is still inactive) is marked
-- processed and never alerted, not even once it goes live.
-- ---------------------------------------------------------------------------
insert into public.follows (user_id, brand_id) select shopper, brand_b from w;
create temp table later as select tests.make_deal((select brand_b from w), 'draft') as id;
update public.deals set starts_at = now() + interval '1 hour' where id = (select id from later);
update public.deals set status = 'published' where id = (select id from later);
select private.plan_alerts() as first_run \gset
-- An hour passes: the deal has started.
update public.deals set starts_at = now() - interval '1 minute' where id = (select id from later);
select private.plan_alerts() as second_run \gset
select is((select count(*) from public.notifications where deal_id = (select id from later)), 1::bigint,
  'QA BUG 2.5-J2: followers are alerted once a scheduled deal starts');

create temp table hidden_brand as select tests.make_brand((select biz_b from w), 'qa-later-brand') as id;
update public.brands set is_active = false where id = (select id from hidden_brand);
insert into public.follows (user_id, brand_id) select shopper, (select id from hidden_brand) from w;
create temp table hidden_deal as select tests.make_deal((select id from hidden_brand), 'published') as id;
select private.plan_alerts() as third_run \gset
update public.brands set is_active = true where id = (select id from hidden_brand);
select private.plan_alerts() as fourth_run \gset
select is((select count(*) from public.notifications where deal_id = (select id from hidden_deal)), 1::bigint,
  'QA BUG 2.5-J2: followers are alerted once staff activate the brand');

-- ---------------------------------------------------------------------------
-- QA BUG 2.5-J3 (S3): "republishing doesn't alert again" holds only for 7
-- days. Once cleanup_old_rows removes the processed queue row, any update
-- that lists status (the admin console saving a live deal) alerts every
-- follower again.
-- ---------------------------------------------------------------------------
create temp table again as select tests.make_deal((select brand_b from w), 'published') as id;
select private.plan_alerts() as run_a \gset
update private.alert_queue set processed_at = now() - interval '8 days' where deal_id = (select id from again);
select private.cleanup_old_rows();
update public.deals set status = 'published', title_en = 'Winter sale on everything!' where id = (select id from again);
select private.plan_alerts() as run_b \gset
select is((select count(*) from public.notifications where deal_id = (select id from again)), 1::bigint,
  'QA BUG 2.5-J3: editing a live deal weeks later does not alert its followers again');

-- ---------------------------------------------------------------------------
-- QA BUG 2.5-J4 (S3): register_push_token has no per-user cap or rate
-- limit. One account registers any number of 4 KB tokens; the dispatcher
-- then sends every alert of that user once per token.
-- ---------------------------------------------------------------------------
select tests.authenticate_as((select shopper from w));
select pg_temp.state($$ select public.register_push_token(md5(g::text) || repeat('x', 4000), 'android')
  from generate_series(1, 200) g $$) as registered \gset
select tests.clear_authentication();
select cmp_ok((select count(*) from public.push_tokens where user_id = (select shopper from w)), '<=', 10::bigint,
  'QA BUG 2.5-J4: one user cannot hold hundreds of device tokens');

-- Things that held up.
-- Quiet hours across midnight in several time zones: deferred to the end.
create temp table tz as
  select z, tests.create_user() as uid from unnest(array['America/Los_Angeles', 'Pacific/Kiritimati',
    'Asia/Kathmandu', 'Pacific/Pago_Pago']) z;
insert into public.follows (user_id, brand_id) select uid, (select brand_a from w) from tz;
insert into public.push_tokens (token, user_id, platform) select md5(uid::text) || md5(z), uid, 'android' from tz;
-- Overnight window that started a minute ago (start > end).
update public.alert_prefs ap set push_enabled = true, time_zone = tz.z,
  quiet_start = (now() at time zone tz.z)::time - interval '1 minute',
  quiet_end = (now() at time zone tz.z)::time - interval '2 minutes'
from tz where ap.user_id = tz.uid;
select tests.make_deal((select brand_a from w), 'published') is not null as made \gset
select private.plan_alerts() as tz_run \gset
select is(
  (select count(*) from tz join private.push_outbox o on o.user_id = tz.uid
   where o.send_at = ((now() at time zone tz.z)::date + 1
                      + ((now() at time zone tz.z)::time - interval '2 minutes')) at time zone tz.z
     and o.local_day = (now() at time zone tz.z)::date + 1),
  4::bigint, 'pushes in overnight quiet hours wait for the next morning in each user''s own time zone');

-- The planner never alerts about a draft or a removed deal.
create temp table removed as select tests.make_deal((select brand_b from w), 'published') as id;
update public.deals set status = 'removed' where id = (select id from removed);
select private.plan_alerts() as removed_run \gset
select is((select count(*) from public.notifications where deal_id = (select id from removed)), 0::bigint,
  'a deal removed before planning alerts nobody');

select * from finish();
rollback;
