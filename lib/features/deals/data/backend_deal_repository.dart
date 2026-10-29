import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/deals/data/deal_row.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_page.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_repository.dart';

/// [DealRepository] over the read APIs (docs/backend/API.md).
final class BackendDealRepository implements DealRepository {
  const new(this._backend, this._logger);

  final BackendGateway _backend;
  final AppLogger _logger;

  static AppFailure? _formatMapper(Object error, StackTrace stackTrace) =>
      error is FormatException
      ? ServerFailure(cause: error, stackTrace: stackTrace)
      : null;

  Future<Result<T>> _guard<T>(Future<T> Function() body) => guard(
    body,
    logger: _logger,
    mappers: const [backendErrorMapper, _formatMapper],
  );

  Future<List<Deal>> _rpc(String fn, Map<String, Object?> params) async => [
    for (final row in await _backend.rpc(fn, params)) dealFromRow(row),
  ];

  static Map<String, Object?> _cursor(FeedCursor? after) => {
    if (after != null) ...{
      'after_published_at': after.publishedAt.toUtc().toIso8601String(),
      'after_id': after.id,
    },
  };

  @override
  Future<Result<DealPage>> feed({
    String? cityId,
    List<String>? categoryIds,
    bool followingOnly = false,
    FeedCursor? after,
    int pageSize = 20,
  }) => _guard(() async {
    final deals = await _rpc('feed', {
      'city_id': ?cityId,
      'category_ids': ?categoryIds,
      if (followingOnly) 'following_only': true,
      ..._cursor(after),
      'page_size': pageSize,
    });
    return DealPage.of(deals, pageSize: pageSize);
  });

  @override
  Future<Result<List<Deal>>> featured(
    FeaturedSlot slot, {
    String? cityId,
    String? categoryId,
  }) => _guard(
    () => _rpc('featured_deals', {
      'slot': slot.wire,
      'city_id': ?cityId,
      'category_id': ?categoryId,
    }),
  );

  @override
  Future<Result<List<Deal>>> trending({String? cityId}) =>
      _guard(() => _rpc('trending_deals', {'city_id': ?cityId}));

  @override
  Future<Result<List<Deal>>> nearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
  }) => _guard(
    () => _rpc('nearby_deals', {
      'lat': latitude,
      'lng': longitude,
      'radius_m': radiusMeters,
    }),
  );

  @override
  Future<Result<DealPage>> forMyCards({String? cityId, FeedCursor? after}) =>
      _guard(() async {
        final deals = await _rpc('deals_for_my_cards', {
          'city_id': ?cityId,
          ..._cursor(after),
          'page_size': 20,
        });
        return DealPage.of(deals, pageSize: 20);
      });

  @override
  Future<Result<List<Deal>>> search(
    String query, {
    String? cityId,
    List<String>? categoryIds,
    int page = 0,
  }) {
    final trimmed = query.trim();
    // The server ignores queries outside 2-100 characters; don't ask.
    if (trimmed.length < 2 || trimmed.length > 100) {
      return Future.value(const Success(<Deal>[]));
    }
    return _guard(
      () => _rpc('search_deals', {
        'query': trimmed,
        'city_id': ?cityId,
        'category_ids': ?categoryIds,
        'page': page,
      }),
    );
  }

  @override
  Future<Result<DealPage>> brandDeals(
    String brandSlug, {
    String? cityId,
    FeedCursor? after,
  }) => _guard(() async {
    final deals = await _rpc('brand_deals', {
      'brand_slug': brandSlug,
      'city_id': ?cityId,
      ..._cursor(after),
      'page_size': 20,
    });
    return DealPage.of(deals, pageSize: 20);
  });

  @override
  Future<Result<Deal>> byId(String id) => _guard(() async {
    final rows = await _backend.select(
      TableQuery('deal_cards', equals: {'id': id}, limit: 1),
    );
    if (rows.isEmpty) throw const NotFoundFailure();
    return dealFromRow(rows.single);
  });
}
