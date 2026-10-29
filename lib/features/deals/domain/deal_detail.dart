import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';

/// A place to use the deal.
@immutable
final class Outlet {
  const new({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.cityId,
    this.areaId,
    this.phone,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String cityId;
  final String? areaId;

  /// E.164 (`+92…`), when the business gave one.
  final String? phone;
}

/// Everything the deal page shows: the card, the long text, where to use
/// it, and where it came from.
@immutable
final class DealDetail {
  const new({
    required this.deal,
    this.descriptionEn,
    this.descriptionUr,
    this.termsEn,
    this.termsUr,
    this.sourceUrl,
    this.outlets = const [],
  });

  final Deal deal;
  final String? descriptionEn;
  final String? descriptionUr;
  final String? termsEn;
  final String? termsUr;

  /// Where the deal was found (a brand's sale page), for "See the source".
  final String? sourceUrl;

  /// Active outlets where it applies: every outlet of the brand, or for a
  /// local deal only those in its target cities and areas.
  final List<Outlet> outlets;

  String? description({required bool urdu}) =>
      urdu ? (descriptionUr ?? descriptionEn) : descriptionEn;

  String? terms({required bool urdu}) => urdu ? (termsUr ?? termsEn) : termsEn;
}
