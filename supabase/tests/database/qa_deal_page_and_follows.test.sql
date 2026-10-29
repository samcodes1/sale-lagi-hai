-- QA, sub-phases 4.4 and 4.5 (docs/qa/4.4.md, docs/qa/4.5.md): the rows
-- the app writes for the deal page and follows, as the app writes them,
-- under each role's RLS: reports, saves, follows, the guest sync with
-- category follows, and what anon reads about outlets and ended deals.
-- Open bugs are marked TODO (they report as "not ok # TODO" and don't fail
-- the run); when fixed they pass and the TODO should be removed.
begin;
select plan(24);

create temp table w as select * from tests.make_world();
update public.brands set is_active = true;
create temp table x as select
  tests.create_user('second@example.com') as shopper2,
  tests.make_deal((select brand_a from w), 'published') as ended;
update public.deals set starts_at = now() - interval '3 days', ends_at = now() - interval '1 day',
  status = 'expired', description_en = 'Was a good one'
  where id = (select ended from x);
grant select on w, x to anon, authenticated;
create temp table many as select tests.make_deal((select brand_a from w), 'published') as id
  from generate_series(1, 11);
grant select on many to authenticated;

-- ---------------------------------------------------------------- reports
select tests.authenticate_as_anon();
select throws_ok($$insert into public.reports (deal_id, reason) select live_a, 'spam' from w$$,
  '42501', null, 'a guest cannot report (the app signs them in first)');
select tests.clear_authentication();

select tests.authenticate_as((select shopper from w));
-- Exactly the row the app sends: deal, reason and (optional) note.
select lives_ok($$insert into public.reports (deal_id, reason) select live_a, 'wrong_price' from w$$,
  'a shopper reports a live deal with the app''s row (reporter from the session)');
select is((select reporter_id from public.reports where deal_id = (select live_a from w)),
  (select shopper from w), 'the reporter is the session user');
select throws_ok($$insert into public.reports (deal_id, reason) select live_a, 'spam' from w$$,
  '23505', null, 'a second report on the same deal is 23505 ("already reported")');
select lives_ok($$insert into public.reports (deal_id, reason, note) select ended, 'expired', 'Over' from x$$,
  'an ended deal can still be reported (its page still opens)');
select throws_ok($$insert into public.reports (deal_id, reason) select draft_a, 'spam' from w$$,
  '42501', null, 'not a deal the shopper cannot see');
select throws_ok($$insert into public.reports (deal_id, reason, reporter_id) select live_b, 'spam', owner from w$$,
  '42501', null, 'not in someone else''s name');
select throws_ok($$insert into public.reports (deal_id, reason, status, resolved_at) select live_b, 'spam', 'resolved', now() from w$$,
  '42501', null, 'not already resolved');
select throws_ok(format($$insert into public.reports (deal_id, reason, note) values (%L, 'other', %L)$$,
                        (select live_b from w), repeat('x', 501)),
  '23514', null, 'a note over 500 characters is refused');
select lives_ok(format($$insert into public.reports (deal_id, reason, note) values (%L, 'other', %L)$$,
                       (select live_b from w), repeat('😀', 500)),
  'a note of 500 emoji is 500 characters, which fits');
select tests.clear_authentication();

select tests.authenticate_as((select shopper2 from x));
select is((select count(*)::int from public.reports), 0, 'another shopper reads none of those reports');
select throws_ok($$insert into public.reports (deal_id, reason) select live_b, 'other' from w$$,
  '23514', null, '"something else" needs a note');
-- Ten an hour, then PT429.
select lives_ok($$insert into public.reports (deal_id, reason) select id, 'spam' from (select id from many limit 10) m$$,
  'ten reports in an hour are fine');
select throws_ok($$insert into public.reports (deal_id, reason) select id, 'spam' from (select id from many offset 10) m$$,
  'PT429', null, 'the eleventh is rate-limited');
select tests.clear_authentication();

-- ------------------------------------------------------------------ saves
select tests.authenticate_as((select shopper from w));
select lives_ok($$insert into public.saves (deal_id) select live_a from w$$,
  'a save as the app sends it ({deal_id} only) is accepted');
select lives_ok($$insert into public.saves (user_id, deal_id) select shopper, live_a from w on conflict do nothing$$,
  'with user_id it is');
select throws_ok($$insert into public.saves (user_id, deal_id) select shopper, draft_a from w$$,
  '42501', null, 'a draft cannot be saved (no probing by id)');

-- ---------------------------------------------------------------- follows
select lives_ok($$insert into public.follows (brand_id) select brand_b from w$$,
  'a follow as the app sends it ({brand_id} only) is accepted');
select tests.clear_authentication();

-- ------------------------------------------------- guest sync (4 args)
create temp table cats as select tests.make_category('qa-live') as live, tests.make_category('qa-off') as off;
update public.categories set is_active = false where id = (select off from cats);
grant select on cats to authenticated;
select tests.authenticate_as((select shopper2 from x));
select lives_ok($$select public.sync_guest_preferences(null, 'ur', array[(select brand_a from w)],
                    array[(select live from cats), (select off from cats), (select live from cats)])$$,
  'the sync takes brands and categories');
select is((select array_agg(category_id) from public.follows
           where user_id = (select shopper2 from x) and category_id is not null),
  (select array[live] from cats), 'only active categories are followed, once');
select throws_ok(format($$select public.sync_guest_preferences(%L, null, %L::uuid[], %L::uuid[])$$,
                        (select city from w),
                        (select array_agg(gen_random_uuid()) from generate_series(1, 150)),
                        (select array_agg(gen_random_uuid()) from generate_series(1, 51))),
  '22023', null, 'more than 200 follows in all are refused');
select is((select home_city_id from public.profiles where id = (select shopper2 from x)), null,
  '... and then nothing of that sync is kept, not even the city (docs/qa/4.5.md)');
select tests.clear_authentication();

-- ------------------------------------------------------ what anon reads
insert into public.outlets (brand_id, city_id, name, address, location, is_active)
  select brand_a, city, 'Closed branch', 'Old Road, Karachi', 'SRID=4326;POINT(67.0 24.8)', false from w;
select tests.authenticate_as_anon();
select is((select count(*)::int from public.outlets where name = 'Closed branch'), 0,
  'an inactive outlet is not listed');
select is((select description_en from public.deals where id = (select ended from x)), 'Was a good one',
  'an ended deal''s text still reads (its page still opens)');
select tests.clear_authentication();

select * from finish();
rollback;
