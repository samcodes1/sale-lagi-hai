// QA (sub-phase 1.2): JsonCache and FlutterSecureStore edge cases.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/storage/json_cache.dart';
import 'package:sale_lagi_hai/core/storage/secure_store.dart';

import '../helpers/fakes.dart';

const _secureChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JsonCache', () {
    late InMemoryKeyValueStore store;
    late MemoryLogSink sink;
    late DateTime now;

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

    test('a 1 MB value round-trips', () async {
      final big = {
        'deals': [
          for (var i = 0; i < 14000; i++)
            {'id': 'deal-$i', 'title': 'Flat 40% off on item $i' * 2},
        ],
      };

      await cache().put('feed', big);
      expect(store.values['cache.feed']!.length, greaterThan(1000000));

      expect((await cache().get('feed'))!.data, big);
    });

    test('an "at" of the wrong type is corrupt: deleted and logged', () async {
      store.values['cache.feed'] = jsonEncode({'v': 1, 'at': 12345, 'd': 1});

      expect(await cache().get('feed'), isNull);
      expect(store.values, isEmpty);
      expect(sink.records.single.level, LogLevel.warning);
    });

    test('works with a local-time clock (saved as UTC)', () async {
      now = DateTime(2026, 10, 29, 17);
      await cache().put('feed', 1);
      now = now.add(const Duration(minutes: 5));

      final entry = await cache().get('feed');

      expect(entry!.ageAt(now), const Duration(minutes: 5));
    });

    test('data that is not JSON-encodable is rejected by put()', () async {
      // Since the BUG-17 fix, put() reports this as a failed Future.
      await expectLater(
        cache().put('feed', DateTime(2026)),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
    });

    test('BUG-10: an entry saved "in the future" (clock moved back) is not '
        'treated as fresh', () async {
      // Saved while the phone clock was a month ahead…
      now = DateTime.utc(2026, 11, 29);
      await cache().put('feed', [1]);
      // …then the clock was corrected.
      now = DateTime.utc(2026, 10, 29);

      expect(
        await cache().get('feed', maxAge: const Duration(minutes: 30)),
        isNull,
      );
    });

    test(
      'BUG-17 (S4): entries from an old format version are deleted',
      () async {
        store.values['cache.feed'] = jsonEncode({
          'v': JsonCache.formatVersion - 1,
          'at': now.toIso8601String(),
          'data': [1],
        });

        await cache().get('feed');

        expect(store.values, isEmpty);
      },
    );
  });

  group('FlutterSecureStore', () {
    test('storage keys are unique and fixed (closed list)', () {
      final keys = SecureKey.values.map((k) => k.storageKey).toList();

      expect(keys.toSet(), hasLength(keys.length));
      expect(keys, everyElement(matches(RegExp(r'^[a-z_]+$'))));
    });

    group('with the real plugin channel', () {
      /// Mimics flutter_secure_storage 11.2.0 on Android when the Keystore
      /// key is unusable (e.g. after a restore to a new phone). Per
      /// FlutterSecureStoragePlugin.java:271-284, with resetOnError=true
      /// (the Dart default) *any* failing call deletes all data and answers
      /// success("Data has been reset"); otherwise it throws.
      void keystoreBroken() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_secureChannel, (call) async {
              final args = call.arguments as Map<Object?, Object?>;
              final options = args['options']! as Map<Object?, Object?>;
              if (options['resetOnError'] == 'true') {
                return 'Data has been reset';
              }
              throw PlatformException(code: 'KeyStoreException');
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(_secureChannel, null),
        );
      }

      test(
        'BUG-7: an unreadable value reads as null, not the plugin sentinel',
        () async {
          keystoreBroken();

          expect(await FlutterSecureStore().read(SecureKey.authSession), null);
        },
      );

      test('BUG-7: a write that fails is reported as StorageFailure', () async {
        keystoreBroken();

        await expectLater(
          FlutterSecureStore().write(SecureKey.authSession, 'session'),
          throwsA(isA<StorageFailure>()),
        );
      });
    });
  });
}
