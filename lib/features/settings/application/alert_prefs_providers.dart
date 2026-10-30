import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
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

/// Where changes made offline wait to be sent (UX S19 "Queued"): one
/// queue per account, under this key plus `.<user id>` (QA P4-R2-1).
const alertPrefsQueueKey = 'settings.alert_prefs.queued.v1';

/// The storage key of [user]'s queue.
String alertPrefsQueueKeyFor(String user) => '$alertPrefsQueueKey.$user';

final class AlertPrefsController extends AsyncNotifier<AlertPrefs?> {
  /// Changes made offline, as `update_alert_prefs` fields, not yet sent
  /// (QA 4.9-N6). Kept on the phone, so closing the app doesn't lose them.
  Map<String, Object?> _queued = const {};
  String? _user;

  /// Whether changes made offline are waiting to be sent.
  bool get queued => _queued.isNotEmpty;

  bool get _offline =>
      ref.read(networkStatusProvider).value == NetworkStatus.offline;

  Future<Result<T>> _guard<T>(Future<T> Function() body) => guard(
    body,
    logger: ref.read(loggerProvider),
    mappers: const [backendErrorMapper],
  );

  @override
  Future<AlertPrefs?> build() async {
    // A new account (or none) starts with no queue in memory: another
    // account's must never be sent under this one (QA P4-R2-1).
    _queued = const {};
    _user = null;
    final user = ref.watch(
      currentUserProvider.select(
        (u) => u.hasValue || u.hasError ? (id: u.value?.id) : null,
      ),
    );
    // Still loading the sign-in state: stay loading (a signed-in shopper
    // never sees the guest view first); the state's arrival rebuilds this.
    if (user == null) return await Completer<AlertPrefs?>().future;
    final id = user.id;
    if (id == null) return null;
    _user = id;
    final queue = await _readQueue(id);
    if (!ref.mounted) return null;
    _queued = queue;
    // Back online: what waited goes out.
    ref.listen(networkStatusProvider, (_, next) {
      if (next.value == NetworkStatus.online && queued) unawaited(_flush());
    });
    final result = await _guard(
      () => ref.read(backendGatewayProvider).rpc('my_alert_prefs'),
    );
    final saved = switch (result) {
      Success(:final value) =>
        value.isEmpty ? const AlertPrefs() : AlertPrefs.fromRow(value.first),
      Failure(:final failure) => throw failure,
    };
    if (!queued) return saved;
    if (!_offline) unawaited(Future.microtask(_flush));
    return AlertPrefs.fromRow({...saved.toRow(), ..._queued});
  }

  Future<Map<String, Object?>> _readQueue(String user) async {
    try {
      final raw = await ref
          .read(keyValueStoreProvider)
          .getString(alertPrefsQueueKeyFor(user));
      if (raw == null) return const {};
      final json = jsonDecode(raw);
      if (json is Map && json['user'] == user && json['changes'] is Map) {
        return Map<String, Object?>.from(json['changes'] as Map);
      }
    } on Object catch (error) {
      _warn('Could not read queued alert settings', error);
    }
    return const {};
  }

  Future<void> _writeQueue() async {
    final user = _user;
    if (user == null) return;
    final store = ref.read(keyValueStoreProvider);
    try {
      if (_queued.isEmpty) {
        await store.remove(alertPrefsQueueKeyFor(user));
      } else {
        await store.setString(
          alertPrefsQueueKeyFor(user),
          jsonEncode({'user': user, 'changes': _queued}),
        );
      }
    } on Object catch (error) {
      _warn('Could not keep queued alert settings', error);
    }
  }

  void _warn(String message, Object error) => ref
      .read(loggerProvider)
      .warning(message, context: {'error': error.runtimeType.toString()});

  /// Sends what waited. A refusal (not a lost connection) drops it and
  /// shows what the server holds.
  Future<void> _flush() async {
    final sending = _queued;
    final user = _user;
    if (sending.isEmpty || user == null) return;
    // Only under the account that queued it (QA P4-R2-1).
    if (ref.read(authRepositoryProvider).currentUser?.id != user) return;
    final result = await _guard(() async {
      final rows = await ref
          .read(backendGatewayProvider)
          .rpc('update_alert_prefs', sending);
      if (rows.isEmpty) throw const UnexpectedFailure();
    });
    if (!ref.mounted) return;
    switch (result) {
      case Success():
        _queued = {
          for (final MapEntry(:key, :value) in _queued.entries)
            if (sending[key] != value) key: value,
        };
        await _writeQueue();
      case Failure(failure: OfflineFailure() || TimeoutFailure()):
        break;
      case Failure():
        _queued = const {};
        await _writeQueue();
        if (ref.mounted) ref.invalidateSelf();
    }
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
    // Offline: kept on the phone and sent when back (UX S19 "Queued").
    if (_offline) {
      _queued = {..._queued, ...changed};
      await _writeQueue();
      return null;
    }
    // What waited goes first, on its own: a queued field the server
    // refuses is dropped there and can't block this change.
    if (queued) await _flush();
    if (!ref.mounted) return null;
    final sending = {..._queued, ...changed};
    final result = await _guard(() async {
      final rows = await ref
          .read(backendGatewayProvider)
          .rpc('update_alert_prefs', sending);
      // No row: nothing was saved (QA 4.9-N5).
      if (rows.isEmpty) throw const UnexpectedFailure();
    });
    if (!ref.mounted) return null;
    switch (result) {
      case Success():
        if (queued) {
          _queued = {
            for (final MapEntry(:key, :value) in _queued.entries)
              if (sending[key] != value) key: value,
          };
          await _writeQueue();
        }
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
