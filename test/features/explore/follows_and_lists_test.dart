import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_providers.dart';
import 'package:sale_lagi_hai/features/follows/application/follow_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

import '../../helpers/fakes.dart';
import '../home/fake_deals.dart';

void main() {
  late DemoGateway backend;
  late DemoAuthRepository auth;

  ProviderContainer container({List<Object> extra = const []}) {
    final c = ProviderContainer(
      overrides: [
        backendGatewayProvider.overrideWithValue(backend),
        authRepositoryProvider.overrideWithValue(auth),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        loggerProvider.overrideWithValue(AppLogger(sinks: [])),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    backend = DemoGateway();
    auth = DemoAuthRepository();
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
      await c.read(guestSyncProvider)();
      expect(
        (await backend.select(const TableQuery('follows')))
            .map((f) => f['category_id']),
        contains(food),
      );
    });
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
