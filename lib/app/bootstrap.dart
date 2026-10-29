import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/errors/crash_reporter.dart';
import 'package:sale_lagi_hai/core/errors/error_handlers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/state/retry_policy.dart';

/// Validates the build config, installs error handling and starts the app.
///
/// Backend setup is added here in Phase 2.
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

  runApp(
    ProviderScope(
      retry: appRetryPolicy,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        loggerProvider.overrideWithValue(logger),
        crashReporterProvider.overrideWithValue(crashReporter),
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
