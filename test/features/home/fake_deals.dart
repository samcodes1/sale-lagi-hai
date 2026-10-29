import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_detail.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_page.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_repository.dart';

/// A live deal for tests: published [publishedHoursAgo] hours before
/// [now], ending [endsInHours] after it (or never).
Deal testDeal(
  int n, {
  required DateTime now,
  int publishedHoursAgo = 1,
  int? endsInHours = 48,
  DealScope scope = DealScope.nationwide,
  int? distanceMeters,
}) => Deal(
  id: '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}',
  brandId: 'b$n',
  brandSlug: 'brand-$n',
  brandName: 'Brand $n',
  categoryId: 'c1',
  categorySlug: 'food',
  scope: scope,
  status: DealStatus.published,
  titleEn: 'Deal number $n',
  offerKind: OfferKind.percentOff,
  percent: 10 + n % 50,
  startsAt: now.subtract(const Duration(days: 2)),
  publishedAt: now.subtract(Duration(hours: publishedHoursAgo, minutes: n)),
  endsAt: endsInHours == null ? null : now.add(Duration(hours: endsInHours)),
  distanceMeters: distanceMeters,
);

/// A [DealRepository] whose answers tests set. Every call is recorded.
final class FakeDeals implements DealRepository {
  new({required this.now, this.total = 45});

  final DateTime now;

  /// How many deals the feed has in all (paged by 20).
  int total;
  AppFailure? failWith;

  /// When set, only this many feed calls succeed; later ones fail.
  int? feedCallsBeforeFailing;
  final calls = <String>[];
  List<Deal> nearbyDeals = const [];

  late final List<Deal> _all = [
    for (var i = 0; i < total; i++) testDeal(i, now: now, publishedHoursAgo: i),
  ];

  Result<T> _or<T>(T value) =>
      failWith == null ? Success(value) : Failure(failWith!);

  @override
  Future<Result<DealPage>> feed({
    String? cityId,
    List<String>? categoryIds,
    bool followingOnly = false,
    FeedCursor? after,
    int pageSize = 20,
  }) async {
    calls.add('feed ${after == null ? 'first' : 'after ${after.id}'}');
    final left = feedCallsBeforeFailing;
    if (left != null) {
      if (left <= 0) return const Failure(OfflineFailure());
      feedCallsBeforeFailing = left - 1;
    }
    final start = after == null
        ? 0
        : _all.indexWhere((d) => d.id == after.id) + 1;
    final page = _all.skip(start).take(pageSize).toList();
    return _or(DealPage.of(page, pageSize: pageSize));
  }

  @override
  Future<Result<List<Deal>>> featured(
    FeaturedSlot slot, {
    String? cityId,
    String? categoryId,
  }) async {
    calls.add('featured');
    return _or([
      for (final d in _all.take(2))
        Deal(
          id: 'f-${d.id}',
          brandId: d.brandId,
          brandSlug: d.brandSlug,
          brandName: d.brandName,
          categoryId: d.categoryId,
          categorySlug: d.categorySlug,
          scope: d.scope,
          status: d.status,
          titleEn: 'Featured ${d.titleEn}',
          offerKind: d.offerKind,
          percent: d.percent,
          startsAt: d.startsAt,
          publishedAt: d.publishedAt,
          isFeatured: true,
        ),
    ]);
  }

  @override
  Future<Result<List<Deal>>> trending({String? cityId}) async {
    calls.add('trending');
    return _or(_all.skip(5).take(4).toList());
  }

  @override
  Future<Result<List<Deal>>> endingSoon({
    String? cityId,
    int withinHours = 72,
  }) async {
    calls.add('ending');
    return _or([
      testDeal(900, now: now, endsInHours: 3),
      // Already ended by the time it's shown: must be dropped.
      testDeal(901, now: now, endsInHours: -1),
    ]);
  }

  @override
  Future<Result<List<Deal>>> nearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
  }) async {
    calls.add('nearby');
    return _or(nearbyDeals);
  }

  @override
  Future<Result<DealPage>> forMyCards({String? cityId, FeedCursor? after}) =>
      throw UnimplementedError();

  @override
  Future<Result<List<Deal>>> search(
    String query, {
    String? cityId,
    List<String>? categoryIds,
    int page = 0,
  }) => throw UnimplementedError();

  @override
  Future<Result<DealPage>> brandDeals(
    String brandSlug, {
    String? cityId,
    FeedCursor? after,
  }) => throw UnimplementedError();

  @override
  Future<Result<Deal>> byId(String id) => throw UnimplementedError();

  @override
  Future<Result<DealDetail>> detail(String id) => throw UnimplementedError();
}
