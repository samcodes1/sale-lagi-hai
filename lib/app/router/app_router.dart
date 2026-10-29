import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sale_lagi_hai/app/router/not_found_screen.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

/// The app's router: one instance for the app's lifetime.
///
/// Until onboarding is done every location leads to `/welcome`; a link
/// that opened the app (a shared deal) is kept and opened right after.
/// Sign-in redirects arrive in 4.2. Unknown locations show
/// [NotFoundScreen], which never displays the location.
final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ValueNotifier<bool>(ref.read(onboardedProvider));
  ref.listen(onboardedProvider, (_, next) => onboarded.value = next);
  String? pending;

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    routes: $appRoutes,
    refreshListenable: onboarded,
    redirect: (context, state) {
      final location = state.uri.toString();
      final inWelcome = state.matchedLocation.startsWith(welcomePath);
      if (!onboarded.value) {
        if (inWelcome) return null;
        // Keep the link for afterwards (it is validated again then, by
        // its own route's redirect).
        if (location != const HomeRoute().location) pending = location;
        return welcomePath;
      }
      if (inWelcome) {
        final next = pending ?? const HomeRoute().location;
        pending = null;
        return next;
      }
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
  ref.onDispose(() {
    router.dispose();
    onboarded.dispose();
  });
  return router;
});

/// Where onboarding starts.
@visibleForTesting
final String welcomePath = const WelcomeRoute().location;
