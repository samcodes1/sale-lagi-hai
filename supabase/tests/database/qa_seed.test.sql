-- QA (sub-phase 2.6): the "no fake offers by real brands" rule and
-- re-running the seed on a long-lived dev database. TODO assertions are S4
-- findings in docs/qa/2.6.md.
begin;
select plan(7);

\ir ../../seed.sql

select is((select count(*) from public.deals d join public.brands b on b.id = d.brand_id
           where b.name not like '%(Demo)'), 0::bigint,
  'every seeded deal belongs to a brand marked (Demo)');
select is((select count(*) from public.brands where slug like 'demo-%' and (name not like '%(Demo)'
           or name_ur not like '%(ڈیمو)')), 0::bigint,
  'every demo brand is marked in English and Urdu');
select is((select count(*) from public.deals d where d.status = 'published'
           and not private.is_live(d.status, d.starts_at, d.ends_at)), 0::bigint,
  'every published demo deal is live right after seeding');
select is((select count(*) from public.deals d where d.offer_kind = 'percent_off'
           and d.price_pkr is not null and d.original_price_pkr is not null
           and d.percent <> ((d.original_price_pkr - d.price_pkr) * 100) / d.original_price_pkr), 0::bigint,
  'demo percentages match their prices');
select is((select count(*) from public.brands b where b.slug not like 'demo-%' and b.is_verified), 0::bigint,
  'no real brand is seeded as verified');

-- ---------------------------------------------------------------------------
-- S4 findings (TODO).
-- ---------------------------------------------------------------------------
select todo('QA 2.6-D1 (S4): the demo card offer is an offer on real HBL cards (the HBL chip shows no demo label)', 1);
select is((select count(*) from public.card_offers co join public.banks bk on bk.id = co.bank_id
           join public.deals d on d.id = co.deal_id where d.title_en like '%(demo)%'
           and bk.slug in ('hbl', 'meezan-bank', 'ubl', 'mcb', 'bank-alfalah', 'standard-chartered',
                           'allied-bank', 'bank-al-habib', 'faysal-bank', 'js-bank', 'askari-bank',
                           'habib-metro', 'national-bank', 'dubai-islamic-bank')), 0::bigint,
  'demo card offers use a fictional demo bank');

select todo('QA 2.6-D2 (S4): re-seeding a dev database after the demo deals expired leaves them expired', 1);
update public.deals set status = 'expired', ends_at = now() - interval '1 minute', starts_at = now() - interval '2 days'
  where title_en = 'Winter collection sale';
\ir ../../seed.sql
select is((select status::text from public.deals where title_en = 'Winter collection sale'), 'published',
  're-running the seed brings an expired demo deal back');

select * from finish();
rollback;
