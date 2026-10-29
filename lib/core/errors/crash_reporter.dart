/// Sends errors to a crash-reporting service.
///
/// Callers pass only redacted text (the logger does this). The Sentry
/// implementation arrives in sub-phase 8.4; until then [NoopCrashReporter]
/// is used.
abstract interface class CrashReporter {
  /// Records an error. [fatal] marks errors that crashed the app.
  void recordError({
    required String message,
    required bool fatal,
    String? errorType,
    String? errorText,
    StackTrace? stackTrace,
  });

  /// Adds a short note that is sent along with the next error.
  void addBreadcrumb(String message);
}

/// Discards everything.
final class NoopCrashReporter implements CrashReporter {
  const new();

  @override
  void recordError({
    required String message,
    required bool fatal,
    String? errorType,
    String? errorText,
    StackTrace? stackTrace,
  }) {}

  @override
  void addBreadcrumb(String message) {}
}
