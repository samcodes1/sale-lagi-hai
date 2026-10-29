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
    try {
      final stored = await ref.read(preferencesStoreProvider).read();
      if (!ref.mounted) return;
      if (stored != const ShopperPreferences()) state = stored;
      _canSave = true;
      if (state != stored) {
        await ref.read(preferencesStoreProvider).write(state);
      }
    } on Object catch (error) {
      if (!ref.mounted) return;
      ref
          .read(loggerProvider)
          .warning(
            'Saved preferences still unreadable; not saving this session',
            error: error,
          );
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

  Future<void> markAlertsAsked(DateTime at) =>
      _update(state.copyWith(alertsAskedAt: at));

  /// Back to a first launch (after account deletion): everything chosen
  /// is forgotten, and the router returns to onboarding.
  Future<void> reset() async {
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
