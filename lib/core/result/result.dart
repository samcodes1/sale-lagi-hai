import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';

/// The outcome of an operation that can fail: either [Success] with a value
/// or [Failure] with an [AppFailure].
///
/// Handle it with an exhaustive switch:
/// ```dart
/// switch (await repository.loadDeals()) {
///   case Success(:final value): show(value);
///   case Failure(:final failure): showError(failure);
/// }
/// ```
@immutable
sealed class Result<T> {
  const new();

  bool get isSuccess => this is Success<T>;

  /// The value, or `null` for a failure.
  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Failure() => null,
  };

  /// The failure, or `null` for a success.
  AppFailure? get failureOrNull => switch (this) {
    Success() => null,
    Failure(:final failure) => failure,
  };

  /// Transforms the value of a success; failures pass through unchanged.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success(:final value) => Success(transform(value)),
    Failure(:final failure) => Failure(failure),
  };

  /// Reduces both cases to a single value.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppFailure failure) onFailure,
  }) => switch (this) {
    Success(:final value) => onSuccess(value),
    Failure(:final failure) => onFailure(failure),
  };
}

final class Success<T> extends Result<T> {
  const new(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Success<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

final class Failure<T> extends Result<T> {
  const new(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      other is Failure<T> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Failure($failure)';
}
