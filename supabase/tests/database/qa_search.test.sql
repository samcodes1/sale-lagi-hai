-- QA (sub-phase 4.6 gate): search_deals paging under ties, the 250 cap,
-- deals expiring or arriving mid-walk and cursors from other queries;
-- every filter before the cap; the area rule's edges; hostile input to
-- both EXECUTE-built helpers; brand_suggestions' escaping, visibility and
-- clamps. "QA BUG" assertions fail until the bug in docs/qa/4.6.md is
-- fixed (S4 ones are marked todo).
begin;
select plan(36);

create temp table w as select * from tests.make_world();
update public.brands set is_active = true;
create temp table s as select
  tests.make_area((select city from w), 'qa-clifton') as clifton,
  tests.make_area((select city from w), 'qa-gulshan') as gulshan,
  tests.make_city('qa-lahore') as lahore,
  tests.make_bank() as hbl;
create temp table s2 as select tests.make_area((select lahore from s), 'qa-gulberg') as gulberg;
grant select on w, s, s2 to anon, authenticated;

-- Walks every page of a search with page size n; returns ids in page order.
create function pg_temp.walk(q text, n int, city uuid default null, min_pct int default null,
                             area uuid default null)
returns uuid[] language plpgsql as $$
declare cursor_id uuid; got uuid; ids uuid[] := '{}'; pages int := 0; k int;
begin
  loop
    k := 0;
    for got in select d.id from public.search_deals(q, city, area_id => area, min_percent => min_pct,
                                                    after_id => cursor_id, page_size => n) d loop
      ids := ids || got; cursor_id := got; k := k + 1;
    end loop;
    pages := pages + 1;
    exit when k = 0 or pages > 400;
  end loop;
  return ids;
end $$;
grant execute on function pg_temp.walk(text, int, uuid, int, uuid) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Ties: 300 deals with the same title (same rank) and the same published_at.
-- ---------------------------------------------------------------------------
insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, offer_kind,
                          percent, url, published_at)
  select (select brand_a from w), (select category_id from public.brands where id = (select brand_a from w)),
         'brand_sale', 'nationwide', 'published', 'staff', 'Quokka tie sale', 'percent_off',
         case when g <= 4 then 70 else 10 end, 'https://example.com/q', '2026-10-01T00:00:00Z'
  from generate_series(1, 300) g;

select tests.authenticate_as_anon();
create temp table tie_walk as select pg_temp.walk('quokka', 7) as ids;
select tests.clear_authentication();
select is((select cardinality(ids) from tie_walk), 250,
  'a 300-way tie walks to exactly the 250-hit cap, then stops');
select is((select count(distinct x) from tie_walk, unnest(ids) x), 250::bigint,
  'no tied deal is shown twice across pages');
select tests.authenticate_as_anon();
select is((select array_agg(d.id) from public.search_deals('quokka', page_size => 50) d),
          (select ids[1:50] from tie_walk),
  'page 1 at size 50 is the same 50 as the walk at size 7 (stable order)');
select is((select count(*)::int from public.search_deals('quokka', min_percent => 70, page_size => 50)), 4,
  'the 4 tied 70% deals all surface past the cap');
select is(cardinality(pg_temp.walk(null, 9, null, 70)), 4,
  'filters alone with a tie on published_at: all 4, once each');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- Mid-walk changes.
-- ---------------------------------------------------------------------------
create temp table mid as select
  tests.make_deal((select brand_a from w), 'published') as a,
  tests.make_deal((select brand_a from w), 'published') as b,
  tests.make_deal((select brand_a from w), 'published') as c,
  tests.make_deal((select brand_a from w), 'published') as d;
grant select on mid to anon;
update public.deals set title_en = 'Wombat deal', percent = 55, ends_at = now() + interval '2 hours',
  starts_at = now() - interval '1 hour',
  published_at = now() - (case id when (select a from mid) then 1 when (select b from mid) then 2
                                  when (select c from mid) then 3 else 4 end) * interval '1 minute'
  where id in (select unnest(array[a, b, c, d]) from mid);

-- With words: the first page (2 rows), then the page's last deal ends.
select tests.authenticate_as_anon();
create temp table p1 as select d.id from public.search_deals('wombat', page_size => 2) d;
select tests.clear_authentication();
grant select on p1 to anon;
create temp table last_of_p1 as select id from p1 offset 1 limit 1;
grant select on last_of_p1 to anon;
update public.deals set ends_at = now() - interval '1 second' where id = (select id from last_of_p1);
select tests.authenticate_as_anon();
-- QA BUG 4.6-S1 (S4): the rest of the list is lost when the cursor deal
-- expires (or is hidden) between pages; it is documented, but "ending
-- soon" lists are exactly where it happens.
select is((select count(*)::int from public.search_deals('wombat',
             after_id => (select id from last_of_p1), page_size => 2)), 2,
  'QA BUG 4.6-S1: with words, the next page still comes after a cursor deal that just ended');
select is((select count(*)::int from public.search_deals(null, min_percent => 55,
             after_id => (select id from last_of_p1), page_size => 2)), 2,
  'without words, the next page still comes (the cursor is read from deals, which keeps expired rows)');
select tests.clear_authentication();
update public.deals set ends_at = now() + interval '2 hours' where id = (select id from last_of_p1);

-- A new best match published mid-walk is not shown twice and moves nothing.
select tests.authenticate_as_anon();
create temp table before_new as select pg_temp.walk('wombat', 2) as ids;
select tests.clear_authentication();
create temp table fresh as select tests.make_deal((select brand_a from w), 'published') as id;
grant select on fresh to anon;
update public.deals set title_en = 'Wombat', percent = 90 where id = (select id from fresh);
select tests.authenticate_as_anon();
select is((select array_agg(x.id) from public.search_deals('wombat',
             after_id => (select ids[2] from before_new), page_size => 10) x),
          (select ids[3:] from before_new),
  'a deal published mid-walk: the remaining pages are exactly the old remainder');
select ok((select (select id from fresh) <> all(ids) from before_new), 'and it is not slipped into later pages');

-- A cursor from another query.
select is((select count(*)::int from public.search_deals('quokka',
             after_id => (select a from mid), page_size => 50)), 0,
  'with words, an after_id from another search ends the list (no leak, no repeat)');
select ok((select count(*)::int from public.search_deals(null, min_percent => 55,
             after_id => (select id from public.search_deals('quokka', page_size => 1)), page_size => 50)) >= 0,
  'without words, an after_id from another query is just a published_at cursor (no error)');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- Every filter applies before the cap (the developer covered min_percent).
-- 300 nationwide "Okapi" matches; one of each kind of narrow match.
-- ---------------------------------------------------------------------------
insert into public.deals (brand_id, category_id, kind, scope, status, source, title_en, offer_kind,
                          percent, url)
  select (select brand_a from w), (select category_id from public.brands where id = (select brand_a from w)),
         'brand_sale', 'nationwide', 'published', 'staff', 'Okapi sale ' || g, 'percent_off', 10,
         'https://example.com/o'
  from generate_series(1, 300) g;
create temp table narrow as select
  tests.make_deal((select brand_b from w), 'published', 'local') as in_area,
  tests.make_deal((select brand_b from w), 'published', 'online', 'card_offer') as by_bank,
  tests.make_deal((select brand_b from w), 'published') as ending,
  tests.make_deal((select brand_b from w), 'published') as other_cat;
grant select on narrow to anon;
update public.deals set title_en = 'Okapy narrow', percent = 10 where id in
  (select unnest(array[in_area, by_bank, ending, other_cat]) from narrow);
update public.deals set ends_at = now() + interval '5 hours' where id = (select ending from narrow);
insert into public.deal_targets (deal_id, city_id, area_id)
  select in_area, (select city from w), (select clifton from s) from narrow;
insert into public.card_offers (deal_id, bank_id) select by_bank, (select hbl from s) from narrow;
create temp table cat2 as select tests.make_category('qa-okapi-cat') as id;
grant select on cat2 to anon;
update public.deals set category_id = (select id from cat2) where id = (select other_cat from narrow);
set constraints all immediate;
-- The 300 match exactly (rank 1); the narrow ones only fuzzily ("Okapy",
-- rank about 0.5), so without filters they fall past the cap.

select tests.authenticate_as_anon();
select ok((select by_bank from narrow) <> all(pg_temp.walk('okapi', 50)),
  'control: without filters the narrow deals are past the cap');
select ok((select (select by_bank from narrow) in (select id from public.search_deals('okapi',
             bank_ids => array[(select hbl from s)], page_size => 50))),
  'bank: the one card offer is found past the cap');
select ok((select (select ending from narrow) in (select id from public.search_deals('okapi',
             ending_within_hours => 24, page_size => 50))),
  'ending soon: the one deal ending today is found past the cap');
select ok((select (select other_cat from narrow) in (select id from public.search_deals('okapi',
             category_ids => array[(select id from cat2)], page_size => 50))),
  'category: the one deal in the category is found past the cap');
-- QA BUG 4.6-S2 (S4): an area keeps every online and nationwide deal, all
-- ranked above or alongside the area's own, so the one Clifton deal is
-- cut by the cap and the area filter cannot surface it.
select ok((select (select in_area from narrow) in (select id from public.search_deals('okapi', (select city from w),
             area_id => (select clifton from s), page_size => 50))),
  'QA BUG 4.6-S2: with an area, the area''s own local deal is on the first page');
select is(cardinality(pg_temp.walk('okapi', 50, (select city from w), null, (select clifton from s))), 250,
  'area keeps online and nationwide deals: the area filter alone does not narrow this search');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- The area rule's edges.
-- ---------------------------------------------------------------------------
set constraints all deferred;
create temp table local2 as select
  tests.make_deal((select brand_b from w), 'published', 'local') as lahore_only,
  tests.make_deal((select brand_b from w), 'published', 'local') as both_cities;
grant select on local2 to anon;
update public.deals set title_en = 'Pangolin' where id in (select unnest(array[lahore_only, both_cities]) from local2);
insert into public.deal_targets (deal_id, city_id, area_id)
  select lahore_only, (select lahore from s), (select gulberg from s2) from local2
  union all select both_cities, (select city from w), null from local2
  union all select both_cities, (select lahore from s), (select gulberg from s2) from local2;
set constraints all immediate;
select is((select array_agg(id) from public.search_deals('pangolin', (select city from w),
             area_id => (select gulberg from s2))),
          (select array[both_cities] from local2),
  'an area of another city with the shopper''s city: only a deal targeting both cities, through the other city''s area');
select is((select count(*)::int from public.search_deals('pangolin', (select city from w),
             area_id => gen_random_uuid())), 0,
  'an unknown area: no local deals (online and nationwide only)');
select is((select array_agg(id order by id) from public.search_deals('pangolin', null,
             area_id => (select gulberg from s2))), null,
  'an area without a city: local deals stay hidden, as everywhere without a city');
select is((select count(*)::int from public.search_deals('okapi', min_percent => 0, page_size => 50)), 50,
  'min_percent 0 is clamped to 1 (percentage offers only)');
select tests.clear_authentication();

-- QA BUG 4.6-S3 (S3): "50%+ off" (min_percent) also returns "Up to 50%
-- off" sales, whose discount is at most 50%: matches_search_filters
-- compares `percent` whatever the offer kind (search.sql:28).
create temp table upto as select tests.make_deal((select brand_a from w), 'published') as id;
grant select on upto to anon;
update public.deals set title_en = 'Narwhal sale', offer_kind = 'up_to_percent_off', percent = 50
  where id = (select id from upto);
select tests.authenticate_as_anon();
select is((select count(*)::int from public.search_deals('narwhal', min_percent => 50)), 0,
  'QA BUG 4.6-S3: an "up to 50% off" sale is not "at least 50% off"');
select tests.clear_authentication();

-- ---------------------------------------------------------------------------
-- Hostile words into the two EXECUTE-built helpers.
-- ---------------------------------------------------------------------------
create temp table hostile (q text);
insert into hostile values
  ($h$'); drop table public.deals; --$h$), ($h$$q$ union select id, 1 from public.deals --$h$),
  ('%1$L'), ('%%'), ('\'), ($h$\'$h$), ($h$' or 1=1 --$h$), ('E''\x'), (repeat('x', 100)),
  ('ق'), ('‮evil'), ('a' || chr(9) || 'b'), ('*:'), ('!!');
grant select on hostile to anon;
select tests.authenticate_as_anon();
select lives_ok($$ select count(*) from hostile h, lateral public.search_deals(h.q, page_size => 50) $$,
  'search_deals takes hostile words without error');
select lives_ok($$ select count(*) from hostile h, lateral public.brand_suggestions(h.q, 10) $$,
  'brand_suggestions takes hostile words without error');
select is((select count(*)::int from hostile h, lateral public.search_deals(h.q, page_size => 50) d
           where d.status <> 'published'), 0, 'and never returns a draft');
select tests.clear_authentication();
select ok(to_regclass('public.deals') is not null, 'the deals table is still there');

-- ---------------------------------------------------------------------------
-- brand_suggestions: escaping, visibility, clamps.
-- ---------------------------------------------------------------------------
insert into public.brands (slug, name, name_ur, category_id, is_active, business_id) values
  ('qa-back', 'Back\Slash Foods', null, (select category_id from public.brands where id = (select brand_a from w)), true, null),
  ('qa-quote', 'O''Neil Shoes', null, (select category_id from public.brands where id = (select brand_a from w)), true, null),
  ('qa-hidden-own', 'Xylo Hidden', 'زائلو', (select category_id from public.brands where id = (select brand_a from w)), false,
   (select biz_a from w));
insert into public.brands (slug, name, category_id, is_active)
  select 'qa-many-' || g, 'Yak ' || g, (select category_id from public.brands where id = (select brand_a from w)), true
  from generate_series(1, 30) g;

select tests.authenticate_as_anon();
select is((select array_agg(name) from public.brand_suggestions('back\s')), array['Back\Slash Foods'],
  'a backslash in the words matches a backslash in the name');
select is((select count(*)::int from public.brand_suggestions('\')), 0,
  'a lone backslash matches nothing by LIKE (and does not error)');
select is((select array_agg(name) from public.brand_suggestions('o''ne')), array['O''Neil Shoes'],
  'a quote in the words is matched as itself');
select is((select count(*)::int from public.brand_suggestions('yak', 100)), 10, 'page_size is capped at 10');
select is((select count(*)::int from public.brand_suggestions('yak', 0)), 1, 'page_size 0 is raised to 1');
select is((select count(*)::int from public.brand_suggestions('yak', null)), 6, 'a null page_size means 6');
select is((select count(*)::int from public.brand_suggestions('   ')), 0, 'blank words: nothing');
select is((select count(*)::int from public.brand_suggestions(null)), 0, 'null words: nothing');
select tests.clear_authentication();

-- The owner's own inactive brand is visible to them under RLS, but is not
-- suggested (it is not live for shoppers).
select tests.authenticate_as((select owner from w));
select is((select count(*)::int from public.brands where slug = 'qa-hidden-own'), 1,
  'the owner can read their hidden brand directly');
select is((select count(*)::int from public.brand_suggestions('xylo')) + (select count(*)::int from public.brand_suggestions('زائ')),
  0, 'but it is never suggested, by English or Urdu name');
select tests.clear_authentication();

select * from finish();
rollback;
