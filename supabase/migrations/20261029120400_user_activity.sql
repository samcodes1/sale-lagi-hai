-- What signed-in users keep: follows, saves, their cards (products only),
-- alert preferences and their in-app notifications. All of it is deleted
-- with the account (on delete cascade).

-- Follow exactly one brand, category, bank or city.
create table public.follows (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  brand_id uuid references public.brands on delete cascade,
  category_id uuid references public.categories on delete cascade,
  bank_id uuid references public.banks on delete cascade,
  city_id uuid references public.cities on delete cascade,
  created_at timestamptz not null default now(),
  check (num_nonnulls(brand_id, category_id, bank_id, city_id) = 1),
  unique nulls not distinct (user_id, brand_id, category_id, bank_id, city_id)
);
create index follows_user_idx on public.follows (user_id);
-- Fan-out for alerts: who follows this brand, category, bank or city.
create index follows_brand_idx on public.follows (brand_id) where brand_id is not null;
create index follows_category_idx on public.follows (category_id) where category_id is not null;
create index follows_bank_idx on public.follows (bank_id) where bank_id is not null;
create index follows_city_idx on public.follows (city_id) where city_id is not null;

create table public.saves (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  deal_id uuid not null references public.deals on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, deal_id)
);
create index saves_deal_idx on public.saves (deal_id);

-- "My cards": card products only. Never a card number, expiry or name.
create table public.user_cards (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  card_product_id uuid not null references public.card_products on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, card_product_id)
);
create index user_cards_product_idx on public.user_cards (card_product_id);

create type public.alert_frequency as enum ('low', 'normal', 'high');

-- One row per user, created with the profile. The push dispatcher enforces
-- these (frequency caps and quiet hours, flutter-ui-ux skill §10).
create table public.alert_prefs (
  user_id uuid primary key references auth.users on delete cascade,
  push_enabled boolean not null default false,
  frequency public.alert_frequency not null default 'normal',
  quiet_start time not null default '22:00',
  quiet_end time not null default '08:00',
  time_zone text not null default 'Asia/Karachi'
    check (time_zone ~ '^[A-Za-z_]+(/[A-Za-z0-9_+-]+){0,2}$'),
  followed_brands boolean not null default true,
  followed_categories boolean not null default true,
  my_cards boolean not null default true,
  my_city boolean not null default true,
  saved_price_drops boolean not null default true,
  saved_expiring boolean not null default true,
  updated_at timestamptz not null default now(),
  check (quiet_start <> quiet_end)
);

create type public.notification_kind as enum (
  'deal_alert', 'price_drop', 'expiring_saved', 'business', 'system'
);

-- The Alerts tab. Short text only; pushes carry the same, with no personal
-- data.
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade,
  kind public.notification_kind not null,
  title text not null check (length(title) between 1 and 120),
  body text check (length(body) <= 300),
  deal_id uuid references public.deals on delete set null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  check (read_at is null or read_at >= created_at)
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index notifications_unread_idx on public.notifications (user_id)
  where read_at is null;
create index notifications_deal_idx on public.notifications (deal_id);

create trigger alert_prefs_touch before update on public.alert_prefs
  for each row execute function private.touch_updated_at();

-- New users get default alert preferences along with their profile.
create or replace function private.create_profile_for_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- Never copy user_metadata: the user controls it.
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  insert into public.alert_prefs (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end $$;

alter table public.follows enable row level security;
alter table public.saves enable row level security;
alter table public.user_cards enable row level security;
alter table public.alert_prefs enable row level security;
alter table public.notifications enable row level security;
