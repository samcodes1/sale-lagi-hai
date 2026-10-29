-- Minimal Supabase-compatible stub for testing RLS on a *plain* Postgres (no Docker, no Supabase CLI).
-- It recreates only what policies depend on: the anon/authenticated/service_role roles, the auth
-- schema helpers (auth.uid(), auth.jwt(), auth.role()) and a tiny auth.users table. It also adds a
-- `qa` schema of assertion helpers. It is NOT a full Supabase (no storage, realtime or PostgREST);
-- use `supabase test db` (pgTAP) as well when Docker is available.
-- The auth.uid()/auth.jwt() bodies mirror Supabase's: they read request.jwt.claim.sub / request.jwt.claims.

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

-- Let the session user switch into the API roles, as PostgREST's authenticator does.
grant anon, authenticated, service_role to current_user;

create schema if not exists auth;
create schema if not exists extensions;
create schema if not exists private;

create table if not exists auth.users (
  id uuid primary key,
  email text,
  phone text,
  raw_app_meta_data jsonb not null default '{}'::jsonb,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
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

grant usage on schema auth, extensions to anon, authenticated, service_role;
grant execute on all functions in schema auth to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- QA assertion helpers (plain SQL alternative to pgTAP). They are SECURITY INVOKER,
-- so the statements they run are subject to the current role's grants and RLS.
-- ---------------------------------------------------------------------------
create schema if not exists qa;
grant usage on schema qa to anon, authenticated, service_role;

create or replace function qa.ok(cond boolean, description text) returns void
language plpgsql as $$
begin
  if cond is not true then
    raise exception 'not ok - %', description;
  end if;
  raise notice 'ok - %', description;
end $$;

-- Passes when `query` raises SQLSTATE `expected_state` (e.g. 42501 = insufficient privilege / RLS check failed).
create or replace function qa.throws(query text, expected_state text, description text) returns void
language plpgsql as $$
begin
  begin
    execute query;
  exception when others then
    if sqlstate = expected_state then
      raise notice 'ok - % (got %)', description, sqlstate;
      return;
    end if;
    raise exception 'not ok - % (expected %, got %: %)', description, expected_state, sqlstate, sqlerrm;
  end;
  raise exception 'not ok - % (expected error %, statement succeeded)', description, expected_state;
end $$;

-- Passes when `query` runs without error.
create or replace function qa.lives(query text, description text) returns void
language plpgsql as $$
begin
  execute query;
  raise notice 'ok - %', description;
exception when others then
  raise exception 'not ok - % (%: %)', description, sqlstate, sqlerrm;
end $$;

-- Number of rows a query returns (or affects, for DML with RETURNING) under the current role.
create or replace function qa.count(query text) returns bigint
language plpgsql as $$
declare n bigint;
begin
  execute format('select count(*) from (%s) as q', query) into n;
  return n;
end $$;

create or replace function qa.dml_count(query text) returns bigint
language plpgsql as $$
declare n bigint;
begin
  execute format('with q as (%s) select count(*) from q', query) into n;
  return n;
end $$;

-- Switch "who is calling": anon, or an authenticated user with optional extra claims (e.g. user_role, aal).
create or replace function qa.as_anon() returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  perform set_config('request.jwt.claim.sub', '', true);
  execute 'set local role anon';
end $$;

create or replace function qa.as_user(uid uuid, extra jsonb default '{}'::jsonb) returns void
language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', uid, 'role', 'authenticated', 'aal', 'aal1') || extra)::text, true);
  perform set_config('request.jwt.claim.sub', uid::text, true);
  execute 'set local role authenticated';
end $$;

grant execute on all functions in schema qa to anon, authenticated, service_role;
