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

  /// Adds saves kept in the account (made on another phone), after the
  /// phone's own.
  Future<void> addFromAccount(Iterable<String> dealIds) =>
      update((current) => {...current, ...dealIds}.toList());

  /// Removes [dealIds] (the Saved tab's "Remove ended deals"), from the
  /// account too when signed in, so the next sign-in doesn't bring them
  /// back (QA 4.8 BUG-2).
  Future<void> removeAll(Iterable<String> dealIds) async {
    final gone = dealIds.toSet();
    if (gone.isEmpty) return;
    final next = await update(
      (current) => [
        for (final id in current)
          if (!gone.contains(id)) id,
      ],
    );
    if (next == null) return;
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    final backend = ref.read(backendGatewayProvider);
    final results = await Future.wait([
      for (final id in gone)
        backend
            .delete('saves', {'user_id': user.id, 'deal_id': id})
            .then((_) => true, onError: (Object _) => false),
    ]);
    final failed = results.where((ok) => !ok).length;
    if (failed > 0 && ref.mounted) {
      ref
          .read(loggerProvider)
          .warning('Could not remove saved deals', context: {'count': failed});
    }
  }

  /// Saves or unsaves [dealId]. A save goes first, or back at [at] (Undo
  /// on the Saved tab puts it where it was; QA 4.8 BUG-6).
  Future<void> toggle(String dealId, {int? at}) async {
    // The intent, decided from what the shopper sees, not re-decided when
    // replayed onto the file (QA 4.4 R2-1): saving twice keeps one.
    final saving = !state.contains(dealId);
    final next = await update((current) {
      final rest = [
        for (final id in current)
          if (id != dealId) id,
      ];
      if (!saving) return rest;
      return rest..insert((at ?? 0).clamp(0, rest.length), dealId);
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
