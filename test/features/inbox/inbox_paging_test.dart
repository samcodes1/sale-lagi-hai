import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/features/alerts/application/alerts_providers.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';

import '../../helpers/fakes.dart';

/// An inbox of [count] alerts, with switches to fail reads, writes and the
/// badge.
final class _Inbox implements BackendGateway {
  new(this.count);

  final int count;
  bool failSelect = false;
  bool failRpc = false;
  final _demo = DemoGateway();

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    if (failSelect) throw const OfflineFailure();
    if (query.table != 'notifications') return await _demo.select(query);
    final all = [
      for (var i = 0; i < count; i++)
        {
          'id': 'n$i',
          'kind': 'deal_alert',
          'title': 'Alert $i',
          'created_at': DateTime.utc(
            2026,
            10,
            29,
            12,
          ).subtract(Duration(minutes: i)).toIso8601String(),
          'read_at': null,
        },
    ];
    return all.skip(query.offset).take(query.limit ?? count).toList();
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    if (failRpc) throw const OfflineFailure();
    return [
      {'value': 7},
    ];
  }

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {
    if (failSelect) throw const OfflineFailure();
    await _demo.insert(table, row);
  }

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      _demo.delete(table, match);
}

void main() {
  late DemoAuthRepository auth;
  late MemoryLogSink logs;

  Future<ProviderContainer> signedIn(BackendGateway backend) async {
    await auth.sendPhoneCode('+923001234567');
    await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        loggerProvider.overrideWithValue(AppLogger(sinks: [logs])),
        backendGatewayProvider.overrideWithValue(backend),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    final sub = c.listen(inboxProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(currentUserProvider.future);
    return c;
  }

  setUp(() {
    auth = DemoAuthRepository();
    logs = MemoryLogSink();
  });

  test('pages of 30, once at a time, then the end', () async {
    final c = await signedIn(_Inbox(35));
    var inbox = await c.read(inboxProvider.future);
    expect(inbox.alerts, hasLength(Inbox.pageSize));
    expect(inbox.hasMore, isTrue);
    await Future.wait([
      c.read(inboxProvider.notifier).loadMore(),
      c.read(inboxProvider.notifier).loadMore(),
    ]);
    inbox = c.read(inboxProvider).requireValue;
    expect(inbox.alerts, hasLength(35));
    expect(inbox.alerts.map((a) => a.id).toSet(), hasLength(35));
    expect(inbox.hasMore, isFalse);
  });

  test(
    'a failed page becomes a retry; a failed first load, the error',
    () async {
      final backend = _Inbox(35);
      final c = await signedIn(backend);
      await c.read(inboxProvider.future);
      backend.failSelect = true;
      await c.read(inboxProvider.notifier).loadMore();
      expect(c.read(inboxProvider).requireValue.moreFailure, isA<AppFailure>());
      backend.failSelect = false;
      await c.read(inboxProvider.notifier).loadMore();
      expect(c.read(inboxProvider).requireValue.alerts, hasLength(35));

      backend.failSelect = true;
      c.invalidate(inboxProvider);
      await expectLater(
        c.read(inboxProvider.future),
        throwsA(isA<AppFailure>()),
      );
    },
  );

  test('a failed mark-read keeps the alert read on screen and logs only '
      'the code; a failed badge is 0', () async {
    final backend = _Inbox(2);
    final c = await signedIn(backend);
    final inbox = await c.read(inboxProvider.future);
    expect(await c.read(alertsBadgeProvider.future), 7);
    backend.failRpc = true;
    await c.read(inboxProvider.notifier).markRead(inbox.alerts.first);
    expect(c.read(inboxProvider).requireValue.alerts.first.isUnread, isFalse);
    final warning = logs.records.singleWhere(
      (r) => r.message == 'Could not mark alerts read',
    );
    expect(warning.context.keys, ['code']);
    expect(await c.read(alertsBadgeProvider.future), 0);
  });

  test(
    'a failed read of the account at sign-in is logged, nothing else',
    () async {
      final backend = _Inbox(0)..failSelect = true;
      final c = await signedIn(backend);
      await c.read(guestSyncProvider)();
      expect(
        logs.records.map((r) => r.message),
        contains('Could not read the account'),
      );
    },
  );
}
