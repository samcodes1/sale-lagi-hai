import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/design_system/models/deal_offer.dart';
import 'package:sale_lagi_hai/features/deals/data/backend_deal_repository.dart';
import 'package:sale_lagi_hai/features/deals/data/deal_row.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_page.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, Object?> _row([Map<String, Object?> over = const {}]) => {
  'id': 'd1',
  'brand_id': 'b1',
  'brand_slug': 'khaadi',
  'brand_name': 'Khaadi',
  'brand_name_ur': 'کھادی',
  'brand_logo_path': null,
  'brand_is_verified': true,
  'category_id': 'c1',
  'category_slug': 'fashion',
  'kind': 'brand_sale',
  'scope': 'nationwide',
  'status': 'published',
  'title_en': 'Winter sale',
  'title_ur': 'سردیوں کی سیل',
  'offer_kind': 'up_to_percent_off',
  'percent': 50,
  'amount_off_pkr': null,
  'price_pkr': null,
  'original_price_pkr': null,
  'offer_text_en': null,
  'offer_text_ur': null,
  'promo_code': null,
  'url': 'https://example.com',
  'image_path': null,
  'starts_at': '2026-10-28T00:00:00Z',
  'ends_at': '2026-11-05T00:00:00Z',
  'verified_at': '2026-10-29T09:00:00Z',
  'published_at': '2026-10-28T10:00:00Z',
  'card_banks': ['HBL'],
  'is_featured': false,
  'distance_m': null,
  ...over,
};

/// Records calls and answers with canned rows (or throws).
final class _FakeGateway implements BackendGateway {
  final calls = <(String, Map<String, Object?>)>[];
  List<Map<String, Object?>> rows = [];
  Object? error;

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    calls.add((function, params));
    if (error case final e?) Error.throwWithStackTrace(e, StackTrace.current);
    return rows;
  }

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    calls.add((query.table, query.equals));
    if (error case final e?) Error.throwWithStackTrace(e, StackTrace.current);
    return rows;
  }

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {}

  @override
  Future<void> delete(String table, Map<String, Object?> match) async {}
}

void main() {
  group('dealFromRow', () {
    test('parses every field', () {
      final d = dealFromRow(_row());
      expect(d.brand(urdu: true), 'کھادی');
      expect(d.title(urdu: false), 'Winter sale');
      expect(d.offer(urdu: false), const UpToPercentOff(50));
      expect(d.endsAt, DateTime.utc(2026, 11, 5));
      expect(d.cardBanks, ['HBL']);
      expect(d.isLive(DateTime.utc(2026, 10, 29)), isTrue);
      expect(d.isLive(DateTime.utc(2026, 11, 6)), isFalse);
    });

    test('offers: text by language, prices give the real percentage', () {
      final text = dealFromRow(
        _row({
          'offer_kind': 'text',
          'percent': null,
          'offer_text_en': 'BOGO',
          'offer_text_ur': 'ایک کے ساتھ ایک',
        }),
      );
      expect(text.offer(urdu: true), const TextOffer('ایک کے ساتھ ایک'));
      expect(text.offer(urdu: false), const TextOffer('BOGO'));
      final priced = dealFromRow(
        _row({
          'offer_kind': 'fixed_price',
          'percent': null,
          'price_pkr': 2999,
          'original_price_pkr': 4999,
        }),
      );
      expect(priced.offer(urdu: false), const PercentOff(40));
      expect(
        dealFromRow(
          _row({
            'offer_kind': 'fixed_price',
            'percent': null,
            'price_pkr': 999,
          }),
        ).offer(urdu: false),
        isNull,
      );
    });

    test('a missing Urdu title falls back to English', () {
      expect(
        dealFromRow(_row({'title_ur': null})).title(urdu: true),
        'Winter sale',
      );
    });

    test('malformed rows are rejected, never half-filled', () {
      expect(() => dealFromRow(_row({'id': null})), throwsFormatException);
      expect(
        () => dealFromRow(_row({'offer_kind': 'mystery'})),
        throwsFormatException,
      );
      expect(() => dealFromRow(_row({'scope': 'mars'})), throwsFormatException);
      expect(() => dealFromRow(_row({'percent': '50'})), throwsFormatException);
    });
  });

  group('BackendDealRepository', () {
    late _FakeGateway gateway;
    late BackendDealRepository repo;
    setUp(() {
      gateway = _FakeGateway();
      repo = BackendDealRepository(gateway, AppLogger(sinks: const []));
    });

    test('feed sends only the filters given, and the cursor in UTC', () async {
      gateway.rows = [_row()];
      await repo.feed(
        cityId: 'k',
        after: FeedCursor(
          publishedAt: DateTime.utc(2026, 10, 28, 10),
          id: 'd0',
        ),
        pageSize: 1,
      );
      expect(gateway.calls.single.$1, 'feed');
      expect(gateway.calls.single.$2, {
        'city_id': 'k',
        'after_published_at': '2026-10-28T10:00:00.000Z',
        'after_id': 'd0',
        'page_size': 1,
      });
    });

    test('a full page has a next cursor; a short one does not', () async {
      gateway.rows = [_row()];
      final full = await repo.feed(pageSize: 1);
      expect(
        (full as Success<DealPage>).value.next,
        FeedCursor(publishedAt: DateTime.utc(2026, 10, 28, 10), id: 'd1'),
      );
      final short = await repo.feed(pageSize: 2);
      expect((short as Success<DealPage>).value.next, isNull);
    });

    test('search trims, and skips queries the server would ignore', () async {
      expect(await repo.search(' a '), isA<Success<List<Deal>>>());
      expect(gateway.calls, isEmpty);
      await repo.search('  karahi ');
      expect(gateway.calls.single.$2['query'], 'karahi');
    });

    test('featured uses the slot name the database knows', () async {
      await repo.featured(FeaturedSlot.homeFeatured, cityId: 'k');
      expect(gateway.calls.single.$1, 'featured_deals');
      expect(gateway.calls.single.$2, {
        'slot': 'home_featured',
        'city_id': 'k',
      });
    });

    test('errors become failures', () async {
      gateway.error = const PostgrestException(
        message: 'denied',
        code: '42501',
      );
      expect(
        (await repo.trending()) as Failure,
        isA<Failure<List<Deal>>>().having(
          (f) => f.failure,
          'failure',
          isA<ForbiddenFailure>(),
        ),
      );
      gateway
        ..error = null
        ..rows = [
          _row({'id': null}),
        ];
      expect(
        ((await repo.trending()) as Failure).failure,
        isA<ServerFailure>(),
        reason: 'a malformed row is a server failure',
      );
    });

    test('a missing deal is not found', () async {
      gateway.rows = [];
      expect(
        ((await repo.byId('nope')) as Failure).failure,
        isA<NotFoundFailure>(),
      );
    });
  });
}
