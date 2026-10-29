import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/settings/domain/alert_prefs.dart';

/// The signed-in shopper's alert preferences; `null` for guests (alerts
/// are kept per account).
final alertPrefsProvider =
    AsyncNotifierProvider<AlertPrefsController, AlertPrefs?>(
      AlertPrefsController.new,
    );

final class AlertPrefsController extends AsyncNotifier<AlertPrefs?> {
  Future<Result<T>> _guard<T>(Future<T> Function() body) => guard(
    body,
    logger: ref.read(loggerProvider),
    mappers: const [backendErrorMapper],
  );

  @override
  Future<AlertPrefs?> build() async {
    final user = ref.watch(currentUserProvider.select((u) => u.value?.id));
    if (user == null) return null;
    final result = await _guard(
      () => ref.read(backendGatewayProvider).rpc('my_alert_prefs'),
    );
    return switch (result) {
      Success(:final value) =>
        value.isEmpty ? const AlertPrefs() : AlertPrefs.fromRow(value.first),
      Failure(:final failure) => throw failure,
    };
  }

  /// Shows [next] at once and saves the fields that changed. On failure
  /// the old values come back and the failure is returned, so the screen
  /// can say so (UX S19: "Save failed → revert + toast").
  Future<AppFailure?> change(AlertPrefs next) async {
    final before = state.value;
    if (before == null || before == next) return null;
    state = AsyncData(next);
    String? when(({int hour, int minute}) a, ({int hour, int minute}) b) =>
        a == b ? null : AlertPrefs.wireTime(b);
    bool? flag({required bool from, required bool to}) =>
        from == to ? null : to;
    final result = await _guard(
      () => ref.read(backendGatewayProvider).rpc('update_alert_prefs', {
        'push_enabled': ?flag(from: before.pushEnabled, to: next.pushEnabled),
        'frequency': ?(before.frequency == next.frequency
            ? null
            : next.frequency.name),
        'quiet_start': ?when(before.quietStart, next.quietStart),
        'quiet_end': ?when(before.quietEnd, next.quietEnd),
        'followed_brands': ?flag(
          from: before.followedBrands,
          to: next.followedBrands,
        ),
        'followed_categories': ?flag(
          from: before.followedCategories,
          to: next.followedCategories,
        ),
        'my_cards': ?flag(from: before.myCards, to: next.myCards),
        'my_city': ?flag(from: before.myCity, to: next.myCity),
        'saved_price_drops': ?flag(
          from: before.savedPriceDrops,
          to: next.savedPriceDrops,
        ),
        'saved_expiring': ?flag(
          from: before.savedExpiring,
          to: next.savedExpiring,
        ),
      }),
    );
    if (!ref.mounted) return null;
    switch (result) {
      case Success():
        return null;
      case Failure(:final failure):
        state = AsyncData(before);
        return failure;
    }
  }
}
