-- A minimal Supabase for testing on plain Postgres (tool/db_test.sh).
--
-- It recreates only what our migrations and policies depend on: the API
-- roles, the auth schema helpers (same bodies as Supabase's) and the
-- auth.users columns we use. On the real stack (`supabase start`) this file
-- is not loaded; `supabase test db` runs the same tests in
-- supabase/tests/database against the real services.

do $$
begin
  if not exists (select from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
  if not exists (select from pg_roles where rolname = 'supabase_auth_admin') then
    create role supabase_auth_admin nologin noinherit;
  end if;
end $$;

-- Let the session user switch into the API roles, as PostgREST does.
grant anon, authenticated, service_role, supabase_auth_admin to current_user;

create schema if not exists auth;
create schema if not exists extensions;
grant usage on schema extensions to anon, authenticated, service_role;

-- Supabase's default search_path includes extensions.
alter role postgres set search_path = "$user", public, extensions;
alter role anon set search_path = public, extensions;
alter role authenticated set search_path = public, extensions;
alter role service_role set search_path = public, extensions;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  phone text,
  raw_app_meta_data jsonb not null default '{}'::jsonb,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create or replace function auth.jwt() returns jsonb
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb,
    jsonb_build_object('sub', nullif(current_setting('request.jwt.claim.sub', true), ''))
  );
$$;

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  ), '')::uuid;
$$;

create or replace function auth.role() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role'
  );
$$;

grant usage on schema auth to anon, authenticated, service_role, supabase_auth_admin;
grant execute on all functions in schema auth to anon, authenticated, service_role;

-- pgTAP, where `supabase test db` expects it.
create extension if not exists pgtap with schema extensions;
