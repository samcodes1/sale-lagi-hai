-- Alerts inbox (4.8): marking read and counting unread, own rows only.
begin;
select plan(9);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;
insert into public.notifications (user_id, kind, title, created_at)
  select (select shopper from w), 'deal_alert'::public.notification_kind, 'Alert ' || g, now() - (g || ' minutes')::interval
  from generate_series(1, 5) g
  union all
  select (select owner from w), 'system', 'Not yours', now();
create temp table mine as
  select id, title from public.notifications where user_id = (select shopper from w);
grant select on mine to authenticated;

select tests.authenticate_as((select shopper from w));
select is(public.unread_alert_count(), 5, 'five unread');
select is(public.unread_alert_count(now() - interval '150 seconds'), 2, 'two since the tab was opened');
select is(public.mark_alerts_read(array[(select id from mine where title = 'Alert 1')]), 1, 'one marked read');
select is(public.mark_alerts_read(array[(select id from mine where title = 'Alert 1')]), 0,
  'marking it again changes nothing');
select is(public.unread_alert_count(), 4, 'four left');
select is(public.mark_alerts_read(), 4, 'mark all read');
select is(public.unread_alert_count(), 0, 'none left');
select tests.clear_authentication();

select tests.authenticate_as((select owner from w));
select is(public.unread_alert_count(), 1, 'another user''s alerts were untouched');
select tests.clear_authentication();

select tests.authenticate_as_anon();
select throws_ok($$ select public.unread_alert_count() $$, '42501', null, 'guests have no inbox');
select tests.clear_authentication();

select * from finish();
rollback;
