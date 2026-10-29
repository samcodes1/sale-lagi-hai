import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/design_system/models/deal_offer.dart';

/// What a deal offers, as stored: one of the backend's offer kinds plus the
/// fields that kind uses (see public.offer_kind).
enum OfferKind {
  percentOff('percent_off'),
  upToPercentOff('up_to_percent_off'),
  flatPercentOff('flat_percent_off'),
  amountOff('amount_off'),
  fixedPrice('fixed_price'),
  text('text');

  new(this.wire);

  final String wire;

  static OfferKind? fromWire(String value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

enum DealScope { nationwide, online, local }

enum DealStatus { draft, pendingReview, published, rejected, expired, removed }

/// A deal as the backend returns it (a `deal_card` row).
@immutable
final class Deal {
  const new({
    required this.id,
    required this.brandId,
    required this.brandSlug,
    required this.brandName,
    required this.categoryId,
    required this.categorySlug,
    required this.scope,
    required this.status,
    required this.titleEn,
    required this.offerKind,
    required this.startsAt,
    this.brandNameUr,
    this.brandLogoPath,
    this.brandVerified = false,
    this.kind = 'other',
    this.titleUr,
    this.percent,
    this.amountOffPkr,
    this.pricePkr,
    this.originalPricePkr,
    this.offerTextEn,
    this.offerTextUr,
    this.promoCode,
    this.url,
    this.imagePath,
    this.endsAt,
    this.verifiedAt,
    this.publishedAt,
    this.cardBanks = const [],
    this.isFeatured = false,
    this.distanceMeters,
  });

  final String id;
  final String brandId;
  final String brandSlug;
  final String brandName;
  final String? brandNameUr;
  final String? brandLogoPath;
  final bool brandVerified;
  final String categoryId;
  final String categorySlug;
  final String kind;
  final DealScope scope;
  final DealStatus status;
  final String titleEn;
  final String? titleUr;
  final OfferKind offerKind;
  final int? percent;
  final int? amountOffPkr;
  final int? pricePkr;
  final int? originalPricePkr;
  final String? offerTextEn;
  final String? offerTextUr;
  final String? promoCode;
  final String? url;
  final String? imagePath;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime? verifiedAt;
  final DateTime? publishedAt;
  final List<String> cardBanks;
  final bool isFeatured;
  final int? distanceMeters;

  /// Live now: published, started, not ended.
  bool isLive(DateTime now) =>
      status == DealStatus.published &&
      !startsAt.isAfter(now) &&
      (endsAt == null || endsAt!.isAfter(now));

  String title({required bool urdu}) => urdu ? (titleUr ?? titleEn) : titleEn;

  String brand({required bool urdu}) =>
      urdu ? (brandNameUr ?? brandName) : brandName;

  /// The badge, or null when the deal has no percentage or text to show.
  /// Prices alone are shown as prices; their percentage comes from
  /// [DealOffer.fromPrices] (never invented).
  DealOffer? offer({required bool urdu}) {
    final p = percent;
    return switch (offerKind) {
      OfferKind.percentOff when p != null => PercentOff(p),
      OfferKind.upToPercentOff when p != null => UpToPercentOff(p),
      OfferKind.flatPercentOff when p != null => FlatPercentOff(p),
      OfferKind.text => switch ((urdu ? offerTextUr : null) ?? offerTextEn) {
        final String text => TextOffer(text),
        null => null,
      },
      _ when pricePkr != null && originalPricePkr != null =>
        DealOffer.fromPrices(was: originalPricePkr!, now: pricePkr!),
      _ => null,
    };
  }
}
