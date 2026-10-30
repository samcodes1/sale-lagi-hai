-- QA (sub-phase 4.9 gate): alert preferences. Grants and RLS on
-- alert_prefs and its two RPCs per role (anon, shopper, another shopper,
-- moderator, admin, service role), what a direct table write can and cannot
-- touch, quiet-hours checks on split updates, hostile time zones, and the
-- RPC's behaviour when the caller has no row.
begin;
select plan(24);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated, service_role;

-- ------------------------------------------------------------------ anon ---
select tests.authenticate_as_anon();
select throws_ok($$ select * from public.update_alert_prefs(push_enabled => true) $$,
  '42501', null, 'anon cannot call update_alert_prefs');
select throws_ok($$ select * from public.alert_prefs $$,
  '42501', null, 'anon cannot read alert_prefs');
select throws_ok($$ update public.alert_prefs set push_enabled = true $$,
  '42501', null, 'anon cannot write alert_prefs');
select tests.clear_authentication();

-- --------------------------------------------------------------- shopper ---
select tests.authenticate_as((select shopper from w));
select is((select count(*)::int from public.my_alert_prefs()), 1, 'a shopper has exactly one row');
select is((select count(*)::int from public.update_alert_prefs()), 1,
  'a call with no fields returns the row unchanged');
select is((select (push_enabled, frequency::text) from public.my_alert_prefs()),
  (false, 'normal'::text), 'and changes nothing');
-- A split update: only the end, equal to the stored start.
select throws_ok($$ select * from public.update_alert_prefs(quiet_end => '22:00') $$,
  '23514', null, 'an end equal to the stored start is refused');
select throws_ok($$ select * from public.update_alert_prefs(quiet_start => '08:00:00') $$,
  '23514', null, 'a start equal to the stored end is refused (seconds form)');
select lives_ok($$ select * from public.update_alert_prefs(quiet_start => '08:00', quiet_end => '22:00') $$,
  'swapping start and end in one call works');
select is((select (quiet_start, quiet_end) from public.my_alert_prefs()),
  ('08:00'::time, '22:00'::time), 'the swap is stored');
select throws_ok($$ select * from public.update_alert_prefs(time_zone => 'Asia/Karachi'';drop table x;--') $$,
  '23514', null, 'a hostile time zone is refused');
select throws_ok($$ select * from public.update_alert_prefs(frequency => 'hourly') $$,
  '22P02', null, 'an unknown frequency is refused');
-- Direct table writes: only the listed columns, only one's own row.
select throws_ok($$ update public.alert_prefs set user_id = gen_random_uuid() $$,
  '42501', null, 'user_id cannot be changed');
select throws_ok($$ update public.alert_prefs set updated_at = now() - interval '1 year' $$,
  '42501', null, 'updated_at cannot be written');
select throws_ok($$ insert into public.alert_prefs (user_id) values ((select shopper from w)) $$,
  '42501', null, 'no inserts');
select throws_ok($$ delete from public.alert_prefs $$, '42501', null, 'no deletes');
select is(tests.affected($$ update public.alert_prefs set push_enabled = true
  where user_id = (select owner from w) returning 1 $$), 0,
  'another shopper''s row cannot be changed directly');
select tests.clear_authentication();

-- --------------------------------------------------------- the other one ---
select tests.authenticate_as((select owner from w));
select is((select (quiet_start, push_enabled) from public.my_alert_prefs()),
  ('22:00'::time, false), 'the other shopper is untouched by all of the above');
select tests.clear_authentication();

-- ------------------------------------------------------------ staff ---
select tests.staff((select moderator from w));
select is((select count(*)::int from public.alert_prefs), 1, 'a moderator sees only their own row');
select is((select count(*)::int from public.update_alert_prefs(push_enabled => true)), 1,
  'and changes only their own');
select tests.clear_authentication();
select tests.staff((select admin from w));
select is((select count(*)::int from public.alert_prefs), 1, 'an admin sees only their own row');
select tests.clear_authentication();

-- ---------------------------------------------------- service role ---
set local role service_role;
select is((select count(*)::int from public.alert_prefs where push_enabled), 1,
  'the service role reads every row (only the moderator turned push on)');
-- A user without a row (deleted by an operator).
delete from public.alert_prefs where user_id = (select shopper from w);
reset role;

select tests.authenticate_as((select shopper from w));
select is((select count(*)::int from public.my_alert_prefs()), 0, 'no row: my_alert_prefs is empty');
select is((select count(*)::int from public.update_alert_prefs(push_enabled => true)), 0,
  'no row: update_alert_prefs changes nothing and returns no row (the client must not treat this as saved)');
select tests.clear_authentication();

select * from finish();
rollback;
