import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:meta/meta.dart';
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

/// The areas of a city (search filter).
final FutureProviderFamily<List<Area>, String> areasProvider =
    FutureProvider.family<List<Area>, String>(
      (ref, cityId) =>
          _load(ref, () => ref.watch(catalogRepositoryProvider).areas(cityId)),
    );

/// Active banks (search filter, My Cards).
final banksProvider = FutureProvider<List<Bank>>(
  (ref) => _load(ref, ref.watch(catalogRepositoryProvider).banks),
);

/// Active card products of every bank (My Cards).
final cardProductsProvider = FutureProvider<List<CardProduct>>(
  (ref) => _load(ref, ref.watch(catalogRepositoryProvider).cardProducts),
);

/// Explore's brand list: every active brand by name, 60 at a time.
@immutable
final class BrandPages {
  const new({
    required this.brands,
    this.hasMore = false,
    this.loadingMore = false,
    this.moreFailure,
  });

  final List<Brand> brands;
  final bool hasMore;
  final bool loadingMore;
  final AppFailure? moreFailure;
}

final exploreBrandsProvider = AsyncNotifierProvider<ExploreBrands, BrandPages>(
  ExploreBrands.new,
);

final class ExploreBrands extends AsyncNotifier<BrandPages> {
  /// The repository's default page of brands.
  static const pageSize = 60;

  @override
  Future<BrandPages> build() async {
    final first = await _load(
      ref,
      () => ref.watch(catalogRepositoryProvider).brands(),
    );
    return BrandPages(brands: first, hasMore: first.length == pageSize);
  }

  /// The next 60; one page at a time. A failure shows a retry row.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(
      BrandPages(brands: current.brands, hasMore: true, loadingMore: true),
    );
    final result = await guard(
      () => ref
          .read(catalogRepositoryProvider)
          .brands(offset: current.brands.length),
      logger: ref.read(loggerProvider),
      mappers: [backendErrorMapper, _formatMapper],
    );
    if (!ref.mounted) return;
    state = AsyncData(switch (result) {
      Success(:final value) => () {
        // A brand added meanwhile can shift the pages: no repeats.
        final fresh = [
          for (final b in value)
            if (!current.brands.contains(b)) b,
        ];
        return BrandPages(
          brands: [...current.brands, ...fresh],
          // A page with nothing new ends the list rather than asking again.
          hasMore: value.length == pageSize && fresh.isNotEmpty,
        );
      }(),
      Failure(:final failure) => BrandPages(
        brands: current.brands,
        hasMore: true,
        moreFailure: failure,
      ),
    });
  }
}
