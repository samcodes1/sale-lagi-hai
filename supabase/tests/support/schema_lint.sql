-- Schema-wide security lint. Run AFTER all migrations; every query must return zero rows.
-- Raises an exception (non-zero psql exit with ON_ERROR_STOP) listing offenders.
-- Exposed schemas default to 'public'; set qa.exposed_schemas to e.g. 'public,api' to change.

do $$
declare
  exposed text[] := string_to_array(coalesce(nullif(current_setting('qa.exposed_schemas', true), ''), 'public'), ',');
  offenders text;
begin
  -- 1. Every table / partitioned table in an exposed schema has RLS enabled.
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ') into offenders
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = any(exposed) and c.relkind in ('r', 'p') and not c.relrowsecurity;
  if offenders is not null then raise exception 'RLS disabled on: %', offenders; end if;
  raise notice 'ok - RLS enabled on every table in %', exposed;

  -- 2. RLS-enabled tables in exposed schemas have at least one policy (otherwise they are dead or misconfigured).
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ') into offenders
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = any(exposed) and c.relkind in ('r', 'p') and c.relrowsecurity
    and not exists (select 1 from pg_policy p where p.polrelid = c.oid);
  if offenders is not null then raise notice 'WARN - RLS on but no policies (deny-all) on: %', offenders; end if;

  -- 3. No SECURITY DEFINER function without a pinned search_path.
  select string_agg(format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)), ', ') into offenders
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where p.prosecdef
    and n.nspname not in ('pg_catalog', 'information_schema', 'auth', 'storage', 'extensions', 'qa')
    and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg where cfg like 'search_path=%');
  if offenders is not null then raise exception 'SECURITY DEFINER without search_path: %', offenders; end if;
  raise notice 'ok - every security definer function pins search_path';

  -- 4. No SECURITY DEFINER function in an exposed schema that anon can execute
  --    (callable over the Data API with the owner's privileges).
  select string_agg(format('%I.%I', n.nspname, p.proname), ', ') into offenders
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where p.prosecdef and n.nspname = any(exposed)
    and has_function_privilege('anon', p.oid, 'execute');
  if offenders is not null then
    raise exception 'SECURITY DEFINER functions executable by anon in exposed schema: % (move to private or revoke execute)', offenders;
  end if;
  raise notice 'ok - no anon-executable security definer functions in exposed schemas';

  -- 5. anon holds no write privileges on exposed tables (adjust if a table is intentionally anon-writable).
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ') into offenders
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = any(exposed) and c.relkind in ('r', 'p')
    and has_table_privilege('anon', c.oid, 'insert,update,delete,truncate');
  if offenders is not null then raise exception 'anon has write grants on: %', offenders; end if;
  raise notice 'ok - anon has no write grants';

  -- 6. Views in exposed schemas run as the invoker (Postgres 15+), otherwise they bypass RLS.
  select string_agg(format('%I.%I', n.nspname, c.relname), ', ') into offenders
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = any(exposed) and c.relkind = 'v'
    and not coalesce('security_invoker=true' = any(c.reloptions) or 'security_invoker=on' = any(c.reloptions), false);
  if offenders is not null then raise exception 'views without security_invoker: %', offenders; end if;
  raise notice 'ok - all exposed views use security_invoker';

  -- 7. No policy relies on user_metadata (user-editable).
  select string_agg(format('%I on %s', p.polname, p.polrelid::regclass), ', ') into offenders
  from pg_policy p
  where pg_get_expr(p.polqual, p.polrelid) ilike '%user_metadata%'
     or pg_get_expr(p.polwithcheck, p.polrelid) ilike '%user_metadata%';
  if offenders is not null then raise exception 'policies reference user_metadata: %', offenders; end if;
  raise notice 'ok - no policy uses user_metadata';
end $$;
