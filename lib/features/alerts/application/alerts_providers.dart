import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/features/alerts/domain/app_alert.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';

/// The inbox, newest first, a page at a time. Empty for guests: alerts
/// are kept for signed-in shoppers only.
@immutable
final class InboxState {
  const new({
    required this.signedIn,
    this.alerts = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.moreFailure,
  });

  final bool signedIn;
  final List<AppAlert> alerts;
  final bool hasMore;
  final bool loadingMore;
  final AppFailure? moreFailure;

  bool get hasUnread => alerts.any((a) => a.isUnread);

  InboxState copyWith({
    List<AppAlert>? alerts,
    bool? hasMore,
    bool? loadingMore,
    AppFailure? Function()? moreFailure,
  }) => InboxState(
    signedIn: signedIn,
    alerts: alerts ?? this.alerts,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    moreFailure: moreFailure == null ? this.moreFailure : moreFailure(),
  );
}

final inboxProvider = AsyncNotifierProvider<Inbox, InboxState>(Inbox.new);

final class Inbox extends AsyncNotifier<InboxState> {
  static const pageSize = 30;

  Future<Result<T>> _guard<T>(Future<T> Function() body) => guard(
    body,
    logger: ref.read(loggerProvider),
    mappers: const [backendErrorMapper, _formatMapper],
  );

  static AppFailure? _formatMapper(Object error, StackTrace stackTrace) =>
      error is FormatException
      ? ServerFailure(cause: error, stackTrace: stackTrace)
      : null;

  Future<List<AppAlert>> _page(int offset) async {
    final rows = await ref
        .read(backendGatewayProvider)
        .select(
          TableQuery(
            'notifications',
            columns: 'id,kind,title,body,deal_id,created_at,read_at',
            orderBy: 'created_at',
            ascending: false,
            limit: pageSize,
            offset: offset,
          ),
        );
    return [for (final row in rows) AppAlert.fromRow(row)];
  }

  @override
  Future<InboxState> build() async {
    final user = ref.watch(currentUserProvider.select((u) => u.value?.id));
    if (user == null) return const InboxState(signedIn: false);
    final result = await _guard(() => _page(0));
    return switch (result) {
      Success(:final value) => InboxState(
        signedIn: true,
        alerts: value,
        hasMore: value.length == pageSize,
      ),
      Failure(:final failure) => throw failure,
    };
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(
      current.copyWith(loadingMore: true, moreFailure: () => null),
    );
    final result = await _guard(() => _page(current.alerts.length));
    if (!ref.mounted) return;
    state = AsyncData(switch (result) {
      Success(:final value) => () {
        final seen = {for (final a in current.alerts) a.id};
        final fresh = [
          for (final a in value)
            if (!seen.contains(a.id)) a,
        ];
        return current.copyWith(
          alerts: [...current.alerts, ...fresh],
          hasMore: value.length == pageSize && fresh.isNotEmpty,
          loadingMore: false,
        );
      }(),
      Failure(:final failure) => current.copyWith(
        loadingMore: false,
        moreFailure: () => failure,
      ),
    });
  }

  /// Marks [alert] read: at once on screen, then on the server. A failed
  /// write is logged; the next load shows the server's view.
  Future<void> markRead(AppAlert alert) => _mark(ids: [alert.id]);

  Future<void> markAllRead() => _mark();

  Future<void> _mark({List<String>? ids}) async {
    final current = state.value;
    if (current == null || !current.signedIn) return;
    final now = ref.read(clockProvider)();
    state = AsyncData(
      current.copyWith(
        alerts: [
          for (final a in current.alerts)
            if (ids == null || ids.contains(a.id)) a.read(now) else a,
        ],
      ),
    );
    final result = await _guard(
      () => ref.read(backendGatewayProvider).rpc('mark_alerts_read', {
        'ids': ?ids,
      }),
    );
    if (result case Failure(:final failure)) {
      ref
          .read(loggerProvider)
          .warning(
            'Could not mark alerts read',
            context: {'code': failure.code},
          );
    }
    if (ref.mounted) ref.invalidate(alertsBadgeProvider);
  }
}

/// When the Alerts tab was last opened, on this phone.
const alertsSeenKey = 'alerts.seen_at.v1';

/// The Alerts tab's badge: unread alerts that came after the tab was last
/// opened (capped at 100 by the server). 0 for guests, and when unknown.
final alertsBadgeProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider.select((u) => u.value?.id));
  if (user == null) return 0;
  String? since;
  try {
    since = await ref.read(keyValueStoreProvider).getString(alertsSeenKey);
  } on Object {
    since = null;
  }
  try {
    final rows = await ref.read(backendGatewayProvider).rpc(
      'unread_alert_count',
      {'since': ?since},
    );
    return switch (rows.firstOrNull?['value']) {
      final int count => count,
      _ => 0,
    };
  } on Object {
    // The badge is a hint: no error to show for it.
    return 0;
  }
});

/// The Alerts tab was opened: its badge clears.
Future<void> markAlertsSeen(WidgetRef ref) async {
  final now = ref.read(clockProvider)().toUtc().toIso8601String();
  try {
    await ref.read(keyValueStoreProvider).setString(alertsSeenKey, now);
  } on Object catch (error) {
    ref
        .read(loggerProvider)
        .warning(
          'Could not save when alerts were seen',
          context: {'error': error.runtimeType.toString()},
        );
  }
  ref.invalidate(alertsBadgeProvider);
}
