import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/app/router/app_router.dart';
import 'package:sale_lagi_hai/app/router/not_found_screen.dart';
import 'package:sale_lagi_hai/app/router/route_params.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/design_system/gallery/theme_preview_page.dart';
import 'package:sale_lagi_hai/features/alerts/presentation/alerts_screen.dart';
import 'package:sale_lagi_hai/features/brands/presentation/brand_screen.dart';
import 'package:sale_lagi_hai/features/categories/presentation/category_screen.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/explore/presentation/explore_screen.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/profile/presentation/profile_screen.dart';
import 'package:sale_lagi_hai/features/saved/presentation/saved_screen.dart';

import '../../helpers/fakes.dart';

const _dealId = '3f2a9c1e-7b4d-4e8a-9c2f-1a2b3c4d5e6f';

AppConfig _config(Flavor flavor) => AppConfig(
  flavor: flavor,
  appName: 'SLH',
  supabaseUrl: '',
  supabasePublishableKey: '',
);

/// Pumps the real app and returns its router.
Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  Flavor flavor = Flavor.dev,
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      onboardedShopper,
      guestAuth(),
      onlineNetwork(),
      appConfigProvider.overrideWithValue(_config(flavor)),
      deviceLocaleProvider.overrideWithValue(const Locale('en')),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      loggerProvider.overrideWithValue(AppLogger(sinks: [])),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _go(WidgetTester tester, GoRouter router, String location) async {
  router.go(location);
  await tester.pumpAndSettle();
}

void main() {
  group('RouteParams', () {
    test('IDs must be lower-case UUIDs', () {
      expect(RouteParams.isId(_dealId), isTrue);
      for (final bad in [
        '',
        'abc',
        _dealId.toUpperCase(),
        '$_dealId/extra',
        '../$_dealId',
        '3f2a9c1e7b4d4e8a9c2f1a2b3c4d5e6f',
        "$_dealId'--",
      ]) {
        expect(RouteParams.isId(bad), isFalse, reason: bad);
      }
    });

    test('slugs are short lower-case words joined by single hyphens', () {
      for (final good in ['khaadi', 'food-and-dining', 'j-dot', 'hbl2']) {
        expect(RouteParams.isSlug(good), isTrue, reason: good);
      }
      for (final bad in [
        '',
        'Khaadi',
        '-khaadi',
        'khaadi-',
        'food--dining',
        'food_dining',
        '../etc',
        'a%2Fb',
        '<script>',
        'a' * 65,
      ]) {
        expect(RouteParams.isSlug(bad), isFalse, reason: bad);
      }
      expect(RouteParams.isSlug('a' * 64), isTrue);
    });

    test('typed routes build the expected locations', () {
      expect(const HomeRoute().location, '/');
      expect(const DealRoute(dealId: _dealId).location, '/deal/$_dealId');
      expect(const BrandRoute(slug: 'khaadi').location, '/brand/khaadi');
      expect(const CategoryRoute(slug: 'food').location, '/category/food');
      expect(const ProfileRoute().location, '/profile');
      expect(const ThemePreviewRoute().location, '/profile/dev/theme');
    });
  });

  group('tabs', () {
    testWidgets('start on Home with a five-tab bottom bar', (tester) async {
      await _pumpApp(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
    });

    testWidgets('each tab opens its screen', (tester) async {
      await _pumpApp(tester);

      for (final (label, screen) in [
        ('Explore', ExploreScreen),
        ('Alerts', AlertsScreen),
        ('Saved', SavedScreen),
        ('Profile', ProfileScreen),
        ('Home', HomeScreen),
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget, reason: label);
      }
    });

    testWidgets('each tab keeps its own stack', (tester) async {
      final router = await _pumpApp(tester);

      await _go(tester, router, '/profile/dev/theme');
      expect(find.byType(ThemePreviewPage), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // Back on the Profile tab, its pushed page is still there.
      expect(find.byType(ThemePreviewPage), findsOneWidget);
    });

    testWidgets('re-selecting the current tab returns to its first screen', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      await _go(tester, router, '/profile/dev/theme');

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.byType(ThemePreviewPage), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('system back on another tab goes to Home first', (
      tester,
    ) async {
      await _pumpApp(tester);
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('wide windows use a navigation rail instead', (tester) async {
      await _pumpApp(tester, size: const Size(900, 700));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('deep links', () {
    testWidgets('a deal opens full screen above the tabs, back returns', (
      tester,
    ) async {
      final router = await _pumpApp(tester);

      unawaited(router.push(const DealRoute(dealId: _dealId).location));
      await tester.pumpAndSettle();

      final screen = tester.widget<DealDetailScreen>(
        find.byType(DealDetailScreen),
      );
      expect(screen.dealId, _dealId);
      expect(find.byType(NavigationBar), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('brand and category pages open with their slug', (
      tester,
    ) async {
      final router = await _pumpApp(tester);

      await _go(tester, router, '/brand/khaadi');
      expect(
        tester.widget<BrandScreen>(find.byType(BrandScreen)).slug,
        'khaadi',
      );

      await _go(tester, router, '/category/food-and-dining');
      expect(
        tester.widget<CategoryScreen>(find.byType(CategoryScreen)).slug,
        'food-and-dining',
      );
    });

    testWidgets('invalid IDs and slugs go Home, never to the page', (
      tester,
    ) async {
      final router = await _pumpApp(tester);

      for (final location in [
        '/deal/not-a-uuid',
        '/deal/${_dealId.toUpperCase()}',
        '/brand/Khaadi',
        '/brand/%3Cscript%3E',
        '/category/..%2F..%2Fetc',
      ]) {
        await _go(tester, router, location);
        expect(find.byType(HomeScreen), findsOneWidget, reason: location);
        expect(find.byType(DealDetailScreen), findsNothing);
        expect(find.byType(BrandScreen), findsNothing);
        expect(find.byType(CategoryScreen), findsNothing);
      }
    });

    testWidgets('unknown locations show Not found without echoing them', (
      tester,
    ) async {
      final router = await _pumpApp(tester);

      await _go(tester, router, '/totally-unknown-xyz123');

      expect(find.byType(NotFoundScreen), findsOneWidget);
      expect(find.textContaining('xyz123'), findsNothing);
      expect(find.text('Page not found'), findsOneWidget);

      await tester.tap(find.text('Go to Home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('developer routes', () {
    testWidgets('the theme preview is listed and reachable outside prod', (
      tester,
    ) async {
      await _pumpApp(tester);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Theme preview (dev)'));
      await tester.pumpAndSettle();

      expect(find.byType(ThemePreviewPage), findsOneWidget);
    });

    testWidgets('production hides it and redirects its URL to Profile', (
      tester,
    ) async {
      final router = await _pumpApp(tester, flavor: Flavor.prod);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Theme preview (dev)'), findsNothing);

      await _go(tester, router, '/profile/dev/theme');

      expect(find.byType(ThemePreviewPage), findsNothing);
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });
}
