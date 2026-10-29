// QA, sub-phases 4.4 and 4.5: a backend that applies the database's own
// rules to the writes the app makes, so tests catch rows the real server
// refuses (docs/qa/4.4.md, docs/qa/4.5.md). The demo gateway accepts any
// row.
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// [DemoGateway] plus the column rules of `saves`, `follows` and `reports`
/// (supabase/migrations/20261029120400_user_activity.sql,
/// 20261029120500_moderation_and_commerce.sql) and their insert policies
/// (20261029130100_rls_policies.sql):
/// - `saves.user_id` and `follows.user_id` are `not null` with no default,
///   and the policy checks `user_id = auth.uid()`: a row without it is
///   refused (42501, as PostgREST reports the policy check).
/// - `reports.reporter_id` defaults to `auth.uid()`; one per user and deal
///   (23505); `note` at most 500 characters (23514).
class RulesGateway implements BackendGateway {
  new(this.auth, [DemoGateway? demo]) : demo = demo ?? DemoGateway();

  final AuthRepository auth;
  final DemoGateway demo;
  final inserts = <String>[];
  final refused = <String>[];

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) =>
      demo.select(query);

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) => demo.rpc(function, params);

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {
    final uid = auth.currentUser?.id;
    inserts.add('$table $row');
    if (uid == null) {
      refused.add('$table: no session');
      throw const PostgrestException(
        message: 'permission denied',
        code: '42501',
      );
    }
    if ((table == 'saves' || table == 'follows') && row['user_id'] != uid) {
      refused.add('$table: user_id ${row['user_id']}');
      throw const PostgrestException(
        message: 'new row violates row-level security policy',
        code: '42501',
      );
    }
    if (table == 'reports') {
      final note = row['note'];
      if (note is String && note.runes.length > 500) {
        throw const PostgrestException(message: 'check', code: '23514');
      }
      if (note is String && _hasLoneSurrogate(note)) {
        // PostgREST parses the body as JSON; Postgres rejects a lone
        // surrogate escape (22P02, "Unicode low surrogate must follow a
        // high surrogate"; checked on Postgres 16).
        throw const PostgrestException(message: 'bad unicode', code: '22P02');
      }
    }
    await demo.insert(table, row);
  }

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      demo.delete(table, match);

  static bool _hasLoneSurrogate(String s) {
    final units = s.codeUnits;
    for (var i = 0; i < units.length; i++) {
      final u = units[i];
      if (u >= 0xD800 && u <= 0xDBFF) {
        if (i + 1 >= units.length) return true;
        final next = units[i + 1];
        if (next < 0xDC00 || next > 0xDFFF) return true;
        i++;
      } else if (u >= 0xDC00 && u <= 0xDFFF) {
        return true;
      }
    }
    return false;
  }
}
