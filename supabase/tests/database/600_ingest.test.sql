-- Ingestion: upserts by fingerprint, review modes, ending and returning
-- deals, cards and cities, run logs, and who can see sources.
begin;
select plan(24);

create temp table w as select * from tests.make_world();
grant select on w to authenticated;
create temp table s as select
  tests.make_brand(slug => 'test-shop') as brand,
  tests.make_city('test-ingest-city') as city,
  tests.make_bank('test-ingest-bank') as bank;
insert into public.ingest_sources (slug, kind, brand_id, base_url, enabled, review_mode) values
  ('auto-shop', 'shopify', (select brand from s), 'https://shop.example.pk', true, 'auto'),
  ('review-shop', 'shopify', (select brand from s), 'https://review.example.pk', true, 'review'),
  ('off-shop', 'shopify', (select brand from s), 'https://off.example.pk', false, 'auto');
create function pg_temp.src(slug text) returns uuid language sql as $$
  select id from public.ingest_sources where ingest_sources.slug = src.slug;
$$;
create function pg_temp.deal(fp_char text, extra jsonb default '{}') returns jsonb language sql as $$
  select jsonb_build_object(
    'fingerprint', repeat(fp_char, 64), 'externalId', 'p-' || fp_char, 'title', 'Winter sale',
    'url', 'https://shop.example.pk/sale',
    'offer', jsonb_build_object('kind', 'up_to_percent_off', 'percent', 50),
    'endsAt', (now() + interval '7 days')::text) || extra;
$$;
create function pg_temp.status(fp_char text) returns text language sql as $$
  select status::text from public.deals where fingerprint = repeat(fp_char, 64);
$$;

select throws_ok($$ select private.ingest_upsert_deal(pg_temp.src('off-shop'), pg_temp.deal('0')) $$,
  '22023', null, 'disabled sources cannot write');
select is(private.ingest_upsert_deal(pg_temp.src('auto-shop'), pg_temp.deal('a')), 'created', 'a new deal is created');
select is(pg_temp.status('a'), 'published', 'auto sources publish straight away');
select ok((select verified_at > now() - interval '1 minute' and source = 'ingestion' from public.deals
           where fingerprint = repeat('a', 64)), 'marked verified now, from ingestion');
select is(private.ingest_upsert_deal(pg_temp.src('review-shop'), pg_temp.deal('b')), 'created', 'a review source creates too');
select is(pg_temp.status('b'), 'pending_review', 'but its deals wait for a moderator');

select is(private.ingest_upsert_deal(pg_temp.src('auto-shop'), pg_temp.deal('a')), 'unchanged', 'the same deal again: unchanged');
select is((select count(*)::int from public.deals where fingerprint = repeat('a', 64)), 1, 'never duplicated');
select is(private.ingest_upsert_deal(pg_temp.src('auto-shop'),
  pg_temp.deal('a', '{"title": "Winter sale extended", "offer": {"kind": "up_to_percent_off", "percent": 60}}')),
  'updated', 'a changed deal is updated');
select is((select percent from public.deals where fingerprint = repeat('a', 64)), 60::smallint, 'with the new offer');

-- Ending and returning
select private.ingest_upsert_deal(pg_temp.src('auto-shop'), pg_temp.deal('c'));
select is(private.ingest_end_missing(pg_temp.src('auto-shop'), array[repeat('a', 64)]), 1,
  'a deal the source stopped listing is ended');
select is(pg_temp.status('c'), 'expired', 'and expired');
select is(private.ingest_upsert_deal(pg_temp.src('auto-shop'), pg_temp.deal('c')), 'updated',
  'when it comes back it is updated');
select is(pg_temp.status('c'), 'published', 'and live again');
update public.deals set status = 'removed' where fingerprint = repeat('a', 64);
select is(private.ingest_upsert_deal(pg_temp.src('auto-shop'), pg_temp.deal('a')), 'unchanged',
  'a deal staff removed is left alone');
select is(pg_temp.status('a'), 'removed', 'and stays removed');

-- Cards and cities
select private.ingest_upsert_deal(pg_temp.src('auto-shop'),
  pg_temp.deal('d', '{"cards": [{"bank": "test-ingest-bank", "kind": "credit"}], "cities": ["test-ingest-city"]}'));
select results_eq($$ select kind::text, scope::text, status::text from public.deals where fingerprint = repeat('d', 64) $$,
  $$ values ('card_offer', 'local', 'published') $$, 'card offers with known banks, local with known cities');
select is((select count(*)::int from public.card_offers co join public.deals d on d.id = co.deal_id
           where d.fingerprint = repeat('d', 64) and co.card_kind = 'credit'), 1, 'the card offer row is written');
select private.ingest_upsert_deal(pg_temp.src('auto-shop'),
  pg_temp.deal('e', '{"cards": [{"bank": "no-such-bank"}], "cities": ["atlantis"]}'));
set constraints all immediate;
select results_eq($$ select kind::text, scope::text, status::text from public.deals where fingerprint = repeat('e', 64) $$,
  $$ values ('brand_sale', 'nationwide', 'published') $$, 'unknown banks and cities fall back to a plain deal');

-- The database still refuses a fake discount, whatever the runner sends.
select throws_ok($$ select private.ingest_upsert_deal(pg_temp.src('auto-shop'), pg_temp.deal('f',
  '{"offer": {"kind": "percent_off", "percent": 50, "pricePkr": 2999, "originalPricePkr": 4999}}')) $$,
  '23514', null, 'a fake percentage is rejected by the database too');

-- Run logs
create temp table r as select private.ingest_start_run(pg_temp.src('auto-shop')) as id;
select private.ingest_finish_run((select id from r), jsonb_build_object('status', 'partial', 'fetched', 3,
  'created', 1, 'updated', 1, 'ended', 0, 'rejected', 1,
  'errors', (select jsonb_agg(repeat('x', 400)) from generate_series(1, 80))));
select results_eq($$ select status, jsonb_array_length(errors), length(errors ->> 0) from public.ingest_runs where id = (select id from r) $$,
  $$ values ('partial', 50, 300) $$, 'run errors are capped at 50 messages of 300 characters');

-- Access
select tests.authenticate_as((select shopper from w));
select is((select count(*)::int from public.ingest_sources), 0, 'shoppers see no sources');
select throws_ok($$ select private.ingest_upsert_deal(gen_random_uuid(), '{}') $$, '42501', null,
  'and cannot write through ingestion');
select tests.staff((select moderator from w));
select is((select count(*)::int from public.ingest_sources), 3, 'staff see the sources');

select * from finish();
rollback;
