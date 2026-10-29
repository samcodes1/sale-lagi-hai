import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_errors.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/guard.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

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
  },
);
