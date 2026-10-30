import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/core/theme/theme_mode_controller.dart';

import '../../helpers/fakes.dart';

final class _BrokenStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> setString(String key, String value) =>
      Future.error(StateError('disk full'));

  @override
  Future<void> remove(String key) async {}

  @override
  Future<Set<String>> keys() async => {};

  @override
  Future<void> clear() async {}
}

void main() {
  test('names read back; anything else is the phone setting', () {
    for (final mode in AppThemeMode.values) {
      expect(AppThemeMode.fromName(mode.name), mode);
    }
    expect(AppThemeMode.fromName(null), AppThemeMode.system);
    expect(AppThemeMode.fromName('neon'), AppThemeMode.system);
    expect(AppThemeMode.system.brightness, isNull);
    expect(AppThemeMode.light.brightness, Brightness.light);
    expect(AppThemeMode.dark.brightness, Brightness.dark);
  });

  test(
    'starts from the saved choice; a new one applies and is saved',
    () async {
      final store = InMemoryKeyValueStore();
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          savedThemeModeProvider.overrideWithValue(AppThemeMode.dark),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(themeModeProvider), AppThemeMode.dark);
      await c.read(themeModeProvider.notifier).select(AppThemeMode.light);
      expect(c.read(themeModeProvider), AppThemeMode.light);
      expect(store.values[themeModeStorageKey], 'light');
    },
  );

  test('a failed save still switches, and logs only the error type', () async {
    final logs = MemoryLogSink();
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(_BrokenStore()),
        loggerProvider.overrideWithValue(AppLogger(sinks: [logs])),
      ],
    );
    addTearDown(c.dispose);
    await c.read(themeModeProvider.notifier).select(AppThemeMode.dark);
    expect(c.read(themeModeProvider), AppThemeMode.dark);
    expect(logs.records.single.context, {'error': 'StateError'});
    expect(logs.records.single.errorText, isNull);
  });
}
