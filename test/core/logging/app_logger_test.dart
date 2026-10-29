import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/errors/crash_reporter.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';

import '../../helpers/fakes.dart';

final class _ThrowingSink implements LogSink {
  @override
  void write(LogRecord record) => throw StateError('sink broken');
}

void main() {
  final fixedTime = DateTime.utc(2026, 10, 29, 12);

  group('AppLogger', () {
    test('drops records below minLevel', () {
      final sink = MemoryLogSink();
      AppLogger(sinks: [sink], minLevel: LogLevel.warning)
        ..debug('d')
        ..info('i')
        ..warning('w')
        ..error('e');

      expect(sink.records.map((r) => r.level), [
        LogLevel.warning,
        LogLevel.error,
      ]);
    });

    test('builds records with time, context and error details', () {
      final sink = MemoryLogSink();
      final stack = StackTrace.current;
      AppLogger(sinks: [sink], clock: () => fixedTime).error(
        'Load failed',
        error: const FormatException('bad'),
        stackTrace: stack,
        context: {'dealId': 'd-1'},
      );

      final record = sink.records.single;
      expect(record.message, 'Load failed');
      expect(record.time, fixedTime);
      expect(record.context, {'dealId': 'd-1'});
      expect(record.errorType, 'FormatException');
      expect(record.errorText, contains('bad'));
      expect(record.stackTrace, same(stack));
    });

    test('redacts message, context and error before any sink', () {
      final sink = MemoryLogSink();
      AppLogger(sinks: [sink]).warning(
        'OTP sent to 03001234567',
        error: Exception('user ali@example.com'),
        context: {'fcmToken': 'abc', 'note': 'at 24.861, 67.001'},
      );

      final record = sink.records.single;
      expect(record.message, 'OTP sent to [phone]');
      expect(record.errorText, contains('[email]'));
      expect(record.context, {
        'fcmToken': '[redacted]',
        'note': 'at [location]',
      });
    });

    test('a broken sink does not stop the others or throw', () {
      final sink = MemoryLogSink();
      final logger = AppLogger(sinks: [_ThrowingSink(), sink]);

      expect(() => logger.info('still logged'), returnsNormally);
      expect(sink.records.single.message, 'still logged');
    });

    test('records without an error have no error fields', () {
      final sink = MemoryLogSink();
      AppLogger(sinks: [sink]).info('hello');

      expect(sink.records.single.errorType, isNull);
      expect(sink.records.single.errorText, isNull);
    });
  });

  group('CrashReporterLogSink', () {
    test('ignores debug, sends info as breadcrumbs, reports warnings and '
        'errors', () {
      final reporter = RecordingCrashReporter();
      AppLogger(sinks: [CrashReporterLogSink(reporter)])
        ..debug('noise')
        ..info('Opened deal')
        ..warning('Slow feed')
        ..error('Crash', error: StateError('boom'));

      expect(reporter.breadcrumbs, ['Opened deal']);
      expect(reporter.errors.map((e) => e.message), ['Slow feed', 'Crash']);
      expect(reporter.errors.every((e) => !e.fatal), isTrue);
      expect(reporter.errors.last.errorType, 'StateError');
    });
  });

  test('ConsoleLogSink prints the message, error and stack trace', () {
    final lines = <String?>[];
    final stack = StackTrace.current;
    AppLogger(
      sinks: [ConsoleLogSink(output: (line, {wrapWidth}) => lines.add(line))],
    ).error(
      'Feed failed',
      error: StateError('for 03001234567'),
      stackTrace: stack,
      context: {'dealId': 'd-1'},
    );

    expect(lines, [
      '[slh.error] Feed failed {dealId: d-1}',
      '  StateError: Bad state: for [phone]',
      '$stack',
    ]);
  });

  test('ConsoleLogSink writes without throwing', () {
    final logger = AppLogger(sinks: [const ConsoleLogSink()]);

    for (final level in LogLevel.values) {
      expect(
        () => logger.log(
          level,
          'msg',
          error: level == LogLevel.error ? StateError('x') : null,
          context: {'k': 'v'},
        ),
        returnsNormally,
      );
    }
  });

  test('NoopCrashReporter accepts everything', () {
    const reporter = NoopCrashReporter();

    expect(
      () => reporter
        ..recordError(message: 'm', fatal: true)
        ..addBreadcrumb('b'),
      returnsNormally,
    );
  });
}
