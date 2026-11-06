import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/features/popups/domain/popup_banner.dart';

/// Pop-up banners over the backend. RLS returns only those running now.
/// Throws (backend errors, or [FormatException] for a malformed row).
final class BackendPopupRepository {
  const new(this._backend);

  final BackendGateway _backend;

  /// More than one can run at once; the app shows the first one due.
  static const _limit = 10;

  static T _req<T>(Map<String, Object?> row, String key) => switch (row[key]) {
    final T value => value,
    _ => throw FormatException('popup_banners.$key is missing or not $T'),
  };

  static T? _opt<T>(Map<String, Object?> row, String key) => switch (row[key]) {
    null => null,
    final T value => value,
    _ => throw FormatException('popup_banners.$key is not $T'),
  };

  static PopupTarget? _target(Map<String, Object?> row) {
    if (_opt<String>(row, 'link_url') case final url?) return PopupLink(url);
    if (_opt<String>(row, 'deal_id') case final id?) return PopupDeal(id);
    return switch (row['brand']) {
      {'slug': final String slug} => PopupBrand(slug),
      null => null,
      _ => throw const FormatException('popup_banners.brand is not a brand'),
    };
  }

  /// The pop-ups running now, most important first.
  Future<List<PopupBanner>> live() async {
    final rows = await _backend.select(
      const TableQuery(
        'popup_banners',
        columns:
            'id,sponsor_name,title_en,title_ur,body_en,body_ur,image_path,'
            'action_label_en,action_label_ur,link_url,deal_id,'
            'brand:brands(slug),city_id,frequency',
        orderBy: 'priority',
        limit: _limit,
      ),
    );
    return [
      for (final row in rows)
        PopupBanner(
          id: _req<String>(row, 'id'),
          titleEn: _req<String>(row, 'title_en'),
          titleUr: _opt<String>(row, 'title_ur'),
          bodyEn: _opt<String>(row, 'body_en'),
          bodyUr: _opt<String>(row, 'body_ur'),
          sponsorName: _opt<String>(row, 'sponsor_name'),
          imagePath: _opt<String>(row, 'image_path'),
          actionLabelEn: _opt<String>(row, 'action_label_en'),
          actionLabelUr: _opt<String>(row, 'action_label_ur'),
          target: _target(row),
          cityId: _opt<String>(row, 'city_id'),
          frequency: PopupFrequency.parse(_req<String>(row, 'frequency')),
        ),
    ];
  }
}
