import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/data/preferences_store.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

/// The preferences saved by an earlier session, read once in `bootstrap`
/// before the first frame, so a returning shopper never sees onboarding
/// flash by. Defaults to a first launch; `null` means they couldn't be
/// read (a storage error), which is not the same as nothing saved.
final savedPreferencesProvider = Provider<ShopperPreferences?>(
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

/// Whether the shopper has chosen a language: saved from an earlier
/// session, or confirmed on the first onboarding step. Until then every
/// onboarding link starts at that step, the one that can't be skipped
/// (QA 4.1 BUG-5).
final languageChosenProvider = NotifierProvider<LanguageChosen, bool>(
  LanguageChosen.new,
);

final class LanguageChosen extends Notifier<bool> {
  @override
  bool build() => ref.watch(savedLocaleProvider) != null;

  void confirm() => state = true;
}

/// Whether onboarding is done: the router's redirect listens to this.
final onboardedProvider = Provider<bool>(
  (ref) => ref.watch(preferencesProvider.select((p) => p.onboarded)),
);

final class PreferencesController extends Notifier<ShopperPreferences> {
  /// False while the saved preferences couldn't be read: writing then would
  /// replace a returning shopper's choices with whatever this session holds.
  bool _canSave = true;

  /// Bumped by [reset]: a re-read that started before it must not bring
  /// the old choices back.
  int _generation = 0;

  @override
  ShopperPreferences build() {
    final saved = ref.watch(savedPreferencesProvider);
    if (saved != null) {
      _canSave = true;
      return saved;
    }
    _canSave = false;
    unawaited(Future.microtask(_recover));
    return const ShopperPreferences();
  }

  /// Tries the read again. What was saved wins if it holds anything;
  /// otherwise this session's choices are kept (and now saved). If it still
  /// fails, choices stay in memory for this session only.
  Future<void> _recover() async {
    final generation = _generation;
    final ShopperPreferences stored;
    try {
      stored = await ref.read(preferencesStoreProvider).read();
    } on Object catch (error) {
      if (!ref.mounted) return;
      ref
          .read(loggerProvider)
          .warning(
            'Saved preferences still unreadable; not saving this session',
            error: error,
          );
      return;
    }
    if (!ref.mounted || generation != _generation) return;
    if (stored != const ShopperPreferences()) state = stored;
    _canSave = true;
    if (state == stored) return;
    try {
      await ref.read(preferencesStoreProvider).write(state);
    } on Object catch (error) {
      if (!ref.mounted) return;
      ref
          .read(loggerProvider)
          .warning('Could not save the shopper preferences', error: error);
    }
  }

  Future<void> _update(ShopperPreferences next) async {
    if (next == state) return;
    state = next;
    if (!_canSave) return;
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

  Future<void> toggleCategoryFollow(String categoryId) => _update(
    state.copyWith(
      categoryFollowIds: _toggle(state.categoryFollowIds, categoryId),
    ),
  );

  /// Drops followed brands and categories that are no longer offered
  /// (switched off or removed), so the Following count matches its list
  /// and nothing is left that can't be unfollowed (QA 4.8 BUG-7). Only
  /// called after a successful read of what is offered.
  Future<void> keepFollows({Set<String>? brandIds, Set<String>? categoryIds}) {
    final brands = [
      for (final id in state.brandIds)
        if (brandIds == null || brandIds.contains(id)) id,
    ];
    final categories = [
      for (final id in state.categoryFollowIds)
        if (categoryIds == null || categoryIds.contains(id)) id,
    ];
    if (brands.length == state.brandIds.length &&
        categories.length == state.categoryFollowIds.length) {
      return Future.value();
    }
    return _update(
      state.copyWith(brandIds: brands, categoryFollowIds: categories),
    );
  }

  /// Adds follows kept in the account (signed in on another phone): the
  /// phone keeps its own, and gains these.
  Future<void> addFollows({
    Iterable<String> brandIds = const [],
    Iterable<String> categoryIds = const [],
  }) => _update(
    state.copyWith(
      brandIds: {...state.brandIds, ...brandIds}.toList(),
      categoryFollowIds: {...state.categoryFollowIds, ...categoryIds}.toList(),
    ),
  );

  /// Replaces the followed brands and categories on the phone (empty by
  /// default), as when another account's are dropped at sign-in.
  Future<void> setFollows({
    List<String> brandIds = const [],
    List<String> categoryIds = const [],
  }) => _update(
    state.copyWith(brandIds: brandIds, categoryFollowIds: categoryIds),
  );

  Future<void> markAlertsAsked(DateTime at) =>
      _update(state.copyWith(alertsAskedAt: at));

  /// Back to a first launch (after account deletion): everything chosen
  /// is forgotten, and the router returns to onboarding.
  Future<void> reset() async {
    _generation++;
    _canSave = true;
    state = const ShopperPreferences();
    try {
      await ref.read(preferencesStoreProvider).clear();
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning('Could not clear the shopper preferences', error: error);
    }
  }

  /// Ends onboarding: from now on the app opens on Home.
  Future<void> completeOnboarding() => _update(state.copyWith(onboarded: true));

  static List<String> _toggle(List<String> ids, String id) => ids.contains(id)
      ? [
          for (final x in ids)
            if (x != id) x,
        ]
      : [...ids, id];
}
