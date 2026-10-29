import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';

/// Everything the app may keep in secure storage. A closed list, so nothing
/// sensitive ends up there by accident under an ad-hoc key.
enum SecureKey {
  /// The Supabase auth session (access and refresh tokens).
  authSession('auth_session');

  new(this.storageKey);

  final String storageKey;
}

/// Storage for secrets, encrypted with hardware-backed keys (Android
/// Keystore / iOS Keychain).
abstract interface class SecureStore {
  /// Returns `null` when the value is missing **or unreadable**. Keystore
  /// keys do not survive a restore to a new phone, so an unreadable value
  /// means "signed out", not an error.
  Future<String?> read(SecureKey key);

  /// Throws a [StorageFailure] if the value cannot be saved.
  Future<void> write(SecureKey key, String value);

  Future<void> delete(SecureKey key);

  /// Removes everything, e.g. on sign-out and account deletion.
  Future<void> deleteAll();
}

/// [SecureStore] backed by `flutter_secure_storage`. Its v11 defaults are
/// AES-GCM data encryption with RSA-OAEP key wrapping in the Keystore.
///
/// `resetOnError` is turned off: with the plugin default, any failed call on
/// Android silently wipes all secure data, then reports success (a write
/// that saved nothing) or returns the string "Data has been reset" as if it
/// were the stored value. Failing visibly is safer.
///
/// The one exception is recovery: when a read fails (typically the Keystore
/// key no longer matches after a restore to a new phone), the data is
/// unreadable anyway, so the store is reset once, explicitly, so that the
/// user can sign in again instead of every later write failing.
final class FlutterSecureStore implements SecureStore {
  new({FlutterSecureStorage? storage, this._logger})
    : _storage = storage ?? const FlutterSecureStorage(aOptions: _android);

  static const _android = AndroidOptions(resetOnError: false);
  static const AndroidOptions _androidRecovery = AndroidOptions.defaultOptions;

  final FlutterSecureStorage _storage;
  final AppLogger? _logger;

  @override
  Future<String?> read(SecureKey key) async {
    try {
      return await _storage.read(key: key.storageKey);
    } on PlatformException catch (error) {
      _logger?.warning(
        'Secure storage unreadable; resetting it',
        context: {'code': error.code},
      );
      await _recover();
      return null;
    }
  }

  /// Deletes everything with the plugin's reset-on-error behaviour, which
  /// also replaces the broken Keystore keys.
  Future<void> _recover() async {
    try {
      await _storage.deleteAll(aOptions: _androidRecovery);
    } on Object catch (error) {
      _logger?.error(
        'Secure storage recovery failed',
        context: {'code': error is PlatformException ? error.code : '$error'},
      );
    }
  }

  @override
  Future<void> write(SecureKey key, String value) async {
    try {
      await _storage.write(key: key.storageKey, value: value);
    } on PlatformException catch (e, st) {
      throw StorageFailure(cause: e, stackTrace: st);
    }
  }

  @override
  Future<void> delete(SecureKey key) async {
    try {
      await _storage.delete(key: key.storageKey);
    } on PlatformException catch (e, st) {
      throw StorageFailure(cause: e, stackTrace: st);
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } on PlatformException catch (e, st) {
      throw StorageFailure(cause: e, stackTrace: st);
    }
  }
}
