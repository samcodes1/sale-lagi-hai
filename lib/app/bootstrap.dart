import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/errors/crash_reporter.dart';
import 'package:sale_lagi_hai/core/errors/error_handlers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/state/retry_policy.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/core/storage/secure_store.dart';
import 'package:sale_lagi_hai/design_system/fonts/font_licenses.dart';

/// Validates the build config, installs error handling, connects the
/// backend and starts the app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Error handling first, so even a misconfigured build logs through the
  // redacting logger instead of Flutter's default handlers.
  const CrashReporter crashReporter = NoopCrashReporter();
  final logger = createLogger(crashReporter: crashReporter);
  installErrorHandlers(logger);

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment()..verifyBuildFlavor(appFlavor);
  } on AppConfigException catch (e) {
    logger.error(
      'Invalid app configuration',
      context: {'problems': e.problems},
    );
    runApp(ConfigErrorApp(problems: e.problems));
    return;
  }

  logger.info('App starting', context: {'flavor': config.flavor.name});
  registerFontLicenses();
  final settings = await loadStartupSettings(logger);

  final BackendGateway backend;
  try {
    backend = await createBackend(config, FlutterSecureStore(logger: logger));
  } on Object catch (error, stackTrace) {
    logger.error(
      'Backend could not start',
      error: error,
      stackTrace: stackTrace,
    );
    runApp(const ConfigErrorApp(problems: ['The backend could not start.']));
    return;
  }

  runApp(
    ProviderScope(
      retry: appRetryPolicy,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        loggerProvider.overrideWithValue(logger),
        crashReporterProvider.overrideWithValue(crashReporter),
        if (settings.store case final store?)
          keyValueStoreProvider.overrideWithValue(store),
        savedLocaleProvider.overrideWithValue(settings.locale),
        backendGatewayProvider.overrideWithValue(backend),
        demoModeProvider.overrideWithValue(!config.hasBackend),
      ],
      child: const App(),
    ),
  );
}

/// Debug builds log everything to the console; release builds log nothing
/// to the console and send info and above to crash reporting.
@visibleForTesting
AppLogger createLogger({
  required CrashReporter crashReporter,
  bool isReleaseMode = kReleaseMode,
}) => AppLogger(
  minLevel: isReleaseMode ? LogLevel.info : LogLevel.debug,
  sinks: [
    if (!isReleaseMode) const ConsoleLogSink(),
    CrashReporterLogSink(crashReporter),
  ],
);

/// Settings needed before the first frame, so the app opens in the right
/// language without a flash.
typedef StartupSettings = ({KeyValueStore? store, Locale? locale});

/// Reads [StartupSettings]. Never throws: if storage is unavailable the app
/// starts with defaults (and the error is logged).
@visibleForTesting
Future<StartupSettings> loadStartupSettings(
  AppLogger logger, {
  KeyValueStore Function() openStore = SharedPrefsKeyValueStore.new,
}) async {
  try {
    final store = openStore();
    final code = await store.getString(localeStorageKey);
    return (
      store: store,
      locale: code == null ? null : AppLocales.resolve(Locale(code)),
    );
  } on Object catch (error) {
    logger.warning('Could not read saved settings', error: error);
    return (store: null, locale: null);
  }
}
