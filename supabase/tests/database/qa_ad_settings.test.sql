-- Ad settings: everyone reads the one row, only admins change it, and the
-- checks hold it within Google's policies.
begin;
select plan(9);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;

select is((select count(*)::int from public.ad_settings), 1,
  'the migration adds the one row');
select throws_ok(
  $$insert into public.ad_settings (id) values (false)$$,
  '23514', null, 'there is only ever one row');
select throws_ok(
  $$update public.ad_settings set feed_ad_every = 2$$,
  '23514', null, 'ads are never denser than one per four deals');
select throws_ok(
  $$update public.ad_settings set interstitial_gap_seconds = 10$$,
  '23514', null, 'full-screen ads are at least a minute apart');

select tests.authenticate_as_anon();
select is((select enabled from public.ad_settings), true,
  'anon reads the settings');

select tests.authenticate_as((select shopper from w));
update public.ad_settings set enabled = false;
select tests.clear_authentication();
select is((select enabled from public.ad_settings), true,
  'a shopper cannot change them');

select tests.authenticate_as((select moderator from w));
select tests.staff((select moderator from w));
update public.ad_settings set enabled = false;
select tests.clear_authentication();
select is((select enabled from public.ad_settings), true,
  'a moderator cannot change them');

select tests.authenticate_as((select admin from w));
select tests.staff((select admin from w));
select lives_ok(
  $$update public.ad_settings set feed_ad_every = 8$$,
  'an admin changes them');
select throws_ok(
  $$delete from public.ad_settings$$,
  '42501', null, 'not even an admin deletes the row');
select tests.clear_authentication();

select * from finish();
rollback;
