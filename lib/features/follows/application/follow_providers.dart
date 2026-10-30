import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

/// Following brands and categories. Guest-first: the phone keeps what is
/// followed (preferences), and a signed-in shopper's `follows` rows are
/// updated too, which is what alerts use (a failed mirror is logged; the
/// next sign-in syncs it).
final followsProvider = Provider<Follows>(Follows.new);

final class Follows {
  const new(this._ref);

  final Ref _ref;

  bool followsBrand(String id) =>
      _ref.read(preferencesProvider).brandIds.contains(id);

  bool followsCategory(String id) =>
      _ref.read(preferencesProvider).categoryFollowIds.contains(id);

  Future<void> toggleBrand(String brandId) async {
    final following = !followsBrand(brandId);
    await _ref.read(preferencesProvider.notifier).toggleBrand(brandId);
    await _mirror('brand_id', brandId, following: following);
  }

  Future<void> toggleCategory(String categoryId) async {
    final following = !followsCategory(categoryId);
    await _ref
        .read(preferencesProvider.notifier)
        .toggleCategoryFollow(categoryId);
    await _mirror('category_id', categoryId, following: following);
  }

  Future<void> _mirror(
    String column,
    String id, {
    required bool following,
  }) async {
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    try {
      final backend = _ref.read(backendGatewayProvider);
      if (following) {
        await backend.insert('follows', {'user_id': user.id, column: id});
      } else {
        await backend.delete('follows', {'user_id': user.id, column: id});
      }
    } on Object catch (error) {
      _ref
          .read(loggerProvider)
          .warning('Could not sync a follow', error: error);
    }
  }
}

/// The brands the shopper follows, by name (hidden ones left out).
final followedBrandsProvider = FutureProvider<List<Brand>>((ref) async {
  final ids = ref.watch(preferencesProvider.select((p) => p.brandIds));
  if (ids.isEmpty) return const [];
  final brands = await ref.watch(catalogRepositoryProvider).brandsByIds(ids);
  // A brand that is no longer offered can't be listed, so it isn't kept
  // either (QA 4.8 BUG-7).
  final offered = {for (final b in brands) b.id};
  if (ids.any((id) => !offered.contains(id))) {
    final preferences = ref.read(preferencesProvider.notifier);
    unawaited(
      Future.microtask(() => preferences.keepFollows(brandIds: offered)),
    );
  }
  return brands;
});

/// The followed categories that are offered, in catalog order. Once the
/// catalog has loaded, follows of categories it no longer has are dropped
/// (QA 4.8 BUG-7).
final followedCategoriesProvider = Provider<List<Category>>((ref) {
  final ids = ref.watch(preferencesProvider.select((p) => p.categoryFollowIds));
  final all = ref.watch(categoriesProvider);
  if (ids.isEmpty || all is! AsyncData<List<Category>>) return const [];
  final offered = {for (final c in all.value) c.id};
  if (offered.isNotEmpty && ids.any((id) => !offered.contains(id))) {
    final preferences = ref.read(preferencesProvider.notifier);
    unawaited(
      Future.microtask(() => preferences.keepFollows(categoryIds: offered)),
    );
  }
  return [
    for (final c in all.value)
      if (ids.contains(c.id)) c,
  ];
});
