import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/popups/data/backend_popup_repository.dart';
import 'package:sale_lagi_hai/features/popups/domain/popup_banner.dart';

/// When this phone last showed each pop-up, by id. Only ids and times:
/// nothing about the shopper.
final class PopupSeenStore {
  const new(this._store);

  final KeyValueStore _store;

  static const key = 'popups.seen';

  /// Old entries are dropped past this many.
  static const _keep = 50;

  Future<Map<String, DateTime>> read() async {
    try {
      final raw = await _store.getString(key);
      if (raw == null) return {};
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) return {};
      return {
        for (final MapEntry(:key, :value) in json.entries)
          if (value is String) key: ?DateTime.tryParse(value),
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> markSeen(String id, DateTime at) async {
    final seen = await read()
      ..remove(id);
    final kept = seen.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    await _store.setString(
      key,
      jsonEncode({
        id: at.toUtc().toIso8601String(),
        for (final e in kept.take(_keep - 1))
          e.key: e.value.toUtc().toIso8601String(),
      }),
    );
  }
}

final popupSeenStoreProvider = Provider<PopupSeenStore>(
  (ref) => PopupSeenStore(ref.watch(keyValueStoreProvider)),
);

/// The pop-up to show over Home now: the most important running one for
/// the shopper's city that is due. A failure only means no pop-up.
final popupToShowProvider = FutureProvider<PopupBanner?>(
  (ref) async {
    final city = ref.watch(homeCityProvider);
    try {
      final popups = await BackendPopupRepository(
        ref.watch(backendGatewayProvider),
      ).live();
      if (popups.isEmpty) return null;
      final seen = await ref.read(popupSeenStoreProvider).read();
      final now = ref.read(clockProvider)();
      for (final popup in popups) {
        if (popup.cityId != null && popup.cityId != city) continue;
        if (popup.isDue(lastSeen: seen[popup.id], now: now)) return popup;
      }
      return null;
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning('Pop-up banners could not load', error: error);
      return null;
    }
  },
  retry: (_, _) => null,
);

/// At most one pop-up per app start, whatever else happens.
final popupShownThisRunProvider = NotifierProvider<PopupShownThisRun, bool>(
  PopupShownThisRun.new,
);

final class PopupShownThisRun extends Notifier<bool> {
  @override
  bool build() => false;

  /// Claims this run's pop-up; `false` if one already showed.
  bool claim() {
    if (state) return false;
    state = true;
    return true;
  }
}
