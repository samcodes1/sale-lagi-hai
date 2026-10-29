import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/storage/stored_string_list.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

/// Where saved deal ids live on the phone (newest first).
const savedDealsKey = 'saved.v1';

/// The deals the shopper saved, newest first. Guest-first: kept on the
/// phone always, and mirrored into the account's `saves` when signed in
/// (a failed mirror is logged; the phone copy still holds). The Saved tab
/// (4.8) shows them.
final savedDealsProvider = NotifierProvider<SavedDeals, List<String>>(
  SavedDeals.new,
);

final class SavedDeals extends StoredStringList {
  /// At most this many saved deals on the phone.
  static const max = 500;

  @override
  String get storageKey => savedDealsKey;

  @override
  int get limit => max;

  @override
  String get what => 'saved deals';

  @override
  List<String> build() {
    // A fresh start (account deleted) forgets them.
    ref.watch(onboardedProvider);
    return super.build();
  }

  bool isSaved(String dealId) => state.contains(dealId);

  Future<void> toggle(String dealId) async {
    var saving = false;
    final next = await update((current) {
      saving = !current.contains(dealId);
      return saving
          ? [dealId, ...current]
          : [
              for (final id in current)
                if (id != dealId) id,
            ];
    });
    if (next == null) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    try {
      final backend = ref.read(backendGatewayProvider);
      if (saving) {
        await backend.insert('saves', {'user_id': user.id, 'deal_id': dealId});
      } else {
        await backend.delete('saves', {'user_id': user.id, 'deal_id': dealId});
      }
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning(
            'Could not sync a saved deal',
            context: {'error': error.runtimeType.toString()},
          );
    }
  }
}
