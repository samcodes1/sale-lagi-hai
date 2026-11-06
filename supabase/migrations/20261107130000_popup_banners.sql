-- Pop-up banners: a full-screen card the app shows over Home when it opens,
-- pushed by staff (from the admin console once it exists; until then, here).
-- At most one shows per app start: the running one with the lowest priority
-- number that the shopper hasn't already seen as often as `frequency` allows.
-- Artwork lives in the public deal-images bucket.

create type public.popup_frequency as enum (
  -- Once per install.
  'once',
  -- At most once a day.
  'daily',
  -- Every time the app starts.
  'every_launch'
);

create table public.popup_banners (
  id uuid primary key default gen_random_uuid(),
  -- Who it's for, shown as "Sponsored by …" when set; null for our own
  -- announcements.
  sponsor_name public.short_name,
  title_en text not null check (char_length(title_en) between 1 and 80),
  title_ur text check (char_length(title_ur) between 1 and 80),
  body_en text check (char_length(body_en) between 1 and 240),
  body_ur text check (char_length(body_ur) between 1 and 240),
  -- Portrait or square artwork. Without one, the card is text only.
  image_path public.storage_path,
  -- The button. It opens one of: a web page, a deal or a brand.
  action_label_en text check (char_length(action_label_en) between 1 and 30),
  action_label_ur text check (char_length(action_label_ur) between 1 and 30),
  link_url public.https_url,
  deal_id uuid references public.deals (id) on delete cascade,
  brand_id uuid references public.brands (id) on delete cascade,
  -- Null shows it in every city.
  city_id uuid references public.cities (id) on delete cascade,
  frequency public.popup_frequency not null default 'once',
  -- Lower shows first.
  priority smallint not null default 100,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at),
  check (num_nonnulls(link_url, deal_id, brand_id) <= 1),
  -- A button needs somewhere to go, and a target needs a button.
  check ((action_label_en is null) = (num_nonnulls(link_url, deal_id, brand_id) = 0)),
  check (action_label_ur is null or action_label_en is not null)
);

create index popup_banners_running_idx
  on public.popup_banners (priority) where is_active;

create index popup_banners_city_idx on public.popup_banners (city_id);
create index popup_banners_deal_idx on public.popup_banners (deal_id);
create index popup_banners_brand_idx on public.popup_banners (brand_id);

create trigger popup_banners_touch before update on public.popup_banners
  for each row execute function private.touch_updated_at();

alter table public.popup_banners enable row level security;

grant select on public.popup_banners to anon, authenticated;
grant insert, update, delete on public.popup_banners to authenticated;

create policy "popup_banners: public read of running" on public.popup_banners
  for select to anon, authenticated
  using (
    is_active and starts_at <= now() and (ends_at is null or ends_at > now())
  );
create policy "popup_banners: staff read" on public.popup_banners
  for select to authenticated using ((select private.is_moderator()));
create policy "popup_banners: staff insert" on public.popup_banners
  for insert to authenticated with check ((select private.is_admin()));
create policy "popup_banners: staff update" on public.popup_banners
  for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "popup_banners: staff delete" on public.popup_banners
  for delete to authenticated using ((select private.is_admin()));
