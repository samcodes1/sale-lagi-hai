import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/catalog/data/backend_catalog_repository.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => BackendCatalogRepository(ref.watch(backendGatewayProvider)),
);

/// Runs a catalog read, failing the provider with an [AppFailure] (never a
/// raw backend error), so screens show a friendly message and the retry
/// policy knows what is worth retrying.
Future<T> _load<T>(Ref ref, Future<T> Function() body) async {
  final result = await guard(
    body,
    logger: ref.read(loggerProvider),
    mappers: [backendErrorMapper, _formatMapper],
  );
  return switch (result) {
    Success(:final value) => value,
    Failure(:final failure) => throw failure,
  };
}

AppFailure? _formatMapper(Object error, StackTrace stackTrace) =>
    error is FormatException
    ? ServerFailure(cause: error, stackTrace: stackTrace)
    : null;

final citiesProvider = FutureProvider<List<City>>(
  (ref) => _load(ref, ref.watch(catalogRepositoryProvider).cities),
);

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => _load(ref, ref.watch(catalogRepositoryProvider).categories),
);

/// Top-level categories: the interests shoppers pick.
final interestsProvider = FutureProvider<List<Category>>((ref) async {
  final all = await ref.watch(categoriesProvider.future);
  return [
    for (final c in all)
      if (c.isTopLevel) c,
  ];
});

/// Active brands in the given top-level interests (and their
/// subcategories); every brand when the list is empty. The key is the
/// interests' ids sorted and joined, so equal selections share a result.
final FutureProviderFamily<List<Brand>, String> brandsForInterestsProvider =
    FutureProvider.family<List<Brand>, String>((ref, interestKey) async {
      final repository = ref.watch(catalogRepositoryProvider);
      if (interestKey.isEmpty) return await _load(ref, repository.brands);
      final interests = interestKey.split(',').toSet();
      final all = await ref.watch(categoriesProvider.future);
      final ids = [
        for (final c in all)
          if (interests.contains(c.id) || interests.contains(c.parentId)) c.id,
      ];
      return await _load(ref, () => repository.brands(categoryIds: ids));
    });

/// The [brandsForInterestsProvider] key for a selection.
String interestKey(Iterable<String> categoryIds) =>
    (categoryIds.toList()..sort()).join(',');

/// A brand page's brand. A missing or hidden brand is a NotFoundFailure.
final FutureProviderFamily<Brand, String> brandProvider =
    FutureProvider.family<Brand, String>((ref, slug) async {
      final brand = await _load(
        ref,
        () => ref.watch(catalogRepositoryProvider).brandBySlug(slug),
      );
      return brand ?? (throw const NotFoundFailure());
    });
