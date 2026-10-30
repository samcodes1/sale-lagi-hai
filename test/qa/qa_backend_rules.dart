// QA, sub-phases 4.4 and 4.5: a backend that applies the database's own
// rules to the writes the app makes, so tests catch rows the real server
// refuses (docs/qa/4.4.md, docs/qa/4.5.md). The demo gateway accepts any
// row.
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
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
/// - `sync_guest_items` and `sync_guest_preferences` add rows as the
///   caller only, skip ones the caller already has, and fail as a whole on
///   a malformed id or over the caps (the demo writes every row as one
///   fixed user).
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

  /// `profiles.home_city_id` and `locale` per user, as
  /// `sync_guest_preferences` leaves them.
  final profiles = <String, Map<String, Object?>>{};

  /// Calls of `sync_guest_items` that the server accepted.
  int guestItemCalls = 0;

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    switch (function) {
      case 'sync_guest_items':
        await _syncGuestItems(params);
        return const [];
      case 'sync_guest_preferences':
        await _syncGuestPreferences(params);
        return const [];
    }
    return await demo.rpc(function, params);
  }

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  String _caller() {
    final uid = auth.currentUser?.id;
    if (uid == null) {
      throw const PostgrestException(message: 'sign in first', code: '42501');
    }
    return uid;
  }

  static List<String> _ids(Object? list) {
    final ids = [...?(list as List<Object?>?)];
    // uuid[]: one malformed id fails the whole call.
    if (ids.any((id) => id is! String || !_uuid.hasMatch(id))) {
      throw const PostgrestException(
        message: 'invalid input syntax for type uuid',
        code: '22P02',
      );
    }
    return ids.cast<String>();
  }

  /// Inserts as `auth.uid()`, `on conflict do nothing` per user.
  Future<void> _addOwn(
    String table,
    String uid,
    String column,
    Iterable<String> ids,
  ) async {
    final rows = await demo.select(TableQuery(table));
    for (final id in ids) {
      if (rows.any((r) => r['user_id'] == uid && r[column] == id)) continue;
      final row = {
        'user_id': uid,
        column: id,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };
      await demo.insert(table, row);
      rows.add(row);
    }
  }

  /// supabase/migrations/20261029270000_guest_items.sql.
  Future<void> _syncGuestItems(Map<String, Object?> params) async {
    final uid = _caller();
    final deals = _ids(params['deal_ids']);
    final cards = _ids(params['card_product_ids']);
    if (deals.length > 500 || cards.length > 20) {
      throw const PostgrestException(message: 'at most', code: '22023');
    }
    guestItemCalls++;
    await _addOwn('saves', uid, 'deal_id', [
      for (final id in deals)
        if (demoDeals.any((d) => d.id == id)) id,
    ]);
    await _addOwn('user_cards', uid, 'card_product_id', [
      for (final id in cards)
        if (demoCardProducts.any(
          (c) => c['id'] == id && c['is_active'] != false,
        ))
          id,
    ]);
  }

  /// supabase/migrations/20261029200000_accounts.sql.
  Future<void> _syncGuestPreferences(Map<String, Object?> params) async {
    final uid = _caller();
    final brands = _ids(params['brand_ids']);
    final categories = _ids(params['category_ids']);
    if (brands.length + categories.length > 200) {
      throw const PostgrestException(message: 'at most', code: '22023');
    }
    final profile = profiles[uid] ??= {};
    if (params['city'] case final Object city) profile['home_city_id'] = city;
    if (params['lang'] case final Object lang) profile['locale'] = lang;
    await _addOwn('follows', uid, 'brand_id', [
      for (final id in brands)
        if (demoBrands.any((b) => b['id'] == id && b['is_active'] == true)) id,
    ]);
    await _addOwn('follows', uid, 'category_id', [
      for (final id in categories)
        if (demoCategories.any((c) => c['id'] == id)) id,
    ]);
  }

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
