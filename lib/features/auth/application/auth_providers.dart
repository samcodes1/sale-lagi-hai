import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
import 'package:sale_lagi_hai/features/cards/application/my_cards_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';

/// Overridden in `bootstrap()`: Supabase Auth, or the demo when there is
/// no backend.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError(
    'authRepositoryProvider must be overridden in bootstrap().',
  ),
);

/// The signed-in shopper, or `null` for a guest.
final currentUserProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).userChanges(),
);

/// Signs out, leaving the phone as a guest's (QA 4.8 BUG-9): the phone's
/// saved deals, cards and follows go into the account first (one call),
/// then from the phone, so the next person doesn't see them and what they
/// save as a guest goes into their own account. If that can't be sent
/// (offline), the lists stay on the phone rather than be lost; the note of
/// whose they are still keeps them out of any other account.
final signOutProvider = Provider<Future<Result<void>> Function()>(
  (ref) => () async {
    final saved = await _sendLists(ref);
    final result = await ref.read(authRepositoryProvider).signOut();
    if (result is Success && saved) await _forgetAccount(ref);
    return result;
  },
);

/// Sends the phone's lists into the signed-in account; whether they are
/// all there.
Future<bool> _sendLists(Ref ref) async {
  if (ref.read(authRepositoryProvider).currentUser == null) return false;
  await (
    ref.read(savedDealsProvider.notifier).loaded,
    ref.read(myCardsProvider.notifier).loaded,
  ).wait;
  final preferences = ref.read(preferencesProvider);
  final dealIds = ref.read(savedDealsProvider);
  final cardIds = ref.read(myCardsProvider);
  final backend = ref.read(backendGatewayProvider);
  final logger = ref.read(loggerProvider);
  final result = await guard(
    () => [
      if (dealIds.isNotEmpty || cardIds.isNotEmpty)
        backend.rpc('sync_guest_items', {
          'deal_ids': dealIds,
          'card_product_ids': cardIds,
        }),
      if (preferences.brandIds.isNotEmpty ||
          preferences.categoryFollowIds.isNotEmpty)
        backend.rpc('sync_guest_preferences', {
          'brand_ids': preferences.brandIds,
          'category_ids': preferences.categoryFollowIds,
        }),
    ].wait,
    logger: logger,
    mappers: const [backendErrorMapper],
  );
  if (result case Failure(:final failure)) {
    logger.warning(
      'Could not send the lists before signing out',
      context: {'code': failure.code},
    );
    return false;
  }
  return true;
}

Future<void> _forgetAccount(Ref ref) async {
  await [
    ref.read(savedDealsProvider.notifier).forget(),
    ref.read(myCardsProvider.notifier).forget(),
    ref.read(preferencesProvider.notifier).setFollows(),
  ].wait;
  try {
    await ref.read(keyValueStoreProvider).remove(accountOnPhoneKey);
  } on Object catch (error) {
    ref
        .read(loggerProvider)
        .warning(
          'Could not forget whose lists were on this phone',
          context: {'error': error.runtimeType.toString()},
        );
  }
}

/// Where the phone notes which account its saved deals, cards and follows
/// belong to (the last one that signed in on it).
const accountOnPhoneKey = 'account.on_phone.v1';

/// Copies the guest's on-phone choices (city, language, follows, saved
/// deals, cards) into the account right after sign-in, so nothing chosen
/// before signing in is lost, then brings the account's onto the phone.
/// A failure is logged and doesn't undo the sign-in: the choices stay on
/// the phone and sync on the next sign-in.
///
/// On a shared phone, what another account left on it never goes into
/// this one (QA 4.8 BUG-1): the phone's lists are dropped, and this
/// account's take their place.
final guestSyncProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final backend = ref.read(backendGatewayProvider);
    final store = ref.read(keyValueStoreProvider);
    final logger = ref.read(loggerProvider);
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;
    final saved = ref.read(savedDealsProvider.notifier);
    final cards = ref.read(myCardsProvider.notifier);
    // What is stored on the phone, not just what this session has loaded
    // (QA 4.7-A6).
    await (saved.loaded, cards.loaded).wait;

    String? onPhone;
    var known = true;
    try {
      onPhone = await store.getString(accountOnPhoneKey);
    } on Object catch (error) {
      known = false;
      logger.warning(
        'Could not read whose lists are on this phone',
        context: {'error': error.runtimeType.toString()},
      );
    }
    // Unknown counts as someone else's: better to start from the account
    // than to copy another person's lists into it.
    if (!known || (onPhone != null && onPhone != userId)) {
      await saved.update((_) => const []);
      await cards.update((_) => const []);
      await ref.read(preferencesProvider.notifier).setFollows();
    }
    try {
      await store.setString(accountOnPhoneKey, userId);
    } on Object catch (error) {
      logger.warning(
        'Could not note whose lists are on this phone',
        context: {'error': error.runtimeType.toString()},
      );
    }

    final preferences = ref.read(preferencesProvider);
    final dealIds = ref.read(savedDealsProvider);
    final cardIds = ref.read(myCardsProvider);
    // Rows go in as auth.uid() on the server, so never in another's name
    // (QA 4.4 BUG-1, 4.5 BUG-1). One call each, whatever the count
    // (QA 4.8 BUG-3); ones already in the account are skipped.
    for (final (what, function, params) in [
      (
        'Could not sync guest choices',
        'sync_guest_preferences',
        <String, Object?>{
          'city': preferences.cityId,
          'lang': ref.read(localeControllerProvider).languageCode,
          'brand_ids': preferences.brandIds,
          'category_ids': preferences.categoryFollowIds,
        },
      ),
      if (dealIds.isNotEmpty || cardIds.isNotEmpty)
        (
          'Could not sync saved deals and cards',
          'sync_guest_items',
          <String, Object?>{'deal_ids': dealIds, 'card_product_ids': cardIds},
        ),
    ]) {
      final result = await guard(
        () => backend.rpc(function, params),
        logger: logger,
        mappers: const [backendErrorMapper],
      );
      if (result case Failure(:final failure)) {
        logger.warning(what, context: {'code': failure.code});
      }
    }
    // And the other way: what the account holds from another phone comes
    // onto this one. A failure leaves the phone as it was.
    try {
      final (saves, cards, follows) = await (
        backend.select(
          const TableQuery(
            'saves',
            columns: 'deal_id',
            orderBy: 'created_at',
            ascending: false,
            limit: SavedDeals.max,
          ),
        ),
        backend.select(
          const TableQuery('user_cards', columns: 'card_product_id', limit: 20),
        ),
        backend.select(
          const TableQuery(
            'follows',
            columns: 'brand_id,category_id',
            limit: 500,
          ),
        ),
      ).wait;
      await ref.read(savedDealsProvider.notifier).addFromAccount([
        for (final r in saves)
          if (r['deal_id'] case final String id) id,
      ]);
      await ref.read(myCardsProvider.notifier).addFromAccount([
        for (final r in cards)
          if (r['card_product_id'] case final String id) id,
      ]);
      await ref
          .read(preferencesProvider.notifier)
          .addFollows(
            brandIds: [
              for (final r in follows)
                if (r['brand_id'] case final String id) id,
            ],
            categoryIds: [
              for (final r in follows)
                if (r['category_id'] case final String id) id,
            ],
          );
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning(
            'Could not read the account',
            context: {'error': error.runtimeType.toString()},
          );
    }
  },
);
