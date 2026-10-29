import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';

void main() {
  test('retryability per failure type', () {
    final expectations = <AppFailure, bool>{
      const OfflineFailure(): true,
      const TimeoutFailure(): true,
      const ServerFailure(): true,
      const ServerFailure(statusCode: 503): true,
      const ServerFailure(statusCode: 500): true,
      const ServerFailure(statusCode: 404): false,
      const ServerFailure(statusCode: 499): false,
      const UnauthorizedFailure(): false,
      const ForbiddenFailure(): false,
      const NotFoundFailure(): false,
      const ValidationFailure(): false,
      const RateLimitedFailure(): true,
      const StorageFailure(): false,
      const UnexpectedFailure(): false,
    };

    for (final MapEntry(key: failure, value: retryable)
        in expectations.entries) {
      expect(failure.isRetryable, retryable, reason: '$failure');
    }
  });

  test('every failure type has a distinct, stable code', () {
    const failures = <AppFailure>[
      OfflineFailure(),
      TimeoutFailure(),
      ServerFailure(),
      UnauthorizedFailure(),
      ForbiddenFailure(),
      NotFoundFailure(),
      ValidationFailure(),
      RateLimitedFailure(),
      StorageFailure(),
      UnexpectedFailure(),
    ];

    final codes = failures.map((f) => f.code).toList();
    expect(codes.toSet(), hasLength(failures.length));
    expect(codes, everyElement(matches(RegExp(r'^[a-z_]+$'))));
  });

  test('toString never includes the cause, which may hold personal data', () {
    const cause = 'user +923001234567 failed';
    const failures = <AppFailure>[
      UnexpectedFailure(cause: cause),
      ServerFailure(statusCode: 500, cause: cause),
      ValidationFailure(fieldErrors: {'phone': 'invalid'}, cause: cause),
      RateLimitedFailure(retryAfter: Duration(seconds: 30), cause: cause),
    ];

    for (final failure in failures) {
      expect(failure.toString(), isNot(contains('923001234567')));
      expect(failure.toString(), startsWith('AppFailure(${failure.code}'));
    }
  });

  test('details are kept for the UI and logs', () {
    const validation = ValidationFailure(fieldErrors: {'phone': 'invalid'});
    const limited = RateLimitedFailure(retryAfter: Duration(seconds: 30));
    final stack = StackTrace.current;
    final server = ServerFailure(
      statusCode: 502,
      cause: 'x',
      stackTrace: stack,
    );

    expect(validation.fieldErrors, {'phone': 'invalid'});
    expect(validation.toString(), 'AppFailure(validation, fields: (phone))');
    expect(limited.retryAfter, const Duration(seconds: 30));
    expect(server.statusCode, 502);
    expect(server.cause, 'x');
    expect(server.stackTrace, same(stack));
  });
}
