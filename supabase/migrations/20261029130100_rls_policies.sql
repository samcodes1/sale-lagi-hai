-- Grants and RLS policies, table by table. The access matrix is in
-- docs/backend/ACCESS.md; supabase/tests/database/1xx_*.test.sql test each
-- cell (allow and deny).
--
-- Pattern: grant the operation, then one policy per operation and role.
-- Columns only staff may change are protected by guard triggers, because
-- grants and policies can't tell a moderator's update from an owner's.

-- Staff write policies, one per operation: `who` is a private helper
-- (is_moderator or is_admin).
create function pg_temp.staff_writes(tbl text, who text) returns void
language plpgsql as $f$
begin
  execute format($p$create policy "%1$s: staff insert" on public.%1$I
    for insert to authenticated with check ((select private.%2$s()))$p$, tbl, who);
  execute format($p$create policy "%1$s: staff update" on public.%1$I
    for update to authenticated using ((select private.%2$s()))
    with check ((select private.%2$s()))$p$, tbl, who);
  execute format($p$create policy "%1$s: staff delete" on public.%1$I
    for delete to authenticated using ((select private.%2$s()))$p$, tbl, who);
end $f$;

-- Who created a row, filled in by the database.
alter table public.businesses alter column created_by set default auth.uid();
alter table public.deals alter column created_by set default auth.uid();
alter table public.placements alter column created_by set default auth.uid();
alter table public.user_roles alter column granted_by set default auth.uid();

-- ===========================================================================
-- Reference data: everyone reads; admins write.
-- ===========================================================================
grant select on public.cities, public.areas, public.categories, public.banks,
  public.card_products to anon, authenticated;
grant insert, update, delete on public.cities, public.areas, public.categories,
  public.banks, public.card_products to authenticated;

create policy "cities: public read" on public.cities
  for select to anon, authenticated using (true);
create policy "areas: public read" on public.areas
  for select to anon, authenticated using (true);
create policy "categories: public read of active" on public.categories
  for select to anon, authenticated using (is_active or (select private.is_moderator()));
create policy "banks: public read of active" on public.banks
  for select to anon, authenticated using (is_active or (select private.is_moderator()));
create policy "card products: public read of active" on public.card_products
  for select to anon, authenticated using (is_active or (select private.is_moderator()));

select pg_temp.staff_writes(t, 'is_admin')
from unnest(array['cities', 'areas', 'categories', 'banks', 'card_products']) t;

-- ===========================================================================
-- Profiles: your own. Staff read all (moderation).
-- ===========================================================================
grant select on public.profiles to authenticated;
grant update (display_name, avatar_path, home_city_id, locale) on public.profiles to authenticated;

create policy "profiles: read own" on public.profiles
  for select to authenticated using (id = (select auth.uid()));
create policy "profiles: staff read" on public.profiles
  for select to authenticated using ((select private.is_moderator()));
create policy "profiles: update own" on public.profiles
  for update to authenticated using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ===========================================================================
-- User roles: you see your own; admins manage them.
-- ===========================================================================
grant select, insert, delete on public.user_roles to authenticated;

create policy "user roles: read own" on public.user_roles
  for select to authenticated using (user_id = (select auth.uid()));
create policy "user roles: admins read" on public.user_roles
  for select to authenticated using ((select private.is_admin()));
create policy "user roles: admins grant" on public.user_roles
  for insert to authenticated
  with check ((select private.is_admin()) and granted_by = (select auth.uid()));
-- Admins can't remove their own admin role (no accidental lock-out).
create policy "user roles: admins revoke" on public.user_roles
  for delete to authenticated
  using ((select private.is_admin())
         and not (user_id = (select auth.uid()) and role = 'admin'));

-- ===========================================================================
-- Businesses: members and staff. Anyone signed in can register one; they
-- become its owner.
-- ===========================================================================
grant select, insert on public.businesses to authenticated;
grant update (name, contact_phone, contact_email, registration_no, status, verified_at)
  on public.businesses to authenticated;
grant delete on public.businesses to authenticated;

create policy "businesses: members read" on public.businesses
  for select to authenticated using (id in (select private.my_business_ids()));
-- Lets the registering user read the row back before the membership exists.
create policy "businesses: creator reads" on public.businesses
  for select to authenticated using (created_by = (select auth.uid()));
create policy "businesses: staff read" on public.businesses
  for select to authenticated using ((select private.is_moderator()));
create policy "businesses: register" on public.businesses
  for insert to authenticated
  with check (created_by = (select auth.uid()) and status = 'pending' and verified_at is null);
create policy "businesses: owners update" on public.businesses
  for update to authenticated using (id in (select private.my_owned_business_ids()))
  with check (id in (select private.my_owned_business_ids()));
create policy "businesses: staff update" on public.businesses
  for update to authenticated using ((select private.is_moderator()))
  with check ((select private.is_moderator()));
create policy "businesses: admins delete" on public.businesses
  for delete to authenticated using ((select private.is_admin()));

-- The registering user becomes the first owner.
create function private.add_business_creator() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.created_by is not null then
    insert into public.business_members (business_id, user_id, role)
    values (new.id, new.created_by, 'owner')
    on conflict do nothing;
  end if;
  return null;
end $$;
revoke execute on function private.add_business_creator() from public;
create trigger businesses_add_creator after insert on public.businesses
  for each row execute function private.add_business_creator();

-- Only staff verify or suspend.
create function private.guard_business() returns trigger
language plpgsql set search_path = '' as $$
begin
  if private.is_trusted_caller() or private.is_moderator() then
    return new;
  end if;
  if (new.status, new.verified_at) is distinct from (old.status, old.verified_at) then
    raise exception 'only staff can verify or suspend a business'
      using errcode = '42501';
  end if;
  if old.status = 'suspended' then
    raise exception 'a suspended business cannot change its details' using errcode = '42501';
  end if;
  -- A verified business that changes who it is goes back to review.
  if old.status = 'verified'
     and (new.name, new.registration_no) is distinct from (old.name, old.registration_no) then
    new.status := 'pending';
    new.verified_at := null;
  end if;
  return new;
end $$;
create trigger businesses_guard before update on public.businesses
  for each row execute function private.guard_business();

-- ===========================================================================
-- Business members: members see their team; owners manage it.
-- ===========================================================================
grant select, insert, delete on public.business_members to authenticated;
grant update (role) on public.business_members to authenticated;

create policy "members: read own team" on public.business_members
  for select to authenticated using (business_id in (select private.my_business_ids()));
create policy "members: staff read" on public.business_members
  for select to authenticated using ((select private.is_moderator()));
create policy "members: owners add" on public.business_members
  for insert to authenticated
  with check (business_id in (select private.my_owned_business_ids()));
create policy "members: owners change roles" on public.business_members
  for update to authenticated using (business_id in (select private.my_owned_business_ids()))
  with check (business_id in (select private.my_owned_business_ids()));
create policy "members: owners remove, or leave" on public.business_members
  for delete to authenticated
  using (business_id in (select private.my_owned_business_ids())
         or user_id = (select auth.uid()));
select pg_temp.staff_writes('business_members', 'is_admin');

-- A business keeps an owner when roles change. Anyone may still leave,
-- even the last owner (nobody is stuck in a business someone else added
-- them to), and account deletion always works; staff then reassign the
-- business.
create function private.keep_an_owner() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.role = 'owner'
     and exists (select 1 from public.businesses b where b.id = old.business_id)
     and exists (select 1 from auth.users u where u.id = old.user_id)
     and not (tg_op = 'DELETE' and old.user_id = (select auth.uid()))
     and not exists (
       select 1 from public.business_members m
       where m.business_id = old.business_id and m.role = 'owner'
     ) then
    raise exception 'a business needs at least one owner' using errcode = '23514';
  end if;
  return null;
end $$;
revoke execute on function private.keep_an_owner() from public;
create trigger business_members_keep_owner after update of role or delete
  on public.business_members for each row execute function private.keep_an_owner();

-- ===========================================================================
-- Brands: public when active. Members manage their own; staff manage all.
-- A brand a business adds stays hidden until staff check and activate it,
-- so nobody can squat a famous brand's name.
-- ===========================================================================
grant select on public.brands to anon, authenticated;
grant insert, delete on public.brands to authenticated;
grant update (slug, name, name_ur, business_id, category_id, logo_path, website,
              bank_id, is_verified, is_active) on public.brands to authenticated;

create policy "brands: public read of active" on public.brands
  for select to anon, authenticated using (is_active);
create policy "brands: members read own" on public.brands
  for select to authenticated using (business_id in (select private.my_business_ids()));
create policy "brands: staff read" on public.brands
  for select to authenticated using ((select private.is_moderator()));
create policy "brands: members add" on public.brands
  for insert to authenticated
  with check (business_id in (select private.my_active_business_ids())
              and not is_verified and not is_active and bank_id is null
              -- A placeholder slug: staff set the real one on approval, so
              -- nobody can reserve a famous brand's address.
              and slug like 'pending-%');
create policy "brands: staff add" on public.brands
  for insert to authenticated with check ((select private.is_moderator()));
create policy "brands: members update own" on public.brands
  for update to authenticated using (business_id in (select private.my_business_ids()))
  with check (business_id in (select private.my_active_business_ids()));
create policy "brands: staff update" on public.brands
  for update to authenticated using ((select private.is_moderator()))
  with check ((select private.is_moderator()));
create policy "brands: staff delete" on public.brands
  for delete to authenticated using ((select private.is_admin()));

-- Members edit their brand's look, not its identity or trust signals.
create function private.guard_brand() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (new.slug, new.business_id, new.bank_id, new.is_verified, new.is_active)
     is distinct from (old.slug, old.business_id, old.bank_id, old.is_verified, old.is_active)
     and not private.is_trusted_caller() and not private.is_moderator() then
    raise exception 'only staff can change a brand''s slug, owner, bank or status'
      using errcode = '42501';
  end if;
  -- Shoppers know a live brand by its name: only staff rename it.
  if old.is_active and (new.name, new.name_ur) is distinct from (old.name, old.name_ur)
     and not private.is_trusted_caller() and not private.is_moderator() then
    raise exception 'ask staff to rename a live brand' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger brands_guard before update on public.brands
  for each row execute function private.guard_brand();

-- ===========================================================================
-- Outlets: public when active (and the brand is); members manage their
-- brands' outlets.
-- ===========================================================================
grant select on public.outlets to anon, authenticated;
grant insert, update, delete on public.outlets to authenticated;

create policy "outlets: public read of active" on public.outlets
  for select to anon, authenticated
  using (is_active and brand_id in (select b.id from public.brands b where b.is_active));
create policy "outlets: members read own" on public.outlets
  for select to authenticated using (brand_id in (select private.my_brand_ids()));
create policy "outlets: staff read" on public.outlets
  for select to authenticated using ((select private.is_moderator()));
create policy "outlets: members add" on public.outlets
  for insert to authenticated with check (brand_id in (select private.my_writable_brand_ids()));
create policy "outlets: members update" on public.outlets
  for update to authenticated using (brand_id in (select private.my_brand_ids()))
  with check (brand_id in (select private.my_writable_brand_ids()));
create policy "outlets: members delete" on public.outlets
  for delete to authenticated using (brand_id in (select private.my_writable_brand_ids()));
select pg_temp.staff_writes('outlets', 'is_moderator');

-- ===========================================================================
-- Deals.
-- Public: published or expired (an expired deal still opens, marked
-- Expired), once started, from an active brand.
-- Members: their brands' deals in any status. They write drafts and send
-- them for review; only staff publish or reject.
-- ===========================================================================
grant select on public.deals to anon, authenticated;
grant insert, delete on public.deals to authenticated;
grant update (brand_id, category_id, kind, scope, status, title_en, title_ur,
              description_en, description_ur, terms_en, terms_ur, offer_kind, percent,
              amount_off_pkr, price_pkr, original_price_pkr, offer_text_en, offer_text_ur,
              promo_code, url, image_path, starts_at, ends_at, verified_at)
  on public.deals to authenticated;

create policy "deals: public read of live and expired" on public.deals
  for select to anon, authenticated
  using (status in ('published', 'expired') and starts_at <= now()
         and brand_id in (select b.id from public.brands b where b.is_active));
create policy "deals: members read own" on public.deals
  for select to authenticated using (brand_id in (select private.my_brand_ids()));
create policy "deals: staff read" on public.deals
  for select to authenticated using ((select private.is_moderator()));

create policy "deals: members write drafts" on public.deals
  for insert to authenticated
  with check (brand_id in (select private.my_writable_brand_ids())
              and status in ('draft', 'pending_review')
              and source = 'business' and created_by = (select auth.uid())
              and verified_at is null and published_at is null and fingerprint is null);
create policy "deals: staff add" on public.deals
  for insert to authenticated
  with check ((select private.is_moderator()) and created_by = (select auth.uid()));

-- Updates match on every brand the member can see but must pass the check
-- for writable ones, so a suspended business gets an error, not a silent
-- no-op.
create policy "deals: members update own" on public.deals
  for update to authenticated using (brand_id in (select private.my_brand_ids()))
  with check (brand_id in (select private.my_writable_brand_ids()));
create policy "deals: staff update" on public.deals
  for update to authenticated using ((select private.is_moderator()))
  with check ((select private.is_moderator()));

create policy "deals: members delete drafts" on public.deals
  for delete to authenticated
  using (brand_id in (select private.my_writable_brand_ids()) and status = 'draft');
create policy "deals: admins delete" on public.deals
  for delete to authenticated using ((select private.is_admin()));

-- What members (not staff) may do to a deal:
-- - status: draft → pending_review → draft; published → draft or removed;
--   rejected or removed → draft. Never publish, reject or expire.
-- - content: only while the deal is, or becomes, a draft. A deal in
--   review or live is taken back to draft first, so a moderator always
--   approves the text that goes live.
-- - verified_at: never (staff and ingestion only).
create function private.guard_deal() returns trigger
language plpgsql set search_path = '' as $$
begin
  if private.is_trusted_caller() or private.is_moderator() then
    return new;
  end if;
  if new.status is distinct from old.status and not (
       (old.status = 'draft' and new.status in ('pending_review', 'removed'))
    or (old.status = 'pending_review' and new.status = 'draft')
    or (old.status = 'published' and new.status in ('draft', 'removed'))
    or (old.status in ('rejected', 'removed') and new.status = 'draft')
  ) then
    raise exception 'a business cannot move a deal from % to %', old.status, new.status
      using errcode = '42501';
  end if;
  if new.verified_at is distinct from old.verified_at then
    raise exception 'only staff and ingestion mark a deal verified' using errcode = '42501';
  end if;
  if new.status <> 'draft' and (
       new.brand_id, new.category_id, new.kind, new.scope, new.title_en, new.title_ur,
       new.description_en, new.description_ur, new.terms_en, new.terms_ur, new.offer_kind,
       new.percent, new.amount_off_pkr, new.price_pkr, new.original_price_pkr,
       new.offer_text_en, new.offer_text_ur, new.promo_code, new.url, new.image_path,
       new.starts_at, new.ends_at
     ) is distinct from (
       old.brand_id, old.category_id, old.kind, old.scope, old.title_en, old.title_ur,
       old.description_en, old.description_ur, old.terms_en, old.terms_ur, old.offer_kind,
       old.percent, old.amount_off_pkr, old.price_pkr, old.original_price_pkr,
       old.offer_text_en, old.offer_text_ur, old.promo_code, old.url, old.image_path,
       old.starts_at, old.ends_at
     ) then
    raise exception 'move the deal back to draft before editing it' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger deals_guard before update on public.deals
  for each row execute function private.guard_deal();

-- Targets and card offers follow their deal: visible when the deal is,
-- editable by members while the deal is a draft, and by staff.
grant select on public.deal_targets, public.card_offers to anon, authenticated;
grant insert, update, delete on public.deal_targets, public.card_offers to authenticated;

do $$
declare t text;
begin
  foreach t in array array['deal_targets', 'card_offers'] loop
    execute format($p$create policy "%1$s: visible with the deal" on public.%1$I
      for select to anon, authenticated
      using (exists (select 1 from public.deals d where d.id = deal_id))$p$, t);
    execute format($p$create policy "%1$s: members edit drafts" on public.%1$I
      for insert to authenticated
      with check (deal_id in (select d.id from public.deals d
                              where d.brand_id in (select private.my_writable_brand_ids())
                                and d.status = 'draft'))$p$, t);
    execute format($p$create policy "%1$s: members update drafts" on public.%1$I
      for update to authenticated
      using (deal_id in (select d.id from public.deals d
                         where d.brand_id in (select private.my_writable_brand_ids())
                           and d.status = 'draft'))
      with check (deal_id in (select d.id from public.deals d
                              where d.brand_id in (select private.my_writable_brand_ids())
                                and d.status = 'draft'))$p$, t);
    execute format($p$create policy "%1$s: members delete from drafts" on public.%1$I
      for delete to authenticated
      using (deal_id in (select d.id from public.deals d
                         where d.brand_id in (select private.my_writable_brand_ids())
                           and d.status = 'draft'))$p$, t);
    perform pg_temp.staff_writes(t, 'is_moderator');
  end loop;
end $$;

-- ===========================================================================
-- Shopper data: your own only.
-- ===========================================================================
grant select, insert, delete on public.follows, public.saves, public.user_cards to authenticated;
grant usage on sequence public.follows_id_seq to authenticated;

create policy "follows: read own" on public.follows
  for select to authenticated using (user_id = (select auth.uid()));
create policy "follows: add own" on public.follows
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "follows: remove own" on public.follows
  for delete to authenticated using (user_id = (select auth.uid()));

create policy "saves: read own" on public.saves
  for select to authenticated using (user_id = (select auth.uid()));
-- Only deals the user can see (no probing drafts by id).
create policy "saves: add own" on public.saves
  for insert to authenticated
  with check (user_id = (select auth.uid()) and deal_id in (select d.id from public.deals d));
create policy "saves: remove own" on public.saves
  for delete to authenticated using (user_id = (select auth.uid()));

create policy "user cards: read own" on public.user_cards
  for select to authenticated using (user_id = (select auth.uid()));
create policy "user cards: add own" on public.user_cards
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy "user cards: remove own" on public.user_cards
  for delete to authenticated using (user_id = (select auth.uid()));

grant select on public.alert_prefs to authenticated;
grant update (push_enabled, frequency, quiet_start, quiet_end, time_zone, followed_brands,
              followed_categories, my_cards, my_city, saved_price_drops, saved_expiring)
  on public.alert_prefs to authenticated;
create policy "alert prefs: read own" on public.alert_prefs
  for select to authenticated using (user_id = (select auth.uid()));
create policy "alert prefs: update own" on public.alert_prefs
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Notifications are written by the push dispatcher (service role). Users
-- read, mark read and delete their own.
grant select, delete on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;
create policy "notifications: read own" on public.notifications
  for select to authenticated using (user_id = (select auth.uid()));
create policy "notifications: mark own read" on public.notifications
  for update to authenticated using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "notifications: delete own" on public.notifications
  for delete to authenticated using (user_id = (select auth.uid()));

-- ===========================================================================
-- Reports and submissions: users send them and see their own; staff
-- review them.
-- ===========================================================================
grant select, insert on public.reports to authenticated;
grant update (status, resolved_by, resolved_at) on public.reports to authenticated;

create policy "reports: read own" on public.reports
  for select to authenticated using (reporter_id = (select auth.uid()));
create policy "reports: staff read" on public.reports
  for select to authenticated using ((select private.is_moderator()));
create policy "reports: send" on public.reports
  for insert to authenticated
  with check (reporter_id = (select auth.uid()) and status = 'open'
              and resolved_by is null and resolved_at is null
              and deal_id in (select d.id from public.deals d));
create policy "reports: staff resolve" on public.reports
  for update to authenticated using ((select private.is_moderator()))
  with check ((select private.is_moderator()) and resolved_by = (select auth.uid()));

grant select, insert, delete on public.submissions to authenticated;
grant update (brand_id, status, deal_id, duplicate_of, reviewer_id, reviewed_at, reject_reason)
  on public.submissions to authenticated;

create policy "submissions: read own" on public.submissions
  for select to authenticated using (submitter_id = (select auth.uid()));
create policy "submissions: staff read" on public.submissions
  for select to authenticated using ((select private.is_moderator()));
create policy "submissions: send" on public.submissions
  for insert to authenticated
  with check (submitter_id = (select auth.uid()) and status = 'pending'
              and deal_id is null and duplicate_of is null and reviewer_id is null
              and reviewed_at is null and reject_reason is null);
create policy "submissions: withdraw own pending" on public.submissions
  for delete to authenticated
  using (submitter_id = (select auth.uid()) and status = 'pending');
create policy "submissions: staff review" on public.submissions
  for update to authenticated using ((select private.is_moderator()))
  with check ((select private.is_moderator()) and reviewer_id = (select auth.uid()));

-- ===========================================================================
-- Placements: everyone sees what is live (it is labelled Featured anyway);
-- members draft them; staff schedule and run them after payment.
-- ===========================================================================
grant select on public.placements to anon, authenticated;
grant insert, delete on public.placements to authenticated;
grant update (deal_id, slot, city_id, category_id, starts_at, ends_at, status, priority)
  on public.placements to authenticated;

create policy "placements: public read of live" on public.placements
  for select to anon, authenticated
  using (status = 'active' and now() >= starts_at and now() < ends_at);
create policy "placements: members read own" on public.placements
  for select to authenticated using (business_id in (select private.my_business_ids()));
create policy "placements: staff read" on public.placements
  for select to authenticated using ((select private.is_moderator()));
create policy "placements: members draft" on public.placements
  for insert to authenticated
  with check (business_id in (select private.my_active_business_ids()) and status = 'draft'
              and priority = 0 and created_by = (select auth.uid()));
create policy "placements: members edit drafts" on public.placements
  for update to authenticated
  using (business_id in (select private.my_business_ids()) and status = 'draft')
  with check (business_id in (select private.my_active_business_ids())
              and status in ('draft', 'cancelled') and priority = 0);
create policy "placements: members delete drafts" on public.placements
  for delete to authenticated
  using (business_id in (select private.my_active_business_ids()) and status = 'draft');
select pg_temp.staff_writes('placements', 'is_admin');

-- ===========================================================================
-- Payments: business owners read theirs; admins read all. Written by the
-- payments webhook (service role) only.
-- ===========================================================================
grant select on public.payments to authenticated;
create policy "payments: owners read" on public.payments
  for select to authenticated using (business_id in (select private.my_owned_business_ids()));
create policy "payments: admins read" on public.payments
  for select to authenticated using ((select private.is_admin()));

-- ===========================================================================
-- Audit log: admins read. Written by trigger only.
-- ===========================================================================
grant select on public.audit_log to authenticated;
create policy "audit log: admins read" on public.audit_log
  for select to authenticated using ((select private.is_admin()));
