// QA (sub-phase 1.2): appRetryPolicy against real Riverpod 3.4.3 behaviour.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/state/retry_policy.dart';

/// A real [ProviderException], as Riverpod throws when a provider reads a
/// dependency that is in error state (its constructor is internal).
ProviderException _providerException(Exception error) {
  final failing = Provider<int>((ref) => throw error);
  final container = ProviderContainer(retry: (_, _) => null);
  try {
    container.read(failing);
  } on ProviderException catch (e) {
    return e;
  } finally {
    container.dispose();
  }
  throw StateError('Riverpod did not throw a ProviderException');
}

void main() {
  test('reading a failed sync provider really throws ProviderException', () {
    final e = _providerException(const OfflineFailure());

    expect(e.exception, isA<OfflineFailure>());
  });

  test('the backoff is 0.5 s, 1 s, 2 s, then stop (total 3.5 s)', () {
    final delays = [
      for (var i = 0; i <= maxProviderRetries; i++)
        appRetryPolicy(i, const TimeoutFailure()),
    ];

    expect(delays, const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      null,
    ]);
  });

  test("BUG-8: a dependent that rethrows its dependency's error "
      "(ProviderException) is not retried, as in Riverpod's default", () {
    final error = _providerException(const OfflineFailure());

    expect(ProviderContainer.defaultRetry(0, error), isNull);
    expect(appRetryPolicy(0, error), isNull);
  });

  test(
    'BUG-8: the dependent shows the error as soon as its dependency gives up',
    () async {
      final sw = Stopwatch()..start();
      // Real delays scaled down 50x.
      Duration? scaled(int count, Object error) {
        final delay = appRetryPolicy(count, error);
        return delay == null ? null : delay ~/ 50;
      }

      final source = FutureProvider<int>(
        (ref) async => throw const OfflineFailure(),
        retry: scaled,
      );
      final dependent = FutureProvider<int>(
        (ref) async => ref.watch(source).requireValue,
        retry: scaled,
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(dependent, (_, _) {});
      addTearDown(sub.close);

      int? sourceGaveUp;
      int? dependentGaveUp;
      // Wait for both: since the fix, the dependent fails at once (it is not
      // retried), possibly before the source has finished retrying.
      for (
        var i = 0;
        i < 400 && (sourceGaveUp == null || dependentGaveUp == null);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final s = container.read(source);
        final d = container.read(dependent);
        if (sourceGaveUp == null && s is AsyncError && !s.isLoading) {
          sourceGaveUp = sw.elapsedMilliseconds;
        }
        if (dependentGaveUp == null && d is AsyncError && !d.isLoading) {
          dependentGaveUp = sw.elapsedMilliseconds;
        }
      }

      expect(sourceGaveUp, isNotNull);
      // Before the fix: ~80 ms later (= ~3.9 s in real time). Now the
      // dependent never lags behind its source.
      expect(dependentGaveUp! - sourceGaveUp!, lessThan(20));
    },
  );

  test("BUG-9: a server's very long retryAfter is not waited out silently", () {
    const failure = RateLimitedFailure(retryAfter: Duration(hours: 1));

    final delay = appRetryPolicy(0, failure);

    expect(
      delay == null || delay <= const Duration(seconds: 30),
      isTrue,
      reason: 'got $delay',
    );
  });

  test('BUG-9: a negative retryAfter is not passed through', () {
    const failure = RateLimitedFailure(retryAfter: Duration(seconds: -5));

    final delay = appRetryPolicy(0, failure);

    expect(delay == null || !delay.isNegative, isTrue, reason: 'got $delay');
  });
}
