import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_detail.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_page.dart';

/// Featured slots (public.placement_slot).
enum FeaturedSlot {
  homeFeatured('home_featured'),
  categoryTop('category_top'),
  searchTop('search_top'),
  citySpotlight('city_spotlight');

  new(this.wire);

  final String wire;
}

abstract interface class DealRepository {
  Future<Result<DealPage>> feed({
    String? cityId,
    List<String>? categoryIds,
    bool followingOnly = false,
    FeedCursor? after,
    int pageSize = 20,
  });

  Future<Result<List<Deal>>> featured(
    FeaturedSlot slot, {
    String? cityId,
    String? categoryId,
  });

  Future<Result<List<Deal>>> trending({String? cityId});

  /// Live deals ending within [withinHours] (at most a week), soonest
  /// first.
  Future<Result<List<Deal>>> endingSoon({String? cityId, int withinHours = 72});

  Future<Result<List<Deal>>> nearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
  });

  Future<Result<DealPage>> forMyCards({String? cityId, FeedCursor? after});

  Future<Result<List<Deal>>> search(
    String query, {
    String? cityId,
    List<String>? categoryIds,
    int page = 0,
  });

  Future<Result<DealPage>> brandDeals(
    String brandSlug, {
    String? cityId,
    FeedCursor? after,
  });

  /// One deal, live or expired (expired deals still open, marked Expired).
  /// A missing or hidden deal is a NotFoundFailure.
  Future<Result<Deal>> byId(String id);

  /// The deal page: [byId] plus its text, source and outlets.
  Future<Result<DealDetail>> detail(String id);
}
