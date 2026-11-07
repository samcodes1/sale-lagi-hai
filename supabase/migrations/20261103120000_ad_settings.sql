-- Ad settings: one row staff edit in Studio to tune how often the app shows
-- ads, without a release. The checks keep every value within what Google's
-- ad policies allow; the app clamps them to the same bounds as well.

create table public.ad_settings (
  -- Always true, so the table holds exactly one row.
  id boolean primary key default true check (id),
  -- The kill switch: false shows no ads at all.
  enabled boolean not null default true,
  -- False shows rectangle banners in the native slots.
  native_enabled boolean not null default true,
  feed_ad_every smallint not null default 6 check (feed_ad_every between 4 and 30),
  interstitial_breaks smallint not null default 3
    check (interstitial_breaks between 2 and 20),
  interstitial_gap_seconds integer not null default 120
    check (interstitial_gap_seconds between 60 and 3600),
  -- 0 turns full-screen ads off.
  interstitial_max_per_session smallint not null default 8
    check (interstitial_max_per_session between 0 and 12),
  app_open_enabled boolean not null default true,
  app_open_min_launches smallint not null default 2
    check (app_open_min_launches between 1 and 20),
  app_open_gap_minutes integer not null default 60
    check (app_open_gap_minutes between 30 and 1440),
  updated_at timestamptz not null default now()
);

insert into public.ad_settings default values;

create trigger ad_settings_touch before update on public.ad_settings
  for each row execute function private.touch_updated_at();

alter table public.ad_settings enable row level security;

grant select on public.ad_settings to anon, authenticated;
grant update on public.ad_settings to authenticated;

create policy "ad_settings: public read" on public.ad_settings
  for select to anon, authenticated using (true);
create policy "ad_settings: admin update" on public.ad_settings
  for update to authenticated
  using ((select private.is_admin())) with check ((select private.is_admin()));
