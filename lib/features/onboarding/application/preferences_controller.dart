import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/data/preferences_store.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

/// The preferences saved by an earlier session, read once in `bootstrap`
/// before the first frame, so a returning shopper never sees onboarding
/// flash by. Defaults to a first launch.
final savedPreferencesProvider = Provider<ShopperPreferences>(
  (ref) => const ShopperPreferences(),
);

final preferencesStoreProvider = Provider<PreferencesStore>(
  (ref) => PreferencesStore(ref.watch(keyValueStoreProvider)),
);

/// The shopper's current preferences. Every change applies at once and is
/// saved in the background; a failed save is logged and the change still
/// holds for this session.
final preferencesProvider =
    NotifierProvider<PreferencesController, ShopperPreferences>(
      PreferencesController.new,
    );

/// Whether onboarding is done: the router's redirect listens to this.
final onboardedProvider = Provider<bool>(
  (ref) => ref.watch(preferencesProvider.select((p) => p.onboarded)),
);

final class PreferencesController extends Notifier<ShopperPreferences> {
  @override
  ShopperPreferences build() => ref.watch(savedPreferencesProvider);

  Future<void> _update(ShopperPreferences next) async {
    if (next == state) return;
    state = next;
    try {
      await ref.read(preferencesStoreProvider).write(next);
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning('Could not save the shopper preferences', error: error);
    }
  }

  /// `null` clears the city (nationwide and online deals only).
  Future<void> setCity(String? cityId) =>
      _update(state.copyWith(cityId: () => cityId));

  Future<void> toggleInterest(String categoryId) => _update(
    state.copyWith(interestIds: _toggle(state.interestIds, categoryId)),
  );

  Future<void> toggleBrand(String brandId) =>
      _update(state.copyWith(brandIds: _toggle(state.brandIds, brandId)));

  Future<void> markAlertsAsked(DateTime at) =>
      _update(state.copyWith(alertsAskedAt: at));

  /// Ends onboarding: from now on the app opens on Home.
  Future<void> completeOnboarding() => _update(state.copyWith(onboarded: true));

  static List<String> _toggle(List<String> ids, String id) => ids.contains(id)
      ? [
          for (final x in ids)
            if (x != id) x,
        ]
      : [...ids, id];
}
