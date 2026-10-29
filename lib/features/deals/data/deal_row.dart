import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_detail.dart';

/// Parses a `deal_card` row. Throws [FormatException] on a shape we don't
/// expect (the repository maps it to a server failure): a malformed row is
/// never shown half-filled.
Deal dealFromRow(Map<String, Object?> row) {
  T req<T>(String key) => switch (row[key]) {
    final T value => value,
    _ => throw FormatException('deal_card.$key is missing or not $T'),
  };
  T? opt<T>(String key) => switch (row[key]) {
    null => null,
    final T value => value,
    _ => throw FormatException('deal_card.$key is not $T'),
  };
  DateTime? time(String key) => switch (opt<String>(key)) {
    null => null,
    final String s => DateTime.parse(s),
  };

  final offerKind = OfferKind.fromWire(req<String>('offer_kind'));
  if (offerKind == null) {
    throw FormatException('unknown offer_kind ${row['offer_kind']}');
  }
  return Deal(
    id: req<String>('id'),
    brandId: req<String>('brand_id'),
    brandSlug: req<String>('brand_slug'),
    brandName: req<String>('brand_name'),
    brandNameUr: opt<String>('brand_name_ur'),
    brandLogoPath: opt<String>('brand_logo_path'),
    brandVerified: opt<bool>('brand_is_verified') ?? false,
    categoryId: req<String>('category_id'),
    categorySlug: req<String>('category_slug'),
    kind: opt<String>('kind') ?? 'other',
    scope: switch (req<String>('scope')) {
      'nationwide' => DealScope.nationwide,
      'online' => DealScope.online,
      'local' => DealScope.local,
      final other => throw FormatException('unknown scope $other'),
    },
    status: switch (req<String>('status')) {
      'draft' => DealStatus.draft,
      'pending_review' => DealStatus.pendingReview,
      'published' => DealStatus.published,
      'rejected' => DealStatus.rejected,
      'expired' => DealStatus.expired,
      'removed' => DealStatus.removed,
      final other => throw FormatException('unknown status $other'),
    },
    titleEn: req<String>('title_en'),
    titleUr: opt<String>('title_ur'),
    offerKind: offerKind,
    percent: opt<int>('percent'),
    amountOffPkr: opt<int>('amount_off_pkr'),
    pricePkr: opt<int>('price_pkr'),
    originalPricePkr: opt<int>('original_price_pkr'),
    offerTextEn: opt<String>('offer_text_en'),
    offerTextUr: opt<String>('offer_text_ur'),
    promoCode: opt<String>('promo_code'),
    url: opt<String>('url'),
    imagePath: opt<String>('image_path'),
    startsAt: DateTime.parse(req<String>('starts_at')),
    endsAt: time('ends_at'),
    verifiedAt: time('verified_at'),
    publishedAt: time('published_at'),
    cardBanks: [
      for (final bank in opt<List<Object?>>('card_banks') ?? const [])
        if (bank is String) bank,
    ],
    isFeatured: opt<bool>('is_featured') ?? false,
    distanceMeters: opt<int>('distance_m'),
  );
}

/// The `deal_card` row for [deal]: the inverse of [dealFromRow], used to
/// cache what the screen showed for offline use.
Map<String, Object?> dealToRow(Deal deal) => {
  'id': deal.id,
  'brand_id': deal.brandId,
  'brand_slug': deal.brandSlug,
  'brand_name': deal.brandName,
  'brand_name_ur': deal.brandNameUr,
  'brand_logo_path': deal.brandLogoPath,
  'brand_is_verified': deal.brandVerified,
  'category_id': deal.categoryId,
  'category_slug': deal.categorySlug,
  'kind': deal.kind,
  'scope': deal.scope.name,
  'status': switch (deal.status) {
    DealStatus.pendingReview => 'pending_review',
    final status => status.name,
  },
  'title_en': deal.titleEn,
  'title_ur': deal.titleUr,
  'offer_kind': deal.offerKind.wire,
  'percent': deal.percent,
  'amount_off_pkr': deal.amountOffPkr,
  'price_pkr': deal.pricePkr,
  'original_price_pkr': deal.originalPricePkr,
  'offer_text_en': deal.offerTextEn,
  'offer_text_ur': deal.offerTextUr,
  'promo_code': deal.promoCode,
  'url': deal.url,
  'image_path': deal.imagePath,
  'starts_at': deal.startsAt.toUtc().toIso8601String(),
  'ends_at': deal.endsAt?.toUtc().toIso8601String(),
  'verified_at': deal.verifiedAt?.toUtc().toIso8601String(),
  'published_at': deal.publishedAt?.toUtc().toIso8601String(),
  'card_banks': deal.cardBanks,
  'is_featured': deal.isFeatured,
  'distance_m': deal.distanceMeters,
};

/// Parses an `outlets` row (the columns the deal page reads).
Outlet outletFromRow(Map<String, Object?> row) {
  T req<T>(String key) => switch (row[key]) {
    final T value => value,
    _ => throw FormatException('outlets.$key is missing or not $T'),
  };
  return Outlet(
    id: req<String>('id'),
    name: req<String>('name'),
    address: req<String>('address'),
    cityId: req<String>('city_id'),
    areaId: row['area_id'] as String?,
    phone: row['phone'] as String?,
    latitude: req<num>('latitude').toDouble(),
    longitude: req<num>('longitude').toDouble(),
  );
}
