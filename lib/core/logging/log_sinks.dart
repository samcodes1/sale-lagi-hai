import 'package:flutter/foundation.dart';
import 'package:sale_lagi_hai/core/errors/crash_reporter.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';

/// Writes to the debug console (`flutter run` output and logcat). Only
/// installed in debug builds. Records are already redacted.
final class ConsoleLogSink implements LogSink {
  const new({this._output});

  /// Where lines go: [debugPrint] unless replaced (tests).
  final DebugPrintCallback? _output;

  @override
  void write(LogRecord record) {
    final output = _output ?? debugPrint;
    final context = record.context.isEmpty ? '' : ' ${record.context}';
    output('[slh.${record.level.name}] ${record.message}$context');
    if (record.errorText != null) {
      output('  ${record.errorType}: ${record.errorText}');
    }
    if (record.stackTrace != null) output('${record.stackTrace}');
  }
}

/// Forwards logs to crash reporting: info as breadcrumbs (context for the
/// next crash), warnings and errors as reported events.
final class CrashReporterLogSink implements LogSink {
  const new(this._reporter);

  final CrashReporter _reporter;

  @override
  void write(LogRecord record) {
    switch (record.level) {
      case LogLevel.debug:
        return;
      case LogLevel.info:
        _reporter.addBreadcrumb(record.message);
      case LogLevel.warning || LogLevel.error:
        _reporter.recordError(
          message: record.message,
          errorType: record.errorType,
          errorText: record.errorText,
          stackTrace: record.stackTrace,
          fatal: false,
        );
    }
  }
}

/// Keeps records in memory, for tests.
final class MemoryLogSink implements LogSink {
  final records = <LogRecord>[];

  @override
  void write(LogRecord record) => records.add(record);
}
