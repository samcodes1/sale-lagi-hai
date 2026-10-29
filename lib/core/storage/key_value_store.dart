import 'package:shared_preferences/shared_preferences.dart';

/// Simple string storage for **non-sensitive** data: settings, the selected
/// city, cached public deal data. Tokens and anything personal belong in
/// `SecureStore`.
abstract interface class KeyValueStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);

  /// Every key this app wrote.
  Future<Set<String>> keys();

  /// Removes every key this app wrote.
  Future<void> clear();
}

/// [KeyValueStore] backed by `SharedPreferencesAsync` (DataStore on
/// Android, NSUserDefaults on iOS, localStorage on web).
///
/// Keys are namespaced so [clear] only removes this app's own entries and
/// never collides with plugins that also use shared preferences.
final class SharedPrefsKeyValueStore implements KeyValueStore {
  new([SharedPreferencesAsync? prefs])
    : _prefs = prefs ?? SharedPreferencesAsync();

  static const _prefix = 'slh.';

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> getString(String key) => _prefs.getString('$_prefix$key');

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString('$_prefix$key', value);

  @override
  Future<void> remove(String key) => _prefs.remove('$_prefix$key');

  @override
  Future<Set<String>> keys() async => {
    for (final key in await _prefs.getKeys())
      if (key.startsWith(_prefix)) key.substring(_prefix.length),
  };

  @override
  Future<void> clear() async {
    final keys = await _prefs.getKeys();
    await _prefs.clear(
      allowList: keys.where((k) => k.startsWith(_prefix)).toSet(),
    );
  }
}
