import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sale_lagi_hai/app/bootstrap.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/errors/crash_reporter.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/core/storage/secure_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/fakes.dart';

class _MockConnectivity extends Mock implements Connectivity;

void main() {
  test('loggerProvider must be overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(loggerProvider),
      throwsA(
        predicate((e) => '$e'.contains('loggerProvider must be overridden')),
      ),
    );
  });

  test('default providers build real implementations', () {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final container = ProviderContainer(
      overrides: [loggerProvider.overrideWithValue(AppLogger(sinks: []))],
    );
    addTearDown(container.dispose);

    expect(container.read(crashReporterProvider), isA<NoopCrashReporter>());
    expect(
      container.read(keyValueStoreProvider),
      isA<SharedPrefsKeyValueStore>(),
    );
    expect(container.read(secureStoreProvider), isA<FlutterSecureStore>());
    expect(
      container.read(connectivityServiceProvider),
      isA<ConnectivityService>(),
    );
  });

  test('jsonCacheProvider uses the overridden store', () async {
    final store = InMemoryKeyValueStore();
    final container = ProviderContainer(
      overrides: [
        loggerProvider.overrideWithValue(AppLogger(sinks: [])),
        keyValueStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    await container.read(jsonCacheProvider).put('k', 1);

    expect(store.values.keys, ['cache.k']);
  });

  test('networkStatusProvider streams connectivity changes', () async {
    final connectivity = _MockConnectivity();
    final changes = StreamController<List<ConnectivityResult>>();
    // close() only completes once a listener gets the done event, so don't
    // wait for it.
    addTearDown(() => unawaited(changes.close()));
    when(connectivity.checkConnectivity)
        .thenAnswer((_) async => [ConnectivityResult.none]);
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => changes.stream);

    final container = ProviderContainer(
      overrides: [
        connectivityServiceProvider.overrideWithValue(
          ConnectivityService(connectivity),
        ),
      ],
    );
    addTearDown(container.dispose);
    final statuses = <NetworkStatus>[];
    final sub = container.listen(
      networkStatusProvider,
      (_, next) => next.whenData(statuses.add),
    );
    addTearDown(sub.close);

    await pumpEventQueue();
    changes.add([ConnectivityResult.wifi]);
    await pumpEventQueue();

    expect(statuses, [NetworkStatus.offline, NetworkStatus.online]);
  });

  group('createLogger', () {
    test('debug builds log everything, including to the console', () {
      final logger = createLogger(crashReporter: const NoopCrashReporter());

      expect(logger.minLevel, LogLevel.debug);
    });

    test('release builds skip debug logs and send info+ to crash '
        'reporting', () {
      final reporter = RecordingCrashReporter();
      createLogger(crashReporter: reporter, isReleaseMode: true)
        ..debug('dropped')
        ..info('breadcrumb')
        ..error('reported');

      expect(reporter.breadcrumbs, ['breadcrumb']);
      expect(reporter.errors.single.message, 'reported');
    });
  });

  test('MemoryLogSink is usable as a LogSink', () {
    final LogSink sink = MemoryLogSink();
    expect(sink, isA<MemoryLogSink>());
  });
}
