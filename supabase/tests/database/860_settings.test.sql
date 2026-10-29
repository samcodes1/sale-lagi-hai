-- Settings (4.9): reading and changing one's own alert preferences.
begin;
select plan(9);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;

select tests.authenticate_as((select shopper from w));
select is((select (push_enabled, frequency::text, quiet_start, quiet_end) from public.my_alert_prefs()),
  (false, 'normal'::text, '22:00'::time, '08:00'::time), 'the defaults: push off, normal, quiet 22:00 to 08:00');
select is((select (push_enabled, my_city) from public.update_alert_prefs(push_enabled => true, my_city => false)),
  (true, false), 'only the given fields change');
select is((select (frequency::text, followed_brands) from public.my_alert_prefs()),
  ('normal'::text, true), 'the others are kept');
select is((select quiet_start from public.update_alert_prefs(quiet_start => '23:30', quiet_end => '07:00')),
  '23:30'::time, 'quiet hours change');
select throws_ok($$ select * from public.update_alert_prefs(quiet_start => '07:00', quiet_end => '07:00') $$,
  '23514', null, 'quiet hours must start and end at different times');
select throws_ok($$ select * from public.update_alert_prefs(time_zone => 'Mars/Olympus') $$,
  '23514', null, 'an unknown time zone is refused');
select tests.clear_authentication();

select tests.authenticate_as((select owner from w));
select is((select push_enabled from public.my_alert_prefs()), false, 'another user''s preferences were untouched');
select is((select count(*)::int from public.alert_prefs), 1, 'and each user sees only their own');
select tests.clear_authentication();

select tests.authenticate_as_anon();
select throws_ok($$ select * from public.my_alert_prefs() $$, '42501', null, 'guests have none');
select tests.clear_authentication();

select * from finish();
rollback;
