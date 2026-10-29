import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
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
