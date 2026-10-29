begin;
select plan(12);

-- Slugs follow the app's route rule.
select lives_ok($$ select tests.make_city('karachi') $$, 'a valid slug is accepted');
select throws_ok($$ select tests.make_city('Karachi') $$, '23514', null, 'upper-case slugs are rejected');
select throws_ok($$ select tests.make_city('new--york') $$, '23514', null, 'double hyphens are rejected');
select throws_ok($$ select tests.make_city('-lahore') $$, '23514', null, 'leading hyphens are rejected');
select throws_ok($$ select tests.make_city(repeat('a', 65)) $$, '23514', null, 'slugs over 64 characters are rejected');
select throws_ok($$ select tests.make_city('karachi') $$, '23505', null, 'city slugs are unique');

select throws_ok($$
  insert into public.cities (slug, name_en, name_ur, province, center)
  values ('lahore', '  ', 'لاہور', 'punjab', 'SRID=4326;POINT(74.35 31.52)')
$$, '23514', null, 'blank names are rejected');

-- Areas: slugs unique per city, not across cities.
select lives_ok($$
  select tests.make_area((select id from public.cities where slug = 'karachi'), 'clifton');
  select tests.make_area(tests.make_city('hyderabad'), 'clifton');
$$, 'two cities may each have an area with the same slug');
select throws_ok($$
  select tests.make_area((select id from public.cities where slug = 'karachi'), 'clifton')
$$, '23505', null, 'area slugs are unique within a city');

-- Categories are at most two levels deep.
select throws_ok($$
  select tests.make_category('c3', tests.make_category('c2', tests.make_category('c1')))
$$, '23514', null, 'a subcategory cannot have subcategories');
select tests.make_category('bbq', tests.make_category('food'));
select tests.make_category('top');
select throws_ok($$
  update public.categories set parent_id = (select id from public.categories where slug = 'top')
  where slug = 'food'
$$, '23514', null, 'a category with subcategories cannot become one');

-- Bank links are https only.
select throws_ok($$
  insert into public.banks (slug, name_en, name_ur, short_name, website)
  values ('ubl', 'UBL', 'یو بی ایل', 'UBL', 'http://ubl.com.pk')
$$, '23514', null, 'http links are rejected');

select * from finish();
rollback;
