import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/deals/data/deal_row.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_detail.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_page.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_repository.dart';
import 'package:sale_lagi_hai/features/deals/domain/search_filters.dart';

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
  Future<Result<List<Deal>>> endingSoon({
    String? cityId,
    int withinHours = 72,
  }) => _guard(
    () => _rpc('ending_soon_deals', {
      'city_id': ?cityId,
      'within_hours': withinHours,
    }),
  );

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
  Future<Result<DealPage>> search(
    String query, {
    String? cityId,
    SearchFilters filters = SearchFilters.none,
    FeedCursor? after,
  }) {
    final words = query.trim();
    // The server returns nothing for 1 or over 100 characters, or for no
    // words and no filters: don't ask.
    if (words.length == 1 ||
        words.length > 100 ||
        (words.isEmpty && filters.isEmpty)) {
      return Future.value(const Success(DealPage([])));
    }
    return _guard(() async {
      final deals = await _rpc('search_deals', {
        'query': ?(words.isEmpty ? null : words),
        'city_id': ?cityId,
        'category_ids': ?(filters.categoryIds.isEmpty
            ? null
            : filters.categoryIds),
        'area_id': ?filters.areaId,
        'bank_ids': ?(filters.bankIds.isEmpty ? null : filters.bankIds),
        'min_percent': ?filters.minPercent,
        'ending_within_hours': ?(filters.endingSoon ? endingSoonHours : null),
        'after_id': ?after?.id,
        'page_size': 20,
      });
      return DealPage.of(deals, pageSize: 20);
    });
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
  Future<Result<Deal>> byId(String id) => _guard(() => _card(id));

  Future<Deal> _card(String id) async {
    final rows = await _backend.select(
      TableQuery('deal_cards', equals: {'id': id}, limit: 1),
    );
    if (rows.isEmpty) throw const NotFoundFailure();
    return dealFromRow(rows.single);
  }

  @override
  Future<Result<DealDetail>> detail(String id) => _guard(() async {
    final deal = await _card(id);
    final (text, outletRows, targets) = await (
      _backend.select(
        TableQuery(
          'deals',
          columns: 'description_en,description_ur,terms_en,terms_ur,source_url',
          equals: {'id': id},
          limit: 1,
        ),
      ),
      _backend.select(
        TableQuery(
          'outlets',
          columns: 'id,name,address,phone,city_id,area_id,latitude,longitude',
          equals: {'brand_id': deal.brandId, 'is_active': true},
          orderBy: 'name',
          limit: 100,
        ),
      ),
      deal.scope == DealScope.local
          ? _backend.select(
              TableQuery(
                'deal_targets',
                columns: 'city_id,area_id',
                equals: {'deal_id': id},
              ),
            )
          : Future.value(const <Map<String, Object?>>[]),
    ).wait;
    final outlets = [for (final row in outletRows) outletFromRow(row)];
    final extra = text.isEmpty ? const <String, Object?>{} : text.single;
    String? opt(String key) => switch (extra[key]) {
      final String s when s.trim().isNotEmpty => s,
      _ => null,
    };
    return DealDetail(
      deal: deal,
      descriptionEn: opt('description_en'),
      descriptionUr: opt('description_ur'),
      termsEn: opt('terms_en'),
      termsUr: opt('terms_ur'),
      sourceUrl: opt('source_url'),
      outlets: deal.scope == DealScope.local
          ? [
              for (final o in outlets)
                if (targets.any(
                  (t) =>
                      t['city_id'] == o.cityId &&
                      (t['area_id'] == null || t['area_id'] == o.areaId),
                ))
                  o,
            ]
          : deal.scope == DealScope.online
          ? const []
          : outlets,
    );
  });
}
