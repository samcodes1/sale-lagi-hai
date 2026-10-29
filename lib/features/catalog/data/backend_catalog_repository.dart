import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';

/// [CatalogRepository] over the public reference tables. Throws (backend
/// errors, or [FormatException] for a malformed row); callers decide how to
/// show a failure.
final class BackendCatalogRepository implements CatalogRepository {
  const new(this._backend);

  final BackendGateway _backend;

  static T _req<T>(Map<String, Object?> row, String table, String key) =>
      switch (row[key]) {
        final T value => value,
        _ => throw FormatException('$table.$key is missing or not $T'),
      };

  static T? _opt<T>(Map<String, Object?> row, String table, String key) =>
      switch (row[key]) {
        null => null,
        final T value => value,
        _ => throw FormatException('$table.$key is not $T'),
      };

  @override
  Future<List<City>> cities() async {
    final rows = await _backend.select(
      const TableQuery(
        'cities',
        columns: 'id,slug,name_en,name_ur,is_live,center_lat,center_lng',
        orderBy: 'sort_order',
      ),
    );
    final cities = [
      for (final row in rows)
        City(
          id: _req<String>(row, 'cities', 'id'),
          slug: _req<String>(row, 'cities', 'slug'),
          nameEn: _req<String>(row, 'cities', 'name_en'),
          nameUr: _req<String>(row, 'cities', 'name_ur'),
          isLive: _req<bool>(row, 'cities', 'is_live'),
          latitude: _req<num>(row, 'cities', 'center_lat').toDouble(),
          longitude: _req<num>(row, 'cities', 'center_lng').toDouble(),
        ),
    ];
    // Stable: live cities first, each group in sort order.
    return [
      ...cities.where((c) => c.isLive),
      ...cities.where((c) => !c.isLive),
    ];
  }

  @override
  Future<List<Category>> categories() async {
    final rows = await _backend.select(
      const TableQuery(
        'categories',
        columns: 'id,slug,parent_id,name_en,name_ur,icon',
        equals: {'is_active': true},
        orderBy: 'sort_order',
      ),
    );
    return [
      for (final row in rows)
        Category(
          id: _req<String>(row, 'categories', 'id'),
          slug: _req<String>(row, 'categories', 'slug'),
          parentId: _opt<String>(row, 'categories', 'parent_id'),
          nameEn: _req<String>(row, 'categories', 'name_en'),
          nameUr: _req<String>(row, 'categories', 'name_ur'),
          icon: _opt<String>(row, 'categories', 'icon') ?? 'local_offer',
        ),
    ];
  }

  @override
  Future<List<Brand>> brands({
    List<String>? categoryIds,
    int limit = 60,
  }) async {
    final rows = await _backend.select(
      TableQuery(
        'brands',
        columns: 'id,slug,name,name_ur,category_id,logo_path,is_verified',
        equals: const {'is_active': true},
        inList: {'category_id': ?categoryIds},
        orderBy: 'name',
        limit: limit.clamp(1, 100),
      ),
    );
    return [
      for (final row in rows)
        Brand(
          id: _req<String>(row, 'brands', 'id'),
          slug: _req<String>(row, 'brands', 'slug'),
          name: _req<String>(row, 'brands', 'name'),
          nameUr: _opt<String>(row, 'brands', 'name_ur'),
          categoryId: _req<String>(row, 'brands', 'category_id'),
          logoPath: _opt<String>(row, 'brands', 'logo_path'),
          isVerified: _opt<bool>(row, 'brands', 'is_verified') ?? false,
        ),
    ];
  }
}
