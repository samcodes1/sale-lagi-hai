import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/router/route_params.dart';
import 'package:sale_lagi_hai/app/shell/app_shell.dart';
import 'package:sale_lagi_hai/design_system/gallery/theme_preview_page.dart';
import 'package:sale_lagi_hai/design_system/gallery/widget_gallery_page.dart';
import 'package:sale_lagi_hai/features/alerts/presentation/alerts_screen.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/presentation/delete_account_screen.dart';
import 'package:sale_lagi_hai/features/auth/presentation/sign_in_screen.dart';
import 'package:sale_lagi_hai/features/brands/presentation/brand_screen.dart';
import 'package:sale_lagi_hai/features/cards/presentation/my_cards_screen.dart';
import 'package:sale_lagi_hai/features/categories/presentation/category_screen.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/explore/presentation/explore_screen.dart';
import 'package:sale_lagi_hai/features/follows/presentation/following_screen.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/alerts_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/brands_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/city_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/interests_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/language_step.dart';
import 'package:sale_lagi_hai/features/profile/presentation/profile_screen.dart';
import 'package:sale_lagi_hai/features/saved/presentation/saved_screen.dart';
import 'package:sale_lagi_hai/features/search/presentation/search_screen.dart';
import 'package:sale_lagi_hai/features/settings/presentation/about_screen.dart';
import 'package:sale_lagi_hai/features/settings/presentation/legal_screen.dart';
import 'package:sale_lagi_hai/features/settings/presentation/notification_settings_screen.dart';
import 'package:sale_lagi_hai/features/settings/presentation/privacy_screen.dart';
import 'package:sale_lagi_hai/features/settings/presentation/settings_screen.dart';

part 'routes.g.dart';

/// The navigator above the tab shell. Full-screen pages (deal, brand,
/// category) open here, so they cover the bottom navigation while the tab
/// they were opened from stays underneath for "back".
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

// ------------------------------------------------------------------ shell ---

@TypedStatefulShellRoute<AppShellRoute>(
  branches: [
    TypedStatefulShellBranch<HomeBranch>(
      routes: [
        TypedGoRoute<HomeRoute>(
          path: '/',
          routes: [
            TypedGoRoute<DealRoute>(path: 'deal/:dealId'),
            TypedGoRoute<BrandRoute>(path: 'brand/:slug'),
            TypedGoRoute<CategoryRoute>(path: 'category/:slug'),
            TypedGoRoute<SearchRoute>(path: 'search'),
            TypedGoRoute<MyCardsRoute>(path: 'cards'),
            TypedGoRoute<FollowingRoute>(path: 'following'),
            TypedGoRoute<SettingsRoute>(
              path: 'settings',
              routes: [
                TypedGoRoute<NotificationSettingsRoute>(path: 'notifications'),
                TypedGoRoute<PrivacyRoute>(path: 'privacy'),
                TypedGoRoute<LegalRoute>(path: 'legal/:doc'),
                TypedGoRoute<AboutRoute>(path: 'about'),
              ],
            ),
          ],
        ),
      ],
    ),
    TypedStatefulShellBranch<ExploreBranch>(
      routes: [TypedGoRoute<ExploreRoute>(path: '/explore')],
    ),
    TypedStatefulShellBranch<AlertsBranch>(
      routes: [TypedGoRoute<AlertsRoute>(path: '/alerts')],
    ),
    TypedStatefulShellBranch<SavedBranch>(
      routes: [TypedGoRoute<SavedRoute>(path: '/saved')],
    ),
    TypedStatefulShellBranch<ProfileBranch>(
      routes: [
        TypedGoRoute<ProfileRoute>(
          path: '/profile',
          routes: [
            TypedGoRoute<DeleteAccountRoute>(path: 'account/delete'),
            TypedGoRoute<ThemePreviewRoute>(path: 'dev/theme'),
            TypedGoRoute<WidgetGalleryRoute>(path: 'dev/gallery'),
          ],
        ),
      ],
    ),
  ],
)
final class AppShellRoute extends StatefulShellRouteData {
  const new();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) => AppShell(navigationShell: navigationShell);
}

final class HomeBranch extends StatefulShellBranchData {
  const new();
}

final class ExploreBranch extends StatefulShellBranchData {
  const new();
}

final class AlertsBranch extends StatefulShellBranchData {
  const new();
}

final class SavedBranch extends StatefulShellBranchData {
  const new();
}

final class ProfileBranch extends StatefulShellBranchData {
  const new();
}

// ------------------------------------------------------------------- tabs ---

final class HomeRoute extends GoRouteData with $HomeRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}

final class ExploreRoute extends GoRouteData with $ExploreRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ExploreScreen();
}

final class AlertsRoute extends GoRouteData with $AlertsRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AlertsScreen();
}

final class SavedRoute extends GoRouteData with $SavedRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SavedScreen();
}

final class ProfileRoute extends GoRouteData with $ProfileRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ProfileScreen();
}

// ------------------------------------------------------ full-screen pages ---

/// `/deal/<uuid>`. An invalid ID goes Home: the value is never shown.
final class DealRoute extends GoRouteData with $DealRoute {
  const new({required this.dealId});

  final String dealId;

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) =>
      RouteParams.isId(dealId) ? null : const HomeRoute().location;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      DealDetailScreen(dealId: dealId);
}

/// `/brand/<slug>`.
final class BrandRoute extends GoRouteData with $BrandRoute {
  const new({required this.slug});

  final String slug;

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) =>
      RouteParams.isSlug(slug) ? null : const HomeRoute().location;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      BrandScreen(slug: slug);
}

/// `/category/<slug>`.
final class CategoryRoute extends GoRouteData with $CategoryRoute {
  const new({required this.slug});

  final String slug;

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) =>
      RouteParams.isSlug(slug) ? null : const HomeRoute().location;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      CategoryScreen(slug: slug);
}

/// `/search?q=`: search, optionally starting with words (cut to 100).
final class SearchRoute extends GoRouteData with $SearchRoute {
  const new({this.q});

  final String? q;

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final words = q?.trim() ?? '';
    return SearchScreen(
      // 100 characters as the server counts them, never splitting one.
      initialQuery: String.fromCharCodes(words.runes.take(100)),
    );
  }
}

/// `/cards`: My Cards.
final class MyCardsRoute extends GoRouteData with $MyCardsRoute {
  const new();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const MyCardsScreen();
}

/// `/following`: the brands and categories followed.
final class FollowingRoute extends GoRouteData with $FollowingRoute {
  const new();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const FollowingScreen();
}

/// `/settings` and its pages.
final class SettingsRoute extends GoRouteData with $SettingsRoute {
  const new();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const SettingsScreen();
}

final class NotificationSettingsRoute extends GoRouteData
    with $NotificationSettingsRoute {
  const new();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const NotificationSettingsScreen();
}

final class PrivacyRoute extends GoRouteData with $PrivacyRoute {
  const new();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const PrivacyScreen();
}

/// `/settings/legal/terms` or `/settings/legal/privacy`; anything else
/// goes to Settings.
final class LegalRoute extends GoRouteData with $LegalRoute {
  const new({required this.doc});

  final String doc;

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) =>
      LegalDoc.values.any((d) => d.name == doc)
      ? null
      : const SettingsRoute().location;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      LegalScreen(doc: LegalDoc.values.byName(doc));
}

final class AboutRoute extends GoRouteData with $AboutRoute {
  const new();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const AboutScreen();
}

// ------------------------------------------------------------- account ---

/// `/sign-in`: optional sign-in, above the tabs. Pops `true` once signed
/// in. `?reauth=true` asks a signed-in shopper to sign in again before a
/// sensitive action.
@TypedGoRoute<SignInRoute>(path: '/sign-in')
final class SignInRoute extends GoRouteData with $SignInRoute {
  const new({this.reauth = false});

  final bool reauth;

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      SignInScreen(reauth: reauth);
}

/// `/profile/account/delete`: account deletion, for signed-in shoppers
/// only (guests go back to Profile).
final class DeleteAccountRoute extends GoRouteData with $DeleteAccountRoute {
  const new();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) =>
      ProviderScope.containerOf(
            context,
            listen: false,
          ).read(authRepositoryProvider).currentUser ==
          null
      ? const ProfileRoute().location
      : null;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const DeleteAccountScreen();
}

// ------------------------------------------------------------ onboarding ---

/// `/welcome`: first launch (UX flow F1). Each step pushes the next, so
/// system back returns to the previous step. The router sends every other
/// location here until onboarding is done, and away from here after.
@TypedGoRoute<WelcomeRoute>(
  path: '/welcome',
  routes: [
    TypedGoRoute<WelcomeCityRoute>(path: 'city'),
    TypedGoRoute<WelcomeInterestsRoute>(path: 'interests'),
    TypedGoRoute<WelcomeBrandsRoute>(path: 'brands'),
    TypedGoRoute<WelcomeAlertsRoute>(path: 'alerts'),
  ],
)
final class WelcomeRoute extends GoRouteData with $WelcomeRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const LanguageStep();
}

/// `/welcome/city`.
final class WelcomeCityRoute extends GoRouteData with $WelcomeCityRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const CityStep();
}

/// `/welcome/interests`.
final class WelcomeInterestsRoute extends GoRouteData
    with $WelcomeInterestsRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const InterestsStep();
}

/// `/welcome/brands`.
final class WelcomeBrandsRoute extends GoRouteData with $WelcomeBrandsRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const BrandsStep();
}

/// `/welcome/alerts`.
final class WelcomeAlertsRoute extends GoRouteData with $WelcomeAlertsRoute {
  const new();

  @override
  Widget build(BuildContext context, GoRouterState state) => const AlertsStep();
}

// -------------------------------------------------------------- dev only ---

/// `/profile/dev/theme`: the theme preview. Not reachable in production.
final class ThemePreviewRoute extends GoRouteData with $ThemePreviewRoute {
  const new();

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) =>
      _devOnly(context);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const ThemePreviewPage();
}

/// `/profile/dev/gallery`: every design-system widget. Not in production.
final class WidgetGalleryRoute extends GoRouteData with $WidgetGalleryRoute {
  const new();

  @override
  FutureOr<String?> redirect(BuildContext context, GoRouterState state) =>
      _devOnly(context);

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const WidgetGalleryPage();
}

/// Sends developer routes back to Profile in production builds.
String? _devOnly(BuildContext context) =>
    ProviderScope.containerOf(
      context,
      listen: false,
    ).read(appConfigProvider).flavor.isProduction
    ? const ProfileRoute().location
    : null;
