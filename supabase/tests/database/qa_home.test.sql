-- QA, sub-phase 4.3: ending_soon_deals edge cases the developer's
-- 810_home.test.sql leaves out (docs/qa/4.3.md): drafts and deals in
-- review (also for their own business), not yet started, inactive brands,
-- non-live cities, parameter clamping, ties, the card extras, and a page
-- full of hidden deals ending first.
begin;
select plan(14);

create temp table w as select * from tests.make_world();
update public.brands set is_active = true;
grant select on w to anon, authenticated;

-- Everything else that is live ends in more than a week, so only this
-- file's deals are in the window.
update public.deals set ends_at = now() + interval '30 days' where status = 'published';

create temp table q (name text primary key, id uuid);
grant select on q to anon, authenticated;
insert into q select 'shown', tests.make_deal((select brand_a from w), 'published');
insert into q select 'draft', tests.make_deal((select brand_a from w), 'draft');
insert into q select 'review', tests.make_deal((select brand_a from w), 'pending_review');
insert into q select 'future', tests.make_deal((select brand_a from w), 'published');
insert into q select 'inactive_brand', tests.make_deal((select brand_b from w), 'published');
update public.deals set ends_at = now() + interval '5 hours'
  where id in (select id from q);
update public.deals set starts_at = now() + interval '1 hour'
  where id = (select id from q where name = 'future');
update public.brands set is_active = false where id = (select brand_b from w);

select tests.authenticate_as_anon();
select is(
  (select array_agg(e.id) from public.ending_soon_deals(null) e where e.id in (select id from q)),
  (select array[id] from q where name = 'shown'),
  'anon: drafts, deals in review, not yet started and inactive brands are left out');
select tests.clear_authentication();

select tests.authenticate_as((select owner from w));
select is(
  (select count(*)::int from public.ending_soon_deals(null) e
    where e.id in (select id from q where name in ('draft', 'review'))),
  0, 'the owner does not see their own drafts or deals in review in the row');
select tests.clear_authentication();

select tests.staff((select admin from w));
select is(
  (select count(*)::int from public.ending_soon_deals(null) e
    where e.id in (select id from q where name in ('draft', 'review', 'future'))),
  0, 'nor does an admin');
select tests.clear_authentication();

-- Parameters are clamped.
select tests.authenticate_as_anon();
select is((select count(*)::int from public.ending_soon_deals(null, null) e
           where e.id = (select id from q where name = 'shown')), 1, 'within_hours null: 72 hours');
select is((select count(*)::int from public.ending_soon_deals(null, 0) e
           where e.id = (select id from q where name = 'shown')), 0, 'within_hours 0: one hour (5 h out is not shown)');
select is((select count(*)::int from public.ending_soon_deals(null, -50) e
           where e.id = (select id from q where name = 'shown')), 0, 'negative hours: one hour');
select lives_ok($$select * from public.ending_soon_deals(null, 2147483647, 2147483647)$$,
  'huge numbers do not overflow');
select tests.clear_authentication();

-- 60 more deals ending in an hour, same moment: ties by id, page clamped.
insert into q select 'tie' || i, tests.make_deal((select brand_a from w), 'published')
  from generate_series(1, 60) i;
update public.deals set ends_at = date_trunc('minute', now()) + interval '2 hours'
  where id in (select id from q where name like 'tie%');
select tests.authenticate_as_anon();
select is((select count(*)::int from public.ending_soon_deals(null, 72, 1000)), 50, 'page size capped at 50');
select is((select count(*)::int from public.ending_soon_deals(null, 72, null)), 20, 'page size null: 20');
select is(
  (select array_agg(id) from public.ending_soon_deals(null, 72, 50)),
  (select array_agg(id order by id) from (
     select id from q where name like 'tie%' order by id limit 50) t),
  'equal end times come in id order, so pages are stable');
select ok(
  (select bool_and(not is_featured and distance_m is null) from public.ending_soon_deals(null, 72, 50)),
  'no Featured label and no distance on ending-soon cards');
select tests.clear_authentication();

-- 50 hidden deals (inactive category) end before one shown deal: the row
-- must still find the shown one.
create temp table h as select tests.make_category('qa-closed') as cat;
grant select on h to anon, authenticated;
update public.deals set category_id = (select cat from h)
  where id in (select id from q where name like 'tie%');
update public.categories set is_active = false where id = (select cat from h);
select tests.authenticate_as_anon();
select is(
  (select array_agg(e.id) from public.ending_soon_deals(null, 72, 20) e),
  (select array[id] from q where name = 'shown'),
  'hidden deals ending first do not crowd the page out');
select tests.clear_authentication();

-- A local deal targeting a city that is not live yet.
create temp table l as select tests.make_city('qa-not-live', false) as city,
  tests.make_deal((select brand_a from w), 'draft', 'local') as deal;
grant select on l to anon;
insert into public.deal_targets (deal_id, city_id) select deal, city from l;
update public.deals set status = 'published', ends_at = now() + interval '3 hours'
  where id = (select deal from l);
select tests.authenticate_as_anon();
select is((select count(*)::int from public.ending_soon_deals((select city from l)) e
           where e.id = (select deal from l)), 0, 'a local deal in a city that is not live is not shown');
select is((select count(*)::int from public.ending_soon_deals(gen_random_uuid()) e
           where e.id = (select deal from l)), 0, 'nor for an unknown city');
select tests.clear_authentication();

select * from finish();
rollback;
