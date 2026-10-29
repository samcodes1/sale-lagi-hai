// QA, sub-phase 4.3: the Home providers under races, offline copies and
// cache growth (docs/qa/4.3.md).
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug; run them with `--dart-define=QA_KNOWN_BUGS=true`.
import 'dart:async';
import 'dart:convert';

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
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../features/onboarding/onboarding_harness.dart' show FakeLocation;
import '../helpers/fakes.dart';
import 'home_fakes.dart';

void main() {
  late GatedDeals deals;
  late InMemoryKeyValueStore store;
  late DateTime clock;
  late FakeLocation location;

  ProviderContainer container({
    ShopperPreferences saved = const ShopperPreferences(
      onboarded: true,
      cityId: 'karachi',
    ),
  }) {
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
        savedPreferencesProvider.overrideWithValue(saved),
        locationServiceProvider.overrideWithValue(location),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    deals = GatedDeals();
    store = InMemoryKeyValueStore();
    clock = qaNow;
    location = FakeLocation(const Located(24.8138, 67.03));
  });

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('loadMore against a city or interest change', () {
    test('the new city answers first, then the old page: the old '
        'page is dropped', () async {
      final c = container();
      final sub = c.listen(forYouProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(forYouProvider.future);
      deals.holdNext = Completer();
      final more = c.read(forYouProvider.notifier).loadMore();
      await c.read(preferencesProvider.notifier).setCity('lahore');
      final fresh = await c.read(forYouProvider.future);
      expect(fresh.deals.map((d) => d.id), everyElement(startsWith('lahore')));
      deals.holdNext!.complete();
      await more;
      await settle();
      final state = c.read(forYouProvider).requireValue;
      expect(state.deals, hasLength(20));
      expect(state.deals.map((d) => d.id), everyElement(startsWith('lahore')));
      expect(state.loadingMore, isFalse);
    });

    test('the old page answers while the new city is still loading: '
        'the old city never comes back on screen', () async {
      final c = container();
      final seen = <String>[];
      final sub = c.listen(forYouProvider, (_, next) {
        if (next case AsyncData(:final value, isLoading: false)) {
          final cities = value.deals.map((d) => d.id.split('-').first);
          seen.add('${cities.toSet().join()} x${value.deals.length}');
        }
      });
      addTearDown(sub.close);
      await c.read(forYouProvider.future);
      deals.holdNext = Completer();
      final more = c.read(forYouProvider.notifier).loadMore();
      deals.holdFirst = Completer();
      await c.read(preferencesProvider.notifier).setCity('lahore');
      seen.clear(); // only what is shown after the switch counts
      await settle();
      deals.holdNext!.complete(); // the stale Karachi page lands first
      await more;
      await settle();
      deals.holdFirst!.complete();
      await c.read(forYouProvider.future);
      await settle();
      final state = c.read(forYouProvider).requireValue;
      expect(state.deals.map((d) => d.id), everyElement(startsWith('lahore')));
      expect(state.deals, hasLength(20));
      expect(
        seen.where((s) => s.contains('karachi')),
        isEmpty,
        reason: 'states shown after the switch: $seen',
      );
    });

    test('an interest change mid-page: the stale page is dropped', () async {
      final c = container();
      final sub = c.listen(forYouProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(forYouProvider.future);
      deals.holdNext = Completer();
      final more = c.read(forYouProvider.notifier).loadMore();
      await c.read(preferencesProvider.notifier).toggleInterest('food');
      await c.read(forYouProvider.future);
      deals.holdNext!.complete();
      await more;
      await settle();
      final state = c.read(forYouProvider).requireValue;
      expect(state.deals.map((d) => d.id), everyElement(contains('+food')));
      expect(state.deals, hasLength(20));
    });

    test('loadMore called 50 times while a page is in flight: one '
        'request', () async {
      final c = container();
      await c.read(forYouProvider.future);
      deals.holdNext = Completer();
      final calls = [
        for (var i = 0; i < 50; i++) c.read(forYouProvider.notifier).loadMore(),
      ];
      deals.holdNext!.complete();
      await Future.wait(calls);
      expect(deals.calls.where((x) => x.contains('after')), hasLength(1));
      expect(c.read(forYouProvider).requireValue.deals, hasLength(40));
    });
  });

  group('offline copies', () {
    test('For you: deals that ended since the copy was saved are left '
        'out, as in the other rows', () async {
      deals.endsIn = const Duration(hours: 1);
      final first = container();
      await first.read(forYouProvider.future);
      // (Developer, round 2: trending needs its own saved copy for the
      // comparison below.)
      await first.read(trendingProvider.future);
      deals.offline = true;
      clock = qaNow.add(const Duration(hours: 2));
      final c = container();
      final state = await c.read(forYouProvider.future);
      expect(state.cachedAt, isNotNull);
      expect(
        state.deals.where((d) => !d.endsAt!.isAfter(clock)),
        isEmpty,
        reason: 'every saved deal ended an hour ago',
      );
      // The carousels do drop them:
      expect((await c.read(trendingProvider.future)).deals, isEmpty);
    });

    test('a copy exactly at maxAge is still shown; one second later it '
        'is not', () async {
      final c1 = container();
      await c1.read(trendingProvider.future);
      deals.offline = true;
      clock = qaNow.add(homeCacheMaxAge);
      expect((await container().read(trendingProvider.future)).isStale, isTrue);
      clock = qaNow.add(homeCacheMaxAge + const Duration(seconds: 1));
      await expectLater(
        container().read(trendingProvider.future),
        throwsA(isA<OfflineFailure>()),
      );
    });

    test(
      'a copy saved "in the future" (clock moved back) is not shown',
      () async {
        clock = qaNow.add(const Duration(hours: 5));
        await container().read(trendingProvider.future);
        deals.offline = true;
        clock = qaNow;
        await expectLater(
          container().read(trendingProvider.future),
          throwsA(isA<OfflineFailure>()),
        );
      },
    );

    for (final (name, raw) in [
      ('not JSON', '{'),
      ('data not a list', '{"v":1,"at":"2026-10-29T12:00:00Z","data":{"a":1}}'),
      (
        'a row of the wrong shape',
        '{"v":1,"at":"2026-10-29T12:00:00Z","data":[{"id":1}]}',
      ),
      (
        'a list of non-maps',
        '{"v":1,"at":"2026-10-29T12:00:00Z","data":[1,2]}',
      ),
      ('an old format', '{"v":0,"at":"2026-10-29T12:00:00Z","data":[]}'),
    ]) {
      test('a corrupt For you copy ($name) is the offline error, not a '
          'crash', () async {
        // Save a real copy first, then spoil it under whatever key the app
        // uses (QA round 2: the key format changed with BUG-4).
        await container().read(forYouProvider.future);
        final key = store.values.keys.singleWhere(
          (k) => k.startsWith('cache.home.foryou.'),
        );
        final at = qaNow.toUtc().toIso8601String();
        await store.setString(key, raw.replaceAll('2026-10-29T12:00:00Z', at));
        deals.offline = true;
        await expectLater(
          container().read(forYouProvider.future),
          throwsA(isA<OfflineFailure>()),
        );
      });
    }
  });

  group('cache growth', () {
    test('the same interests picked in another order share one copy', () async {
      // No listener: the feed is built only when read, so no copy is saved
      // for the in-between interests. (QA round 2: counts copies instead of
      // naming keys, so it holds whatever the key format.)
      final c = container();
      final prefs = c.read(preferencesProvider.notifier);
      await prefs.toggleInterest('food');
      await prefs.toggleInterest('fashion');
      await c.read(forYouProvider.future);
      Iterable<String> copies() =>
          store.values.keys.where((k) => k.startsWith('cache.home.foryou.'));
      expect(copies(), hasLength(1));
      await prefs.toggleInterest('food');
      await prefs.toggleInterest('food'); // now [fashion, food]
      await c.read(forYouProvider.future);
      expect(c.read(preferencesProvider).interestIds, ['fashion', 'food']);
      expect(copies(), hasLength(1), reason: '${copies()}');
    });

    test(
      'copies past maxAge are removed, so the cache cannot only grow',
      () async {
        final c = container();
        for (final city in ['karachi', 'lahore', 'islamabad']) {
          await c.read(preferencesProvider.notifier).setCity(city);
          await c.read(trendingProvider.future);
        }
        final before = store.values.keys
            .where((k) => k.startsWith('cache.'))
            .length;
        expect(before, 3);
        deals.offline = true;
        clock = qaNow.add(const Duration(days: 30));
        for (final city in ['karachi', 'lahore', 'islamabad']) {
          await c.read(preferencesProvider.notifier).setCity(city);
          await expectLater(
            c.read(trendingProvider.future),
            throwsA(isA<OfflineFailure>()),
          );
        }
        expect(
          store.values.keys.where((k) => k.startsWith('cache.')),
          isEmpty,
          reason: 'month-old copies are never shown again',
        );
      },
    );

    test('size: one full For you copy', () async {
      await container().read(forYouProvider.future);
      final key = store.values.keys.singleWhere((k) => k.contains('foryou'));
      final bytes = utf8.encode(store.values[key]!).length;
      // 20 short demo-like cards; real cards (Urdu titles, offer text,
      // card banks, image paths) are larger. Recorded in docs/qa/4.3.md.
      expect(bytes, lessThan(20 * 1024));
    });
  });

  group('near me', () {
    test('two taps before the location answers: one request', () async {
      final c = container();
      final first = c.read(nearMeProvider.notifier).locate();
      final second = c.read(nearMeProvider.notifier).locate();
      await Future.wait([first, second]);
      expect(location.asked, 1);
      expect(c.read(nearMeProvider), isA<NearMeFound>());
    });
  });

  group('privacy', () {
    test('Near me results and the location are never cached', () async {
      final c = container();
      await c.read(nearMeProvider.notifier).locate();
      expect(c.read(nearMeProvider), isA<NearMeFound>());
      await c.read(forYouProvider.future);
      await c.read(trendingProvider.future);
      final all = store.values.entries.map((e) => '${e.key}=${e.value}');
      expect(all.where((s) => s.contains('near')), isEmpty);
      expect(
        all.where((s) => s.contains('24.81') || s.contains('67.03')),
        isEmpty,
      );
      for (final raw in store.values.values) {
        if (raw.contains('"data"')) {
          final data = (jsonDecode(raw) as Map)['data'];
          if (data is List) {
            for (final row in data.cast<Map<String, Object?>>()) {
              expect(row['distance_m'], isNull);
            }
          }
        }
      }
    });

    test('dealToRow round-trips every field of a full deal', () {
      final d = Deal(
        id: 'x',
        brandId: 'b',
        brandSlug: 's',
        brandName: 'B',
        brandNameUr: 'بی',
        brandLogoPath: 'b/logo.png',
        brandVerified: true,
        categoryId: 'c',
        categorySlug: 'cs',
        kind: 'bank_offer',
        scope: DealScope.local,
        status: DealStatus.pendingReview,
        titleEn: 'T',
        titleUr: 'ٹی',
        offerKind: OfferKind.percentOff,
        percent: 30,
        amountOffPkr: 100,
        pricePkr: 900,
        originalPricePkr: 1000,
        offerTextEn: 'o',
        offerTextUr: 'او',
        promoCode: 'P',
        url: 'https://e.com',
        imagePath: 'i.png',
        startsAt: qaNow,
        endsAt: qaNow.add(const Duration(days: 1)),
        verifiedAt: qaNow,
        publishedAt: qaNow,
        cardBanks: const ['HBL'],
        isFeatured: true,
        distanceMeters: 5,
      );
      final row = dealToRow(d);
      expect(row.values.where((v) => v == null), isEmpty);
      expect(
        dealToRow(
          dealFromRow(jsonDecode(jsonEncode(row)) as Map<String, Object?>),
        ),
        row,
      );
    });
  });
}
