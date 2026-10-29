import 'dart:async';

import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';

/// Turns an exception from a specific library (the Supabase client, HTTP,
/// a platform plugin) into an [AppFailure], or returns `null` when it does
/// not recognise the error. Data sources register their own mappers.
typedef ExceptionMapper = AppFailure? Function(
  Object error,
  StackTrace stackTrace,
);

/// Runs [body] and converts any thrown error into a [Failure].
///
/// An [AppFailure] thrown by [body] passes through as-is. Other errors are
/// offered to each of [mappers] in order; anything still unrecognised
/// becomes an [UnexpectedFailure] and is logged to [logger], since it
/// usually means a bug or a missing mapper. `guard` itself never throws.
Future<Result<T>> guard<T>(
  Future<T> Function() body, {
  required AppLogger logger,
  List<ExceptionMapper> mappers = const [],
}) async {
  try {
    return Success(await body());
  } on AppFailure catch (failure) {
    return Failure(failure);
  } on Object catch (error, stackTrace) {
    final failure = mapError(error, stackTrace, mappers: mappers);
    if (failure is UnexpectedFailure) {
      logger.error(
        'Unmapped error in guard()',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return Failure(failure);
  }
}

/// Maps a thrown error to an [AppFailure] without running anything.
///
/// A mapper that throws is treated as not recognising the error: a bug in
/// one mapper must not turn a handled failure into a crash.
AppFailure mapError(
  Object error,
  StackTrace stackTrace, {
  List<ExceptionMapper> mappers = const [],
}) {
  if (error is AppFailure) return error;
  for (final mapper in mappers) {
    try {
      final failure = mapper(error, stackTrace);
      if (failure != null) return failure;
    } on Object {
      continue;
    }
  }
  if (error is TimeoutException) {
    return TimeoutFailure(cause: error, stackTrace: stackTrace);
  }
  return UnexpectedFailure(cause: error, stackTrace: stackTrace);
}
