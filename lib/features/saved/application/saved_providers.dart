import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';

/// Where saved deal ids live on the phone (newest first).
const savedDealsKey = 'saved.v1';

/// The deals the shopper saved, newest first. Guest-first: kept on the
/// phone always, and mirrored into the account's `saves` when signed in
/// (a failed mirror is logged; the phone copy still holds). The Saved tab
/// (4.8) shows them.
final savedDealsProvider = NotifierProvider<SavedDeals, List<String>>(
  SavedDeals.new,
);

final class SavedDeals extends Notifier<List<String>> {
  /// At most this many saved deals on the phone.
  static const limit = 500;

  @override
  List<String> build() {
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    try {
      final raw = await ref
          .read(keyValueStoreProvider)
          .getString(savedDealsKey);
      if (raw == null || !ref.mounted) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final ids = [
        for (final id in decoded)
          if (id is String && id.isNotEmpty) id,
      ];
      // Saves made before the file was read come first.
      state = {...state, ...ids}.take(limit).toList();
    } on Object catch (error) {
      if (!ref.mounted) return;
      ref
          .read(loggerProvider)
          .warning('Could not read saved deals', error: error);
    }
  }

  bool isSaved(String dealId) => state.contains(dealId);

  Future<void> toggle(String dealId) async {
    final saving = !state.contains(dealId);
    state = saving
        ? [dealId, ...state].take(limit).toList()
        : [
            for (final id in state)
              if (id != dealId) id,
          ];
    try {
      await ref
          .read(keyValueStoreProvider)
          .setString(savedDealsKey, jsonEncode(state));
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning('Could not save the saved deals', error: error);
    }
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    try {
      final backend = ref.read(backendGatewayProvider);
      if (saving) {
        await backend.insert('saves', {'deal_id': dealId});
      } else {
        await backend.delete('saves', {'user_id': user.id, 'deal_id': dealId});
      }
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning('Could not sync a saved deal', error: error);
    }
  }
}
