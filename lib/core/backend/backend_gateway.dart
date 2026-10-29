import 'package:meta/meta.dart';

/// The app's only door to the backend. Repositories talk to this, never to
/// the Supabase SDK, so they can be tested with a fake and the app can run
/// on demo data without a backend.
///
/// Implementations throw; repositories wrap calls in `guard()` with
/// `backendErrorMapper` to turn errors into `AppFailure`s.
abstract interface class BackendGateway {
  /// Calls a Postgres function (`supabase.rpc`). Set-returning functions
  /// return their rows; scalar ones a single row `{'value': ...}`.
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]);

  /// Reads rows from a table or view, under the caller's RLS.
  Future<List<Map<String, Object?>>> select(TableQuery query);

  Future<void> insert(String table, Map<String, Object?> row);

  /// Deletes the rows matching every column in [match] (never all rows:
  /// [match] must not be empty).
  Future<void> delete(String table, Map<String, Object?> match);
}

/// A read: equality and `in` filters, one ordering, a row limit, and how
/// many rows to skip first.
@immutable
final class TableQuery {
  const new(
    this.table, {
    this.columns = '*',
    this.equals = const {},
    this.inList = const {},
    this.orderBy,
    this.ascending = true,
    this.limit,
    this.offset = 0,
  });

  final String table;
  final String columns;
  final Map<String, Object> equals;
  final Map<String, List<Object>> inList;
  final String? orderBy;
  final bool ascending;
  final int? limit;
  final int offset;
}
