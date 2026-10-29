import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_providers.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_page.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_repository.dart';
import 'package:sale_lagi_hai/features/deals/domain/search_filters.dart';

/// A paged list of deals: what is loaded, where the next page starts,
/// and how loading more is going.
@immutable
final class FeedState {
  const new({
    required this.deals,
    this.next,
    this.loadingMore = false,
    this.moreFailure,
    this.cachedAt,
  });

  final List<Deal> deals;

  /// Where the next page starts; `null` at the end.
  final FeedCursor? next;
  final bool loadingMore;

  /// The next page failed: shown as a retry row at the bottom, never as a
  /// full-screen error.
  final AppFailure? moreFailure;

  /// Set when the first page came from the offline cache.
  final DateTime? cachedAt;

  bool get atEnd => next == null;

  FeedState copyWith({
    List<Deal>? deals,
    FeedCursor? Function()? next,
    bool? loadingMore,
    AppFailure? Function()? moreFailure,
  }) => FeedState(
    deals: deals ?? this.deals,
    next: next == null ? this.next : next(),
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailure: moreFailure == null ? this.moreFailure : moreFailure(),
    cachedAt: cachedAt,
  );
}

/// Which deals a [DealListController] pages through.
@immutable
sealed class DealListQuery {
  const new({this.cityId});

  final String? cityId;

  Future<Result<DealPage>> fetch(DealRepository deals, FeedCursor? after);
}

/// A category page: the category and its subcategories.
final class CategoryDeals extends DealListQuery {
  const new(this.categoryIds, {super.cityId});

  final List<String> categoryIds;

  @override
  Future<Result<DealPage>> fetch(DealRepository deals, FeedCursor? after) =>
      deals.feed(cityId: cityId, categoryIds: categoryIds, after: after);

  @override
  bool operator ==(Object other) =>
      other is CategoryDeals &&
      other.cityId == cityId &&
      other.categoryIds.join(',') == categoryIds.join(',');

  @override
  int get hashCode => Object.hash(cityId, categoryIds.join(','));
}

/// A brand page.
final class BrandDeals extends DealListQuery {
  const new(this.brandSlug, {super.cityId});

  final String brandSlug;

  @override
  Future<Result<DealPage>> fetch(DealRepository deals, FeedCursor? after) =>
      deals.brandDeals(brandSlug, cityId: cityId, after: after);

  @override
  bool operator ==(Object other) =>
      other is BrandDeals &&
      other.cityId == cityId &&
      other.brandSlug == brandSlug;

  @override
  int get hashCode => Object.hash(cityId, brandSlug);
}

/// Search results: the words (best first) and filters; with no words,
/// the newest deals that pass the filters.
final class SearchDeals extends DealListQuery {
  const new(this.query, {this.filters = SearchFilters.none, super.cityId});

  final String query;
  final SearchFilters filters;

  @override
  Future<Result<DealPage>> fetch(DealRepository deals, FeedCursor? after) =>
      deals.search(query, cityId: cityId, filters: filters, after: after);

  @override
  bool operator ==(Object other) =>
      other is SearchDeals &&
      other.cityId == cityId &&
      other.query == query &&
      other.filters == filters;

  @override
  int get hashCode => Object.hash(cityId, query, filters);
}

final AsyncNotifierProviderFamily<DealListController, FeedState, DealListQuery>
dealListProvider =
    AsyncNotifierProvider.family<DealListController, FeedState, DealListQuery>(
      DealListController.new,
    );

/// Pages through a [DealListQuery]: the first page on build, the next on
/// [loadMore] (one at a time; a failed page becomes a retry row).
final class DealListController extends AsyncNotifier<FeedState> {
  new(this.query);

  final DealListQuery query;

  /// Bumped on every rebuild (refresh), so a page asked for before it is
  /// dropped.
  int _generation = 0;

  @override
  Future<FeedState> build() async {
    _generation++;
    final result = await query.fetch(ref.watch(dealRepositoryProvider), null);
    return switch (result) {
      Success(:final value) => FeedState(deals: value.deals, next: value.next),
      Failure(:final failure) => throw failure,
    };
  }

  Future<void> loadMore() async {
    final current = state.value;
    final next = current?.next;
    if (current == null || next == null || current.loadingMore) return;
    final generation = _generation;
    state = AsyncData(
      current.copyWith(loadingMore: true, moreFailure: () => null),
    );
    final result = await query.fetch(ref.read(dealRepositoryProvider), next);
    if (!ref.mounted || generation != _generation) return;
    final now = state.value;
    if (now == null || now.next != next) return;
    switch (result) {
      case Success(:final value):
        final seen = {for (final d in now.deals) d.id};
        state = AsyncData(
          now.copyWith(
            deals: [
              ...now.deals,
              for (final d in value.deals)
                if (!seen.contains(d.id)) d,
            ],
            next: () => value.next,
            loadingMore: false,
          ),
        );
      case Failure(:final failure):
        state = AsyncData(
          now.copyWith(loadingMore: false, moreFailure: () => failure),
        );
    }
  }
}
