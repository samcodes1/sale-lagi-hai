import 'dart:async';
import 'dart:io';

import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps errors from the Supabase SDK and the network to [AppFailure]s.
/// Use it as a `guard()` mapper in every repository.
///
/// Postgres and PostgREST codes (see supabase/migrations):
/// - 42501 permission denied / RLS check → forbidden
/// - PGRST301/302/303 JWT problems, 401 → unauthorized
/// - PT429 (our rate limits) → rate limited
/// - 23xxx constraint, 22xxx bad input, 55000 already decided → validation
/// - P0002, PGRST116 (no row) → not found
AppFailure? backendErrorMapper(Object error, StackTrace stackTrace) {
  switch (error) {
    case PostgrestException(:final code):
      return switch (code) {
        '42501' => ForbiddenFailure(cause: error, stackTrace: stackTrace),
        'PGRST301' ||
        'PGRST302' ||
        'PGRST303' ||
        '401' => UnauthorizedFailure(cause: error, stackTrace: stackTrace),
        'PT429' ||
        '429' => RateLimitedFailure(cause: error, stackTrace: stackTrace),
        'P0002' ||
        'PGRST116' => NotFoundFailure(cause: error, stackTrace: stackTrace),
        final String c when c.startsWith('23') || c.startsWith('22') =>
          ValidationFailure(cause: error, stackTrace: stackTrace),
        '55000' => ValidationFailure(cause: error, stackTrace: stackTrace),
        _ => ServerFailure(
          statusCode: int.tryParse(code ?? ''),
          cause: error,
          stackTrace: stackTrace,
        ),
      };
    case AuthRetryableFetchException():
      return OfflineFailure(cause: error, stackTrace: stackTrace);
    case AuthException(:final statusCode):
      return switch (statusCode) {
        '429' => RateLimitedFailure(cause: error, stackTrace: stackTrace),
        '401' ||
        '403' => UnauthorizedFailure(cause: error, stackTrace: stackTrace),
        '422' ||
        '400' => ValidationFailure(cause: error, stackTrace: stackTrace),
        _ => ServerFailure(
          statusCode: int.tryParse(statusCode ?? ''),
          cause: error,
          stackTrace: stackTrace,
        ),
      };
    case SocketException() || HttpException():
      return OfflineFailure(cause: error, stackTrace: stackTrace);
    case TimeoutException():
      return TimeoutFailure(cause: error, stackTrace: stackTrace);
  }
  return null;
}
