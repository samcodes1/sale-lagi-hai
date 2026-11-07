import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/splash/brand_splash.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/errors/crash_reporter.dart';
import 'package:sale_lagi_hai/core/errors/error_handlers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/state/retry_policy.dart';
import 'package:sale_lagi_hai/core/storage/json_cache.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/core/storage/secure_store.dart';
import 'package:sale_lagi_hai/core/theme/theme_mode_controller.dart';
import 'package:sale_lagi_hai/design_system/fonts/font_licenses.dart';
import 'package:sale_lagi_hai/features/ads/application/ads_providers.dart';
import 'package:sale_lagi_hai/features/ads/data/ad_service_factory.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/data/google_id_token.dart';
import 'package:sale_lagi_hai/features/auth/data/supabase_auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/data/preferences_store.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

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
  if (settings.store case final store?) {
    unawaited(
      JsonCache(store, logger: logger).prune('home.', maxAge: homeCacheMaxAge),
    );
  }

  final Backend backend;
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
        savedThemeModeProvider.overrideWithValue(settings.theme),
        savedPreferencesProvider.overrideWithValue(settings.preferences),
        backendGatewayProvider.overrideWithValue(backend.gateway),
        authRepositoryProvider.overrideWithValue(
          createAuthRepository(config, backend.supabase, logger),
        ),
        demoModeProvider.overrideWithValue(!config.hasBackend),
        adServiceProvider.overrideWithValue(createAdService(config, logger)),
      ],
      child: const BrandSplash(child: App()),
    ),
  );
}

/// Supabase Auth when there is a backend, else the demo sign-in. Google is
/// offered only when this build has its client ID and the platform has
/// native sign-in.
@visibleForTesting
AuthRepository createAuthRepository(
  AppConfig config,
  SupabaseClient? supabase,
  AppLogger logger,
) {
  final google = config.hasGoogleSignIn && PluginGoogleIdTokenSource.supported;
  if (supabase == null) return DemoAuthRepository(googleAvailable: google);
  return SupabaseAuthRepository(
    supabase,
    logger,
    google: google
        ? PluginGoogleIdTokenSource(config.googleServerClientId)
        : null,
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
/// language, and on the right screen (onboarding or Home), without a flash.
///
/// `preferences` is `null` when they couldn't be read (not when nothing was
/// saved): the app then never overwrites them with defaults (QA 4.1 BUG-1).
typedef StartupSettings = ({
  KeyValueStore? store,
  Locale? locale,
  ShopperPreferences? preferences,
  AppThemeMode theme,
});

/// Reads [StartupSettings]. Never throws: if storage is unavailable the app
/// starts with defaults (and the error is logged). Each value is read on
/// its own, so one failing read doesn't hide the other.
@visibleForTesting
Future<StartupSettings> loadStartupSettings(
  AppLogger logger, {
  KeyValueStore Function() openStore = SharedPrefsKeyValueStore.new,
}) async {
  final KeyValueStore store;
  try {
    store = openStore();
  } on Object catch (error) {
    logger.warning('Could not read saved settings', error: error);
    return (
      store: null,
      locale: null,
      preferences: null,
      theme: AppThemeMode.system,
    );
  }
  Locale? locale;
  try {
    final code = await store.getString(localeStorageKey);
    locale = code == null ? null : AppLocales.resolve(Locale(code));
  } on Object catch (error) {
    logger.warning('Could not read the saved language', error: error);
  }
  ShopperPreferences? preferences;
  try {
    preferences = await PreferencesStore(store).read();
  } on Object catch (error) {
    logger.warning('Could not read the saved preferences', error: error);
  }
  var theme = AppThemeMode.system;
  try {
    theme = AppThemeMode.fromName(await store.getString(themeModeStorageKey));
  } on Object catch (error) {
    logger.warning('Could not read the saved theme', error: error);
  }
  return (store: store, locale: locale, preferences: preferences, theme: theme);
}
