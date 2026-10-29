import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/data/preferences_store.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../../helpers/fakes.dart';

final class _BrokenStore implements KeyValueStore {
  final _inner = InMemoryKeyValueStore();

  @override
  Future<String?> getString(String key) => _inner.getString(key);

  @override
  Future<void> setString(String key, String value) async =>
      throw StateError('disk full');

  @override
  Future<void> remove(String key) => _inner.remove(key);

  @override
  Future<Set<String>> keys() => _inner.keys();

  @override
  Future<void> clear() => _inner.clear();
}

void main() {
  final asked = DateTime.utc(2026, 10, 29, 9);
  final full = ShopperPreferences(
    onboarded: true,
    cityId: 'c1',
    interestIds: const ['a', 'b'],
    brandIds: const ['x'],
    alertsAskedAt: asked,
  );

  group('ShopperPreferences', () {
    test('round-trips through JSON', () {
      expect(
        ShopperPreferences.fromJson(jsonDecode(jsonEncode(full.toJson()))),
        full,
      );
    });

    test('malformed fields fall back one by one, never throw', () {
      final decoded = ShopperPreferences.fromJson(const {
        'onboarded': 'yes',
        'city_id': 42,
        'interest_ids': ['a', 7, '', null, 'b'],
        'brand_ids': 'x',
        'alerts_asked_at': 'not a date',
      });
      expect(decoded.onboarded, isFalse);
      expect(decoded.cityId, isNull);
      expect(decoded.interestIds, ['a', 'b']);
      expect(decoded.brandIds, isEmpty);
      expect(decoded.alertsAskedAt, isNull);
      expect(ShopperPreferences.fromJson('junk'), const ShopperPreferences());
      expect(ShopperPreferences.fromJson(null), const ShopperPreferences());
    });

    test('copyWith can clear the city', () {
      expect(full.copyWith(cityId: () => null).cityId, isNull);
      expect(full.copyWith().cityId, 'c1');
    });

    test('equality compares the lists, and toString holds no ids', () {
      expect(full, full.copyWith(interestIds: ['a', 'b']));
      expect(full == full.copyWith(interestIds: ['b', 'a']), isFalse);
      expect(full.hashCode, full.copyWith(brandIds: ['x']).hashCode);
      expect(full.toString(), isNot(contains('c1')));
    });
  });

  group('PreferencesStore', () {
    test('reads back what it wrote; nothing saved is a first launch', () async {
      final store = PreferencesStore(InMemoryKeyValueStore());
      expect(await store.read(), const ShopperPreferences());
      await store.write(full);
      expect(await store.read(), full);
    });

    test('a corrupt file reads as a first launch', () async {
      final raw = InMemoryKeyValueStore()
        ..values[PreferencesStore.key] = '{not json';
      expect(await PreferencesStore(raw).read(), const ShopperPreferences());
    });
  });

  group('PreferencesController', () {
    late InMemoryKeyValueStore store;
    late MemoryLogSink sink;

    ProviderContainer container({
      ShopperPreferences saved = const ShopperPreferences(),
      KeyValueStore? kv,
    }) {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(kv ?? store),
          loggerProvider.overrideWithValue(AppLogger(sinks: [sink])),
          savedPreferencesProvider.overrideWithValue(saved),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      store = InMemoryKeyValueStore();
      sink = MemoryLogSink();
    });

    test('starts from the saved preferences', () {
      final c = container(saved: full);
      expect(c.read(preferencesProvider), full);
      expect(c.read(onboardedProvider), isTrue);
    });

    test('every change applies and is saved', () async {
      final c = container();
      final controller = c.read(preferencesProvider.notifier);
      await controller.setCity('c1');
      await controller.toggleInterest('a');
      await controller.toggleInterest('b');
      await controller.toggleInterest('a');
      await controller.toggleBrand('x');
      await controller.markAlertsAsked(asked);
      expect(c.read(onboardedProvider), isFalse);
      await controller.completeOnboarding();
      expect(c.read(onboardedProvider), isTrue);
      expect(c.read(preferencesProvider), full.copyWith(interestIds: ['b']));
      expect(await PreferencesStore(store).read(), c.read(preferencesProvider));
    });

    test('a failed save is logged and the change still holds', () async {
      final c = container(kv: _BrokenStore());
      await c.read(preferencesProvider.notifier).completeOnboarding();
      expect(c.read(onboardedProvider), isTrue);
      expect(sink.records.single.message, contains('Could not save'));
    });
  });
}
