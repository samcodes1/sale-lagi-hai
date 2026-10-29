-- Schema-wide rules that every table must follow.
begin;
select plan(9);

select tables_are('public', array[
  'cities', 'areas', 'categories', 'banks', 'card_products',
  'profiles', 'user_roles', 'businesses', 'business_members', 'brands', 'outlets',
  'deals', 'deal_targets', 'card_offers',
  'follows', 'saves', 'user_cards', 'alert_prefs', 'notifications',
  'reports', 'submissions', 'placements', 'payments', 'audit_log'
], 'public has exactly the planned tables');

select is_empty($$
  select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity
$$, 'RLS is enabled on every public table');

select is_empty($$
  select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
    and not exists (select 1 from pg_constraint k where k.conrelid = c.oid and k.contype = 'p')
$$, 'every public table has a primary key');

-- Unindexed foreign keys make cascades and RLS joins slow.
select is_empty($$
  select format('%s(%s)', k.conrelid::regclass, k.conkey)
  from pg_constraint k join pg_namespace n on n.oid = k.connamespace
  where k.contype = 'f' and n.nspname = 'public'
    and not exists (
      select 1 from pg_index i
      where i.indrelid = k.conrelid
        and (i.indkey::int2[])[0:cardinality(k.conkey) - 1] @> k.conkey
        and (i.indkey::int2[])[0:cardinality(k.conkey) - 1] <@ k.conkey
    )
$$, 'every foreign key has an index that starts with its columns');

select is_empty($$
  select c.table_name from information_schema.columns c
  where c.table_schema = 'public' and c.column_name = 'updated_at'
    and not exists (
      select 1 from information_schema.triggers t
      where t.event_object_schema = 'public' and t.event_object_table = c.table_name
        and t.action_statement like '%touch_updated_at%')
$$, 'every updated_at column has its touch trigger');

select is_empty($$
  select table_name || '.' || column_name from information_schema.columns
  where table_schema = 'public' and data_type in ('json', 'timestamp without time zone',
                                                   'character varying', 'money')
$$, 'no json, timestamp without time zone, varchar or money columns');

-- Until the RLS migration grants access, the API roles see nothing.
select is_empty($$
  select table_name || ':' || grantee || ':' || privilege_type
  from information_schema.role_table_grants
  where table_schema = 'public' and grantee in ('anon', 'authenticated')
$$, 'anon and authenticated have no table grants yet');

select is_empty($$
  select p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private' and p.prosecdef
    and (has_function_privilege('anon', p.oid, 'execute')
         or has_function_privilege('authenticated', p.oid, 'execute'))
$$, 'no private security definer function is executable by the API roles yet');

-- The app's DealOffer mirrors this enum.
select enum_has_labels('public', 'offer_kind', array[
  'percent_off', 'up_to_percent_off', 'flat_percent_off', 'amount_off', 'fixed_price', 'text'
], 'offer_kind matches the app''s DealOffer kinds');

select * from finish();
rollback;
