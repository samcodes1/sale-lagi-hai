import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sale_lagi_hai/app/router/not_found_screen.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';

/// The app's router: one instance for the app's lifetime.
///
/// Onboarding and sign-in redirects arrive in Phase 4 (4.1, 4.2). Unknown
/// locations show [NotFoundScreen], which never displays the location.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    routes: $appRoutes,
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
  ref.onDispose(router.dispose);
  return router;
});
