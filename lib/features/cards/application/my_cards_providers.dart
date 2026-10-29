import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/storage/stored_string_list.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

/// Where the shopper's cards live on the phone: card product ids only.
const myCardsKey = 'cards.v1';

/// The shopper's cards, as card products ("HBL Visa Platinum Credit"),
/// in the order added. Never a card number: the app has nowhere to type
/// one. Guest-first like saves and follows: kept on the phone always,
/// mirrored into the account's `user_cards` when signed in.
final myCardsProvider = NotifierProvider<MyCards, List<String>>(MyCards.new);

final class MyCards extends StoredStringList {
  /// At most this many cards (the server reads 20).
  static const max = 20;

  @override
  String get storageKey => myCardsKey;

  @override
  int get limit => max;

  @override
  String get what => 'my cards';

  @override
  List<String> build() {
    // A fresh start (account deleted) forgets them.
    ref.watch(onboardedProvider);
    return super.build();
  }

  bool has(String cardProductId) => state.contains(cardProductId);

  /// Drops cards the catalog no longer offers (retired products), here
  /// and in the account, so they neither hide nor count toward the limit
  /// (QA 4.7-A1). [offered] is the full, freshly loaded catalog.
  Future<void> keepOnly(Set<String> offered) async {
    final retired = [
      for (final id in state)
        if (!offered.contains(id)) id,
    ];
    if (retired.isEmpty) return;
    final next = await update(
      (current) => [
        for (final id in current)
          if (!retired.contains(id)) id,
      ],
    );
    if (next == null) return;
    for (final id in retired) {
      await _mirror(
        (backend, userId) => backend.delete('user_cards', {
          'user_id': userId,
          'card_product_id': id,
        }),
      );
    }
  }

  /// Adds cards kept in the account (added on another phone).
  Future<void> addFromAccount(Iterable<String> cardProductIds) =>
      update((current) => {...current, ...cardProductIds}.toList());

  /// Adds a card; false when there are already [max].
  Future<bool> add(String cardProductId) async {
    // The limit counts the stored cards too (QA 4.7-A4).
    await loaded;
    if (!ref.mounted) return false;
    var added = false;
    final next = await update((current) {
      if (current.contains(cardProductId)) {
        added = true;
        return current;
      }
      if (current.length >= max) return current;
      added = true;
      return [...current, cardProductId];
    });
    if (next == null || !added) return added;
    await _mirror(
      (backend, userId) => backend.insert('user_cards', {
        'user_id': userId,
        'card_product_id': cardProductId,
      }),
    );
    return true;
  }

  Future<void> remove(String cardProductId) async {
    final next = await update(
      (current) => [
        for (final id in current)
          if (id != cardProductId) id,
      ],
    );
    if (next == null) return;
    await _mirror(
      (backend, userId) => backend.delete('user_cards', {
        'user_id': userId,
        'card_product_id': cardProductId,
      }),
    );
  }

  /// Signed in: the account's copy follows (a failure keeps the phone's;
  /// the next sign-in syncs it).
  Future<void> _mirror(
    Future<void> Function(BackendGateway backend, String userId) change,
  ) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    try {
      await change(ref.read(backendGatewayProvider), user.id);
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning(
            'Could not sync my cards',
            context: {'error': error.runtimeType.toString()},
          );
    }
  }
}
