import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/deals/application/report_providers.dart';
import 'package:sale_lagi_hai/features/deals/data/backend_deal_repository.dart';
import 'package:sale_lagi_hai/features/deals/data/deal_row.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';

import '../../helpers/fakes.dart';

String _deal(int n) => demoDeals.firstWhere((d) => d.n == n).id;

void main() {
  final repository = BackendDealRepository(DemoGateway(), AppLogger(sinks: []));

  group('detail', () {
    test('a local deal for the whole city lists every outlet there', () async {
      final detail = (await repository.detail(_deal(1))).valueOrNull!;
      expect(detail.outlets, hasLength(2));
      expect(detail.descriptionEn, contains('made-up'));
      expect(detail.terms(urdu: true), contains('ڈیمو'));
    });

    test('a local deal for some areas lists only outlets there', () async {
      final detail = (await repository.detail(_deal(7))).valueOrNull!;
      expect(detail.outlets.map((o) => o.name), [
        'Karahi House (Demo) · Clifton',
      ]);
      expect(detail.outlets.single.latitude, closeTo(24.815, 0.001));
    });

    test(
      'online deals list no outlets; nationwide ones list them all',
      () async {
        final online = (await repository.detail(_deal(5))).valueOrNull!;
        expect(online.outlets, isEmpty);
        expect(online.deal.promoCode, 'WINTER30');
        expect(online.sourceUrl, startsWith('https://'));
        final nationwide = (await repository.detail(_deal(4))).valueOrNull!;
        expect(nationwide.outlets, hasLength(1));
      },
    );

    test('an unknown deal is not found', () async {
      expect(
        (await repository.detail('00000000-0000-4000-8000-00000000dead'))
            .failureOrNull,
        isA<NotFoundFailure>(),
      );
    });

    test('an outlet row missing coordinates is rejected, not half-shown', () {
      expect(
        () => outletFromRow({
          'id': 'o',
          'name': 'n',
          'address': 'a',
          'city_id': 'c',
        }),
        throwsFormatException,
      );
    });
  });

  group('saved deals', () {
    late InMemoryKeyValueStore store;
    late DemoGateway backend;
    late DemoAuthRepository auth;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          backendGatewayProvider.overrideWithValue(backend),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      store = InMemoryKeyValueStore();
      backend = DemoGateway();
      auth = DemoAuthRepository();
    });

    test('a guest saves on the phone, newest first, and it survives a '
        'restart', () async {
      final c = container();
      await c.read(savedDealsProvider.notifier).toggle(_deal(1));
      await c.read(savedDealsProvider.notifier).toggle(_deal(2));
      expect(c.read(savedDealsProvider), [_deal(2), _deal(1)]);
      await c.read(savedDealsProvider.notifier).toggle(_deal(1));
      expect(c.read(savedDealsProvider), [_deal(2)]);
      expect(await backend.select(const TableQuery('saves')), isEmpty);

      final after = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(after.read(savedDealsProvider), [_deal(2)]);
    });

    test('a corrupt saved file reads as nothing saved', () async {
      store.values[savedDealsKey] = '{oops';
      final c = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(savedDealsProvider), isEmpty);
    });

    test(
      'signed in, saves also go to the account, and come out of it',
      () async {
        await auth.sendPhoneCode('+923001234567');
        await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
        final c = container();
        await c.read(savedDealsProvider.notifier).toggle(_deal(3));
        expect(
          (await backend.select(const TableQuery('saves')))
              .map((s) => s['deal_id']),
          [_deal(3)],
        );
        await c.read(savedDealsProvider.notifier).toggle(_deal(3));
        expect(await backend.select(const TableQuery('saves')), isEmpty);
      },
    );

    test('deals saved as a guest move into the account at sign-in', () async {
      final c = container();
      await c.read(savedDealsProvider.notifier).toggle(_deal(4));
      // The sync runs right after sign-in.
      await auth.sendPhoneCode('+923001234567');
      await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
      await c.read(guestSyncProvider)();
      expect(
        (await backend.select(const TableQuery('saves')))
            .map((s) => s['deal_id']),
        [_deal(4)],
      );
    });
  });

  group('reports', () {
    ProviderContainer container(BackendGateway backend) {
      final c = ProviderContainer(
        overrides: [
          backendGatewayProvider.overrideWithValue(backend),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'sent once; a second report on the same deal is not an error',
      () async {
        final c = container(DemoGateway());
        final report = c.read(reportDealProvider);
        expect(
          await report(_deal(1), ReportReason.expired),
          const Success(ReportOutcome.sent),
        );
        expect(
          await report(_deal(1), ReportReason.wrongPrice),
          const Success(ReportOutcome.alreadyReported),
        );
      },
    );

    test(
      '"something else" needs a note; notes are trimmed and capped',
      () async {
        final backend = DemoGateway();
        final report = container(backend).read(reportDealProvider);
        expect(
          (await report(
            _deal(2),
            ReportReason.other,
            note: '   ',
          )).failureOrNull,
          isA<ValidationFailure>(),
        );
        await report(_deal(2), ReportReason.other, note: '  ${'x' * 600}  ');
        final row = (await backend.select(const TableQuery('reports'))).single;
        expect(row['reason'], 'other');
        expect((row['note']! as String).length, 500);
      },
    );

    test('reasons map to the database enum', () {
      expect(ReportReason.values.map((r) => r.wire), [
        'expired',
        'wrong_price',
        'wrong_place',
        'closed',
        'spam',
        'offensive',
        'other',
      ]);
    });
  });
}
