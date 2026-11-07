-- Pop-up banners under each role: the public sees only those running now,
-- moderators see all of them, only admins push them, and a button always
-- has exactly one place to go.
begin;
select plan(10);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;

insert into public.popup_banners (title_en, is_active, starts_at, ends_at) values
  ('Running', true, now() - interval '1 day', now() + interval '1 day'),
  ('Open ended', true, now() - interval '1 day', null),
  ('Paused', false, now() - interval '1 day', null),
  ('Future', true, now() + interval '1 day', null),
  ('Over', true, now() - interval '2 days', now() - interval '1 day');

select tests.authenticate_as_anon();
select is((select count(*)::int from public.popup_banners), 2,
  'anon sees only pop-ups running now');

select tests.authenticate_as((select shopper from w));
select is((select count(*)::int from public.popup_banners), 2,
  'a shopper sees only pop-ups running now');
select throws_ok(
  $$insert into public.popup_banners (title_en) values ('Mine')$$,
  '42501', null, 'a shopper cannot push one');

select tests.authenticate_as((select moderator from w));
select tests.staff((select moderator from w));
select is((select count(*)::int from public.popup_banners), 5,
  'a moderator sees all of them');
select throws_ok(
  $$insert into public.popup_banners (title_en) values ('Mod')$$,
  '42501', null, 'a moderator cannot push one');

select tests.authenticate_as((select admin from w));
select tests.staff((select admin from w));
select lives_ok(
  $$insert into public.popup_banners (title_en, action_label_en, link_url, frequency)
    values ('Admin', 'Shop now', 'https://example.pk/sale', 'daily')$$,
  'an admin pushes one');
select tests.clear_authentication();

select throws_ok(
  $$insert into public.popup_banners (title_en, action_label_en, link_url)
    values ('Bad', 'Go', 'http://example.com')$$,
  '23514', null, 'links must be https');
select throws_ok(
  $$insert into public.popup_banners (title_en, action_label_en) values ('No target', 'Go')$$,
  '23514', null, 'a button needs somewhere to go');
select throws_ok(
  $$insert into public.popup_banners (title_en, link_url) values ('No button', 'https://example.pk')$$,
  '23514', null, 'a target needs a button');
select throws_ok(
  $$insert into public.popup_banners (title_en, action_label_en, link_url, brand_id)
    values ('Two', 'Go', 'https://example.pk', (select brand_a from w))$$,
  '23514', null, 'only one place to go');

select * from finish();
rollback;
