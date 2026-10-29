-- Foundation: extensions, schemas, default privileges, shared types and
-- helpers. Every later migration builds on this.
--
-- Security model (docs/backend/SCHEMA.md, flutter-secure-dev skill):
-- - `public` is exposed through the Data API. Every table there has RLS on,
--   and grants are opt-in: nothing is readable or writable by anon or
--   authenticated until a migration grants it and a policy allows it.
-- - `private` is not exposed. It holds helpers and internal tables.
-- - service_role (the server-only secret key) keeps its grants, for Edge
--   Functions and ingestion; it bypasses RLS by design.

-- Extensions go in `extensions`, as on Supabase.
create extension if not exists postgis with schema extensions;
create extension if not exists pg_trgm with schema extensions;

create schema if not exists private;
revoke all on schema private from public;

-- Grants are opt-in: new objects in public are not visible to the API
-- roles until a migration grants them.
alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on functions from anon, authenticated;
alter default privileges for role postgres
  revoke execute on functions from public;

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------
-- Staff and business roles. Signed-in shoppers have no row: "user" is the
-- default.
create type public.app_role as enum ('business_owner', 'moderator', 'admin');

create type public.province as enum (
  'sindh', 'punjab', 'khyber_pakhtunkhwa', 'balochistan', 'islamabad',
  'gilgit_baltistan', 'azad_kashmir'
);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- Slugs match the app's route validation (lib/app/router/route_params.dart):
-- lower-case words joined by single hyphens, at most 64 characters.
create domain public.slug as text
  check (value ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(value) <= 64);

-- Short display names, in English (or Roman Urdu) and Urdu.
create domain public.short_name as text
  check (length(btrim(value)) between 1 and 120 and value = btrim(value));

-- Amounts in whole Pakistani rupees.
create domain public.pkr as integer check (value >= 0 and value <= 100000000);

-- HTTPS links only.
create domain public.https_url as text
  check (value ~ '^https://[^\s/$.?#][^\s]*$' and length(value) <= 2048);

-- Paths inside a Storage bucket ("<owner-id>/<file>"), never full URLs.
create domain public.storage_path as text
  check (value ~ '^[A-Za-z0-9_-]+(/[A-Za-z0-9._-]+)+$'
         and value !~ '\.\.' and length(value) <= 512);

-- Keeps updated_at current on every update.
create function private.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;
