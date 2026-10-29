// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$appShellRoute, $welcomeRoute];

RouteBase get $appShellRoute => StatefulShellRouteData.$route(
  factory: $AppShellRouteExtension._fromState,
  branches: [
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/',
          hasOverriddenOnExit: false,
          factory: $HomeRoute._fromState,
          routes: [
            GoRouteData.$route(
              path: 'deal/:dealId',
              hasOverriddenOnExit: false,
              parentNavigatorKey: DealRoute.$parentNavigatorKey,
              factory: $DealRoute._fromState,
            ),
            GoRouteData.$route(
              path: 'brand/:slug',
              hasOverriddenOnExit: false,
              parentNavigatorKey: BrandRoute.$parentNavigatorKey,
              factory: $BrandRoute._fromState,
            ),
            GoRouteData.$route(
              path: 'category/:slug',
              hasOverriddenOnExit: false,
              parentNavigatorKey: CategoryRoute.$parentNavigatorKey,
              factory: $CategoryRoute._fromState,
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/explore',
          hasOverriddenOnExit: false,
          factory: $ExploreRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/alerts',
          hasOverriddenOnExit: false,
          factory: $AlertsRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/saved',
          hasOverriddenOnExit: false,
          factory: $SavedRoute._fromState,
        ),
      ],
    ),
    StatefulShellBranchData.$branch(
      routes: [
        GoRouteData.$route(
          path: '/profile',
          hasOverriddenOnExit: false,
          factory: $ProfileRoute._fromState,
          routes: [
            GoRouteData.$route(
              path: 'dev/theme',
              hasOverriddenOnExit: false,
              factory: $ThemePreviewRoute._fromState,
            ),
            GoRouteData.$route(
              path: 'dev/gallery',
              hasOverriddenOnExit: false,
              factory: $WidgetGalleryRoute._fromState,
            ),
          ],
        ),
      ],
    ),
  ],
);

extension $AppShellRouteExtension on AppShellRoute {
  static AppShellRoute _fromState(GoRouterState state) => const AppShellRoute();
}

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) => const HomeRoute();

  @override
  String get location => GoRouteData.$location('/');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $DealRoute on GoRouteData {
  static DealRoute _fromState(GoRouterState state) =>
      DealRoute(dealId: state.pathParameters['dealId']!);

  DealRoute get _self => this as DealRoute;

  @override
  String get location =>
      GoRouteData.$location('/deal/${Uri.encodeComponent(_self.dealId)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $BrandRoute on GoRouteData {
  static BrandRoute _fromState(GoRouterState state) =>
      BrandRoute(slug: state.pathParameters['slug']!);

  BrandRoute get _self => this as BrandRoute;

  @override
  String get location =>
      GoRouteData.$location('/brand/${Uri.encodeComponent(_self.slug)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $CategoryRoute on GoRouteData {
  static CategoryRoute _fromState(GoRouterState state) =>
      CategoryRoute(slug: state.pathParameters['slug']!);

  CategoryRoute get _self => this as CategoryRoute;

  @override
  String get location =>
      GoRouteData.$location('/category/${Uri.encodeComponent(_self.slug)}');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ExploreRoute on GoRouteData {
  static ExploreRoute _fromState(GoRouterState state) => const ExploreRoute();

  @override
  String get location => GoRouteData.$location('/explore');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $AlertsRoute on GoRouteData {
  static AlertsRoute _fromState(GoRouterState state) => const AlertsRoute();

  @override
  String get location => GoRouteData.$location('/alerts');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $SavedRoute on GoRouteData {
  static SavedRoute _fromState(GoRouterState state) => const SavedRoute();

  @override
  String get location => GoRouteData.$location('/saved');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ProfileRoute on GoRouteData {
  static ProfileRoute _fromState(GoRouterState state) => const ProfileRoute();

  @override
  String get location => GoRouteData.$location('/profile');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $ThemePreviewRoute on GoRouteData {
  static ThemePreviewRoute _fromState(GoRouterState state) =>
      const ThemePreviewRoute();

  @override
  String get location => GoRouteData.$location('/profile/dev/theme');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $WidgetGalleryRoute on GoRouteData {
  static WidgetGalleryRoute _fromState(GoRouterState state) =>
      const WidgetGalleryRoute();

  @override
  String get location => GoRouteData.$location('/profile/dev/gallery');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

RouteBase get $welcomeRoute => GoRouteData.$route(
  path: '/welcome',
  hasOverriddenOnExit: false,
  factory: $WelcomeRoute._fromState,
  routes: [
    GoRouteData.$route(
      path: 'city',
      hasOverriddenOnExit: false,
      factory: $WelcomeCityRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'interests',
      hasOverriddenOnExit: false,
      factory: $WelcomeInterestsRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'brands',
      hasOverriddenOnExit: false,
      factory: $WelcomeBrandsRoute._fromState,
    ),
    GoRouteData.$route(
      path: 'alerts',
      hasOverriddenOnExit: false,
      factory: $WelcomeAlertsRoute._fromState,
    ),
  ],
);

mixin $WelcomeRoute on GoRouteData {
  static WelcomeRoute _fromState(GoRouterState state) => const WelcomeRoute();

  @override
  String get location => GoRouteData.$location('/welcome');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $WelcomeCityRoute on GoRouteData {
  static WelcomeCityRoute _fromState(GoRouterState state) =>
      const WelcomeCityRoute();

  @override
  String get location => GoRouteData.$location('/welcome/city');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $WelcomeInterestsRoute on GoRouteData {
  static WelcomeInterestsRoute _fromState(GoRouterState state) =>
      const WelcomeInterestsRoute();

  @override
  String get location => GoRouteData.$location('/welcome/interests');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $WelcomeBrandsRoute on GoRouteData {
  static WelcomeBrandsRoute _fromState(GoRouterState state) =>
      const WelcomeBrandsRoute();

  @override
  String get location => GoRouteData.$location('/welcome/brands');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin $WelcomeAlertsRoute on GoRouteData {
  static WelcomeAlertsRoute _fromState(GoRouterState state) =>
      const WelcomeAlertsRoute();

  @override
  String get location => GoRouteData.$location('/welcome/alerts');

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}
