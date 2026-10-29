import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/app/bootstrap.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../../helpers/fakes.dart';

/// Storage whose reads and writes fail, like a broken disk.
final class _FailingStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) async => throw StateError('disk');

  @override
  Future<void> setString(String key, String value) async =>
      throw StateError('disk full');

  @override
  Future<void> remove(String key) async {}

  @override
  Future<Set<String>> keys() async => {};

  @override
  Future<void> clear() async {}
}

void main() {
  group('AppLocales.resolve', () {
    test('Urdu in any region is Urdu', () {
      expect(AppLocales.resolve(const Locale('ur', 'PK')), AppLocales.urdu);
      expect(AppLocales.resolve(const Locale('ur', 'IN')), AppLocales.urdu);
    });

    test('everything else is English', () {
      for (final locale in const [
        Locale('en', 'PK'),
        Locale('fr'),
        Locale('ar'),
        Locale('pa'),
      ]) {
        expect(AppLocales.resolve(locale), AppLocales.english);
      }
      expect(AppLocales.resolve(null), AppLocales.english);
    });

    test('only Urdu is right-to-left', () {
      expect(AppLocales.isRtl(AppLocales.urdu), isTrue);
      expect(AppLocales.isRtl(AppLocales.english), isFalse);
      expect(AppLocales.supported, [AppLocales.english, AppLocales.urdu]);
    });
  });

  group('LocaleController', () {
    late InMemoryKeyValueStore store;
    late MemoryLogSink sink;

    ProviderContainer container({
      Locale device = const Locale('en', 'US'),
      Locale? saved,
      KeyValueStore? storage,
    }) {
      final c = ProviderContainer(
        overrides: [
          deviceLocaleProvider.overrideWithValue(device),
          savedLocaleProvider.overrideWithValue(saved),
          keyValueStoreProvider.overrideWithValue(storage ?? store),
          loggerProvider.overrideWithValue(AppLogger(sinks: [sink])),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      store = InMemoryKeyValueStore();
      sink = MemoryLogSink();
    });

    test('defaults to the phone language when nothing is saved', () {
      expect(
        container(device: const Locale('ur', 'PK'))
            .read(localeControllerProvider),
        AppLocales.urdu,
      );
      expect(
        container(device: const Locale('de')).read(localeControllerProvider),
        AppLocales.english,
      );
    });

    test('a saved choice wins over the phone language', () {
      expect(
        container(
          device: const Locale('ur'),
          saved: AppLocales.english,
        ).read(localeControllerProvider),
        AppLocales.english,
      );
    });

    test('select switches and saves the language', () async {
      final c = container();

      await c
          .read(localeControllerProvider.notifier)
          .select(const Locale('ur', 'PK'));

      expect(c.read(localeControllerProvider), AppLocales.urdu);
      expect(store.values[localeStorageKey], 'ur');
    });

    test(
      'a failed save still switches for this session, and is logged',
      () async {
        final c = container(storage: _FailingStore());

        await c.read(localeControllerProvider.notifier).select(AppLocales.urdu);

        expect(c.read(localeControllerProvider), AppLocales.urdu);
        expect(sink.records.single.level, LogLevel.warning);
      },
    );
  });

  group('loadStartupSettings', () {
    late MemoryLogSink sink;
    late AppLogger logger;

    setUp(() {
      sink = MemoryLogSink();
      logger = AppLogger(sinks: [sink]);
    });

    test('reads the saved language', () async {
      final store = InMemoryKeyValueStore()..values[localeStorageKey] = 'ur';

      final settings = await loadStartupSettings(
        logger,
        openStore: () => store,
      );

      expect(settings.store, same(store));
      expect(settings.locale, AppLocales.urdu);
    });

    test('nothing saved means no locale', () async {
      final settings = await loadStartupSettings(
        logger,
        openStore: InMemoryKeyValueStore.new,
      );

      expect(settings.locale, isNull);
      expect(settings.store, isNotNull);
    });

    test('an unknown saved value resolves to English', () async {
      final store = InMemoryKeyValueStore()..values[localeStorageKey] = 'xx';

      final settings = await loadStartupSettings(
        logger,
        openStore: () => store,
      );

      expect(settings.locale, AppLocales.english);
    });

    test('unavailable storage starts with defaults and logs', () async {
      final failing = await loadStartupSettings(
        logger,
        openStore: _FailingStore.new,
      );
      final throwing = await loadStartupSettings(
        logger,
        openStore: () => throw StateError('no plugin'),
      );

      const defaults = (
        store: null,
        locale: null,
        preferences: ShopperPreferences(),
      );
      expect(failing, defaults);
      expect(throwing, defaults);
      expect(sink.records, hasLength(2));
    });
  });
}
