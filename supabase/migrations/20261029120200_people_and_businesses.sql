-- People (profiles, roles) and the businesses behind deals (businesses,
-- their members, brands and outlets).

-- ---------------------------------------------------------------------------
-- Profiles: one per auth user, created automatically on sign-up.
-- Holds no phone number or email (those stay in auth.users).
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text check (length(btrim(display_name)) between 1 and 60),
  avatar_path public.storage_path,
  home_city_id uuid references public.cities on delete set null,
  locale text not null default 'en' check (locale in ('en', 'ur')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index profiles_home_city_idx on public.profiles (home_city_id);

create function private.create_profile_for_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- Never copy user_metadata: the user controls it.
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end $$;
revoke execute on function private.create_profile_for_new_user() from public;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.create_profile_for_new_user();

-- Staff and business roles. Authorization always reads this table (through
-- private helpers); the JWT claim added later is for UI only.
create table public.user_roles (
  user_id uuid not null references auth.users on delete cascade,
  role public.app_role not null,
  granted_by uuid references auth.users on delete set null,
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);
create index user_roles_granted_by_idx on public.user_roles (granted_by);

-- ---------------------------------------------------------------------------
-- Businesses: the account a shop, restaurant or brand uses in the business
-- portal. Contact details are private to its members and staff.
-- ---------------------------------------------------------------------------
create type public.business_status as enum ('pending', 'verified', 'suspended');

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  name public.short_name not null,
  status public.business_status not null default 'pending',
  contact_phone text check (contact_phone ~ '^\+92[0-9]{9,10}$'),
  contact_email text check (contact_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
                            and length(contact_email) <= 254),
  -- NTN or other registration number, checked by staff on verification.
  registration_no text check (length(registration_no) between 3 and 40),
  verified_at timestamptz,
  created_by uuid references auth.users on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((status = 'verified') = (verified_at is not null))
);
create index businesses_created_by_idx on public.businesses (created_by);

create type public.business_member_role as enum ('owner', 'editor');

create table public.business_members (
  business_id uuid not null references public.businesses on delete cascade,
  user_id uuid not null references auth.users on delete cascade,
  role public.business_member_role not null default 'editor',
  created_at timestamptz not null default now(),
  primary key (business_id, user_id)
);
create index business_members_user_idx on public.business_members (user_id);

-- ---------------------------------------------------------------------------
-- Brands: what shoppers see and follow ("Khaadi", "Kolachi", "HBL"). A brand
-- may exist before any business claims it (ingested deals); claiming sets
-- business_id.
-- ---------------------------------------------------------------------------
create table public.brands (
  id uuid primary key default gen_random_uuid(),
  slug public.slug not null unique,
  name public.short_name not null,
  name_ur public.short_name,
  business_id uuid references public.businesses on delete set null,
  category_id uuid not null references public.categories on delete restrict,
  logo_path public.storage_path,
  website public.https_url,
  -- A bank brand links to its bank, so card offers and brand pages match.
  bank_id uuid unique references public.banks on delete set null,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index brands_business_idx on public.brands (business_id);
create index brands_category_idx on public.brands (category_id);
create index brands_name_trgm_idx on public.brands
  using gin (name extensions.gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- Outlets: physical branches, for "near me" and area deals.
-- ---------------------------------------------------------------------------
create table public.outlets (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references public.brands on delete cascade,
  city_id uuid not null references public.cities on delete restrict,
  area_id uuid,
  name public.short_name not null,
  address text not null check (length(btrim(address)) between 5 and 300),
  location extensions.geography(point, 4326) not null,
  -- As plain numbers, for the app's "Open in Maps" (deal detail, 4.4).
  latitude double precision generated always as (extensions.st_y(location::extensions.geometry)) stored,
  longitude double precision generated always as (extensions.st_x(location::extensions.geometry)) stored,
  phone text check (phone ~ '^\+92[0-9]{9,10}$'),
  -- {"mon": [["11:00","23:00"]], ...}; validated by the portal.
  opening_hours jsonb check (jsonb_typeof(opening_hours) = 'object'),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (area_id, city_id) references public.areas (id, city_id)
    on delete restrict
);
create index outlets_brand_idx on public.outlets (brand_id);
create index outlets_city_area_idx on public.outlets (city_id, area_id);
create index outlets_location_idx on public.outlets using gist (location);

create trigger profiles_touch before update on public.profiles
  for each row execute function private.touch_updated_at();
create trigger businesses_touch before update on public.businesses
  for each row execute function private.touch_updated_at();
create trigger brands_touch before update on public.brands
  for each row execute function private.touch_updated_at();
create trigger outlets_touch before update on public.outlets
  for each row execute function private.touch_updated_at();

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.brands enable row level security;
alter table public.outlets enable row level security;
