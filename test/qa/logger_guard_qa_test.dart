// QA (sub-phase 1.2): AppLogger, error handlers and guard() edge cases.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/app/bootstrap.dart';
import 'package:sale_lagi_hai/core/errors/error_handlers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';

import '../helpers/fakes.dart';

final class _BadToString implements Exception {
  @override
  String toString() => throw StateError('toString is broken');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryLogSink sink;
  late AppLogger logger;

  setUp(() {
    sink = MemoryLogSink();
    logger = AppLogger(sinks: [sink]);
  });

  group('AppLogger', () {
    test('every text field a sink sees is redacted', () {
      final reporter = RecordingCrashReporter();
      AppLogger(sinks: [sink, CrashReporterLogSink(reporter)])
        ..info('opened by 03001234567')
        ..error(
          'failed for a@b.co',
          error: Exception('token eyJa.eyJb.c'),
          context: {'note': 'sb_secret_abc'},
        );

      final all = [
        ...sink.records.expand(
          (r) => [r.message, r.errorText ?? '', ...r.context.values],
        ),
        ...reporter.breadcrumbs,
        ...reporter.errors.expand((e) => [e.message, e.errorText ?? '']),
      ].join('\n');
      for (final secret in ['03001234567', 'a@b.co', 'eyJa', 'sb_secret']) {
        expect(all, isNot(contains(secret)));
      }
    });

    test('errorType is the runtime type only, never the message', () {
      logger.error('x', error: const FormatException('user 03001234567'));

      expect(sink.records.single.errorType, 'FormatException');
    });

    test('info breadcrumbs drop the context entirely', () {
      final reporter = RecordingCrashReporter();
      AppLogger(sinks: [CrashReporterLogSink(reporter)])
          .info('Opened deal', context: {'dealId': 'd-1'});

      expect(reporter.breadcrumbs, ['Opened deal']);
    });

    test('release logger: debug is dropped before any redaction work', () {
      final reporter = RecordingCrashReporter();
      // Would throw if it were redacted (BUG-12); dropping it first is fine.
      createLogger(
        crashReporter: reporter,
        isReleaseMode: true,
      ).debug('noise', context: {'v': _BadToString()});

      expect(reporter.breadcrumbs, isEmpty);
      expect(reporter.errors, isEmpty);
    });

    test('BUG-12 (S4): an error whose toString() throws is still logged', () {
      expect(() => logger.error('x', error: _BadToString()), returnsNormally);
      expect(sink.records, hasLength(1));
    });
  });

  group('installErrorHandlers', () {
    setUp(() {
      final flutterOnError = FlutterError.onError;
      final presentError = FlutterError.presentError;
      final dispatcherOnError = PlatformDispatcher.instance.onError;
      final errorWidgetBuilder = ErrorWidget.builder;
      addTearDown(() {
        FlutterError.onError = flutterOnError;
        FlutterError.presentError = presentError;
        PlatformDispatcher.instance.onError = dispatcherOnError;
        ErrorWidget.builder = errorWidgetBuilder;
      });
    });

    test('release builds never present (print) the raw error', () {
      final presented = <FlutterErrorDetails>[];
      FlutterError.presentError = presented.add;
      installErrorHandlers(logger, isReleaseMode: true);

      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('for 03001234567')),
      );

      expect(presented, isEmpty);
      expect(sink.records.single.errorText, isNot(contains('03001234567')));
    });
  });

  group('guard()', () {
    test('Errors (bugs) become a logged UnexpectedFailure', () async {
      final result = await guard<int>(
        () async => throw TypeError(),
        logger: logger,
      );

      expect(result.failureOrNull, isA<UnexpectedFailure>());
      expect(sink.records.single.level, LogLevel.error);
    });

    test('a mapper runs before the built-in TimeoutException rule', () {
      final failure = mapError(
        TimeoutException('slow'),
        StackTrace.empty,
        mappers: [(_, _) => const OfflineFailure()],
      );

      expect(failure, isA<OfflineFailure>());
    });

    test("awaiting a failed provider's future yields its AppFailure, not "
        'ProviderException', () async {
      final source = FutureProvider<int>(
        (ref) async => throw const OfflineFailure(),
        retry: (_, _) => null,
      );
      final guarded = FutureProvider<Result<int>>(
        (ref) => guard(() => ref.watch(source.future), logger: logger),
        retry: (_, _) => null,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(guarded, (_, _) {});
      addTearDown(sub.close);

      final result = await container.read(guarded.future);

      expect(result.failureOrNull, isA<OfflineFailure>());
      expect(sink.records, isEmpty);
    });

    test('BUG-12 (S4): a throwing mapper does not escape guard()', () async {
      final result = await guard<int>(
        () async => throw StateError('x'),
        mappers: [(_, _) => throw ArgumentError('mapper bug')],
        logger: logger,
      );
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });

    test('BUG-12 (S4): an error with a throwing toString() does not escape '
        'guard()', () async {
      final result = await guard<int>(
        () async => throw _BadToString(),
        logger: logger,
      );
      expect(result.failureOrNull, isA<UnexpectedFailure>());
    });
  });
}
