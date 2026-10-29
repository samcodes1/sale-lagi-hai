import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';

final class _NetworkDown implements Exception;

void main() {
  late MemoryLogSink sink;
  late AppLogger logger;

  setUp(() {
    sink = MemoryLogSink();
    logger = AppLogger(sinks: [sink]);
  });

  AppFailure? offlineMapper(Object error, StackTrace _) =>
      error is _NetworkDown ? OfflineFailure(cause: error) : null;

  test('wraps a returned value in Success', () async {
    expect(await guard(() async => 7, logger: logger), const Success(7));
  });

  test('passes a thrown AppFailure through unchanged', () async {
    const failure = NotFoundFailure();

    final result = await guard<int>(() async => throw failure, logger: logger);

    expect(result.failureOrNull, same(failure));
    expect(sink.records, isEmpty);
  });

  test('uses a mapper that recognises the error', () async {
    final result = await guard<int>(
      () async => throw _NetworkDown(),
      mappers: [offlineMapper],
      logger: logger,
    );

    expect(result.failureOrNull, isA<OfflineFailure>());
    expect(result.failureOrNull!.cause, isA<_NetworkDown>());
    expect(sink.records, isEmpty, reason: 'mapped errors are expected');
  });

  test('tries mappers in order and the first match wins', () async {
    final calls = <String>[];
    AppFailure? skip(Object e, StackTrace s) {
      calls.add('skip');
      return null;
    }

    AppFailure? first(Object e, StackTrace s) {
      calls.add('first');
      return const ForbiddenFailure();
    }

    AppFailure? second(Object e, StackTrace s) {
      calls.add('second');
      return const NotFoundFailure();
    }

    final result = await guard<int>(
      () async => throw StateError('x'),
      mappers: [skip, first, second],
      logger: logger,
    );

    expect(result.failureOrNull, isA<ForbiddenFailure>());
    expect(calls, ['skip', 'first']);
  });

  test('maps TimeoutException to TimeoutFailure', () async {
    final result = await guard<int>(
      () => Completer<int>().future.timeout(Duration.zero),
      logger: logger,
    );

    expect(result.failureOrNull, isA<TimeoutFailure>());
  });

  test('turns unknown errors into a logged UnexpectedFailure', () async {
    final result = await guard<int>(
      () async => throw const FormatException('bad +923001234567'),
      logger: logger,
    );

    final failure = result.failureOrNull!;
    expect(failure, isA<UnexpectedFailure>());
    expect(failure.cause, isA<FormatException>());
    expect(failure.stackTrace, isNotNull);

    final record = sink.records.single;
    expect(record.level, LogLevel.error);
    expect(record.errorType, 'FormatException');
    expect(record.errorText, isNot(contains('923001234567')));
  });

  test('catches synchronous throws inside the body', () async {
    final result = await guard<int>(
      () => throw ArgumentError('sync'),
      logger: logger,
    );

    expect(result.failureOrNull, isA<UnexpectedFailure>());
  });

  test('mapError works without running anything', () {
    expect(
      mapError(_NetworkDown(), StackTrace.empty, mappers: [offlineMapper]),
      isA<OfflineFailure>(),
    );
    expect(
      mapError(const UnauthorizedFailure(), StackTrace.empty),
      isA<UnauthorizedFailure>(),
    );
    expect(mapError('anything', StackTrace.empty), isA<UnexpectedFailure>());
  });
}
