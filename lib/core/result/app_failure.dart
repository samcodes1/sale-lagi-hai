/// Every failure the app can show to a user or recover from.
///
/// Repositories return these (inside a `Result`) instead of throwing, so the
/// UI can handle each case explicitly with an exhaustive `switch`. Messages
/// for users are chosen by type in the presentation layer, never taken from
/// [cause], which may contain technical or personal details.
sealed class AppFailure implements Exception {
  const new({required this.code, this.cause, this.stackTrace});

  /// A stable identifier for logs and analytics, e.g. `offline`. Unlike
  /// `runtimeType`, it survives minification in release web builds.
  final String code;

  /// The original error, kept for logging only.
  final Object? cause;
  final StackTrace? stackTrace;

  /// Whether repeating the same request might succeed.
  bool get isRetryable;

  // Deliberately omits [cause]: it may contain personal data.
  @override
  String toString() => 'AppFailure($code)';
}

/// The device has no network connection.
final class OfflineFailure extends AppFailure {
  const new({super.cause, super.stackTrace}) : super(code: 'offline');

  @override
  bool get isRetryable => true;
}

/// The request took too long.
final class TimeoutFailure extends AppFailure {
  const new({super.cause, super.stackTrace}) : super(code: 'timeout');

  @override
  bool get isRetryable => true;
}

/// The server answered with an error.
final class ServerFailure extends AppFailure {
  const new({this.statusCode, super.cause, super.stackTrace})
    : super(code: 'server');

  final int? statusCode;

  /// Server-side errors (5xx) and unknown statuses may be temporary.
  @override
  bool get isRetryable => statusCode == null || statusCode! >= 500;

  @override
  String toString() => 'AppFailure($code, statusCode: $statusCode)';
}

/// The user's session is missing or expired; they must sign in again.
final class UnauthorizedFailure extends AppFailure {
  const new({super.cause, super.stackTrace}) : super(code: 'unauthorized');

  @override
  bool get isRetryable => false;
}

/// The user is signed in but not allowed to do this (e.g. an RLS denial).
final class ForbiddenFailure extends AppFailure {
  const new({super.cause, super.stackTrace}) : super(code: 'forbidden');

  @override
  bool get isRetryable => false;
}

/// The requested item does not exist, or no longer does (an expired deal).
final class NotFoundFailure extends AppFailure {
  const new({super.cause, super.stackTrace}) : super(code: 'not_found');

  @override
  bool get isRetryable => false;
}

/// The input was rejected. [fieldErrors] maps a field name to an error code
/// that the UI translates, e.g. `{'phone': 'invalid_format'}`.
final class ValidationFailure extends AppFailure {
  const new({this.fieldErrors = const {}, super.cause, super.stackTrace})
    : super(code: 'validation');

  final Map<String, String> fieldErrors;

  @override
  bool get isRetryable => false;

  @override
  String toString() => 'AppFailure($code, fields: ${fieldErrors.keys})';
}

/// Too many requests, e.g. OTP attempts or deal reports.
final class RateLimitedFailure extends AppFailure {
  const new({this.retryAfter, super.cause, super.stackTrace})
    : super(code: 'rate_limited');

  /// How long to wait before trying again, when the server says.
  final Duration? retryAfter;

  @override
  bool get isRetryable => true;

  @override
  String toString() => 'AppFailure($code, retryAfter: $retryAfter)';
}

/// Reading or writing local storage failed.
final class StorageFailure extends AppFailure {
  const new({super.cause, super.stackTrace}) : super(code: 'storage');

  @override
  bool get isRetryable => false;
}

/// Anything not covered above: a bug, or an error nobody mapped yet.
final class UnexpectedFailure extends AppFailure {
  const new({super.cause, super.stackTrace}) : super(code: 'unexpected');

  @override
  bool get isRetryable => false;
}
