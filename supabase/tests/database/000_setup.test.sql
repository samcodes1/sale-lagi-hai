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

-- A small world for access tests: business A (owner + editor, a verified
-- active brand with a live deal, a draft and a deal in review), business B
-- (its own owner, brand and live deal), a shopper, a moderator and an
-- admin. Staff sessions need MFA: authenticate them with tests.staff().
create or replace function tests.make_world() returns table (
  shopper uuid, editor uuid, owner uuid, other_owner uuid, moderator uuid, admin uuid,
  biz_a uuid, biz_b uuid, brand_a uuid, brand_b uuid,
  live_a uuid, draft_a uuid, review_a uuid, live_b uuid, city uuid
) language plpgsql as $$
begin
  shopper := tests.create_user('shopper@example.com');
  editor := tests.create_user('editor@example.com');
  owner := tests.create_user('owner@example.com');
  other_owner := tests.create_user('other@example.com');
  moderator := tests.create_user('mod@example.com');
  admin := tests.create_user('admin@example.com');
  insert into public.user_roles (user_id, role) values (moderator, 'moderator'), (admin, 'admin');

  biz_a := tests.make_business('Kolachi');
  biz_b := tests.make_business('Burger Lab');
  insert into public.business_members (business_id, user_id, role)
  values (biz_a, owner, 'owner'), (biz_a, editor, 'editor'), (biz_b, other_owner, 'owner');

  brand_a := tests.make_brand(biz_a, 'kolachi');
  brand_b := tests.make_brand(biz_b, 'burger-lab');
  live_a := tests.make_deal(brand_a, 'published');
  draft_a := tests.make_deal(brand_a, 'draft');
  review_a := tests.make_deal(brand_a, 'pending_review');
  live_b := tests.make_deal(brand_b, 'published');
  city := tests.make_city('test-karachi');
  return next;
end $$;

-- Rows an UPDATE or DELETE ... RETURNING 1 affected, under the current role
-- (0 when RLS filtered them out silently).
create or replace function tests.affected(statement text) returns int
language plpgsql as $$
declare n int;
begin
  execute format('with q as (%s) select count(*) from q', statement) into n;
  return n;
end $$;

-- Act as staff with an MFA session.
create or replace function tests.staff(uid uuid) returns void
language sql as $$ select tests.authenticate_as(uid, '{"aal": "aal2"}') $$;

grant usage on schema tests to anon, authenticated;
grant execute on all functions in schema tests to anon, authenticated;

select plan(1);
select pass('test helpers installed');
select * from finish();
