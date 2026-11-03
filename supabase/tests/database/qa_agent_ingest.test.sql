-- Agent ingestion (the daily Claude run): per-deal brands, new brands added
-- unverified, Urdu text, and agent sources kept out of the cron runner.
begin;
select plan(14);

create temp table s as select
  tests.make_brand(slug => 'test-agent-bank') as brand,
  tests.make_brand(slug => 'test-agent-cafe') as cafe,
  tests.make_category('test-agent-food') as category,
  tests.make_bank('test-agent-hbl') as bank;
insert into public.ingest_sources (slug, kind, brand_id, base_url, enabled, review_mode, config) values
  ('agent-bank', 'agent', (select brand from s), 'https://bank.example.pk', true, 'auto', '{"deal_kind": "food_deal"}'),
  ('agent-off', 'agent', (select brand from s), 'https://off.example.pk', false, 'auto', '{}'),
  ('shop-src', 'shopify', (select brand from s), 'https://shop.example.pk', true, 'auto', '{}');
create function pg_temp.src(slug text) returns uuid language sql as $$
  select id from public.ingest_sources where ingest_sources.slug = src.slug;
$$;
create function pg_temp.deal(fp_char text, extra jsonb default '{}') returns jsonb language sql as $$
  select jsonb_build_object(
    'fingerprint', repeat(fp_char, 64), 'externalId', 'o-' || fp_char,
    'title', 'Cafe: 20% off with cards', 'url', 'https://bank.example.pk/offers',
    'offer', jsonb_build_object('kind', 'percent_off', 'percent', 20)) || extra;
$$;

-- Listing and finding agent sources
select is((select array_agg(slug::text) from private.ingest_agent_sources()), array['agent-bank'],
  'only enabled agent sources are listed');
select is((select count(*)::int from private.ingest_agent_source('shop-src')), 0,
  'a non-agent source is not an agent source');
select ok(not exists (select 1 from private.ingest_due_sources(50) where kind::text = 'agent'),
  'the cron runner never picks agent sources');
select ok(exists (select 1 from private.ingest_due_sources(50) where slug = 'shop-src'),
  'but still picks the others');

-- New brands
select ok(private.ingest_ensure_brand(pg_temp.src('agent-bank'), 'test-agent-new', 'New Cafe', 'نیا کیفے',
  'test-agent-food') is not null, 'an agent source adds a new brand');
select is((select is_verified from public.brands where slug = 'test-agent-new'), false,
  'unverified, for staff to check');
select is(private.ingest_ensure_brand(pg_temp.src('agent-bank'), 'test-agent-cafe', 'Renamed', null,
  'test-agent-food'), (select cafe from s), 'an existing brand is returned unchanged');
select is((select name::text from public.brands where slug = 'test-agent-cafe'), 'Kolachi',
  'and never renamed');
select throws_ok($$ select private.ingest_ensure_brand(pg_temp.src('shop-src'), 'test-agent-x', 'X', null,
  'test-agent-food') $$, '22023', null, 'only agent sources add brands');
select throws_ok($$ select private.ingest_ensure_brand(pg_temp.src('agent-bank'), 'test-agent-y', 'Y', null,
  'no-such-category') $$, '22023', null, 'the category must exist');

-- Deals naming their merchant, with Urdu
select is(private.ingest_upsert_deal(pg_temp.src('agent-bank'), pg_temp.deal('a', jsonb_build_object(
  'brand', 'test-agent-cafe', 'titleUr', 'کیفے: کارڈز پر 20٪ رعایت',
  'cards', jsonb_build_array(jsonb_build_object('bank', 'test-agent-hbl', 'kind', 'credit'))))),
  'created', 'a deal for another merchant is created');
select is((select b.slug || '/' || d.kind || '/' || d.title_ur from public.deals d
           join public.brands b on b.id = d.brand_id where d.fingerprint = repeat('a', 64)),
  'test-agent-cafe/card_offer/کیفے: کارڈز پر 20٪ رعایت',
  'under that merchant, as a card offer, with its Urdu title');
select throws_ok($$ select private.ingest_upsert_deal(pg_temp.src('agent-bank'),
  pg_temp.deal('b', '{"brand": "no-such-brand"}')) $$, '22023', null, 'an unknown merchant is rejected');
select private.ingest_upsert_deal(pg_temp.src('agent-bank'), pg_temp.deal('c'));
select is((select b.slug || '/' || d.kind from public.deals d
           join public.brands b on b.id = d.brand_id where d.fingerprint = repeat('c', 64)),
  'test-agent-bank/food_deal', 'without a brand: the source''s own brand and deal kind');

select * from finish();
rollback;
