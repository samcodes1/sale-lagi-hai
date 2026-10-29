import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/core/logging/log_redactor.dart';

enum LogLevel { debug, info, warning, error }

/// One log entry. Everything in it has already been redacted, so sinks can
/// write or upload it as-is.
@immutable
final class LogRecord {
  const new({
    required this.level,
    required this.message,
    required this.time,
    this.context = const {},
    this.errorType,
    this.errorText,
    this.stackTrace,
  });

  final LogLevel level;
  final String message;
  final DateTime time;
  final Map<String, String> context;

  /// The error's runtime type, e.g. `FormatException`.
  final String? errorType;

  /// The redacted `toString()` of the error.
  final String? errorText;
  final StackTrace? stackTrace;
}

/// A destination for log records: the debug console, crash reporting, or a
/// test buffer.
abstract interface class LogSink {
  void write(LogRecord record);
}

/// The app's only logger. Use it instead of `print`/`debugPrint`.
///
/// Every message, context value and error description passes through the
/// [LogRedactor] before any sink sees it. Never log request bodies, tokens,
/// phone numbers or precise locations, even so.
final class AppLogger {
  new({
    required List<LogSink> sinks,
    this.minLevel = LogLevel.debug,
    this._redactor = const LogRedactor(),
    DateTime Function()? clock,
  }) : _sinks = List.unmodifiable(sinks),
       _clock = clock ?? DateTime.now;

  final List<LogSink> _sinks;
  final LogRedactor _redactor;
  final DateTime Function() _clock;

  /// Records below this level are dropped.
  final LogLevel minLevel;

  void debug(String message, {Map<String, Object?> context = const {}}) =>
      log(LogLevel.debug, message, context: context);

  void info(String message, {Map<String, Object?> context = const {}}) =>
      log(LogLevel.info, message, context: context);

  void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) => log(
    LogLevel.warning,
    message,
    error: error,
    stackTrace: stackTrace,
    context: context,
  );

  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) => log(
    LogLevel.error,
    message,
    error: error,
    stackTrace: stackTrace,
    context: context,
  );

  void log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    if (level.index < minLevel.index) return;
    final record = LogRecord(
      level: level,
      message: _redactor.redact(message),
      time: _clock(),
      context: _redactor.redactContext(context),
      errorType: error?.runtimeType.toString(),
      errorText: error == null
          ? null
          : _redactor.redact(LogRedactor.describe(error)),
      stackTrace: stackTrace,
    );
    for (final sink in _sinks) {
      // A broken sink must never take the app down or block other sinks.
      try {
        sink.write(record);
      } on Object {
        // Nowhere safe to report this; drop it.
      }
    }
  }
}
