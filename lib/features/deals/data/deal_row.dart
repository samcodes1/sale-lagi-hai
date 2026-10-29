import 'package:sale_lagi_hai/features/deals/domain/deal.dart';

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
