-- Schema-wide rules that every table must follow.
begin;
select plan(9);

select tables_are('public', array[
  'cities', 'areas', 'categories', 'banks', 'card_products',
  'profiles', 'user_roles', 'businesses', 'business_members', 'brands', 'outlets',
  'deals', 'deal_targets', 'card_offers',
  'follows', 'saves', 'user_cards', 'alert_prefs', 'notifications',
  'reports', 'submissions', 'placements', 'payments', 'audit_log', 'push_tokens',
  'ingest_sources', 'ingest_runs'
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

-- anon reads public content only, and writes nothing.
select set_eq($$
  select table_name::text from information_schema.role_table_grants
  where table_schema = 'public' and grantee = 'anon'
$$, array['cities', 'areas', 'categories', 'banks', 'card_products', 'brands', 'outlets',
          'deals', 'deal_targets', 'card_offers', 'placements', 'deal_cards'],
'anon has grants on the public-content tables only');

-- The only private functions the API roles can call are the RLS helpers.
select set_eq($$
  select p.proname::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'private'
    and (has_function_privilege('anon', p.oid, 'execute')
         or has_function_privilege('authenticated', p.oid, 'execute'))
$$, array['has_role', 'mfa_verified', 'is_moderator', 'is_admin', 'my_business_ids',
          'my_owned_business_ids', 'my_brand_ids', 'is_trusted_caller',
          'is_live', 'shown_in_city', 'in_categories', 'page_size', 'follows_deal', 'recent_save_counts', 'search_hits', 'outlets_near',
          'is_image_name', 'can_write_media', 'my_recent_uploads'],
'only the RLS and query helpers in private are callable by the API roles');

-- The app's DealOffer mirrors this enum.
select enum_has_labels('public', 'offer_kind', array[
  'percent_off', 'up_to_percent_off', 'flat_percent_off', 'amount_off', 'fixed_price', 'text'
], 'offer_kind matches the app''s DealOffer kinds');

select * from finish();
rollback;
