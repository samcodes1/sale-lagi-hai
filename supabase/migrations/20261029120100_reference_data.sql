-- Reference data: places, categories, banks and card products. Managed by
-- staff (admin console, seed data); read by everyone (policies in the RLS
-- migration).

create table public.cities (
  id uuid primary key default gen_random_uuid(),
  slug public.slug not null unique,
  name_en public.short_name not null,
  name_ur public.short_name not null,
  province public.province not null,
  -- City deals go live city by city (Karachi first). Nationwide deals show
  -- everywhere regardless.
  is_live boolean not null default false,
  center extensions.geography(point, 4326) not null,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.areas (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references public.cities on delete restrict,
  slug public.slug not null,
  name_en public.short_name not null,
  name_ur public.short_name not null,
  center extensions.geography(point, 4326) not null,
  -- Rough size, for "deals in this area" without drawing boundaries.
  radius_m integer not null default 2000 check (radius_m between 200 and 30000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (city_id, slug),
  -- Lets other tables reference an area together with its city, so an
  -- area can never be paired with the wrong city.
  unique (id, city_id)
);
create index areas_center_idx on public.areas using gist (center);

-- Categories are data, not code: added from the admin console without an
-- app update. One level of subcategories.
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  slug public.slug not null unique,
  parent_id uuid references public.categories on delete restrict,
  name_en public.short_name not null,
  name_ur public.short_name not null,
  -- A Material Symbols name the app maps to an icon.
  icon text not null default 'local_offer' check (icon ~ '^[a-z0-9_]{1,40}$'),
  sort_order smallint not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (parent_id is distinct from id)
);
create index categories_parent_idx on public.categories (parent_id);

-- A subcategory's parent must itself be top-level.
-- Security definer: the rule must see every category, whatever the caller's RLS.
create function private.check_category_depth() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.parent_id is not null and exists (
    select 1 from public.categories p
    where p.id = new.parent_id and p.parent_id is not null
  ) then
    raise exception 'categories are at most two levels deep'
      using errcode = '23514';
  end if;
  if new.parent_id is not null and exists (
    select 1 from public.categories c where c.parent_id = new.id
  ) then
    raise exception 'a category with subcategories cannot become one'
      using errcode = '23514';
  end if;
  return new;
end $$;
create trigger categories_depth before insert or update of parent_id
  on public.categories for each row execute function private.check_category_depth();

create table public.banks (
  id uuid primary key default gen_random_uuid(),
  slug public.slug not null unique,
  name_en public.short_name not null,
  name_ur public.short_name not null,
  -- Short name on card chips ("HBL", "Meezan").
  short_name text not null check (length(short_name) between 1 and 16),
  logo_path public.storage_path,
  website public.https_url,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create type public.card_network as enum (
  'visa', 'mastercard', 'unionpay', 'paypak', 'amex', 'jcb'
);
create type public.card_kind as enum ('credit', 'debit', 'prepaid');

-- Card products, never card numbers: "HBL Platinum Credit (Visa)". Users
-- pick these to get "deals for my cards"; we store nothing else.
create table public.card_products (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references public.banks on delete restrict,
  slug public.slug not null,
  name public.short_name not null,
  network public.card_network not null,
  kind public.card_kind not null,
  -- Classic, Gold, Platinum, Signature, World, Infinite... free text, as
  -- banks name tiers inconsistently.
  tier text check (length(tier) between 1 and 40),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (bank_id, slug)
);
create index card_products_bank_idx on public.card_products (bank_id);

create trigger cities_touch before update on public.cities
  for each row execute function private.touch_updated_at();
create trigger areas_touch before update on public.areas
  for each row execute function private.touch_updated_at();
create trigger categories_touch before update on public.categories
  for each row execute function private.touch_updated_at();
create trigger banks_touch before update on public.banks
  for each row execute function private.touch_updated_at();
create trigger card_products_touch before update on public.card_products
  for each row execute function private.touch_updated_at();

alter table public.cities enable row level security;
alter table public.areas enable row level security;
alter table public.categories enable row level security;
alter table public.banks enable row level security;
alter table public.card_products enable row level security;
