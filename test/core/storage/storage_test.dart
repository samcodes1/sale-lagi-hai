import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/storage/json_cache.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/core/storage/secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/fakes.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage;

/// A store whose every call fails, like a full or corrupted disk.
final class _BrokenStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) async => throw StateError('disk');

  @override
  Future<void> setString(String key, String value) async =>
      throw StateError('disk full');

  @override
  Future<void> remove(String key) async => throw StateError('disk');

  @override
  Future<Set<String>> keys() async => throw StateError('disk');

  @override
  Future<void> clear() async => throw StateError('disk');
}

void main() {
  group('SharedPrefsKeyValueStore', () {
    late SharedPreferencesAsync prefs;
    late SharedPrefsKeyValueStore store;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = SharedPreferencesAsync();
      store = SharedPrefsKeyValueStore(prefs);
    });

    test('stores, reads and removes namespaced strings', () async {
      await store.setString('city', 'karachi');

      expect(await store.getString('city'), 'karachi');
      expect(await prefs.getString('slh.city'), 'karachi');

      await store.remove('city');
      expect(await store.getString('city'), isNull);
    });

    test("clear() removes only this app's keys", () async {
      await prefs.setString('plugin.setting', 'keep');
      await store.setString('city', 'karachi');
      await store.setString('lang', 'ur');

      await store.clear();

      expect(await store.getString('city'), isNull);
      expect(await store.getString('lang'), isNull);
      expect(await prefs.getString('plugin.setting'), 'keep');
    });

    test("keys() lists only this app's keys, without the prefix", () async {
      await prefs.setString('plugin.setting', 'x');
      await store.setString('city', 'karachi');
      await store.setString('cache.feed', '{}');

      expect(await store.keys(), {'city', 'cache.feed'});
    });

    test('the default constructor uses the platform instance', () async {
      await SharedPrefsKeyValueStore().setString('x', '1');

      expect(await prefs.getString('slh.x'), '1');
    });
  });

  group('FlutterSecureStore', () {
    setUpAll(() => registerFallbackValue(AndroidOptions.defaultOptions));

    late _MockSecureStorage storage;
    late FlutterSecureStore store;
    final platformError = PlatformException(code: 'KeystoreError');

    setUp(() {
      storage = _MockSecureStorage();
      store = FlutterSecureStore(storage: storage);
    });

    test('reads, writes and deletes by SecureKey', () async {
      when(() => storage.read(key: 'auth_session'))
          .thenAnswer((_) async => 'session');
      when(() => storage.write(key: 'auth_session', value: 'new'))
          .thenAnswer((_) async {});
      when(() => storage.delete(key: 'auth_session')).thenAnswer((_) async {});
      when(() => storage.deleteAll()).thenAnswer((_) async {});

      expect(await store.read(SecureKey.authSession), 'session');
      await store.write(SecureKey.authSession, 'new');
      await store.delete(SecureKey.authSession);
      await store.deleteAll();

      verify(() => storage.write(key: 'auth_session', value: 'new')).called(1);
      verify(() => storage.delete(key: 'auth_session')).called(1);
      verify(() => storage.deleteAll()).called(1);
    });

    test('an unreadable value reads as signed out and resets the store '
        'once, logged', () async {
      final sink = MemoryLogSink();
      store = FlutterSecureStore(
        storage: storage,
        logger: AppLogger(sinks: [sink]),
      );
      when(() => storage.read(key: any(named: 'key'))).thenThrow(platformError);
      when(() => storage.deleteAll(aOptions: any(named: 'aOptions')))
          .thenAnswer((_) async {});

      expect(await store.read(SecureKey.authSession), isNull);

      final recovery = verify(
        () => storage.deleteAll(aOptions: captureAny(named: 'aOptions')),
      )..called(1);
      final options = recovery.captured.single as AndroidOptions;
      expect(options.toMap()['resetOnError'], 'true');
      expect(sink.records.single.context, {'code': 'KeystoreError'});
    });

    test('a failed recovery is logged and still reads as signed out', () async {
      final sink = MemoryLogSink();
      store = FlutterSecureStore(
        storage: storage,
        logger: AppLogger(sinks: [sink]),
      );
      when(() => storage.read(key: any(named: 'key'))).thenThrow(platformError);
      when(() => storage.deleteAll(aOptions: any(named: 'aOptions')))
          .thenThrow(StateError('plugin gone'));

      expect(await store.read(SecureKey.authSession), isNull);
      expect(sink.records.map((r) => r.level), [
        LogLevel.warning,
        LogLevel.error,
      ]);
    });

    test('write, delete and deleteAll failures become StorageFailure', () {
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenThrow(platformError);
      when(() => storage.delete(key: any(named: 'key')))
          .thenThrow(platformError);
      when(() => storage.deleteAll()).thenThrow(platformError);

      expect(
        store.write(SecureKey.authSession, 'x'),
        throwsA(isA<StorageFailure>()),
      );
      expect(
        store.delete(SecureKey.authSession),
        throwsA(isA<StorageFailure>()),
      );
      expect(store.deleteAll(), throwsA(isA<StorageFailure>()));
    });

    test('the default constructor creates its own storage', () {
      expect(FlutterSecureStore.new, returnsNormally);
    });
  });

  group('JsonCache', () {
    late InMemoryKeyValueStore store;
    late MemoryLogSink sink;
    var now = DateTime.utc(2026, 10, 29, 12);

    JsonCache cache() => JsonCache(
      store,
      logger: AppLogger(sinks: [sink]),
      clock: () => now,
    );

    setUp(() {
      store = InMemoryKeyValueStore();
      sink = MemoryLogSink();
      now = DateTime.utc(2026, 10, 29, 12);
    });

    test('round-trips JSON data with the save time', () async {
      final data = {
        'deals': [
          {'id': 'd-1', 'discount': 40},
        ],
      };

      await cache().put('feed.karachi', data);
      final entry = await cache().get('feed.karachi');

      expect(entry!.data, data);
      expect(entry.savedAt, now);
      expect(store.values.keys, ['cache.feed.karachi']);
    });

    test('returns null for a missing key', () async {
      expect(await cache().get('nothing'), isNull);
    });

    test('respects maxAge', () async {
      await cache().put('feed', [1]);
      now = now.add(const Duration(minutes: 31));

      expect(
        await cache().get('feed', maxAge: const Duration(minutes: 30)),
        isNull,
      );
      expect(
        await cache().get('feed', maxAge: const Duration(hours: 1)),
        isNotNull,
      );
      expect(
        (await cache().get('feed'))!.ageAt(now),
        const Duration(minutes: 31),
      );
    });

    test(
      'dropExpired deletes a copy that is too old; plain reads keep it',
      () async {
        await cache().put('feed', [1]);
        now = now.add(const Duration(minutes: 31));
        const age = Duration(minutes: 30);
        expect(await cache().get('feed', maxAge: age), isNull);
        expect(store.values, contains('cache.feed'));
        expect(
          await cache().get('feed', maxAge: age, dropExpired: true),
          isNull,
        );
        expect(store.values, isNot(contains('cache.feed')));
      },
    );

    test('prune removes old and corrupt copies under a prefix only', () async {
      await cache().put('home.a', [1]);
      now = now.add(const Duration(days: 4));
      await cache().put('home.b', [2]);
      await cache().put('other', [3]);
      store.values['cache.home.c'] = '{oops';
      store.values['settings'] = 'kept';
      await cache().prune('home.', maxAge: const Duration(days: 3));
      expect(store.values.keys.toSet(), {
        'cache.home.b',
        'cache.other',
        'settings',
      });
    });

    test('treats entries from another format version as a miss', () async {
      store.values['cache.feed'] = jsonEncode({
        'v': JsonCache.formatVersion + 1,
        'at': now.toIso8601String(),
        'data': [1],
      });

      expect(await cache().get('feed'), isNull);
      expect(sink.records, isEmpty);
    });

    test('deletes and logs corrupt entries', () async {
      for (final corrupt in ['{not json', '{"v": 1}', '{"v":1,"at":"nope"}']) {
        store.values['cache.feed'] = corrupt;

        expect(await cache().get('feed'), isNull, reason: corrupt);
        expect(store.values.containsKey('cache.feed'), isFalse);
      }
      expect(sink.records, hasLength(3));
      expect(sink.records.first.level, LogLevel.warning);
    });

    test('a non-object entry is a miss', () async {
      store.values['cache.feed'] = '[1, 2]';

      expect(await cache().get('feed'), isNull);
    });

    test(
      'a future save time beyond the tolerance is stale with maxAge',
      () async {
        now = DateTime.utc(2026, 10, 29, 12, 0, 30);
        await cache().put('slightly-ahead', [1]);
        now = DateTime.utc(2026, 10, 29, 12);

        // 30 s ahead is within the tolerance, so it is still fresh.
        expect(
          await cache().get(
            'slightly-ahead',
            maxAge: const Duration(minutes: 5),
          ),
          isNotNull,
        );

        now = DateTime.utc(2026, 10, 29, 14);
        await cache().put('far-ahead', [1]);
        now = DateTime.utc(2026, 10, 29, 12);

        expect(
          await cache().get('far-ahead', maxAge: const Duration(hours: 5)),
          isNull,
        );
        // Without maxAge (offline fallback, any age) the data is still usable.
        expect(await cache().get('far-ahead'), isNotNull);
      },
    );

    test('clear() removes cache entries but keeps other values', () async {
      store.values['city'] = 'karachi';
      await cache().put('feed', [1]);
      await cache().put('brands', [2]);

      await cache().clear();

      expect(store.values, {'city': 'karachi'});
    });

    test('storage errors: put fails with StorageFailure, get and remove '
        'degrade to a logged miss', () async {
      final broken = JsonCache(
        _BrokenStore(),
        logger: AppLogger(sinks: [sink]),
      );

      await expectLater(
        broken.put('feed', [1]),
        throwsA(isA<StorageFailure>()),
      );
      expect(await broken.get('feed'), isNull);
      await broken.remove('feed');

      expect(sink.records.map((r) => r.message), [
        'Cache read failed',
        'Cache remove failed',
      ]);
    });

    test('remove deletes the entry', () async {
      await cache().put('feed', [1]);
      await cache().remove('feed');

      expect(await cache().get('feed'), isNull);
    });
  });

  group('test fakes behave like the real stores', () {
    test('InMemorySecureStore', () async {
      final store = InMemorySecureStore();
      await store.write(SecureKey.authSession, 's');
      expect(await store.read(SecureKey.authSession), 's');
      await store.delete(SecureKey.authSession);
      expect(await store.read(SecureKey.authSession), isNull);
      await store.write(SecureKey.authSession, 's');
      await store.deleteAll();
      expect(store.values, isEmpty);
    });

    test('InMemoryKeyValueStore', () async {
      final store = InMemoryKeyValueStore();
      await store.setString('a', '1');
      await store.clear();
      expect(await store.getString('a'), isNull);
    });
  });
}
