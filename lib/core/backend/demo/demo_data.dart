/// Demo data for builds without a backend (dev, tests, web QA): the
/// reference data of supabase/migrations/20261029170000_reference_seed.sql
/// in brief, and the fictional "(Demo)" brands and deals of
/// supabase/seed.sql. No real brand is shown with an offer.
library;

const karachiId = '00000000-0000-4000-a000-000000000001';
const lahoreId = '00000000-0000-4000-a000-000000000002';
const islamabadId = '00000000-0000-4000-a000-000000000003';

String _id(int prefix, int n) {
  final group = prefix.toString().padLeft(4, '0');
  return '00000000-0000-4000-$group-${n.toString().padLeft(12, '0')}';
}

final demoCities = <Map<String, Object?>>[
  {
    'id': karachiId,
    'slug': 'karachi',
    'name_en': 'Karachi',
    'name_ur': 'کراچی',
    'province': 'sindh',
    'is_live': true,
    'center_lat': 24.8607,
    'center_lng': 67.0011,
    'sort_order': 1,
  },
  {
    'id': lahoreId,
    'slug': 'lahore',
    'name_en': 'Lahore',
    'name_ur': 'لاہور',
    'province': 'punjab',
    'is_live': false,
    'center_lat': 31.5204,
    'center_lng': 74.3587,
    'sort_order': 2,
  },
  {
    'id': islamabadId,
    'slug': 'islamabad',
    'name_en': 'Islamabad',
    'name_ur': 'اسلام آباد',
    'province': 'islamabad',
    'is_live': false,
    'center_lat': 33.6844,
    'center_lng': 73.0479,
    'sort_order': 3,
  },
  {
    'id': _id(1, 4),
    'slug': 'rawalpindi',
    'name_en': 'Rawalpindi',
    'name_ur': 'راولپنڈی',
    'province': 'punjab',
    'is_live': false,
    'center_lat': 33.5651,
    'center_lng': 73.0169,
    'sort_order': 4,
  },
  {
    'id': _id(1, 5),
    'slug': 'faisalabad',
    'name_en': 'Faisalabad',
    'name_ur': 'فیصل آباد',
    'province': 'punjab',
    'is_live': false,
    'center_lat': 31.4504,
    'center_lng': 73.135,
    'sort_order': 5,
  },
  {
    'id': _id(1, 6),
    'slug': 'multan',
    'name_en': 'Multan',
    'name_ur': 'ملتان',
    'province': 'punjab',
    'is_live': false,
    'center_lat': 30.1575,
    'center_lng': 71.5249,
    'sort_order': 6,
  },
  {
    'id': _id(1, 7),
    'slug': 'peshawar',
    'name_en': 'Peshawar',
    'name_ur': 'پشاور',
    'province': 'khyber_pakhtunkhwa',
    'is_live': false,
    'center_lat': 34.0151,
    'center_lng': 71.5785,
    'sort_order': 7,
  },
  {
    'id': _id(1, 8),
    'slug': 'hyderabad',
    'name_en': 'Hyderabad',
    'name_ur': 'حیدرآباد',
    'province': 'sindh',
    'is_live': false,
    'center_lat': 25.396,
    'center_lng': 68.3578,
    'sort_order': 9,
  },
];

final demoAreas = <Map<String, Object?>>[
  for (final (n, slug, en, ur, lat, lng) in const [
    (1, 'clifton', 'Clifton', 'کلفٹن', 24.8138, 67.0300),
    (2, 'dha', 'DHA', 'ڈیفنس', 24.8050, 67.0650),
    (3, 'saddar', 'Saddar', 'صدر', 24.8556, 67.0241),
    (4, 'gulshan-e-iqbal', 'Gulshan-e-Iqbal', 'گلشنِ اقبال', 24.9206, 67.0914),
    (5, 'tariq-road', 'Tariq Road', 'طارق روڈ', 24.8722, 67.0599),
    (6, 'bahadurabad', 'Bahadurabad', 'بہادرآباد', 24.8820, 67.0700),
  ])
    {
      'id': _id(2, n),
      'city_id': karachiId,
      'slug': slug,
      'name_en': en,
      'name_ur': ur,
      'lat': lat,
      'lng': lng,
    },
];

final demoCategories = <Map<String, Object?>>[
  for (final (n, slug, en, ur, icon) in const [
    (
      1,
      'food-and-restaurants',
      'Food & Restaurants',
      'کھانا اور ریسٹورنٹ',
      'restaurant',
    ),
    (2, 'fashion', 'Fashion', 'فیشن', 'checkroom'),
    (3, 'bank-cards', 'Bank Cards', 'بینک کارڈز', 'credit_card'),
    (4, 'groceries', 'Groceries', 'گروسری', 'shopping_cart'),
    (5, 'beauty-and-salons', 'Beauty & Salons', 'بیوٹی اور سیلون', 'spa'),
    (
      6,
      'mobiles-and-electronics',
      'Mobiles & Electronics',
      'موبائل اور الیکٹرانکس',
      'smartphone',
    ),
    (7, 'telecom-bundles', 'Telecom Bundles', 'ٹیلی کام بنڈلز', 'cell_tower'),
    (
      8,
      'online-promo-codes',
      'Online Promo Codes',
      'آن لائن پرومو کوڈز',
      'confirmation_number',
    ),
    (
      9,
      'health-and-fitness',
      'Health & Fitness',
      'صحت اور فٹنس',
      'fitness_center',
    ),
    (10, 'events-and-cinema', 'Events & Cinema', 'ایونٹس اور سنیما', 'movie'),
    (11, 'travel-and-hotels', 'Travel & Hotels', 'سفر اور ہوٹل', 'flight'),
    (12, 'education', 'Education', 'تعلیم', 'school'),
    (13, 'home-and-furniture', 'Home & Furniture', 'گھر اور فرنیچر', 'chair'),
  ])
    {
      'id': _id(3, n),
      'slug': slug,
      'parent_id': null,
      'name_en': en,
      'name_ur': ur,
      'icon': icon,
      'sort_order': n,
      'is_active': true,
    },
  for (final (n, parent, slug, en, ur, icon) in const [
    (
      21,
      1,
      'bbq-and-karahi',
      'BBQ & Karahi',
      'باربی کیو اور کڑاہی',
      'outdoor_grill',
    ),
    (
      22,
      1,
      'fast-food',
      'Burgers & Fast Food',
      'برگر اور فاسٹ فوڈ',
      'lunch_dining',
    ),
    (
      23,
      1,
      'cafes-and-desserts',
      'Cafés & Desserts',
      'کیفے اور میٹھا',
      'local_cafe',
    ),
    (24, 2, 'womens-wear', "Women's Wear", 'خواتین کے کپڑے', 'woman'),
  ])
    {
      'id': _id(3, n),
      'slug': slug,
      'parent_id': _id(3, parent),
      'name_en': en,
      'name_ur': ur,
      'icon': icon,
      'sort_order': n,
      'is_active': true,
    },
];

String categoryId(String slug) =>
    demoCategories.firstWhere((c) => c['slug'] == slug)['id']! as String;

final demoBanks = <Map<String, Object?>>[
  for (final (n, slug, en, ur, short) in const [
    (1, 'hbl', 'HBL', 'ایچ بی ایل', 'HBL'),
    (2, 'meezan-bank', 'Meezan Bank', 'میزان بینک', 'Meezan'),
    (3, 'ubl', 'UBL', 'یو بی ایل', 'UBL'),
    (4, 'bank-alfalah', 'Bank Alfalah', 'بینک الفلاح', 'Alfalah'),
  ])
    {
      'id': _id(4, n),
      'slug': slug,
      'name_en': en,
      'name_ur': ur,
      'short_name': short,
      'is_active': true,
    },
];

final demoCardProducts = <Map<String, Object?>>[
  for (final bank in demoBanks)
    for (final (k, slug, name, network, kind) in const [
      (1, 'visa-debit', 'Visa Debit', 'visa', 'debit'),
      (2, 'paypak-debit', 'PayPak Debit', 'paypak', 'debit'),
      (3, 'visa-credit', 'Visa Credit', 'visa', 'credit'),
    ])
      if (!(bank['slug'] == 'meezan-bank' && kind == 'credit'))
        {
          'id': _productId(bank['id']! as String, k),
          'bank_id': bank['id'],
          'slug': slug,
          'name': name,
          'network': network,
          'kind': kind,
          'is_active': true,
        },
];

/// Unique per bank and product: the bank's own number, then the product's.
String _productId(String bankId, int k) =>
    '00000000-0000-4000-0005-'
    '${bankId.substring(30)}${k.toString().padLeft(6, '0')}';

final demoBrands = <Map<String, Object?>>[
  for (final (n, slug, name, ur, category) in const [
    (
      1,
      'demo-karahi-house',
      'Karahi House (Demo)',
      'کڑاہی ہاؤس (ڈیمو)',
      'bbq-and-karahi',
    ),
    (
      2,
      'demo-burger-point',
      'Burger Point (Demo)',
      'برگر پوائنٹ (ڈیمو)',
      'fast-food',
    ),
    (
      3,
      'demo-chai-adda',
      'Chai Adda (Demo)',
      'چائے اڈا (ڈیمو)',
      'cafes-and-desserts',
    ),
    (4, 'demo-threads', 'Threads (Demo)', 'تھریڈز (ڈیمو)', 'womens-wear'),
    (
      5,
      'demo-glow-salon',
      'Glow Salon (Demo)',
      'گلو سیلون (ڈیمو)',
      'beauty-and-salons',
    ),
    (
      6,
      'demo-dataplus',
      'DataPlus (Demo)',
      'ڈیٹا پلس (ڈیمو)',
      'telecom-bundles',
    ),
  ])
    {
      'id': _id(5, n),
      'slug': slug,
      'name': name,
      'name_ur': ur,
      'category_id': categoryId(category),
      'logo_path': null,
      'website': null,
      'is_verified': true,
      'is_active': true,
    },
];

Map<String, Object?> brandBySlug(String slug) =>
    demoBrands.firstWhere((b) => b['slug'] == slug);

/// Outlets: brand slug, area slug, lat, lng.
/// Sample sponsor banners, so Home shows what a sponsor would get.
final demoSponsorBanners = <Map<String, Object?>>[
  {
    'id': '00000000-0000-4000-b000-000000000001',
    'sponsor_name': 'Sample Sponsor',
    'title_en': 'Your brand here',
    'title_ur': 'یہاں آپ کا برانڈ',
    'subtitle_en': 'Reach shoppers the moment they look for a deal',
    'subtitle_ur': 'خریداروں تک اسی وقت پہنچیں جب وہ ڈیل ڈھونڈ رہے ہوں',
    'image_path': null,
    'link_url': null,
    'city_id': null,
    'sort_order': 1,
  },
  {
    'id': '00000000-0000-4000-b000-000000000002',
    'sponsor_name': 'Sample Sponsor',
    'title_en': 'A second sponsor slot',
    'title_ur': 'سپانسر کی دوسری جگہ',
    'subtitle_en': 'Target one city, or all of them',
    'subtitle_ur': 'ایک شہر چنیں یا سب شہر',
    'image_path': null,
    'link_url': null,
    'city_id': null,
    'sort_order': 2,
  },
];

const demoOutlets = [
  ('demo-karahi-house', 'clifton', 24.8150, 67.0310),
  ('demo-karahi-house', 'gulshan-e-iqbal', 24.9210, 67.0920),
  ('demo-burger-point', 'dha', 24.8040, 67.0660),
  ('demo-chai-adda', 'saddar', 24.8560, 67.0250),
  ('demo-threads', 'tariq-road', 24.8725, 67.0600),
  ('demo-glow-salon', 'bahadurabad', 24.8822, 67.0705),
];

/// A demo deal. Times are relative to the current time, so the demo never
/// goes stale.
final class DemoDeal {
  const new({
    required this.n,
    required this.brand,
    required this.titleEn,
    required this.titleUr,
    required this.offerKind,
    this.kind = 'brand_sale',
    this.scope = 'nationwide',
    this.percent,
    this.amountOff,
    this.price,
    this.originalPrice,
    this.offerTextEn,
    this.offerTextUr,
    this.endsInHours,
    this.publishedHoursAgo = 2,
    this.verifiedHoursAgo = 3,
    this.areas = const [],
    this.cardBank,
    this.url,
    this.promoCode,
  });

  final int n;
  final String brand;
  final String titleEn;
  final String titleUr;
  final String offerKind;
  final String kind;
  final String scope;
  final int? percent;
  final int? amountOff;
  final int? price;
  final int? originalPrice;
  final String? offerTextEn;
  final String? offerTextUr;
  final int? endsInHours;
  final int publishedHoursAgo;
  final int verifiedHoursAgo;

  /// Local deals: Karachi area slugs; empty means the whole city.
  final List<String> areas;
  final String? cardBank;
  final String? url;
  final String? promoCode;

  String get id => _id(6, n);
}

const demoDeals = [
  DemoDeal(
    n: 1,
    brand: 'demo-karahi-house',
    kind: 'food_deal',
    scope: 'local',
    titleEn: 'Family karahi for 4',
    titleUr: 'چار افراد کی فیملی کڑاہی',
    offerKind: 'fixed_price',
    price: 2499,
    originalPrice: 3299,
    endsInHours: 30,
    publishedHoursAgo: 1,
  ),
  DemoDeal(
    n: 2,
    brand: 'demo-burger-point',
    kind: 'food_deal',
    scope: 'local',
    areas: ['dha'],
    titleEn: 'Two smash burgers for Rs 999',
    titleUr: 'دو اسمیش برگر 999 روپے میں',
    offerKind: 'text',
    price: 999,
    offerTextEn: '2 for Rs 999',
    offerTextUr: '999 روپے میں دو',
    endsInHours: 5,
    publishedHoursAgo: 3,
  ),
  DemoDeal(
    n: 3,
    brand: 'demo-chai-adda',
    kind: 'food_deal',
    scope: 'local',
    areas: ['saddar'],
    titleEn: 'Chai and paratha breakfast',
    titleUr: 'چائے پراٹھا ناشتہ',
    offerKind: 'amount_off',
    amountOff: 150,
    endsInHours: 240,
    publishedHoursAgo: 6,
  ),
  DemoDeal(
    n: 4,
    brand: 'demo-threads',
    titleEn: 'Winter collection sale',
    titleUr: 'سردیوں کی کلیکشن سیل',
    offerKind: 'up_to_percent_off',
    percent: 50,
    endsInHours: 336,
    publishedHoursAgo: 4,
  ),
  DemoDeal(
    n: 5,
    brand: 'demo-threads',
    scope: 'online',
    titleEn: 'Online exclusive: flat 30% off',
    titleUr: 'آن لائن خصوصی: فلیٹ 30% رعایت',
    offerKind: 'flat_percent_off',
    percent: 30,
    endsInHours: 120,
    publishedHoursAgo: 8,
    url: 'https://example.com/demo-threads',
    promoCode: 'WINTER30',
  ),
  DemoDeal(
    n: 6,
    brand: 'demo-glow-salon',
    kind: 'service_deal',
    scope: 'local',
    titleEn: 'Hair cut and blow dry',
    titleUr: 'ہیئر کٹ اور بلو ڈرائی',
    offerKind: 'percent_off',
    percent: 25,
    price: 1800,
    originalPrice: 2400,
    endsInHours: 480,
    publishedHoursAgo: 10,
  ),
  DemoDeal(
    n: 7,
    brand: 'demo-karahi-house',
    kind: 'card_offer',
    scope: 'local',
    areas: ['clifton'],
    titleEn: '20% off with HBL credit cards (demo)',
    titleUr: 'ایچ بی ایل کریڈٹ کارڈ پر 20% رعایت (ڈیمو)',
    offerKind: 'percent_off',
    percent: 20,
    endsInHours: 720,
    publishedHoursAgo: 12,
    cardBank: 'hbl',
  ),
  DemoDeal(
    n: 8,
    brand: 'demo-dataplus',
    kind: 'telecom_bundle',
    titleEn: 'Weekly 20 GB bundle',
    titleUr: 'ہفتہ وار 20 جی بی بنڈل',
    offerKind: 'fixed_price',
    price: 450,
    originalPrice: 600,
    endsInHours: 168,
    publishedHoursAgo: 20,
    verifiedHoursAgo: 30,
  ),
  DemoDeal(
    n: 9,
    brand: 'demo-burger-point',
    kind: 'card_offer',
    titleEn: 'Meezan debit card: 15% off',
    titleUr: 'میزان ڈیبٹ کارڈ پر 15% رعایت',
    offerKind: 'percent_off',
    percent: 15,
    endsInHours: 96,
    publishedHoursAgo: 26,
    cardBank: 'meezan-bank',
  ),
  DemoDeal(
    n: 10,
    brand: 'demo-chai-adda',
    kind: 'food_deal',
    scope: 'local',
    titleEn: 'Evening chai happy hour',
    titleUr: 'شام کی چائے ہیپی آور',
    offerKind: 'text',
    offerTextEn: 'Buy 1 Get 1',
    offerTextUr: 'ایک کے ساتھ ایک مفت',
    publishedHoursAgo: 30,
  ),
];
