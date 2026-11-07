import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/features/sponsors/domain/sponsor_banner.dart';

/// Sponsor banners over the backend. RLS returns only those running now.
/// Throws (backend errors, or [FormatException] for a malformed row).
final class BackendSponsorRepository {
  const new(this._backend);

  final BackendGateway _backend;

  /// The most a shopper is shown at once.
  static const _limit = 8;

  static T _req<T>(Map<String, Object?> row, String key) => switch (row[key]) {
    final T value => value,
    _ => throw FormatException('sponsor_banners.$key is missing or not $T'),
  };

  static T? _opt<T>(Map<String, Object?> row, String key) => switch (row[key]) {
    null => null,
    final T value => value,
    _ => throw FormatException('sponsor_banners.$key is not $T'),
  };

  /// The banners running now, in the order staff set.
  Future<List<SponsorBanner>> live() async {
    final rows = await _backend.select(
      const TableQuery(
        'sponsor_banners',
        columns:
            'id,sponsor_name,title_en,title_ur,subtitle_en,subtitle_ur,'
            'image_path,link_url,city_id',
        orderBy: 'sort_order',
        limit: _limit,
      ),
    );
    return [
      for (final row in rows)
        SponsorBanner(
          id: _req<String>(row, 'id'),
          sponsorName: _req<String>(row, 'sponsor_name'),
          titleEn: _req<String>(row, 'title_en'),
          titleUr: _opt<String>(row, 'title_ur'),
          subtitleEn: _opt<String>(row, 'subtitle_en'),
          subtitleUr: _opt<String>(row, 'subtitle_ur'),
          imagePath: _opt<String>(row, 'image_path'),
          linkUrl: _opt<String>(row, 'link_url'),
          cityId: _opt<String>(row, 'city_id'),
        ),
    ];
  }
}
