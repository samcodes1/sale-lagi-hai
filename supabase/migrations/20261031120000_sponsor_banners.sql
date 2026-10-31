-- Sponsor banners: direct sales shown at the top of Home. Staff manage them
-- here until the admin console exists (Phase 7). Artwork lives in the public
-- deal-images bucket.

create table public.sponsor_banners (
  id uuid primary key default gen_random_uuid(),
  sponsor_name public.short_name not null,
  title_en text not null check (char_length(title_en) between 1 and 80),
  title_ur text check (char_length(title_ur) between 1 and 80),
  subtitle_en text check (char_length(subtitle_en) between 1 and 120),
  subtitle_ur text check (char_length(subtitle_ur) between 1 and 120),
  image_path public.storage_path,
  link_url public.https_url,
  -- Null shows it in every city.
  city_id uuid references public.cities (id) on delete cascade,
  sort_order smallint not null default 100,
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);

create index sponsor_banners_running_idx
  on public.sponsor_banners (sort_order) where is_active;

create index sponsor_banners_city_idx on public.sponsor_banners (city_id);

create trigger sponsor_banners_touch before update on public.sponsor_banners
  for each row execute function private.touch_updated_at();

alter table public.sponsor_banners enable row level security;

grant select on public.sponsor_banners to anon, authenticated;
grant insert, update, delete on public.sponsor_banners to authenticated;

create policy "sponsor_banners: public read of running" on public.sponsor_banners
  for select to anon, authenticated
  using (
    is_active and starts_at <= now() and (ends_at is null or ends_at > now())
  );
create policy "sponsor_banners: staff read" on public.sponsor_banners
  for select to authenticated using ((select private.is_moderator()));
create policy "sponsor_banners: staff insert" on public.sponsor_banners
  for insert to authenticated with check ((select private.is_admin()));
create policy "sponsor_banners: staff update" on public.sponsor_banners
  for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
create policy "sponsor_banners: staff delete" on public.sponsor_banners
  for delete to authenticated using ((select private.is_admin()));
