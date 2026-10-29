-- Deal page (4.4): what anon reads besides the card.
begin;
select plan(4);

create temp table w as select * from tests.make_world();
grant select on w to anon;
update public.brands set is_active = true;
insert into public.outlets (brand_id, city_id, name, address, location)
  select brand_a, city, 'Do Darya', 'Do Darya, DHA Phase 8', 'SRID=4326;POINT(67.04 24.78)' from w;
update public.deals set description_en = 'Two big plates', terms_en = 'Dine-in only'
  where id = (select live_a from w);

select tests.authenticate_as_anon();
select is((select (round(latitude::numeric, 2), round(longitude::numeric, 2)) from public.outlets
           where name = 'Do Darya'),
  (24.78::numeric, 67.04::numeric), 'outlets expose their location as numbers');
select is((select (description_en, terms_en) from public.deals where id = (select live_a from w)),
  ('Two big plates'::text, 'Dine-in only'::text), 'a live deal''s text is readable');
select is((select count(*)::int from public.deals where id = (select draft_a from w)), 0,
  'a draft''s text is not');
select ok((select count(*) from public.deal_targets t join w on t.deal_id = w.draft_a) = 0,
  'targets of hidden deals are hidden');
select tests.clear_authentication();

select * from finish();
rollback;
