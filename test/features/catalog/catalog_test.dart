import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/data/backend_catalog_repository.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';

/// A gateway whose tables return [rows] (or throw [error]).
final class _TableGateway implements BackendGateway {
  new({this.rows = const [], this.error});

  final List<Map<String, Object?>> rows;
  final Object? error;
  final queries = <TableQuery>[];

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    queries.add(query);
    if (error case final e?) Error.throwWithStackTrace(e, StackTrace.current);
    return rows;
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) => throw UnimplementedError();

  @override
  Future<void> insert(String table, Map<String, Object?> row) =>
      throw UnimplementedError();

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      throw UnimplementedError();
}

ProviderContainer _container(BackendGateway backend) {
  final container = ProviderContainer(
    overrides: [
      backendGatewayProvider.overrideWithValue(backend),
      loggerProvider.overrideWithValue(AppLogger(sinks: [])),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final repository = BackendCatalogRepository(DemoGateway());

  group('BackendCatalogRepository', () {
    test('cities: live ones first, with their centres', () async {
      final cities = await repository.cities();
      expect(cities.first.slug, 'karachi');
      expect(cities.first.isLive, isTrue);
      expect(cities.skip(1).every((c) => !c.isLive), isTrue);
      expect(cities.first.latitude, closeTo(24.86, 0.01));
      expect(cities.first.longitude, closeTo(67.00, 0.01));
    });

    test('categories: active ones, top-level and sub', () async {
      final categories = await repository.categories();
      expect(categories.where((c) => c.isTopLevel), isNotEmpty);
      expect(categories.where((c) => !c.isTopLevel), isNotEmpty);
    });

    test('brands: active, by name, optionally by category', () async {
      final all = await repository.brands();
      expect(
        all.map((b) => b.name),
        orderedEquals([...all.map((b) => b.name)]..sort()),
      );
      final food = await repository.brands(
        categoryIds: [categoryId('fast-food')],
      );
      expect(food.map((b) => b.slug), ['demo-burger-point']);
    });

    test('asks only for the columns it reads, and caps brand lists', () async {
      final backend = _TableGateway();
      final repo = BackendCatalogRepository(backend);
      await repo.cities();
      await repo.brands(limit: 5000);
      expect(backend.queries.first.columns, contains('center_lat'));
      expect(backend.queries.last.limit, 100);
      expect(backend.queries.last.equals, {'is_active': true});
    });

    test(
      'areas of a city, by name; active banks with their short names',
      () async {
        final areas = await repository.areas(karachiId);
        expect(areas.map((a) => a.nameEn), contains('Clifton'));
        expect(areas.every((a) => a.cityId == karachiId), isTrue);
        expect(await repository.areas(lahoreId), isEmpty);
        final banks = await repository.banks();
        expect(banks.map((b) => b.shortName), containsAll(['HBL', 'Meezan']));
        expect(banks.first.name(urdu: true), isNotEmpty);
      },
    );

    test('areas and banks are equal by id', () {
      const a = Area(
        id: 'a',
        cityId: 'k',
        slug: 's',
        nameEn: 'Clifton',
        nameUr: 'کلفٹن',
      );
      const b = Bank(
        id: 'b',
        slug: 'hbl',
        nameEn: 'HBL',
        nameUr: 'ایچ بی ایل',
        shortName: 'HBL',
      );
      expect(
        a,
        const Area(id: 'a', cityId: 'x', slug: 'y', nameEn: '', nameUr: ''),
      );
      expect(a.hashCode, 'a'.hashCode);
      expect(a.name(urdu: true), 'کلفٹن');
      expect(
        b,
        const Bank(id: 'b', slug: '', nameEn: '', nameUr: '', shortName: ''),
      );
      expect(b.hashCode, 'b'.hashCode);
      expect(b.name(urdu: false), 'HBL');
    });

    test(
      'brand suggestions: prefix first, typos too, never for nothing',
      () async {
        expect((await repository.suggestBrands('kara')).map((b) => b.slug), [
          'demo-karahi-house',
        ]);
        expect(
          (await repository.suggestBrands('karahy')).map((b) => b.slug),
          contains('demo-karahi-house'),
        );
        expect(await repository.suggestBrands('  '), isEmpty);
        expect(await repository.suggestBrands('k' * 61), isEmpty);
      },
    );

    test('a malformed row is a FormatException, never a half-filled city', () {
      final repo = BackendCatalogRepository(
        _TableGateway(
          rows: [
            {'id': 'x', 'slug': 'karachi'},
          ],
        ),
      );
      expect(repo.cities(), throwsFormatException);
    });
  });

  group('nearestCity', () {
    late List<City> cities;
    setUpAll(() async => cities = await repository.cities());

    test('a point in Clifton is Karachi', () {
      expect(nearestCity(cities, 24.81, 67.03)?.slug, 'karachi');
    });

    test('a point in Lahore is Lahore, even though it is not live', () {
      expect(nearestCity(cities, 31.55, 74.34)?.slug, 'lahore');
    });

    test('a point far from every city matches none', () {
      // Gwadar: about 480 km from Karachi.
      expect(nearestCity(cities, 25.12, 62.32), isNull);
      expect(nearestCity(const [], 24.8, 67), isNull);
    });

    test('distance is symmetric and zero at the centre', () {
      final karachi = cities.first;
      expect(karachi.distanceKm(karachi.latitude, karachi.longitude), 0);
      expect(karachi.distanceKm(31.5204, 74.3587), closeTo(1030, 30));
    });
  });

  group('providers', () {
    test('interests are the top-level categories', () async {
      final container = _container(DemoGateway());
      final interests = await container.read(interestsProvider.future);
      expect(interests, isNotEmpty);
      expect(interests.every((c) => c.isTopLevel), isTrue);
    });

    test('brands for an interest include its subcategories', () async {
      final container = _container(DemoGateway());
      final categories = await container.read(categoriesProvider.future);
      final food = categories.firstWhere(
        (c) => c.slug == 'food-and-restaurants',
      );
      final brands = await container.read(
        brandsForInterestsProvider(interestKey([food.id])).future,
      );
      expect(brands.map((b) => b.slug), {
        'demo-karahi-house',
        'demo-burger-point',
        'demo-chai-adda',
      });
    });

    test('the interest key ignores order', () {
      expect(interestKey(['b', 'a']), interestKey(['a', 'b']));
      expect(interestKey(const []), isEmpty);
    });

    test(
      'backend errors become AppFailures, malformed rows ServerFailure',
      () async {
        final offline = _container(
          _TableGateway(error: const OfflineFailure()),
        );
        await expectLater(
          offline.read(citiesProvider.future),
          throwsA(isA<OfflineFailure>()),
        );
        final malformed = _container(
          _TableGateway(
            rows: [
              {'id': 1},
            ],
          ),
        );
        await expectLater(
          malformed.read(categoriesProvider.future),
          throwsA(isA<ServerFailure>()),
        );
      },
    );
  });
}
