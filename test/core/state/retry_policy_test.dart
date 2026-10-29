import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/state/retry_policy.dart';

void main() {
  group('appRetryPolicy', () {
    test('retries retryable failures with exponential backoff', () {
      expect(
        appRetryPolicy(0, const OfflineFailure()),
        const Duration(milliseconds: 500),
      );
      expect(
        appRetryPolicy(1, const TimeoutFailure()),
        const Duration(seconds: 1),
      );
      expect(
        appRetryPolicy(2, const ServerFailure(statusCode: 503)),
        const Duration(seconds: 2),
      );
    });

    test('stops after maxProviderRetries', () {
      expect(
        appRetryPolicy(maxProviderRetries, const OfflineFailure()),
        isNull,
      );
    });

    test('never retries failures that cannot succeed', () {
      for (final failure in const <AppFailure>[
        UnauthorizedFailure(),
        ForbiddenFailure(),
        NotFoundFailure(),
        ValidationFailure(),
        ServerFailure(statusCode: 400),
        StorageFailure(),
        UnexpectedFailure(),
      ]) {
        expect(appRetryPolicy(0, failure), isNull, reason: '$failure');
      }
    });

    test('never retries plain exceptions or errors (bugs)', () {
      expect(appRetryPolicy(0, StateError('bug')), isNull);
      expect(appRetryPolicy(0, Exception('unmapped')), isNull);
    });

    test("honours the server's retryAfter", () {
      expect(
        appRetryPolicy(
          0,
          const RateLimitedFailure(retryAfter: Duration(seconds: 30)),
        ),
        const Duration(seconds: 30),
      );
      expect(
        appRetryPolicy(0, const RateLimitedFailure()),
        const Duration(milliseconds: 500),
      );
    });
  });

  test(
    'works as ProviderContainer.retry, unwrapping provider errors',
    () async {
      var attempts = 0;
      final provider = FutureProvider<int>((ref) async {
        attempts++;
        if (attempts < 2) throw const OfflineFailure();
        return 42;
      });
      final container = ProviderContainer(
        retry: (count, error) =>
            appRetryPolicy(count, error) == null ? null : Duration.zero,
      );
      addTearDown(container.dispose);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);

      await expectLater(container.read(provider.future), completion(42));
      expect(attempts, 2);
    },
  );

  test('a non-retryable failure is surfaced on the first attempt', () async {
    var attempts = 0;
    final provider = FutureProvider<int>((ref) async {
      attempts++;
      throw const NotFoundFailure();
    });
    final container = ProviderContainer(retry: appRetryPolicy);
    addTearDown(container.dispose);
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);

    await expectLater(
      container.read(provider.future),
      throwsA(isA<NotFoundFailure>()),
    );
    expect(attempts, 1);
  });
}
