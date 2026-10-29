import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/errors/crash_reporter.dart';
import 'package:sale_lagi_hai/core/links/link_service.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/core/storage/json_cache.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/core/storage/secure_store.dart';

/// The app logger. Overridden in `bootstrap` with the configured sinks.
final loggerProvider = Provider<AppLogger>(
  (ref) => throw UnimplementedError(
    'loggerProvider must be overridden in bootstrap().',
  ),
);

final crashReporterProvider = Provider<CrashReporter>(
  (ref) => const NoopCrashReporter(),
);

/// Created lazily, on first use, so widget tests never touch the platform
/// plugin unless they override this.
final keyValueStoreProvider = Provider<KeyValueStore>(
  (ref) => SharedPrefsKeyValueStore(),
);

final jsonCacheProvider = Provider<JsonCache>(
  (ref) => JsonCache(
    ref.watch(keyValueStoreProvider),
    logger: ref.watch(loggerProvider),
  ),
);

final secureStoreProvider = Provider<SecureStore>(
  (ref) => FlutterSecureStore(logger: ref.watch(loggerProvider)),
);

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

/// The current network status, for UI hints such as the offline banner.
final networkStatusProvider = StreamProvider<NetworkStatus>(
  (ref) => ref.watch(connectivityServiceProvider).watch(),
);

/// Opens web pages, maps, WhatsApp and the dialler. Overridden in tests.
final linkServiceProvider = Provider<LinkService>(
  (ref) => const UrlLauncherLinkService(),
);
