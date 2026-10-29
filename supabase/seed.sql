-- Development seed: demo brands, outlets and deals in Karachi, loaded by
-- `supabase db reset` on local and dev projects only (never production).
--
-- Every brand here is fictional and marked "(Demo)", so no real business is
-- shown with an offer it didn't make. IDs are derived from fixed names, so
-- the seed can run any number of times. It runs statement by statement
-- (autocommit), so local deals are published after their targets exist.

-- Brands
insert into public.brands (slug, name, name_ur, category_id, is_verified)
select b.slug, b.name, b.name_ur, c.id, true
from (values
  ('demo-karahi-house', 'Karahi House (Demo)', 'کڑاہی ہاؤس (ڈیمو)', 'bbq-and-karahi'),
  ('demo-burger-point', 'Burger Point (Demo)', 'برگر پوائنٹ (ڈیمو)', 'fast-food'),
  ('demo-chai-adda', 'Chai Adda (Demo)', 'چائے اڈا (ڈیمو)', 'cafes-and-desserts'),
  ('demo-threads', 'Threads (Demo)', 'تھریڈز (ڈیمو)', 'womens-wear'),
  ('demo-glow-salon', 'Glow Salon (Demo)', 'گلو سیلون (ڈیمو)', 'beauty-and-salons')
) as b(slug, name, name_ur, category)
join public.categories c on c.slug = b.category
on conflict (slug) do update set name = excluded.name, name_ur = excluded.name_ur,
  category_id = excluded.category_id;

-- Outlets
insert into public.outlets (id, brand_id, city_id, area_id, name, address, location)
select md5('slh-demo-outlet-' || o.key)::uuid, b.id, c.id, a.id, o.name, o.address,
       o.location::extensions.geography
from (values
  ('1', 'demo-karahi-house', 'clifton', 'Karahi House Clifton', 'Block 4, Clifton, Karachi', 'SRID=4326;POINT(67.0310 24.8150)'),
  ('2', 'demo-karahi-house', 'gulshan-e-iqbal', 'Karahi House Gulshan', 'Block 13-D, Gulshan-e-Iqbal, Karachi', 'SRID=4326;POINT(67.0920 24.9210)'),
  ('3', 'demo-burger-point', 'dha', 'Burger Point DHA', 'Khayaban-e-Ittehad, DHA Phase 6, Karachi', 'SRID=4326;POINT(67.0660 24.8040)'),
  ('4', 'demo-chai-adda', 'saddar', 'Chai Adda Saddar', 'Abdullah Haroon Road, Saddar, Karachi', 'SRID=4326;POINT(67.0250 24.8560)'),
  ('5', 'demo-threads', 'tariq-road', 'Threads Tariq Road', 'Tariq Road, PECHS, Karachi', 'SRID=4326;POINT(67.0600 24.8725)'),
  ('6', 'demo-glow-salon', 'bahadurabad', 'Glow Salon Bahadurabad', 'Bahadurabad Chowrangi, Karachi', 'SRID=4326;POINT(67.0705 24.8822)')
) as o(key, brand, area, name, address, location)
join public.brands b on b.slug = o.brand
join public.cities c on c.slug = 'karachi'
join public.areas a on a.city_id = c.id and a.slug = o.area
on conflict (id) do update set name = excluded.name, address = excluded.address,
  location = excluded.location;

-- Deals: one of each offer kind, nationwide and local. Local ones start as
-- drafts and are published below, once their targets exist.
insert into public.deals (id, brand_id, category_id, kind, scope, status, source, title_en, title_ur,
                          offer_kind, percent, amount_off_pkr, price_pkr, original_price_pkr,
                          offer_text_en, offer_text_ur, url, starts_at, ends_at, verified_at)
select md5('slh-demo-deal-' || d.key)::uuid, b.id, b.category_id, d.kind::public.deal_kind,
       d.scope::public.deal_scope, d.status::public.deal_status, 'staff', d.title_en, d.title_ur,
       d.offer::public.offer_kind, d.percent, d.amount_off, d.price, d.original,
       d.text_en, d.text_ur, d.url, now() - interval '1 day', now() + (d.days || ' days')::interval,
       now() - interval '2 hours'
from (values
  ('1', 'demo-karahi-house', 'food_deal', 'local', 'draft', 'Family karahi for 4', 'چار افراد کی فیملی کڑاہی',
   'fixed_price', null::smallint, null::int, 2499, 3299, null, null, null::text, '6'),
  ('2', 'demo-burger-point', 'food_deal', 'local', 'draft', 'Two smash burgers for Rs 999', 'دو اسمیش برگر 999 روپے میں',
   'text', null, null, 999, null, '2 for Rs 999', '999 روپے میں دو', null, '2'),
  ('3', 'demo-chai-adda', 'food_deal', 'local', 'draft', 'Chai and paratha breakfast', 'چائے پراٹھا ناشتہ',
   'amount_off', null, 150, null, null, null, null, null, '10'),
  ('4', 'demo-threads', 'brand_sale', 'nationwide', 'published', 'Winter collection sale', 'سردیوں کی کلیکشن سیل',
   'up_to_percent_off', 50, null, null, null, null, null, null, '14'),
  ('5', 'demo-threads', 'brand_sale', 'online', 'published', 'Online exclusive: flat 30% off', 'آن لائن خصوصی: فلیٹ 30% رعایت',
   'flat_percent_off', 30, null, null, null, null, null, 'https://example.com/demo-threads', '5'),
  ('6', 'demo-glow-salon', 'service_deal', 'local', 'draft', 'Hair cut and blow dry', 'ہیئر کٹ اور بلو ڈرائی',
   'percent_off', 25, null, 1800, 2400, null, null, null, '20'),
  ('7', 'demo-karahi-house', 'card_offer', 'local', 'draft', '20% off with HBL credit cards (demo)', 'ایچ بی ایل کریڈٹ کارڈ پر 20% رعایت (ڈیمو)',
   'percent_off', 20, null, null, null, null, null, null, '30')
) as d(key, brand, kind, scope, status, title_en, title_ur, offer, percent, amount_off, price, original,
       text_en, text_ur, url, days)
join public.brands b on b.slug = d.brand
on conflict (id) do update set
  title_en = excluded.title_en, title_ur = excluded.title_ur,
  ends_at = excluded.ends_at, verified_at = excluded.verified_at;

insert into public.deal_targets (deal_id, city_id, area_id)
select md5('slh-demo-deal-' || t.key)::uuid, c.id, a.id
from (values ('1', null), ('2', 'dha'), ('3', 'saddar'), ('6', null), ('7', 'clifton')) as t(key, area)
join public.cities c on c.slug = 'karachi'
left join public.areas a on a.city_id = c.id and a.slug = t.area
on conflict do nothing;

insert into public.card_offers (deal_id, bank_id, card_kind, max_discount_pkr)
select md5('slh-demo-deal-7')::uuid, b.id, 'credit', 1500
from public.banks b where b.slug = 'hbl'
on conflict do nothing;

update public.deals set status = 'published'
where id in (select md5('slh-demo-deal-' || k)::uuid from unnest(array['1', '2', '3', '6', '7']) k)
  and status = 'draft';
