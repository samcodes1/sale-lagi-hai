import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/design_system/models/deal_offer.dart';

/// Everything a deal card displays. A presentation model: the deals
/// feature (Phase 4) maps its domain entities to this.
@immutable
final class DealCardData {
  const new({
    required this.id,
    required this.brandName,
    required this.title,
    this.offer,
    this.price,
    this.oldPrice,
    this.endsAt,
    this.verifiedAt,
    this.place,
    this.imageUrl,
    this.featured = false,
    this.saved = false,
    this.cardNames = const [],
  });

  final String id;
  final String brandName;

  /// The offer headline, e.g. "Winter collection". Already localized.
  final String title;

  /// The badge. Shown only when set: no offer, no badge.
  final DealOffer? offer;

  /// New and old price in rupees. The old price is shown struck through
  /// only alongside a new price.
  final int? price;
  final int? oldPrice;

  final DateTime? endsAt;
  final DateTime? verifiedAt;

  /// Where: "DHA · 1.2 km", "Online", "All Pakistan". Already localized.
  final String? place;

  /// Remote image (16:9). Without one, the card shows a brand plate.
  final String? imageUrl;

  /// A paid placement: always labelled "Featured".
  final bool featured;
  final bool saved;

  /// Bank cards the offer applies to, e.g. ["HBL", "Meezan"].
  final List<String> cardNames;
}
