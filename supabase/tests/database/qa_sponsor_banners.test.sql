-- Sponsor banners under each role: the public sees only those running now,
-- moderators see all of them, and only admins change them.
begin;
select plan(7);

create temp table w as select * from tests.make_world();
grant select on w to anon, authenticated;

insert into public.sponsor_banners (sponsor_name, title_en, is_active, starts_at, ends_at) values
  ('Running', 'Running', true, now() - interval '1 day', now() + interval '1 day'),
  ('Open ended', 'Open ended', true, now() - interval '1 day', null),
  ('Paused', 'Paused', false, now() - interval '1 day', null),
  ('Future', 'Future', true, now() + interval '1 day', null),
  ('Over', 'Over', true, now() - interval '2 days', now() - interval '1 day');

select tests.authenticate_as_anon();
select is((select count(*)::int from public.sponsor_banners), 2,
  'anon sees only banners running now');

select tests.authenticate_as((select shopper from w));
select is((select count(*)::int from public.sponsor_banners), 2,
  'a shopper sees only banners running now');
select throws_ok(
  $$insert into public.sponsor_banners (sponsor_name, title_en) values ('Me', 'Mine')$$,
  '42501', null, 'a shopper cannot add one');

select tests.authenticate_as((select moderator from w));
select tests.staff((select moderator from w));
select is((select count(*)::int from public.sponsor_banners), 5,
  'a moderator sees all of them');
select throws_ok(
  $$insert into public.sponsor_banners (sponsor_name, title_en) values ('Mod', 'Mine')$$,
  '42501', null, 'a moderator cannot add one');

select tests.authenticate_as((select admin from w));
select tests.staff((select admin from w));
select lives_ok(
  $$insert into public.sponsor_banners (sponsor_name, title_en) values ('Admin', 'New')$$,
  'an admin adds one');
select tests.clear_authentication();

select throws_ok(
  $$insert into public.sponsor_banners (sponsor_name, title_en, link_url)
    values ('Bad', 'Bad link', 'http://example.com')$$,
  '23514', null, 'links must be https');

select * from finish();
rollback;
