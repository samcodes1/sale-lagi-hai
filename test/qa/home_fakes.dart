// QA, sub-phase 4.3: a scripted deal repository for the Home QA tests.
import 'dart:async';

import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_detail.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_page.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_repository.dart';
import 'package:sale_lagi_hai/features/deals/domain/search_filters.dart';

final DateTime qaNow = DateTime.now().toUtc().copyWith(
  second: 0,
  millisecond: 0,
  microsecond: 0,
);

/// A long Urdu title (about 120 characters), as merchants write them.
const qaLongUrduTitle =
    'سردیوں کی میگا سیل: تمام اونی شالیں، سویٹر اور '
    'جیکٹس پر پچاس فیصد تک رعایت، '
    'صرف منتخب اسٹورز اور آن لائن، اسٹاک ختم ہونے تک';

/// A deal whose id says which city (or interests) it was loaded for.
Deal qaDeal(
  String tag,
  int n, {
  Duration endsIn = const Duration(days: 2),
  bool longUrdu = false,
}) => Deal(
  id: '$tag-$n',
  brandId: 'b$n',
  brandSlug: 'brand-$n',
  brandName: 'Brand $n',
  categoryId: 'c1',
  categorySlug: 'food',
  scope: DealScope.nationwide,
  status: DealStatus.published,
  titleEn: 'Deal $tag $n',
  titleUr: longUrdu ? qaLongUrduTitle : null,
  brandNameUr: longUrdu ? 'گل احمد ٹیکسٹائل ملز لمیٹڈ' : null,
  offerTextUr: longUrdu ? 'دوسری شال آدھی قیمت پر' : null,
  offerTextEn: longUrdu ? 'Second shawl at half price' : null,
  offerKind: longUrdu ? OfferKind.text : OfferKind.percentOff,
  percent: longUrdu ? null : 20,
  startsAt: qaNow.subtract(const Duration(days: 3)),
  publishedAt: qaNow.subtract(Duration(minutes: n)),
  endsAt: qaNow.add(endsIn),
);

/// Feed pages of 20 per city; any call can be held with [holdFirst] /
/// [holdNext] until the test releases it.
final class GatedDeals implements DealRepository {
  final calls = <String>[];
  Completer<void>? holdFirst;
  Completer<void>? holdNext;
  bool offline = false;
  Duration endsIn = const Duration(days: 2);
  bool longUrdu = false;

  String _tag(String? city, List<String>? categories) =>
      '${city ?? 'all'}${categories == null ? '' : '+${categories.join('+')}'}';

  @override
  Future<Result<DealPage>> feed({
    String? cityId,
    List<String>? categoryIds,
    bool followingOnly = false,
    FeedCursor? after,
    int pageSize = 20,
  }) async {
    final tag = _tag(cityId, categoryIds);
    calls.add('feed $tag ${after == null ? 'first' : 'after ${after.id}'}');
    final hold = after == null ? holdFirst : holdNext;
    if (hold != null) await hold.future;
    if (offline) return const Failure(OfflineFailure());
    final start = after == null ? 0 : int.parse(after.id.split('-').last) + 1;
    final page = [
      for (var i = start; i < start + pageSize && i < 100; i++)
        qaDeal(tag, i, endsIn: endsIn, longUrdu: longUrdu),
    ];
    return Success(DealPage.of(page, pageSize: pageSize));
  }

  Future<Result<List<Deal>>> _row(String name, String? city) async {
    calls.add('$name ${city ?? 'all'}');
    if (offline) return const Failure(OfflineFailure());
    return Success([
      for (var i = 0; i < 5; i++)
        qaDeal('$name-$city', i, endsIn: endsIn, longUrdu: longUrdu),
    ]);
  }

  @override
  Future<Result<List<Deal>>> featured(
    FeaturedSlot slot, {
    String? cityId,
    String? categoryId,
  }) => _row('featured', cityId);

  @override
  Future<Result<List<Deal>>> trending({String? cityId}) =>
      _row('trending', cityId);

  @override
  Future<Result<List<Deal>>> endingSoon({
    String? cityId,
    int withinHours = 72,
  }) => _row('ending', cityId);

  @override
  Future<Result<List<Deal>>> nearby({
    required double latitude,
    required double longitude,
    int radiusMeters = 3000,
  }) async => Success([qaDeal('near', 1)]);

  @override
  Future<Result<DealPage>> forMyCards({String? cityId, FeedCursor? after}) =>
      throw UnimplementedError();

  @override
  Future<Result<DealPage>> search(
    String query, {
    String? cityId,
    SearchFilters filters = SearchFilters.none,
    FeedCursor? after,
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
