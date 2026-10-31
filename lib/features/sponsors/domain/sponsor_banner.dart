import 'package:meta/meta.dart';

/// A paid banner on Home, sold directly to a sponsor. Staff manage them in
/// the `sponsor_banners` table.
@immutable
final class SponsorBanner {
  const new({
    required this.id,
    required this.sponsorName,
    required this.titleEn,
    this.titleUr,
    this.subtitleEn,
    this.subtitleUr,
    this.imagePath,
    this.linkUrl,
    this.cityId,
  });

  final String id;
  final String sponsorName;
  final String titleEn;
  final String? titleUr;
  final String? subtitleEn;
  final String? subtitleUr;

  /// The artwork in the deal-images bucket. Without one, the banner shows
  /// its title and subtitle as text.
  final String? imagePath;

  /// Where a tap goes (https only). Without one, it isn't tappable.
  final String? linkUrl;

  /// The only city it shows in; `null` shows it everywhere.
  final String? cityId;

  String title({required bool urdu}) => urdu ? titleUr ?? titleEn : titleEn;

  String? subtitle({required bool urdu}) =>
      urdu ? subtitleUr ?? subtitleEn : subtitleEn;
}
