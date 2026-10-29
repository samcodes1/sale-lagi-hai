import 'package:sale_lagi_hai/core/errors/crash_reporter.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/core/storage/secure_store.dart';

/// In-memory [KeyValueStore] for tests.
final class InMemoryKeyValueStore implements KeyValueStore {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<Set<String>> keys() async => values.keys.toSet();

  @override
  Future<void> clear() async => values.clear();
}

/// In-memory [SecureStore] for tests.
final class InMemorySecureStore implements SecureStore {
  final values = <SecureKey, String>{};

  @override
  Future<String?> read(SecureKey key) async => values[key];

  @override
  Future<void> write(SecureKey key, String value) async => values[key] = value;

  @override
  Future<void> delete(SecureKey key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}

/// A recorded [CrashReporter.recordError] call.
typedef RecordedError = ({
  String message,
  bool fatal,
  String? errorType,
  String? errorText,
});

/// [CrashReporter] that remembers what it was sent.
final class RecordingCrashReporter implements CrashReporter {
  final errors = <RecordedError>[];
  final breadcrumbs = <String>[];

  @override
  void recordError({
    required String message,
    required bool fatal,
    String? errorType,
    String? errorText,
    StackTrace? stackTrace,
  }) => errors.add((
    message: message,
    fatal: fatal,
    errorType: errorType,
    errorText: errorText,
  ));

  @override
  void addBreadcrumb(String message) => breadcrumbs.add(message);
}
