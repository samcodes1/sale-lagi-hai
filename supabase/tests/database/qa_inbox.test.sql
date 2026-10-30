-- QA, sub-phase 4.8 (docs/qa/4.8.md): the inbox RPCs and the
-- notifications table under each role: nobody reads or marks another
-- user's alerts, only read_at can change, and the caps hold.
begin;
select plan(20);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;
insert into public.notifications (user_id, kind, title, created_at)
  select (select shopper from w), 'deal_alert', 'Mine ' || g, now() - (g || ' seconds')::interval
  from generate_series(1, 250) g;
insert into public.notifications (user_id, kind, title, created_at)
  select (select owner from w), 'deal_alert', 'Theirs ' || g, now() - (g || ' seconds')::interval
  from generate_series(1, 3) g;
create temp table theirs as
  select id from public.notifications where user_id = (select owner from w);
create temp table mine as
  select id from public.notifications where user_id = (select shopper from w);
grant select on theirs, mine to authenticated;

select tests.authenticate_as((select shopper from w));
select is((select count(*)::int from public.notifications), 250, 'a shopper reads only their own alerts');
select is(public.unread_alert_count(), 100, 'the count is capped at 100');
select is(public.unread_alert_count(now() + interval '1 hour'), 0, 'a "since" in the future counts none');
select is(public.mark_alerts_read((select array_agg(id) from theirs)), 0,
  'someone else''s ids mark nothing');
select is(public.mark_alerts_read('{}'), 0, 'an empty list marks nothing (not "all")');
select is(public.mark_alerts_read(array[null::uuid]), 0, 'a null id marks nothing');
select is(public.mark_alerts_read((select array_agg(id) from (select id from mine limit 201) m)), 200,
  'at most 200 ids at once');
select throws_ok($$update public.notifications set title = 'x' where id = (select id from mine limit 1)$$,
  '42501', null, 'no other column can change');
select is(tests.affected($$update public.notifications set read_at = now() where id in (select id from theirs) returning 1$$),
  0, 'someone else''s alerts can''t be marked directly either');
select throws_ok($$update public.notifications set read_at = created_at - interval '1 day'
                   where id = (select id from mine where id not in (select id from public.notifications where read_at is not null) limit 1)$$,
  '23514', null, 'read before it arrived is refused');
select throws_ok($$insert into public.notifications (user_id, kind, title) select shopper, 'system', 'Fake' from w$$,
  '42501', null, 'nobody writes alerts but the dispatcher');
select is(tests.affected($$delete from public.notifications where id in (select id from theirs) returning 1$$),
  0, 'someone else''s alerts can''t be deleted');
select is(tests.affected($$delete from public.notifications where id = (select id from mine limit 1) returning 1$$),
  1, 'a shopper may delete their own');
select ok(public.mark_alerts_read() between 49 and 50, 'mark all read: the rest of the caller''s (50 left, less the one deleted if it was unread)');
select is(public.unread_alert_count(), 0, 'none left');
select tests.clear_authentication();

select tests.authenticate_as((select owner from w));
select is(public.unread_alert_count(), 3, 'the other user''s alerts are untouched');
select tests.clear_authentication();

select tests.authenticate_as_anon();
select throws_ok($$select public.mark_alerts_read()$$, '42501', null, 'guests can''t mark');
select throws_ok($$select count(*) from public.notifications$$, '42501', null, 'guests can''t read alerts');
select tests.clear_authentication();

-- The service role (no auth.uid()) marks and counts nothing by accident.
set local role service_role;
select is(public.mark_alerts_read(), 0, 'without a user, nothing is marked');
reset role;
select is((select count(*)::int from public.notifications where read_at is null and user_id = (select owner from w)), 3,
  '... and the other user''s alerts are still unread');

select * from finish();
rollback;
