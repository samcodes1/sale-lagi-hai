-- Test helpers, installed once before the other test files (pg_prove runs
-- files in name order). Unlike the other files this one commits, so the
-- helpers stay for the run. They live in `tests`, which is not exposed.
--
-- Fixture factories build valid rows with sensible defaults; tests pass
-- only what they care about.

create schema if not exists tests;

-- A new auth user (profile and alert prefs are created by trigger).
create or replace function tests.create_user(email text default null) returns uuid
language sql as $$
  insert into auth.users (id, email)
  values (gen_random_uuid(), coalesce(email, 'user-' || gen_random_uuid() || '@example.com'))
  returning id;
$$;

-- Act as a signed-in user (with optional extra JWT claims) or as anon.
create or replace function tests.authenticate_as(uid uuid, extra jsonb default '{}') returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', uid, 'role', 'authenticated', 'aal', 'aal1') || extra)::text, true);
  perform set_config('request.jwt.claim.sub', uid::text, true);
  execute 'set local role authenticated';
end $$;

create or replace function tests.authenticate_as_anon() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role anon';
end $$;

create or replace function tests.clear_authentication() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'reset role';
end $$;

create or replace function tests.make_city(slug text default null, is_live boolean default true)
returns uuid language sql as $$
  insert into public.cities (slug, name_en, name_ur, province, is_live, center)
  values (coalesce(slug, 'city-' || substr(md5(random()::text), 1, 8)), 'Karachi', 'کراچی',
          'sindh', is_live, 'SRID=4326;POINT(67.0011 24.8607)')
  returning id;
$$;

create or replace function tests.make_area(city uuid, slug text default null)
returns uuid language sql as $$
  insert into public.areas (city_id, slug, name_en, name_ur, center)
  values (city, coalesce(slug, 'area-' || substr(md5(random()::text), 1, 8)), 'Clifton', 'کلفٹن',
          'SRID=4326;POINT(67.0300 24.8138)')
  returning id;
$$;

create or replace function tests.make_category(slug text default null, parent uuid default null)
returns uuid language sql as $$
  insert into public.categories (slug, parent_id, name_en, name_ur)
  values (coalesce(slug, 'cat-' || substr(md5(random()::text), 1, 8)), parent, 'Food', 'کھانا')
  returning id;
$$;

create or replace function tests.make_bank(slug text default null)
returns uuid language sql as $$
  insert into public.banks (slug, name_en, name_ur, short_name)
  values (coalesce(slug, 'bank-' || substr(md5(random()::text), 1, 8)), 'HBL', 'ایچ بی ایل', 'HBL')
  returning id;
$$;

create or replace function tests.make_card_product(bank uuid)
returns uuid language sql as $$
  insert into public.card_products (bank_id, slug, name, network, kind)
  values (bank, 'card-' || substr(md5(random()::text), 1, 8), 'Platinum Credit', 'visa', 'credit')
  returning id;
$$;

create or replace function tests.make_business(name text default 'Kolachi Restaurant')
returns uuid language sql as $$
  insert into public.businesses (name) values (name) returning id;
$$;

create or replace function tests.make_brand(business uuid default null, slug text default null)
returns uuid language sql as $$
  insert into public.brands (slug, name, business_id, category_id)
  values (coalesce(slug, 'brand-' || substr(md5(random()::text), 1, 8)), 'Kolachi', business,
          tests.make_category())
  returning id;
$$;

-- A draft nationwide "-40%" deal unless told otherwise.
create or replace function tests.make_deal(
  brand uuid default null,
  status public.deal_status default 'draft',
  scope public.deal_scope default 'nationwide',
  kind public.deal_kind default 'brand_sale'
) returns uuid language plpgsql as $$
declare
  b uuid := coalesce(brand, tests.make_brand());
  d uuid;
begin
  insert into public.deals (brand_id, category_id, kind, scope, status, source,
                            title_en, offer_kind, percent, url)
  values (b, (select category_id from public.brands where id = b), kind, scope, status,
          'staff', 'Winter sale on everything', 'percent_off', 40,
          'https://example.com/sale')
  returning id into d;
  return d;
end $$;

grant usage on schema tests to anon, authenticated;
grant execute on all functions in schema tests to anon, authenticated;

select plan(1);
select pass('test helpers installed');
select * from finish();
