import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/settings/application/alert_prefs_providers.dart';
import 'package:sale_lagi_hai/features/settings/domain/alert_prefs.dart';

import '../../helpers/fakes.dart';

/// The demo backend, recording RPCs; [failUpdates] makes saves fail.
final class _Recording implements BackendGateway {
  final _demo = DemoGateway();
  final calls = <(String, Map<String, Object?>)>[];
  bool failUpdates = false;
  bool failReads = false;

  /// Updates are refused as the database would refuse a bad value.
  bool refuseUpdates = false;

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    calls.add((function, params));
    if (failReads && function == 'my_alert_prefs') {
      throw const OfflineFailure();
    }
    if (failUpdates && function == 'update_alert_prefs') {
      throw const OfflineFailure();
    }
    if (refuseUpdates && function == 'update_alert_prefs') {
      throw const ValidationFailure();
    }
    return await _demo.rpc(function, params);
  }

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) =>
      _demo.select(query);

  @override
  Future<void> insert(String table, Map<String, Object?> row) =>
      _demo.insert(table, row);

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      _demo.delete(table, match);
}

Future<void> _signIn(DemoAuthRepository auth) async {
  await auth.sendPhoneCode('+923001234567');
  await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
}

void main() {
  group('AlertPrefs', () {
    test('reads a row; odd or missing values keep the defaults', () {
      final prefs = AlertPrefs.fromRow(const {
        'push_enabled': true,
        'frequency': 'high',
        'quiet_start': '23:30:00',
        'quiet_end': '07:15:00',
        'time_zone': 'Asia/Karachi',
        'followed_brands': false,
        'my_cards': false,
      });
      expect(prefs.pushEnabled, isTrue);
      expect(prefs.frequency, AlertFrequency.high);
      expect(prefs.quietStart, (hour: 23, minute: 30));
      expect(prefs.quietEnd, (hour: 7, minute: 15));
      expect(prefs.followedBrands, isFalse);
      expect(prefs.myCards, isFalse);
      expect(prefs.followedCategories, isTrue);

      expect(
        AlertPrefs.fromRow(const {
          'push_enabled': 'yes',
          'frequency': 'hourly',
          'quiet_start': 'late',
          'quiet_end': 8,
          'time_zone': 5,
          'my_city': 'no',
        }),
        const AlertPrefs(),
      );
      expect(AlertPrefs.fromRow(const {'quiet_start': '6'}).quietStart, (
        hour: 6,
        minute: 0,
      ));
    });

    test('frequencies carry their daily cap', () {
      expect(AlertFrequency.values.map((f) => f.perDay), [1, 3, 6]);
      expect(AlertFrequency.fromWire('low'), AlertFrequency.low);
      expect(AlertFrequency.fromWire(null), AlertFrequency.normal);
    });

    test('times go to the database as HH:MM', () {
      expect(AlertPrefs.wireTime((hour: 7, minute: 5)), '07:05');
      expect(AlertPrefs.wireTime((hour: 22, minute: 0)), '22:00');
    });

    test('equal by value', () {
      expect(const AlertPrefs(), const AlertPrefs());
      expect(const AlertPrefs().hashCode, const AlertPrefs().hashCode);
      expect(const AlertPrefs(), isNot(const AlertPrefs(myCity: false)));
    });
  });

  group('the alert prefs of the signed-in shopper', () {
    late _Recording backend;
    late DemoAuthRepository auth;
    late InMemoryKeyValueStore store;
    late StreamController<NetworkStatus> network;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          networkStatusProvider.overrideWith((ref) => network.stream),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          backendGatewayProvider.overrideWithValue(backend),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      // Riverpod pauses what nothing listens to; the screen listens.
      final sub = c.listen(alertPrefsProvider, (_, _) {});
      addTearDown(sub.close);
      return c;
    }

    setUp(() {
      backend = _Recording();
      auth = DemoAuthRepository();
      store = InMemoryKeyValueStore();
      network = StreamController<NetworkStatus>.broadcast();
      addTearDown(network.close);
    });

    Future<void> goOffline(ProviderContainer c) async {
      final sub = c.listen(networkStatusProvider, (_, _) {});
      addTearDown(sub.close);
      network.add(NetworkStatus.offline);
      await Future<void>.delayed(Duration.zero);
    }

    group('offline (UX S19 "Queued", QA 4.9-N6)', () {
      test(
        'a change is kept on the phone, not sent, and sent when back',
        () async {
          await _signIn(auth);
          final c = container();
          await c.read(alertPrefsProvider.future);
          await goOffline(c);
          final sent = backend.calls.length;
          const next = AlertPrefs(myCity: false);
          expect(
            await c.read(alertPrefsProvider.notifier).change(next),
            isNull,
          );
          expect(c.read(alertPrefsProvider).value, next);
          expect(c.read(alertPrefsProvider.notifier).queued, isTrue);
          expect(
            backend.calls,
            hasLength(sent),
            reason: 'nothing sent offline',
          );
          expect(jsonDecode(store.values[alertPrefsQueueKey]!), {
            'user': auth.currentUser!.id,
            'changes': {'my_city': false},
          });

          network.add(NetworkStatus.online);
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          final (function, params) = backend.calls.last;
          expect(function, 'update_alert_prefs');
          expect(params, {'my_city': false});
          expect(c.read(alertPrefsProvider.notifier).queued, isFalse);
          expect(store.values.containsKey(alertPrefsQueueKey), isFalse);
        },
      );

      test('the queue outlives a restart, and goes out then', () async {
        await _signIn(auth);
        store.values[alertPrefsQueueKey] = jsonEncode({
          'user': auth.currentUser!.id,
          'changes': {'frequency': 'high'},
        });
        final c = container();
        final shown = await c.read(alertPrefsProvider.future);
        expect(shown?.frequency, AlertFrequency.high);
        await Future<void>.delayed(Duration.zero);
        final (function, params) = backend.calls.last;
        expect(function, 'update_alert_prefs');
        expect(params, {'frequency': 'high'});
        expect(store.values.containsKey(alertPrefsQueueKey), isFalse);
      });

      test("another account's queue is ignored", () async {
        await _signIn(auth);
        store.values[alertPrefsQueueKey] = jsonEncode({
          'user': 'someone-else',
          'changes': {'my_cards': false},
        });
        final c = container();
        expect((await c.read(alertPrefsProvider.future))?.myCards, isTrue);
        expect(
          backend.calls.map((c) => c.$1),
          isNot(contains('update_alert_prefs')),
        );
      });

      test('a queued change the server refuses is dropped; the saved values '
          'show', () async {
        await _signIn(auth);
        store.values[alertPrefsQueueKey] = jsonEncode({
          'user': auth.currentUser!.id,
          'changes': {'my_city': false},
        });
        backend.refuseUpdates = true;
        final c = container();
        await c.read(alertPrefsProvider.future);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(store.values.containsKey(alertPrefsQueueKey), isFalse);
        expect((await c.read(alertPrefsProvider.future))?.myCity, isTrue);
      });
    });

    test('guests have none, and nothing is asked of the server', () async {
      final c = container();
      expect(await c.read(alertPrefsProvider.future), isNull);
      expect(backend.calls, isEmpty);
      // Nothing to change either.
      expect(
        await c.read(alertPrefsProvider.notifier).change(const AlertPrefs()),
        isNull,
      );
      expect(backend.calls, isEmpty);
    });

    test('signed in: loaded; a change sends only what changed', () async {
      await _signIn(auth);
      final c = container();
      final prefs = await c.read(alertPrefsProvider.future);
      expect(prefs, const AlertPrefs());

      final next = AlertPrefs(
        frequency: AlertFrequency.low,
        quietStart: const (hour: 23, minute: 0),
        myCity: false,
        timeZone: prefs!.timeZone,
      );
      expect(await c.read(alertPrefsProvider.notifier).change(next), isNull);
      expect(c.read(alertPrefsProvider).value, next);
      final (function, params) = backend.calls.last;
      expect(function, 'update_alert_prefs');
      expect(params, {
        'frequency': 'low',
        'quiet_start': '23:00',
        'my_city': false,
      });

      // The same again sends nothing.
      final sent = backend.calls.length;
      await c.read(alertPrefsProvider.notifier).change(next);
      expect(backend.calls, hasLength(sent));
    });

    test('a failed save shows the old values again, and says why', () async {
      await _signIn(auth);
      final c = container();
      await c.read(alertPrefsProvider.future);
      backend.failUpdates = true;
      final failure = await c
          .read(alertPrefsProvider.notifier)
          .change(const AlertPrefs(pushEnabled: true));
      expect(failure, isA<OfflineFailure>());
      expect(c.read(alertPrefsProvider).value, const AlertPrefs());
    });

    test('a failed load is an error, and a retry loads', () async {
      await _signIn(auth);
      backend.failReads = true;
      final c = container();
      await expectLater(
        c.read(alertPrefsProvider.future),
        throwsA(isA<OfflineFailure>()),
      );
      backend.failReads = false;
      c.invalidate(alertPrefsProvider);
      expect(await c.read(alertPrefsProvider.future), const AlertPrefs());
    });

    test('signing out drops them', () async {
      await _signIn(auth);
      final c = container();
      expect(await c.read(alertPrefsProvider.future), isNotNull);
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(await c.read(alertPrefsProvider.future), isNull);
    });
  });
}
