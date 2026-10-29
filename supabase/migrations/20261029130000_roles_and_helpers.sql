-- Roles and the helpers RLS policies use.
--
-- Who is who:
-- - anon: signed out. Reads public content only.
-- - authenticated: a signed-in shopper. Their own data, plus what a
--   business membership or staff role adds.
-- - business member: a row in business_members (owner or editor). Manages
--   the business's brands, outlets, deals and placements.
-- - moderator / admin: a row in user_roles. Staff powers need a session
--   with MFA (aal2), checked on every request.
-- - service_role: Edge Functions and ingestion. Bypasses RLS.

grant usage on schema private to anon, authenticated, service_role;

-- The service role works on every table (it bypasses RLS). Hosted Supabase
-- grants this by default; it is explicit here so we don't depend on it.
grant usage on schema public to service_role;
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
alter default privileges for role postgres in schema public
  grant all on tables to service_role;
alter default privileges for role postgres in schema public
  grant all on sequences to service_role;

-- The current user's role, read fresh from the table (JWT claims are stale
-- until the token refreshes).
create function private.has_role(r public.app_role) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.user_roles ur
    where ur.user_id = (select auth.uid()) and ur.role = r
  );
$$;

-- Staff powers need a multi-factor session.
create function private.mfa_verified() returns boolean
language sql stable set search_path = '' as $$
  select coalesce((select auth.jwt()) ->> 'aal', '') = 'aal2';
$$;

create function private.is_moderator() returns boolean
language sql stable set search_path = '' as $$
  select private.mfa_verified()
     and (private.has_role('moderator') or private.has_role('admin'));
$$;

create function private.is_admin() returns boolean
language sql stable set search_path = '' as $$
  select private.mfa_verified() and private.has_role('admin');
$$;

-- Businesses the current user belongs to (any role), and owns.
create function private.my_business_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select bm.business_id from public.business_members bm
  where bm.user_id = (select auth.uid());
$$;

create function private.my_owned_business_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select bm.business_id from public.business_members bm
  where bm.user_id = (select auth.uid()) and bm.role = 'owner';
$$;

-- Businesses the current user may act for: a suspended business's members
-- can still see their data but not change anything.
create function private.my_active_business_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select bm.business_id from public.business_members bm
  join public.businesses b on b.id = bm.business_id
  where bm.user_id = (select auth.uid()) and b.status <> 'suspended';
$$;

-- Brands of the businesses the current user belongs to.
create function private.my_brand_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select b.id from public.brands b
  where b.business_id in (
    select bm.business_id from public.business_members bm
    where bm.user_id = (select auth.uid())
  );
$$;

-- Brands the current user may change (their business is not suspended).
create function private.my_writable_brand_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select b.id from public.brands b
  where b.business_id in (
    select bm.business_id from public.business_members bm
    join public.businesses bz on bz.id = bm.business_id
    where bm.user_id = (select auth.uid()) and bz.status <> 'suspended'
  );
$$;

-- True for trusted callers: the service role, and database owners running
-- migrations, seeds or security-definer code. Guards use it to let jobs and
-- ingestion through. Security invoker, so current_user is the caller.
create function private.is_trusted_caller() returns boolean
language sql stable set search_path = '' as $$
  select current_user not in ('anon', 'authenticated');
$$;

revoke execute on all functions in schema private from public;
grant execute on function
  private.has_role(public.app_role), private.mfa_verified(), private.is_moderator(),
  private.is_admin(), private.my_business_ids(), private.my_owned_business_ids(),
  private.my_brand_ids(), private.my_active_business_ids(), private.my_writable_brand_ids(),
  private.is_trusted_caller()
  to authenticated, service_role;
-- Anon reaches only these, through policies on public content and guards.
grant execute on function private.is_trusted_caller(), private.mfa_verified(),
  private.has_role(public.app_role), private.is_moderator()
  to anon;

-- ---------------------------------------------------------------------------
-- Custom Access Token Hook: adds `user_roles` (e.g. ["moderator"]) to the
-- JWT, for the apps' UI only. Authorization always re-checks the table.
-- Enable it in the dashboard: Authentication → Hooks → Custom Access Token.
-- ---------------------------------------------------------------------------
create function public.custom_access_token_hook(event jsonb) returns jsonb
language plpgsql stable set search_path = '' as $$
declare
  claims jsonb := coalesce(event -> 'claims', '{}'::jsonb);
  roles jsonb;
begin
  select coalesce(jsonb_agg(ur.role order by ur.role), '[]'::jsonb) into roles
  from public.user_roles ur
  where ur.user_id = (event ->> 'user_id')::uuid;
  return jsonb_set(event, '{claims}', claims || jsonb_build_object('user_roles', roles));
end $$;

revoke execute on function public.custom_access_token_hook(jsonb) from public, anon, authenticated;
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
grant usage on schema public to supabase_auth_admin;
grant select on table public.user_roles to supabase_auth_admin;
create policy "auth hook reads roles" on public.user_roles
  for select to supabase_auth_admin using (true);
