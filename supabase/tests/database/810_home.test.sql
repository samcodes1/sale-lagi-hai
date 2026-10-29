-- Home: ending_soon_deals.
begin;
select plan(7);

create temp table w as select * from tests.make_world();
grant select on w to anon;
update public.brands set is_active = true;

-- Three live deals ending in 2 hours, 2 days and 10 days, one open-ended.
create temp table e as select
  tests.make_deal((select brand_a from w), 'published') as soon,
  tests.make_deal((select brand_a from w), 'published') as later,
  tests.make_deal((select brand_a from w), 'published') as far,
  tests.make_deal((select brand_a from w), 'published') as open_ended;
grant select on e to anon;
update public.deals set ends_at = now() + interval '2 hours' where id = (select soon from e);
update public.deals set ends_at = now() + interval '2 days' where id = (select later from e);
update public.deals set ends_at = now() + interval '10 days' where id = (select far from e);
update public.deals set ends_at = null where id = (select open_ended from e);

select tests.authenticate_as_anon();
select is((select array_agg(id) from public.ending_soon_deals((select city from w))
           where id in (select soon from e union select later from e union select far from e
                        union select open_ended from e)),
  (select array[soon, later] from e), 'soonest first, within 72 hours, never open-ended');
select is((select count(*)::int from public.ending_soon_deals((select city from w), 3)
           where id in (select soon from e union select later from e)), 1,
  'the window narrows to the hours asked');
select is((select count(*)::int from public.ending_soon_deals((select city from w), 100000)
           where id in (select later from e union select far from e)), 1,
  'the window is capped at a week (2 days in, 10 days out)');
select is((select count(*)::int from public.ending_soon_deals(null, 72, 1)), 1, 'the page size is honoured');
select tests.clear_authentication();

-- Ended deals, drafts and inactive categories are not shown.
update public.deals set starts_at = now() - interval '2 hours', ends_at = now() - interval '1 minute'
  where id = (select soon from e);
update public.categories set is_active = false
  where id = (select category_id from public.deals where id = (select later from e));
select tests.authenticate_as_anon();
select is((select count(*)::int from public.ending_soon_deals((select city from w))
           where id in (select soon from e union select later from e)), 0,
  'ended deals and deals in a switched-off category are gone');
select tests.clear_authentication();

-- Local deals only in their live city.
update public.categories set is_active = true;
create temp table l as select tests.make_deal((select brand_a from w), 'draft', 'local') as id;
grant select on l to anon;
insert into public.deal_targets (deal_id, city_id) select (select id from l), city from w;
update public.deals set status = 'published', ends_at = now() + interval '1 hour' where id = (select id from l);
select tests.authenticate_as_anon();
select is((select count(*)::int from public.ending_soon_deals((select city from w)) where id = (select id from l)), 1,
  'a local deal shows in its city');
select is((select count(*)::int from public.ending_soon_deals(null) where id = (select id from l)), 0,
  'and nowhere else');
select tests.clear_authentication();

select * from finish();
rollback;
