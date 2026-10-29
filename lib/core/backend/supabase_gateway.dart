import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// [BackendGateway] over the Supabase client.
final class SupabaseGateway implements BackendGateway {
  const new(this._client);

  final SupabaseClient _client;

  static const _timeout = Duration(seconds: 20);

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    final result = await _client
        .rpc<Object?>(function, params: params)
        .timeout(_timeout);
    return switch (result) {
      final List<Object?> rows => [
        for (final row in rows) Map<String, Object?>.from(row! as Map),
      ],
      final Map<Object?, Object?> row => [Map<String, Object?>.from(row)],
      null => const [],
      final value => [
        {'value': value},
      ],
    };
  }

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    var filter = _client.from(query.table).select(query.columns);
    for (final MapEntry(:key, :value) in query.equals.entries) {
      filter = filter.eq(key, value);
    }
    for (final MapEntry(:key, :value) in query.inList.entries) {
      filter = filter.inFilter(key, value);
    }
    PostgrestTransformBuilder<List<Map<String, dynamic>>> transform = filter;
    if (query.orderBy case final column?) {
      transform = transform.order(column, ascending: query.ascending);
    }
    if (query.limit case final limit?) {
      transform = transform.limit(limit);
    }
    final rows = await transform.timeout(_timeout);
    return [for (final row in rows) Map<String, Object?>.from(row)];
  }

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {
    await _client.from(table).insert(row).timeout(_timeout);
  }

  @override
  Future<void> delete(String table, Map<String, Object?> match) async {
    if (match.isEmpty) {
      throw ArgumentError.value(match, 'match', 'must not be empty');
    }
    await _client
        .from(table)
        .delete()
        .match(match.map((k, v) => MapEntry(k, v!)))
        .timeout(_timeout);
  }
}
