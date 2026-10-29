import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/storage/json_cache.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_providers.dart';
import 'package:sale_lagi_hai/features/deals/data/deal_row.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../../helpers/fakes.dart';
import '../onboarding/onboarding_harness.dart' show FakeLocation;
import 'fake_deals.dart';

void main() {
  final now = DateTime.utc(2026, 10, 29, 12);
  late FakeDeals deals;
  late InMemoryKeyValueStore store;
  late DateTime clock;
  late FakeLocation location;

  ProviderContainer container() {
    final logger = AppLogger(sinks: []);
    final c = ProviderContainer(
      overrides: [
        dealRepositoryProvider.overrideWithValue(deals),
        keyValueStoreProvider.overrideWithValue(store),
        loggerProvider.overrideWithValue(logger),
        jsonCacheProvider.overrideWithValue(
          JsonCache(store, logger: logger, clock: () => clock),
        ),
        clockProvider.overrideWithValue(() => clock),
        savedPreferencesProvider.overrideWithValue(
          const ShopperPreferences(onboarded: true, cityId: 'karachi'),
        ),
        locationServiceProvider.overrideWithValue(location),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    deals = FakeDeals(now: now);
    store = InMemoryKeyValueStore();
    clock = now;
    location = FakeLocation(const Located(24.86, 67));
  });

  group('rows', () {
    test('load fresh, and keep a copy for offline', () async {
      final c = container();
      final trending = await c.read(trendingProvider.future);
      expect(trending.deals, hasLength(4));
      expect(trending.isStale, isFalse);
      expect(store.values.keys, contains('cache.home.trending.karachi'));
    });

    test(
      'offline: the copy shows, marked with its age and the failure',
      () async {
        await container().read(trendingProvider.future);
        deals.failWith = const OfflineFailure();
        clock = now.add(const Duration(hours: 2));
        final c = container();
        final stale = await c.read(trendingProvider.future);
        expect(stale.deals, hasLength(4));
        expect(stale.cachedAt, now);
        expect(stale.failure, isA<OfflineFailure>());
      },
    );

    test(
      'offline with no copy (or too old a copy): the failure shows',
      () async {
        deals.failWith = const OfflineFailure();
        await expectLater(
          container().read(featuredProvider.future),
          throwsA(isA<OfflineFailure>()),
        );
        deals.failWith = null;
        await container().read(featuredProvider.future);
        deals.failWith = const ServerFailure(statusCode: 503);
        clock = now.add(homeCacheMaxAge + const Duration(minutes: 1));
        await expectLater(
          container().read(featuredProvider.future),
          throwsA(isA<ServerFailure>()),
        );
      },
    );

    test('a corrupt copy is treated as none', () async {
      store.values['cache.home.ending.karachi'] =
          '{"v":1,"at":"2026-10-29T12:00:00.000Z","data":[{"id":7}]}';
      deals.failWith = const OfflineFailure();
      await expectLater(
        container().read(endingSoonProvider.future),
        throwsA(isA<OfflineFailure>()),
      );
    });

    test('deals that ended since loading are left out', () async {
      final ending = await container().read(endingSoonProvider.future);
      expect(ending.deals.map((d) => d.titleEn), ['Deal number 900']);
    });

    test('featured deals keep their label through the cache', () async {
      await container().read(featuredProvider.future);
      deals.failWith = const OfflineFailure();
      final cached = await container().read(featuredProvider.future);
      expect(cached.deals.every((d) => d.isFeatured), isTrue);
    });

    test('rows follow the chosen city', () async {
      final c = container();
      await c.read(trendingProvider.future);
      await c.read(preferencesProvider.notifier).setCity('lahore');
      await c.read(trendingProvider.future);
      expect(store.values.keys, contains('cache.home.trending.lahore'));
    });
  });

  group('for you', () {
    test('pages through the feed without repeats, then ends', () async {
      final c = container();
      var state = await c.read(forYouProvider.future);
      expect(state.deals, hasLength(20));
      expect(state.atEnd, isFalse);
      await c.read(forYouProvider.notifier).loadMore();
      await c.read(forYouProvider.notifier).loadMore();
      state = c.read(forYouProvider).requireValue;
      expect(state.deals, hasLength(45));
      expect(state.deals.map((d) => d.id).toSet(), hasLength(45));
      expect(state.atEnd, isTrue);
      await c.read(forYouProvider.notifier).loadMore();
      expect(deals.calls.where((x) => x.startsWith('feed')), hasLength(3));
    });

    test('one page at a time, however often it is asked', () async {
      final c = container();
      await c.read(forYouProvider.future);
      await Future.wait([
        for (var i = 0; i < 5; i++) c.read(forYouProvider.notifier).loadMore(),
      ]);
      expect(deals.calls.where((x) => x.startsWith('feed')), hasLength(2));
    });

    test('a failed page keeps what is shown and can be retried', () async {
      deals.feedCallsBeforeFailing = 1;
      final c = container();
      await c.read(forYouProvider.future);
      await c.read(forYouProvider.notifier).loadMore();
      var state = c.read(forYouProvider).requireValue;
      expect(state.deals, hasLength(20));
      expect(state.moreFailure, isA<OfflineFailure>());
      deals.feedCallsBeforeFailing = null;
      await c.read(forYouProvider.notifier).loadMore();
      state = c.read(forYouProvider).requireValue;
      expect(state.deals, hasLength(40));
      expect(state.moreFailure, isNull);
    });

    test(
      'offline: the cached first page, and no paging until refreshed',
      () async {
        await container().read(forYouProvider.future);
        deals.failWith = const OfflineFailure();
        final c = container();
        final state = await c.read(forYouProvider.future);
        expect(state.deals, hasLength(20));
        expect(state.cachedAt, now);
        expect(state.atEnd, isTrue);
      },
    );

    test('interests narrow the feed; the cache key follows them', () async {
      final c = container();
      await c.read(forYouProvider.future);
      final before = store.values.keys
          .where((k) => k.contains('foryou'))
          .toSet();
      await c.read(preferencesProvider.notifier).toggleInterest('food');
      await c.read(forYouProvider.future);
      final after = store.values.keys
          .where((k) => k.contains('foryou'))
          .toSet();
      expect(after.difference(before), hasLength(1));
    });

    test('rows round-trip through the cache unchanged', () {
      final deal = testDeal(3, now: now, distanceMeters: 1200);
      expect(dealToRow(dealFromRow(dealToRow(deal))), dealToRow(deal));
    });
  });

  group('near me', () {
    test('idle until asked; never asks for location on its own', () {
      final c = container();
      expect(c.read(nearMeProvider), isA<NearMeIdle>());
      expect(location.asked, 0);
    });

    test('found: nearby deals with their distance', () async {
      deals.nearbyDeals = [testDeal(1, now: now, distanceMeters: 800)];
      final c = container();
      await c.read(nearMeProvider.notifier).locate();
      final state = c.read(nearMeProvider);
      expect(state, isA<NearMeFound>());
      expect((state as NearMeFound).deals.single.distanceMeters, 800);
      expect(location.asked, 1);
      // Nothing about where the shopper is gets stored.
      expect(store.values.keys.where((k) => k.contains('near')), isEmpty);
    });

    test('no location, or a failed lookup, says so', () async {
      location.outcome = const LocationDenied(permanently: true);
      final c = container();
      await c.read(nearMeProvider.notifier).locate();
      expect(
        (c.read(nearMeProvider) as NearMeNoLocation).outcome,
        isA<LocationDenied>(),
      );
      location.outcome = const Located(24.86, 67);
      deals.failWith = const TimeoutFailure();
      await c.read(nearMeProvider.notifier).locate();
      expect(
        (c.read(nearMeProvider) as NearMeFailed).failure,
        isA<TimeoutFailure>(),
      );
    });
  });
}
