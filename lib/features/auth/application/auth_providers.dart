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

/// Copies the guest's on-phone choices (city, language, followed brands)
/// into the account right after sign-in, so nothing chosen before signing
/// in is lost. A failure is logged and doesn't undo the sign-in: the
/// choices stay on the phone and sync on the next sign-in.
final guestSyncProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final preferences = ref.read(preferencesProvider);
    final backend = ref.read(backendGatewayProvider);
    // Rows name their owner: the insert policies check user_id = auth.uid()
    // (QA 4.4 BUG-1, 4.5 BUG-1).
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return;
    final result = await guard(
      () => backend.rpc('sync_guest_preferences', {
        'city': preferences.cityId,
        'lang': ref.read(localeControllerProvider).languageCode,
        'brand_ids': preferences.brandIds,
        'category_ids': preferences.categoryFollowIds,
      }),
      logger: ref.read(loggerProvider),
      mappers: const [backendErrorMapper],
    );
    if (result case Failure(:final failure)) {
      ref
          .read(loggerProvider)
          .warning(
            'Could not sync guest choices',
            context: {'code': failure.code},
          );
    }
    // Deals saved as a guest go into the account too (already saved ones
    // are skipped by the primary key; any failure leaves the phone copy).
    var failed = 0;
    for (final dealId in ref.read(savedDealsProvider)) {
      try {
        await backend.insert('saves', {'user_id': userId, 'deal_id': dealId});
      } on Object {
        failed++;
      }
    }
    if (failed > 0) {
      ref
          .read(loggerProvider)
          .info(
            'Some saved deals were already synced',
            context: {'count': failed},
          );
    }
    // Cards added as a guest too (card products only, never numbers).
    var cardsFailed = 0;
    for (final cardProductId in ref.read(myCardsProvider)) {
      try {
        await backend.insert('user_cards', {
          'user_id': userId,
          'card_product_id': cardProductId,
        });
      } on Object {
        cardsFailed++;
      }
    }
    if (cardsFailed > 0) {
      ref
          .read(loggerProvider)
          .info(
            'Some cards were already synced',
            context: {'count': cardsFailed},
          );
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
