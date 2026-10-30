import 'dart:async';

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
    final user = ref.watch(
      currentUserProvider.select(
        (u) => u.hasValue || u.hasError ? (id: u.value?.id) : null,
      ),
    );
    // Still loading the sign-in state: stay loading (a signed-in shopper
    // never sees the guest view first); the state's arrival rebuilds this.
    if (user == null) return await Completer<AlertPrefs?>().future;
    if (user.id == null) return null;
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
  /// those fields come back as they were and the failure is returned, so
  /// the screen can say so (UX S19: "Save failed → revert + toast"). Only
  /// those: a later change that was saved stays (QA 4.9-N4).
  Future<AppFailure?> change(AlertPrefs next) async {
    final before = state.value;
    if (before == null || before == next) return null;
    final was = before.toRow();
    final now = next.toRow();
    final changed = {
      for (final MapEntry(:key, :value) in now.entries)
        if (was[key] != value && key != 'time_zone') key: value,
    };
    if (changed.isEmpty) return null;
    state = AsyncData(next);
    final result = await _guard(() async {
      final rows = await ref
          .read(backendGatewayProvider)
          .rpc('update_alert_prefs', changed);
      // No row: nothing was saved (QA 4.9-N5).
      if (rows.isEmpty) throw const UnexpectedFailure();
    });
    if (!ref.mounted) return null;
    switch (result) {
      case Success():
        return null;
      case Failure(:final failure):
        final current = state.value?.toRow() ?? now;
        state = AsyncData(
          AlertPrefs.fromRow({
            ...current,
            // Back as it was, unless changed again since.
            for (final key in changed.keys)
              if (current[key] == changed[key]) key: was[key],
          }),
        );
        return failure;
    }
  }
}
