import 'dart:convert';

import 'package:sale_lagi_hai/core/storage/secure_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the Supabase session in hardware-backed secure storage instead of
/// the SDK's default (SharedPreferences, which is plain text and included in
/// backups). An unreadable value reads as "signed out".
final class SecureSessionStorage extends LocalStorage {
  const new(this._store);

  final SecureStore _store;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async =>
      (await _store.read(SecureKey.authSession)) != null;

  @override
  Future<String?> accessToken() => _store.read(SecureKey.authSession);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(SecureKey.authSession, persistSessionString);

  @override
  Future<void> removePersistedSession() => _store.delete(SecureKey.authSession);
}

/// The PKCE code verifier store (sign-in with Google), also in secure
/// storage. GoTrue's keys are kept together in one secure entry.
final class SecurePkceStorage extends GotrueAsyncStorage {
  const new(this._store);

  final SecureStore _store;

  Future<Map<String, String>> _all() async {
    final raw = await _store.read(SecureKey.authPkce);
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return {};
    }
  }

  @override
  Future<String?> getItem({required String key}) async => (await _all())[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    final all = await _all();
    all[key] = value;
    await _store.write(SecureKey.authPkce, jsonEncode(all));
  }

  @override
  Future<void> removeItem({required String key}) async {
    final all = await _all()
      ..remove(key);
    if (all.isEmpty) {
      await _store.delete(SecureKey.authPkce);
    } else {
      await _store.write(SecureKey.authPkce, jsonEncode(all));
    }
  }
}
