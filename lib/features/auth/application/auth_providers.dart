import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
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
        await backend.insert('saves', {'deal_id': dealId});
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
  },
);
