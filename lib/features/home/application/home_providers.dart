import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_providers.dart';
import 'package:sale_lagi_hai/features/deals/data/deal_row.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_repository.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

/// Cached sections older than this are not shown even offline: a week-old
/// "ending soon" list misleads more than it helps.
const homeCacheMaxAge = Duration(days: 3);

/// A home row: its deals, and when they came from the offline cache, how
/// old they are and why fresh ones couldn't load.
@immutable
final class HomeSection {
  const new(this.deals, {this.cachedAt, this.failure});

  final List<Deal> deals;

  /// Set when [deals] is the saved copy (the network failed).
  final DateTime? cachedAt;
  final AppFailure? failure;

  bool get isStale => cachedAt != null;
}

/// The city the home rows are for (the shopper's choice; `null` shows
/// nationwide and online deals only).
final homeCityProvider = Provider<String?>(
  (ref) => ref.watch(preferencesProvider.select((p) => p.cityId)),
);

/// Loads [fetch], caching what it got under [key]. When it fails, the
/// cached copy (if any, and recent enough) is shown instead, marked
/// stale; with no copy the failure surfaces.
Future<HomeSection> _cached(
  Ref ref,
  String key,
  Future<Result<List<Deal>>> Function() fetch,
) async {
  final cache = ref.read(jsonCacheProvider);
  switch (await fetch()) {
    case Success(:final value):
      try {
        await cache.put(key, [for (final d in value) dealToRow(d)]);
      } on Object catch (error) {
        ref.read(loggerProvider).warning('Could not cache $key', error: error);
      }
      return HomeSection(value);
    case Failure(:final failure):
      final entry = await cache.get(key, maxAge: homeCacheMaxAge);
      final rows = entry?.data;
      if (entry == null || rows is! List) throw failure;
      try {
        return HomeSection(
          [
            for (final row in rows)
              dealFromRow(Map<String, Object?>.from(row as Map)),
          ],
          cachedAt: entry.savedAt,
          failure: failure,
        );
      } on Object {
        throw failure;
      }
  }
}

String _key(String row, String? city) => 'home.$row.${city ?? 'all'}';

/// Removes deals that ended since they were loaded (or cached).
List<Deal> _live(List<Deal> deals, DateTime now) => [
  for (final d in deals)
    if (d.endsAt == null || d.endsAt!.isAfter(now)) d,
];

HomeSection _onlyLive(HomeSection s, DateTime now) =>
    HomeSection(_live(s.deals, now), cachedAt: s.cachedAt, failure: s.failure);

/// Paid placements in the home slot: always labelled "Featured".
final featuredProvider = FutureProvider<HomeSection>((ref) async {
  final city = ref.watch(homeCityProvider);
  final deals = ref.watch(dealRepositoryProvider);
  final section = await _cached(
    ref,
    _key('featured', city),
    () => deals.featured(FeaturedSlot.homeFeatured, cityId: city),
  );
  return _onlyLive(section, ref.read(clockProvider)());
});

/// Trending today: saved most in the last day.
final trendingProvider = FutureProvider<HomeSection>((ref) async {
  final city = ref.watch(homeCityProvider);
  final deals = ref.watch(dealRepositoryProvider);
  final section = await _cached(
    ref,
    _key('trending', city),
    () => deals.trending(cityId: city),
  );
  return _onlyLive(section, ref.read(clockProvider)());
});

/// Ending in the next 3 days, soonest first.
final endingSoonProvider = FutureProvider<HomeSection>((ref) async {
  final city = ref.watch(homeCityProvider);
  final deals = ref.watch(dealRepositoryProvider);
  final section = await _cached(
    ref,
    _key('ending', city),
    () => deals.endingSoon(cityId: city),
  );
  return _onlyLive(section, ref.read(clockProvider)());
});

// ------------------------------------------------------------- for you ---

/// The "For you" list: newest live deals in the shopper's interests (all
/// categories when none were picked), paged as they scroll.
final forYouProvider = AsyncNotifierProvider<ForYouController, FeedState>(
  ForYouController.new,
);

final class ForYouController extends AsyncNotifier<FeedState> {
  String? get _city => ref.read(homeCityProvider);
  List<String>? _interests() {
    final ids = ref.read(preferencesProvider).interestIds;
    return ids.isEmpty ? null : ids;
  }

  @override
  Future<FeedState> build() async {
    final city = ref.watch(homeCityProvider);
    final interests = ref.watch(
      preferencesProvider.select((p) => p.interestIds.join(',')),
    );
    final key = 'home.foryou.${city ?? 'all'}.${interests.hashCode}';
    final cache = ref.read(jsonCacheProvider);
    final result = await ref
        .read(dealRepositoryProvider)
        .feed(cityId: city, categoryIds: _interests());
    switch (result) {
      case Success(:final value):
        try {
          await cache.put(key, [for (final d in value.deals) dealToRow(d)]);
        } on Object catch (error) {
          ref
              .read(loggerProvider)
              .warning('Could not cache the feed', error: error);
        }
        return FeedState(deals: value.deals, next: value.next);
      case Failure(:final failure):
        final entry = await cache.get(key, maxAge: homeCacheMaxAge);
        final rows = entry?.data;
        if (entry == null || rows is! List) throw failure;
        try {
          final deals = [
            for (final row in rows)
              dealFromRow(Map<String, Object?>.from(row as Map)),
          ];
          // A cached first page: paging resumes once the network is back
          // (pull to refresh).
          return FeedState(deals: deals, cachedAt: entry.savedAt);
        } on Object {
          throw failure;
        }
    }
  }

  /// Loads the next page, once at a time. Safe to call repeatedly while
  /// scrolling.
  Future<void> loadMore() async {
    final current = state.value;
    final next = current?.next;
    if (current == null || next == null || current.loadingMore) return;
    state = AsyncData(
      current.copyWith(loadingMore: true, moreFailure: () => null),
    );
    final result = await ref
        .read(dealRepositoryProvider)
        .feed(cityId: _city, categoryIds: _interests(), after: next);
    // The list may have been rebuilt (new city) meanwhile: drop the page.
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

// ------------------------------------------------------------- near me ---

sealed class NearMeState {
  const new();
}

/// Location not asked yet: the row offers a button.
final class NearMeIdle extends NearMeState {
  const new();
}

final class NearMeLocating extends NearMeState {
  const new();
}

final class NearMeFound extends NearMeState {
  const new(this.deals);

  final List<Deal> deals;
}

/// No location: [outcome] says why (denied, off, unavailable).
final class NearMeNoLocation extends NearMeState {
  const new(this.outcome);

  final LocationOutcome outcome;
}

final class NearMeFailed extends NearMeState {
  const new(this.failure);

  final AppFailure failure;
}

/// "Near me": approximate location, asked only when the shopper taps the
/// button, used for this one query and never stored or cached.
final nearMeProvider = NotifierProvider<NearMeController, NearMeState>(
  NearMeController.new,
);

final class NearMeController extends Notifier<NearMeState> {
  @override
  NearMeState build() => const NearMeIdle();

  Future<void> locate() async {
    if (state is NearMeLocating) return;
    state = const NearMeLocating();
    final outcome = await ref
        .read(locationServiceProvider)
        .approximateLocation();
    if (outcome is! Located) {
      state = NearMeNoLocation(outcome);
      return;
    }
    final result = await ref
        .read(dealRepositoryProvider)
        .nearby(latitude: outcome.latitude, longitude: outcome.longitude);
    state = switch (result) {
      Success(:final value) => NearMeFound(value),
      Failure(:final failure) => NearMeFailed(failure),
    };
  }
}
