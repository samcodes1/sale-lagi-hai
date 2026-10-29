import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_providers.dart';
import 'package:sale_lagi_hai/features/follows/application/follow_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';

import '../../helpers/fakes.dart';
import '../home/fake_deals.dart';

void main() {
  late DemoGateway backend;
  late DemoAuthRepository auth;

  late MemoryLogSink logs;

  ProviderContainer container({BackendGateway? gateway}) {
    final c = ProviderContainer(
      overrides: [
        backendGatewayProvider.overrideWithValue(gateway ?? backend),
        authRepositoryProvider.overrideWithValue(auth),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        loggerProvider.overrideWithValue(AppLogger(sinks: [logs])),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    backend = DemoGateway();
    auth = DemoAuthRepository();
    logs = MemoryLogSink();
  });

  final threads = brandBySlug('demo-threads')['id']! as String;
  final food = categoryId('food-and-restaurants');

  group('follows', () {
    test('a guest follows on the phone only', () async {
      final c = container();
      await c.read(followsProvider).toggleBrand(threads);
      await c.read(followsProvider).toggleCategory(food);
      expect(c.read(preferencesProvider).brandIds, [threads]);
      expect(c.read(preferencesProvider).categoryFollowIds, [food]);
      expect(c.read(followsProvider).followsBrand(threads), isTrue);
      expect(await backend.select(const TableQuery('follows')), isEmpty);
      await c.read(followsProvider).toggleBrand(threads);
      expect(c.read(followsProvider).followsBrand(threads), isFalse);
    });

    test('signed in, follows also change in the account', () async {
      await auth.sendPhoneCode('+923001234567');
      await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
      final c = container();
      await c.read(followsProvider).toggleCategory(food);
      expect(
        (await backend.select(const TableQuery('follows')))
            .single['category_id'],
        food,
      );
      await c.read(followsProvider).toggleCategory(food);
      expect(await backend.select(const TableQuery('follows')), isEmpty);
    });

    test('category follows made as a guest move in at sign-in', () async {
      final c = container();
      await c.read(followsProvider).toggleCategory(food);
      // The sync runs right after sign-in.
      await auth.sendPhoneCode('+923001234567');
      await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
      await c.read(guestSyncProvider)();
      expect(
        (await backend.select(const TableQuery('follows')))
            .map((f) => f['category_id']),
        contains(food),
      );
    });
  });

  test('a failed guest sync keeps the phone copy, logs only the failure '
      'code, and still moves saved deals', () async {
    final c = container(gateway: _SyncFails(backend));
    await c.read(followsProvider).toggleBrand(threads);
    await c.read(savedDealsProvider.notifier).toggle(demoDeals.first.id);
    // The sync runs right after sign-in.
    await auth.sendPhoneCode('+923001234567');
    await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
    await c.read(guestSyncProvider)();
    expect(c.read(preferencesProvider).brandIds, [threads]);
    final warning = logs.records.singleWhere(
      (r) => r.message == 'Could not sync guest choices',
    );
    expect(warning.context, {'code': 'offline'});
    expect(
      (await backend.select(const TableQuery('saves')))
          .map((s) => s['deal_id']),
      [demoDeals.first.id],
    );
  });

  group('brand lookup', () {
    test('an active brand by slug; unknown is not found', () async {
      final c = container();
      expect((await c.read(brandProvider('demo-threads').future)).id, threads);
      await expectLater(
        c.read(brandProvider('no-such-brand').future),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('paged lists', () {
    test('a category list pages like the feed, a brand list too', () async {
      final deals = FakeDeals(now: DateTime.utc(2026, 10, 29, 12));
      final c = ProviderContainer(
        overrides: [dealRepositoryProvider.overrideWithValue(deals)],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      const query = CategoryDeals(['c1', 'c2'], cityId: 'k');
      var state = await c.read(dealListProvider(query).future);
      expect(state.deals, hasLength(20));
      await c.read(dealListProvider(query).notifier).loadMore();
      await c.read(dealListProvider(query).notifier).loadMore();
      state = c.read(dealListProvider(query)).requireValue;
      expect(state.deals, hasLength(45));
      expect(state.atEnd, isTrue);

      const brand = BrandDeals('brand-1', cityId: 'k');
      final first = await c.read(dealListProvider(brand).future);
      expect(first.deals, isNotEmpty);
      expect(deals.calls, contains('brand brand-1 first'));
    });

    test('equal queries share one list', () {
      expect(
        const CategoryDeals(['a', 'b'], cityId: 'k'),
        const CategoryDeals(['a', 'b'], cityId: 'k'),
      );
      expect(
        const CategoryDeals(['a'], cityId: 'k') == const CategoryDeals(['a']),
        isFalse,
      );
      expect(const BrandDeals('x'), const BrandDeals('x'));
    });
  });
}

/// The demo backend, except that the guest sync fails (offline).
final class _SyncFails implements BackendGateway {
  new(this._demo);

  final DemoGateway _demo;

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) =>
      _demo.select(query);

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    if (function == 'sync_guest_preferences') throw const OfflineFailure();
    return await _demo.rpc(function, params);
  }

  @override
  Future<void> insert(String table, Map<String, Object?> row) =>
      _demo.insert(table, row);

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      _demo.delete(table, match);
}
