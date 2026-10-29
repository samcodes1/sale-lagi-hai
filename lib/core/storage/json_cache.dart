import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';

/// A cached value and when it was saved.
@immutable
final class CacheEntry {
  const new({required this.data, required this.savedAt});

  /// The decoded JSON value.
  final Object? data;
  final DateTime savedAt;

  Duration ageAt(DateTime now) => now.difference(savedAt);
}

/// Caches JSON-encodable values for offline use, e.g. the last loaded feed.
///
/// For public, non-sensitive data only. Entries are versioned: bumping
/// [formatVersion] makes every old entry read as a miss (and deletes it)
/// instead of being decoded into the wrong shape.
final class JsonCache {
  new(this._store, {this._logger, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  @visibleForTesting
  static const formatVersion = 1;

  /// How far in the future a save time may be before the entry is treated
  /// as untrustworthy (the phone's clock was corrected backwards).
  @visibleForTesting
  static const clockSkewTolerance = Duration(minutes: 1);

  static const _keyPrefix = 'cache.';

  final KeyValueStore _store;
  final AppLogger? _logger;
  final DateTime Function() _clock;

  /// Saves [data] under [key].
  ///
  /// Throws a [JsonUnsupportedObjectError] (a programming error) if [data]
  /// is not JSON-encodable, and a [StorageFailure] if it cannot be saved.
  Future<void> put(String key, Object? data) async {
    final encoded = jsonEncode({
      'v': formatVersion,
      'at': _clock().toUtc().toIso8601String(),
      'data': data,
    });
    try {
      await _store.setString('$_keyPrefix$key', encoded);
    } on Object catch (error, stackTrace) {
      throw StorageFailure(cause: error, stackTrace: stackTrace);
    }
  }

  /// Returns the entry, or `null` when it is missing, older than [maxAge],
  /// saved in the future (with [maxAge] set), from another format version,
  /// corrupt, or unreadable. Old-format and corrupt entries are deleted.
  Future<CacheEntry?> get(String key, {Duration? maxAge}) async {
    final String? raw;
    try {
      raw = await _store.getString('$_keyPrefix$key');
    } on Object catch (error) {
      _logger?.warning('Cache read failed', error: error);
      return null;
    }
    if (raw == null) return null;

    final CacheEntry entry;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) throw const FormatException();
      if (decoded['v'] != formatVersion) {
        await remove(key);
        return null;
      }
      entry = CacheEntry(
        data: decoded['data'],
        savedAt: DateTime.parse(decoded['at']! as String),
      );
    } on Object catch (error) {
      _logger?.warning('Dropping corrupt cache entry', error: error);
      await remove(key);
      return null;
    }

    if (maxAge != null) {
      final age = entry.ageAt(_clock());
      if (age > maxAge || age < -clockSkewTolerance) return null;
    }
    return entry;
  }

  Future<void> remove(String key) async {
    try {
      await _store.remove('$_keyPrefix$key');
    } on Object catch (error) {
      _logger?.warning('Cache remove failed', error: error);
    }
  }

  /// Removes every cache entry, e.g. on sign-out. Other stored values
  /// (settings) are kept.
  Future<void> clear() async {
    for (final key in await _store.keys()) {
      if (key.startsWith(_keyPrefix)) await _store.remove(key);
    }
  }
}
