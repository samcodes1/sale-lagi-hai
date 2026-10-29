import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// Routes every uncaught error to [logger], so nothing fails silently and
/// nothing reaches the console unredacted.
///
/// - Framework errors (build, layout, paint) via [FlutterError.onError].
/// - Uncaught async and platform errors via [PlatformDispatcher.onError].
/// - In release builds, a broken widget renders [ReleaseErrorWidget]
///   instead of the grey error box.
void installErrorHandlers(
  AppLogger logger, {
  PlatformDispatcher? dispatcher,
  bool isReleaseMode = kReleaseMode,
}) {
  FlutterError.onError = (details) {
    logger.error(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
      context: {'library': details.library ?? 'unknown'},
    );
    if (!isReleaseMode) FlutterError.presentError(details);
  };

  (dispatcher ?? PlatformDispatcher.instance).onError = (error, stackTrace) {
    logger.error('Uncaught error', error: error, stackTrace: stackTrace);
    // Handled: don't let the engine also print it unredacted.
    return true;
  };

  if (isReleaseMode) {
    ErrorWidget.builder = (_) => const ReleaseErrorWidget();
  }
}

/// A quiet placeholder for a widget that failed to build in production.
/// It shows no error text, which could expose internals.
class ReleaseErrorWidget extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0x00000000),
      child: Center(
        child: Icon(Icons.error_outline, size: 24, color: BrandColors.surma500),
      ),
    );
  }
}
