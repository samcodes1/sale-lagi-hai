import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/features/ads/application/ad_service.dart';
import 'package:sale_lagi_hai/features/ads/application/ads_providers.dart';
import 'package:sale_lagi_hai/features/ads/domain/app_open_pacing.dart';

final class _Service extends NoAdService {
  new({this.enabled = true, this.ready = true});

  @override
  final bool enabled;

  final bool ready;
  bool fromAd = false;
  int shows = 0;

  @override
  Future<bool> showAppOpen() async {
    shows++;
    return ready;
  }

  @override
  bool takeAdActivity() {
    final value = fromAd;
    fromAd = false;
    return value;
  }
}

final class _Store implements KeyValueStore {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  var now = DateTime.utc(2026, 11, 3, 12);
  AppOpenPacing pacing({int launches = 2}) =>
      AppOpenPacing(clock: () => now, launches: launches);

  setUp(() => now = DateTime.utc(2026, 11, 3, 12));

  void wait(Duration time) => now = now.add(time);

  bool away(AppOpenPacing subject, Duration time, {bool fromAd = false}) {
    subject.onLeft();
    wait(time);
    return subject.onReturned(fromAd: fromAd);
  }

  test('shows after a real absence', () {
    expect(away(pacing(), const Duration(minutes: 2)), isTrue);
  });

  test('never on a first launch', () {
    expect(away(pacing(launches: 1), const Duration(hours: 1)), isFalse);
  });

  test('never after a short trip away', () {
    expect(away(pacing(), const Duration(seconds: 30)), isFalse);
  });

  test('never on coming back from an ad', () {
    expect(away(pacing(), const Duration(minutes: 5), fromAd: true), isFalse);
  });

  test('never without having left', () {
    expect(pacing().onReturned(fromAd: false), isFalse);
  });

  test('waits the gap after one showed', () {
    final subject = pacing();
    expect(away(subject, const Duration(minutes: 2)), isTrue);
    subject.markShown();
    expect(away(subject, const Duration(minutes: 30)), isFalse);
    expect(away(subject, const Duration(minutes: 31)), isTrue);
  });

  test('the absence counts from the first time it left', () {
    final subject = pacing()..onLeft();
    wait(const Duration(seconds: 40));
    subject.onLeft();
    wait(const Duration(seconds: 40));
    expect(subject.onReturned(fromAd: false), isTrue);
  });

  group('AppOpenAds', () {
    test('shows when the pacing allows, and counts only a real show', () async {
      final service = _Service(ready: false);
      final subject = pacing();
      final ads = AppOpenAds(service, subject)..onLeft();
      wait(const Duration(minutes: 2));
      ads.onReturned();
      await pumpEventQueue();
      expect(service.shows, 1);
      // Nothing showed, so the next return may try again.
      ads.onLeft();
      wait(const Duration(minutes: 2));
      ads.onReturned();
      await pumpEventQueue();
      expect(service.shows, 2);
    });

    test('skips a return from an ad', () async {
      final service = _Service()..fromAd = true;
      final ads = AppOpenAds(service, pacing())..onLeft();
      wait(const Duration(minutes: 2));
      ads.onReturned();
      await pumpEventQueue();
      expect(service.shows, 0);
      expect(service.fromAd, isFalse);
    });

    test('does nothing in a build without ads', () async {
      final service = _Service(enabled: false);
      final ads = AppOpenAds(service, pacing())..onLeft();
      wait(const Duration(minutes: 2));
      ads.onReturned();
      await pumpEventQueue();
      expect(service.shows, 0);
    });
  });

  group('appLaunchCountProvider', () {
    test('counts each run of the app', () async {
      final store = _Store();
      Future<int> run() async {
        final c = ProviderContainer(
          overrides: [
            keyValueStoreProvider.overrideWithValue(store),
            loggerProvider.overrideWithValue(
              AppLogger(minLevel: LogLevel.error, sinks: const []),
            ),
          ],
        );
        addTearDown(c.dispose);
        return await c.read(appLaunchCountProvider.future);
      }

      expect(await run(), 1);
      expect(await run(), 2);
      store.values['ads.launches'] = 'garbled';
      expect(await run(), 1);
    });
  });
}
