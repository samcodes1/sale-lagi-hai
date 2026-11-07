import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/features/ads/application/ad_service.dart';
import 'package:sale_lagi_hai/features/ads/application/ads_providers.dart';
import 'package:sale_lagi_hai/features/ads/domain/ad_settings.dart';

final class _Gateway implements BackendGateway {
  new(this.rows);

  final List<Map<String, Object?>>? rows;
  TableQuery? query;

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    this.query = query;
    return rows ?? (throw StateError('offline'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Ads extends NoAdService {
  const new();

  @override
  bool get enabled => true;
}

void main() {
  group('AdSettings.fromMap', () {
    test('an empty row is the defaults', () {
      final s = AdSettings.fromMap(const {});
      expect(s.enabled, isTrue);
      expect(s.nativeEnabled, isTrue);
      expect(s.feedAdEvery, 6);
      expect(s.interstitialBreaks, 3);
      expect(s.interstitialGap, const Duration(minutes: 2));
      expect(s.interstitialMaxPerSession, 8);
      expect(s.appOpenEnabled, isTrue);
      expect(s.appOpenMinLaunches, 2);
      expect(s.appOpenGap, const Duration(hours: 1));
    });

    test('reads every column', () {
      final s = AdSettings.fromMap(const {
        'enabled': false,
        'native_enabled': false,
        'feed_ad_every': 8,
        'interstitial_breaks': 4,
        'interstitial_gap_seconds': 300,
        'interstitial_max_per_session': 5,
        'app_open_enabled': false,
        'app_open_min_launches': 3,
        'app_open_gap_minutes': 120,
      });
      expect(s.enabled, isFalse);
      expect(s.nativeEnabled, isFalse);
      expect(s.feedAdEvery, 8);
      expect(s.interstitialBreaks, 4);
      expect(s.interstitialGap, const Duration(minutes: 5));
      expect(s.interstitialMaxPerSession, 5);
      expect(s.appOpenEnabled, isFalse);
      expect(s.appOpenMinLaunches, 3);
      expect(s.appOpenGap, const Duration(hours: 2));
    });

    test('holds values to policy-safe bounds', () {
      final dense = AdSettings.fromMap(const {
        'feed_ad_every': 1,
        'interstitial_breaks': 0,
        'interstitial_gap_seconds': 5,
        'interstitial_max_per_session': 100,
        'app_open_min_launches': 0,
        'app_open_gap_minutes': 1,
      });
      expect(dense.feedAdEvery, 4);
      expect(dense.interstitialBreaks, 2);
      expect(dense.interstitialGap, const Duration(minutes: 1));
      expect(dense.interstitialMaxPerSession, 12);
      expect(dense.appOpenMinLaunches, 1);
      expect(dense.appOpenGap, const Duration(minutes: 30));
    });

    test('a value of the wrong type is the default', () {
      final s = AdSettings.fromMap(const {
        'enabled': 'no',
        'feed_ad_every': '2',
      });
      expect(s.enabled, isTrue);
      expect(s.feedAdEvery, 6);
    });
  });

  group('adSettingsProvider', () {
    ProviderContainer container(BackendGateway backend, {AdService? ads}) {
      final c = ProviderContainer(
        overrides: [
          adServiceProvider.overrideWithValue(ads ?? const _Ads()),
          backendGatewayProvider.overrideWithValue(backend),
          loggerProvider.overrideWithValue(
            AppLogger(minLevel: LogLevel.error, sinks: const []),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('reads the one row', () async {
      final backend = _Gateway([
        {'feed_ad_every': 10},
      ]);
      final c = container(backend);
      expect((await c.read(adSettingsProvider.future)).feedAdEvery, 10);
      expect(backend.query?.table, 'ad_settings');
      expect(backend.query?.limit, 1);
    });

    test('no row, or a failure, means the defaults', () async {
      expect(
        (await container(_Gateway(const [])).read(adSettingsProvider.future))
            .feedAdEvery,
        6,
      );
      expect(
        (await container(_Gateway(null)).read(adSettingsProvider.future))
            .enabled,
        isTrue,
      );
    });

    test('a build without ads never asks', () async {
      final backend = _Gateway(const []);
      await container(
        backend,
        ads: const NoAdService(),
      ).read(adSettingsProvider.future);
      expect(backend.query, isNull);
    });

    test('the demo backend has the defaults', () async {
      final c = container(DemoGateway());
      expect((await c.read(adSettingsProvider.future)).enabled, isTrue);
    });

    test('the defaults hold until staff settings load', () async {
      final c = container(
        _Gateway([
          {'enabled': false},
        ]),
      );
      expect(c.read(currentAdSettingsProvider).enabled, isTrue);
      await c.read(adSettingsProvider.future);
      expect(c.read(currentAdSettingsProvider).enabled, isFalse);
    });
  });
}
