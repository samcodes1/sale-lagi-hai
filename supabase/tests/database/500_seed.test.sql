-- Reference data: complete, consistent, and safe to re-run.
begin;
select plan(14);

select is((select count(*)::int from public.cities), 16, '16 cities');
select is((select array_agg(slug::text) from public.cities where is_live), array['karachi'],
  'only Karachi is live at launch');
select is_empty($$ select slug from public.cities
  where not (extensions.st_y(center::extensions.geometry) between 23.5 and 37.2
             and extensions.st_x(center::extensions.geometry) between 60.8 and 77.9) $$,
  'every city centre is inside Pakistan');
select is_empty($$ select a.slug from public.areas a join public.cities c on c.id = a.city_id
  where extensions.st_distance(a.center, c.center) > 40000 $$,
  'every area is within 40 km of its city centre');
select ok((select count(*) from public.areas a join public.cities c on c.id = a.city_id where c.slug = 'karachi') >= 10,
  'Karachi has its areas');
select is((select count(*)::int from public.categories where parent_id is null), 13, '13 top-level categories');
select is_empty($$ select slug from public.categories where icon = 'local_offer' $$,
  'every seeded category has its own icon');
select is_empty($$ select b.slug from public.banks b
  where (select count(*) from public.card_products p where p.bank_id = b.id) < 2 $$,
  'every bank has card products');
select is_empty($$ select b.slug from public.banks b join public.card_products p on p.bank_id = b.id
  where b.slug in ('meezan-bank', 'dubai-islamic-bank', 'faysal-bank') and p.kind = 'credit' $$,
  'no conventional credit cards for Islamic banks');
select is_empty($$ select br.slug from public.brands br join public.banks b on b.id = br.bank_id
  where br.slug <> b.slug $$, 'bank brands link to the bank with the same slug');

-- Re-running changes nothing.
create temp table before as
  select (select count(*) from public.cities) c, (select count(*) from public.areas) a,
         (select count(*) from public.categories) k, (select count(*) from public.banks) b,
         (select count(*) from public.card_products) p, (select count(*) from public.brands) br;
update public.cities set is_live = true where slug = 'lahore';
\ir ../../migrations/20261029170000_reference_seed.sql
\ir ../../migrations/20261029170000_reference_seed.sql
select results_eq($$ select (select count(*) from public.cities), (select count(*) from public.areas),
  (select count(*) from public.categories), (select count(*) from public.banks),
  (select count(*) from public.card_products), (select count(*) from public.brands) $$,
  $$ select * from before $$, 'running the reference data twice more adds nothing');
select ok((select is_live from public.cities where slug = 'lahore'),
  're-running keeps cities staff have switched on');

-- The development seed loads cleanly, twice.
\ir ../../seed.sql
create temp table seeded as select count(*) as n from public.deals where title_en like '%' or true;
\ir ../../seed.sql
select is((select count(*) from public.deals), (select n from seeded),
  'the development seed runs twice without adding duplicates');
set constraints all immediate;
select is((select count(*)::int from public.feed((select id from public.cities where slug = 'karachi'))), 7,
  'all seven demo deals are live in the Karachi feed');

select * from finish();
rollback;
