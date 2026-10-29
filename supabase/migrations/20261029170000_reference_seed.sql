-- Reference data (sub-phase 2.6): cities and areas, categories, banks and
-- card products, and the top brands ingestion will track. Production needs
-- these, so they live in a migration. Every insert is an upsert on the
-- natural key, so re-running is safe. Demo deals for development are in
-- supabase/seed.sql.
--
-- To check before launch (docs/backend/SEED.md): the card catalogue (each
-- bank's actual networks and credit products) and area boundaries.

-- ---------------------------------------------------------------------------
-- Cities: Karachi is live first; the others go live city by city.
-- ---------------------------------------------------------------------------
insert into public.cities (slug, name_en, name_ur, province, is_live, center, sort_order) values
  ('karachi', 'Karachi', 'کراچی', 'sindh', true, 'SRID=4326;POINT(67.0011 24.8607)', 1),
  ('lahore', 'Lahore', 'لاہور', 'punjab', false, 'SRID=4326;POINT(74.3587 31.5204)', 2),
  ('islamabad', 'Islamabad', 'اسلام آباد', 'islamabad', false, 'SRID=4326;POINT(73.0479 33.6844)', 3),
  ('rawalpindi', 'Rawalpindi', 'راولپنڈی', 'punjab', false, 'SRID=4326;POINT(73.0169 33.5651)', 4),
  ('faisalabad', 'Faisalabad', 'فیصل آباد', 'punjab', false, 'SRID=4326;POINT(73.1350 31.4504)', 5),
  ('multan', 'Multan', 'ملتان', 'punjab', false, 'SRID=4326;POINT(71.5249 30.1575)', 6),
  ('peshawar', 'Peshawar', 'پشاور', 'khyber_pakhtunkhwa', false, 'SRID=4326;POINT(71.5785 34.0151)', 7),
  ('quetta', 'Quetta', 'کوئٹہ', 'balochistan', false, 'SRID=4326;POINT(66.9750 30.1798)', 8),
  ('hyderabad', 'Hyderabad', 'حیدرآباد', 'sindh', false, 'SRID=4326;POINT(68.3578 25.3960)', 9),
  ('sialkot', 'Sialkot', 'سیالکوٹ', 'punjab', false, 'SRID=4326;POINT(74.5229 32.4945)', 10),
  ('gujranwala', 'Gujranwala', 'گوجرانوالہ', 'punjab', false, 'SRID=4326;POINT(74.1945 32.1877)', 11),
  ('abbottabad', 'Abbottabad', 'ایبٹ آباد', 'khyber_pakhtunkhwa', false, 'SRID=4326;POINT(73.2215 34.1688)', 12),
  ('sukkur', 'Sukkur', 'سکھر', 'sindh', false, 'SRID=4326;POINT(68.8574 27.7052)', 13),
  ('bahawalpur', 'Bahawalpur', 'بہاولپور', 'punjab', false, 'SRID=4326;POINT(71.6911 29.3544)', 14),
  ('gilgit', 'Gilgit', 'گلگت', 'gilgit_baltistan', false, 'SRID=4326;POINT(74.3089 35.9208)', 15),
  ('muzaffarabad', 'Muzaffarabad', 'مظفرآباد', 'azad_kashmir', false, 'SRID=4326;POINT(73.4711 34.3700)', 16)
on conflict (slug) do update set
  name_en = excluded.name_en, name_ur = excluded.name_ur, province = excluded.province,
  center = excluded.center, sort_order = excluded.sort_order;
-- (is_live is not overwritten: staff switch cities on in the console.)

-- ---------------------------------------------------------------------------
-- Areas (approximate centres and radii).
-- ---------------------------------------------------------------------------
insert into public.areas (city_id, slug, name_en, name_ur, center, radius_m)
select c.id, a.slug, a.name_en, a.name_ur, a.center::extensions.geography, a.radius_m
from (values
  ('karachi', 'clifton', 'Clifton', 'کلفٹن', 'SRID=4326;POINT(67.0300 24.8138)', 2500),
  ('karachi', 'dha', 'DHA', 'ڈیفنس', 'SRID=4326;POINT(67.0650 24.8050)', 4000),
  ('karachi', 'saddar', 'Saddar', 'صدر', 'SRID=4326;POINT(67.0241 24.8556)', 1500),
  ('karachi', 'pechs', 'PECHS', 'پی ای سی ایچ ایس', 'SRID=4326;POINT(67.0627 24.8727)', 1500),
  ('karachi', 'tariq-road', 'Tariq Road', 'طارق روڈ', 'SRID=4326;POINT(67.0599 24.8722)', 1000),
  ('karachi', 'bahadurabad', 'Bahadurabad', 'بہادرآباد', 'SRID=4326;POINT(67.0700 24.8820)', 1000),
  ('karachi', 'gulshan-e-iqbal', 'Gulshan-e-Iqbal', 'گلشنِ اقبال', 'SRID=4326;POINT(67.0914 24.9206)', 3000),
  ('karachi', 'gulistan-e-johar', 'Gulistan-e-Johar', 'گلستانِ جوہر', 'SRID=4326;POINT(67.1300 24.9180)', 3000),
  ('karachi', 'north-nazimabad', 'North Nazimabad', 'نارتھ ناظم آباد', 'SRID=4326;POINT(67.0436 24.9425)', 2500),
  ('karachi', 'nazimabad', 'Nazimabad', 'ناظم آباد', 'SRID=4326;POINT(67.0300 24.9100)', 1500),
  ('karachi', 'federal-b-area', 'Federal B Area', 'فیڈرل بی ایریا', 'SRID=4326;POINT(67.0750 24.9300)', 2500),
  ('karachi', 'korangi', 'Korangi', 'کورنگی', 'SRID=4326;POINT(67.1290 24.8318)', 3000),
  ('karachi', 'malir', 'Malir', 'ملیر', 'SRID=4326;POINT(67.2050 24.8930)', 4000),
  ('karachi', 'bahria-town', 'Bahria Town', 'بحریہ ٹاؤن', 'SRID=4326;POINT(67.3000 25.0100)', 5000),
  ('lahore', 'gulberg', 'Gulberg', 'گلبرگ', 'SRID=4326;POINT(74.3436 31.5160)', 2500),
  ('lahore', 'dha', 'DHA', 'ڈیفنس', 'SRID=4326;POINT(74.4086 31.4715)', 4000),
  ('lahore', 'johar-town', 'Johar Town', 'جوہر ٹاؤن', 'SRID=4326;POINT(74.2728 31.4697)', 2500),
  ('lahore', 'model-town', 'Model Town', 'ماڈل ٹاؤن', 'SRID=4326;POINT(74.3260 31.4834)', 2000),
  ('lahore', 'bahria-town', 'Bahria Town', 'بحریہ ٹاؤن', 'SRID=4326;POINT(74.1800 31.3700)', 4000),
  ('islamabad', 'f-7', 'F-7', 'ایف سیون', 'SRID=4326;POINT(73.0560 33.7200)', 1200),
  ('islamabad', 'blue-area', 'Blue Area', 'بلیو ایریا', 'SRID=4326;POINT(73.0600 33.7100)', 1500),
  ('islamabad', 'f-10', 'F-10', 'ایف ٹین', 'SRID=4326;POINT(73.0130 33.6950)', 1200)
) as a(city, slug, name_en, name_ur, center, radius_m)
join public.cities c on c.slug = a.city
on conflict (city_id, slug) do update set
  name_en = excluded.name_en, name_ur = excluded.name_ur,
  center = excluded.center, radius_m = excluded.radius_m;

-- ---------------------------------------------------------------------------
-- Categories (docs/DEVELOPMENT_PLAN.md §1) and a first set of
-- subcategories. Icons are Material Symbols names.
-- ---------------------------------------------------------------------------
insert into public.categories (slug, name_en, name_ur, icon, sort_order) values
  ('food-and-restaurants', 'Food & Restaurants', 'کھانا اور ریسٹورنٹ', 'restaurant', 1),
  ('fashion', 'Fashion', 'فیشن', 'checkroom', 2),
  ('bank-cards', 'Bank Cards', 'بینک کارڈز', 'credit_card', 3),
  ('groceries', 'Groceries', 'گروسری', 'shopping_cart', 4),
  ('beauty-and-salons', 'Beauty & Salons', 'بیوٹی اور سیلون', 'spa', 5),
  ('mobiles-and-electronics', 'Mobiles & Electronics', 'موبائل اور الیکٹرانکس', 'smartphone', 6),
  ('telecom-bundles', 'Telecom Bundles', 'ٹیلی کام بنڈلز', 'cell_tower', 7),
  ('online-promo-codes', 'Online Promo Codes', 'آن لائن پرومو کوڈز', 'confirmation_number', 8),
  ('health-and-fitness', 'Health & Fitness', 'صحت اور فٹنس', 'fitness_center', 9),
  ('events-and-cinema', 'Events & Cinema', 'ایونٹس اور سنیما', 'movie', 10),
  ('travel-and-hotels', 'Travel & Hotels', 'سفر اور ہوٹل', 'flight', 11),
  ('education', 'Education', 'تعلیم', 'school', 12),
  ('home-and-furniture', 'Home & Furniture', 'گھر اور فرنیچر', 'chair', 13)
on conflict (slug) do update set
  name_en = excluded.name_en, name_ur = excluded.name_ur, icon = excluded.icon,
  sort_order = excluded.sort_order;

insert into public.categories (slug, parent_id, name_en, name_ur, icon, sort_order)
select s.slug, p.id, s.name_en, s.name_ur, s.icon, s.sort_order
from (values
  ('food-and-restaurants', 'bbq-and-karahi', 'BBQ & Karahi', 'باربی کیو اور کڑاہی', 'outdoor_grill', 1),
  ('food-and-restaurants', 'fast-food', 'Burgers & Fast Food', 'برگر اور فاسٹ فوڈ', 'lunch_dining', 2),
  ('food-and-restaurants', 'pizza', 'Pizza', 'پیزا', 'local_pizza', 3),
  ('food-and-restaurants', 'biryani-and-desi', 'Biryani & Desi', 'بریانی اور دیسی', 'rice_bowl', 4),
  ('food-and-restaurants', 'cafes-and-desserts', 'Cafés & Desserts', 'کیفے اور میٹھا', 'local_cafe', 5),
  ('fashion', 'womens-wear', 'Women''s Wear', 'خواتین کے کپڑے', 'woman', 1),
  ('fashion', 'mens-wear', 'Men''s Wear', 'مردوں کے کپڑے', 'man', 2),
  ('fashion', 'kids-wear', 'Kids'' Wear', 'بچوں کے کپڑے', 'child_care', 3),
  ('fashion', 'shoes-and-bags', 'Shoes & Bags', 'جوتے اور بیگ', 'steps', 4)
) as s(parent, slug, name_en, name_ur, icon, sort_order)
join public.categories p on p.slug = s.parent
on conflict (slug) do update set
  parent_id = excluded.parent_id, name_en = excluded.name_en, name_ur = excluded.name_ur,
  icon = excluded.icon, sort_order = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- Banks and card products. Products are generic per network and kind; the
-- exact range per bank is verified by staff before launch.
-- ---------------------------------------------------------------------------
insert into public.banks (slug, name_en, name_ur, short_name, website) values
  ('hbl', 'HBL', 'ایچ بی ایل', 'HBL', 'https://www.hbl.com'),
  ('meezan-bank', 'Meezan Bank', 'میزان بینک', 'Meezan', 'https://www.meezanbank.com'),
  ('ubl', 'UBL', 'یو بی ایل', 'UBL', 'https://www.ubldigital.com'),
  ('mcb', 'MCB Bank', 'ایم سی بی بینک', 'MCB', 'https://www.mcb.com.pk'),
  ('bank-alfalah', 'Bank Alfalah', 'بینک الفلاح', 'Alfalah', 'https://www.bankalfalah.com'),
  ('standard-chartered', 'Standard Chartered', 'اسٹینڈرڈ چارٹرڈ', 'SCB', 'https://www.sc.com/pk'),
  ('allied-bank', 'Allied Bank', 'الائیڈ بینک', 'ABL', 'https://www.abl.com'),
  ('bank-al-habib', 'Bank AL Habib', 'بینک الحبیب', 'BAHL', 'https://www.bankalhabib.com'),
  ('faysal-bank', 'Faysal Bank', 'فیصل بینک', 'Faysal', 'https://www.faysalbank.com'),
  ('js-bank', 'JS Bank', 'جے ایس بینک', 'JS Bank', 'https://www.jsbl.com'),
  ('askari-bank', 'Askari Bank', 'عسکری بینک', 'Askari', 'https://www.askaribank.com'),
  ('habib-metro', 'HabibMetro', 'حبیب میٹرو', 'HabibMetro', 'https://www.habibmetro.com'),
  ('national-bank', 'National Bank of Pakistan', 'نیشنل بینک آف پاکستان', 'NBP', 'https://www.nbp.com.pk'),
  ('dubai-islamic-bank', 'Dubai Islamic Bank', 'دبئی اسلامک بینک', 'DIB', 'https://www.dibpak.com')
on conflict (slug) do update set
  name_en = excluded.name_en, name_ur = excluded.name_ur, short_name = excluded.short_name,
  website = excluded.website;

-- Every bank: Visa and PayPak debit. Conventional banks with credit cards:
-- Visa credit.
insert into public.card_products (bank_id, slug, name, network, kind)
select b.id, p.slug, p.name, p.network::public.card_network, p.kind::public.card_kind
from public.banks b
cross join (values
  ('visa-debit', 'Visa Debit', 'visa', 'debit'),
  ('paypak-debit', 'PayPak Debit', 'paypak', 'debit')
) as p(slug, name, network, kind)
where b.slug in ('hbl', 'meezan-bank', 'ubl', 'mcb', 'bank-alfalah', 'standard-chartered',
                 'allied-bank', 'bank-al-habib', 'faysal-bank', 'js-bank', 'askari-bank',
                 'habib-metro', 'national-bank', 'dubai-islamic-bank')
union all
select b.id, 'visa-credit', 'Visa Credit', 'visa', 'credit'
from public.banks b
where b.slug in ('hbl', 'ubl', 'mcb', 'bank-alfalah', 'standard-chartered', 'bank-al-habib',
                 'js-bank', 'askari-bank')
on conflict (bank_id, slug) do update set
  name = excluded.name, network = excluded.network, kind = excluded.kind;

-- ---------------------------------------------------------------------------
-- Top brands that ingestion tracks (Phase 3). No logos or claims: staff
-- verify each brand, and a business can claim it later.
-- ---------------------------------------------------------------------------
insert into public.brands (slug, name, name_ur, category_id, website, bank_id)
select b.slug, b.name, b.name_ur, c.id, b.website, bk.id
from (values
  ('khaadi', 'Khaadi', 'کھادی', 'fashion', 'https://pk.khaadi.com', null),
  ('sapphire', 'Sapphire', 'سفائر', 'fashion', 'https://pk.sapphireonline.pk', null),
  ('gul-ahmed', 'Gul Ahmed', 'گل احمد', 'fashion', 'https://www.gulahmedshop.com', null),
  ('junaid-jamshed', 'J.', 'جے', 'fashion', 'https://www.junaidjamshed.com', null),
  ('alkaram', 'Alkaram Studio', 'الکرم اسٹوڈیو', 'fashion', 'https://www.alkaramstudio.com', null),
  ('outfitters', 'Outfitters', 'آؤٹ فٹرز', 'fashion', 'https://outfitters.com.pk', null),
  ('bonanza-satrangi', 'Bonanza Satrangi', 'بونانزا سترنگی', 'fashion', 'https://bonanzasatrangi.com', null),
  ('jazz', 'Jazz', 'جاز', 'telecom-bundles', 'https://jazz.com.pk', null),
  ('zong', 'Zong', 'زونگ', 'telecom-bundles', 'https://www.zong.com.pk', null),
  ('telenor', 'Telenor', 'ٹیلی نار', 'telecom-bundles', 'https://www.telenor.com.pk', null),
  ('ufone', 'Ufone', 'یوفون', 'telecom-bundles', 'https://www.ufone.com', null),
  ('daraz', 'Daraz', 'دراز', 'online-promo-codes', 'https://www.daraz.pk', null),
  ('foodpanda', 'foodpanda', 'فوڈ پانڈا', 'online-promo-codes', 'https://www.foodpanda.pk', null),
  ('hbl', 'HBL', 'ایچ بی ایل', 'bank-cards', 'https://www.hbl.com', 'hbl'),
  ('meezan-bank', 'Meezan Bank', 'میزان بینک', 'bank-cards', 'https://www.meezanbank.com', 'meezan-bank'),
  ('ubl', 'UBL', 'یو بی ایل', 'bank-cards', 'https://www.ubldigital.com', 'ubl'),
  ('bank-alfalah', 'Bank Alfalah', 'بینک الفلاح', 'bank-cards', 'https://www.bankalfalah.com', 'bank-alfalah')
) as b(slug, name, name_ur, category, website, bank)
join public.categories c on c.slug = b.category
left join public.banks bk on bk.slug = b.bank
on conflict (slug) do update set
  name = excluded.name, name_ur = excluded.name_ur, category_id = excluded.category_id,
  website = excluded.website, bank_id = excluded.bank_id;
