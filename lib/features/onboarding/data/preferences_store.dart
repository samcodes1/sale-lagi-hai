import 'dart:convert';

import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

/// Saves [ShopperPreferences] as JSON in the (non-secure) key-value store:
/// they hold public ids and flags only.
final class PreferencesStore {
  const new(this._store);

  static const key = 'preferences.v1';

  final KeyValueStore _store;

  /// The saved preferences, or the defaults when nothing (or nothing
  /// readable) was saved. Storage errors propagate to the caller.
  Future<ShopperPreferences> read() async {
    final raw = await _store.getString(key);
    if (raw == null) return const ShopperPreferences();
    try {
      return ShopperPreferences.fromJson(jsonDecode(raw));
    } on FormatException {
      return const ShopperPreferences();
    }
  }

  /// Forgets the saved preferences: the next launch is a first launch.
  Future<void> clear() => _store.remove(key);

  Future<void> write(ShopperPreferences preferences) =>
      _store.setString(key, jsonEncode(preferences.toJson()));
}
