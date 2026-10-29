import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:sale_lagi_hai/core/result/app_failure.dart';

/// How many times a failing provider is retried before showing its error.
const maxProviderRetries = 3;

/// The longest server-requested wait the app sits through silently. Longer
/// waits surface the error, so the UI can say "try again in N minutes".
const maxRetryAfter = Duration(seconds: 30);

/// The app-wide Riverpod retry policy (passed to `ProviderScope.retry`).
///
/// Riverpod retries every failing provider by default, which would repeat
/// requests that can never succeed (bad input, signed out, forbidden). This
/// only retries [AppFailure]s that say they are retryable, with exponential
/// backoff (0.5s, 1s, 2s), and honours a server's `retryAfter` up to
/// [maxRetryAfter]. Anything else, including programming errors, fails
/// immediately.
///
/// A [ProviderException] means this provider failed only because a provider
/// it depends on did. That dependency retries itself; retrying here too
/// would multiply requests and delay the error (Riverpod's default skips
/// these for the same reason).
Duration? appRetryPolicy(int retryCount, Object error) {
  if (error is ProviderException) return null;
  if (error is! AppFailure || !error.isRetryable) return null;
  if (retryCount >= maxProviderRetries) return null;
  final backoff = Duration(milliseconds: 500 * (1 << retryCount));
  if (error is RateLimitedFailure) {
    final retryAfter = error.retryAfter;
    if (retryAfter == null || retryAfter <= Duration.zero) return backoff;
    return retryAfter > maxRetryAfter ? null : retryAfter;
  }
  return backoff;
}
