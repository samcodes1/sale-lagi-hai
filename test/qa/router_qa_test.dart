// QA tests for sub-phase 1.5 (Navigation shell), written by the QA
// engineer. Tests marked `skip: knownBug(...)` assert the expected
// behaviour of an open bug (docs/qa/1.5.md); run them with
// `--dart-define=QA_KNOWN_BUGS=true`.
import 'dart:async';
import 'dart:io';

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
import 'package:sale_lagi_hai/design_system/gallery/widget_gallery_page.dart';
import 'package:sale_lagi_hai/features/brands/presentation/brand_screen.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/profile/presentation/profile_screen.dart';
import 'package:sale_lagi_hai/features/saved/presentation/saved_screen.dart';

import '../helpers/fakes.dart';

const _dealId = '3f2a9c1e-7b4d-4e8a-9c2f-1a2b3c4d5e6f';

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  Flavor flavor = Flavor.dev,
  Size size = const Size(412, 915),
  Locale locale = AppLocales.english,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        AppConfig(
          flavor: flavor,
          appName: 'SLH',
          supabaseUrl: '',
          supabaseAnonKey: '',
        ),
      ),
      deviceLocaleProvider.overrideWithValue(locale),
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
  group('back behaviour', () {
    testWidgets('a deal pushed from the Saved tab returns to Saved', (
      tester,
    ) async {
      // routes.dart: full-screen pages open "while the tab they were opened
      // from stays underneath for back".
      final router = await _pumpApp(tester);
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();

      unawaited(router.push(const DealRoute(dealId: _dealId).location));
      await tester.pumpAndSettle();
      expect(find.byType(DealDetailScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SavedScreen), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3,
      );
    });

    testWidgets('back inside a tab pops that tab first, then goes Home', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Widget gallery (dev)'));
      await tester.pumpAndSettle();
      expect(find.byType(WidgetGalleryPage), findsOneWidget);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(router.state.uri.path, '/');
    });

    testWidgets('back on Home is left to the system (app exits)', (
      tester,
    ) async {
      await _pumpApp(tester);
      expect(await tester.binding.handlePopRoute(), isFalse);
    });

    testWidgets('back on the rail layout also goes Home first', (tester) async {
      await _pumpApp(tester, size: const Size(900, 700));
      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('layout breakpoint', () {
    for (final (width, rail) in const [(599.0, false), (600.0, true)]) {
      testWidgets('${width}dp: ${rail ? 'rail' : 'bottom bar'}', (
        tester,
      ) async {
        await _pumpApp(tester, size: Size(width, 800));
        expect(
          find.byType(NavigationRail),
          rail ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(NavigationBar),
          rail ? findsNothing : findsOneWidget,
        );
      });
    }

    testWidgets('Urdu mirrors the bar: Home is the right-most tab', (
      tester,
    ) async {
      await _pumpApp(tester, locale: AppLocales.urdu);
      final home = tester.getCenter(find.text('ہوم'));
      final profile = tester.getCenter(find.text('پروفائل'));
      expect(home.dx, greaterThan(profile.dx));
    });

    testWidgets('Urdu rail sits on the right', (tester) async {
      await _pumpApp(
        tester,
        size: const Size(900, 700),
        locale: AppLocales.urdu,
      );
      final rail = tester.getRect(find.byType(NavigationRail));
      expect(rail.right, closeTo(900, 1));
    });
  });

  group('hostile and odd deep links', () {
    testWidgets('never reach a detail page with a bad value', (tester) async {
      final router = await _pumpApp(tester);
      for (final location in [
        '/deal/',
        '/deal/$_dealId%0A',
        '/deal/%20$_dealId',
        '/deal/${_dealId.replaceAll('-', '')}',
        '/deal/$_dealId-',
        '/deal/javascript:alert(1)',
        '/deal/%2e%2e%2f%2e%2e',
        '/brand/${'a' * 65}',
        '/brand/a--b',
        '/brand/-khaadi',
        '/brand/khaadi%00',
        '/brand/${'x' * 5000}',
        '/category/food_and_dining',
      ]) {
        await _go(tester, router, location);
        expect(find.byType(DealDetailScreen), findsNothing, reason: location);
        expect(find.byType(BrandScreen), findsNothing, reason: location);
        expect(tester.takeException(), isNull, reason: location);
      }
    });

    testWidgets('extra path segments are not found, and never echoed', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      await _go(tester, router, '/deal/$_dealId/%3Cscript%3Eabc');
      expect(find.byType(NotFoundScreen), findsOneWidget);
      expect(find.textContaining('script'), findsNothing);
      expect(find.textContaining('abc'), findsNothing);
    });

    testWidgets('a query string does not change which deal opens', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      await _go(tester, router, '/deal/$_dealId?dealId=evil&utm_source=wa');
      expect(
        tester.widget<DealDetailScreen>(find.byType(DealDetailScreen)).dealId,
        _dealId,
      );
    });

    test('the ID and slug validators reject newline tricks', () {
      expect(RouteParams.isId('$_dealId\n'), isFalse);
      expect(RouteParams.isSlug('khaadi\n'), isFalse);
      expect(RouteParams.isSlug('a' * 64), isTrue);
    });
  });

  group('developer routes in production', () {
    for (final path in ['/profile/dev/gallery', '/profile/dev/theme']) {
      testWidgets('$path redirects to Profile', (tester) async {
        final router = await _pumpApp(tester, flavor: Flavor.prod);
        await _go(tester, router, path);
        expect(find.byType(WidgetGalleryPage), findsNothing);
        expect(find.byType(ThemePreviewPage), findsNothing);
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(router.state.uri.path, '/profile');
      });
    }

    testWidgets('staging keeps the developer tools (by design)', (
      tester,
    ) async {
      final router = await _pumpApp(tester, flavor: Flavor.staging);
      await _go(tester, router, '/profile/dev/gallery');
      expect(find.byType(WidgetGalleryPage), findsOneWidget);
    });
  });

  test('Android: Flutter deep linking is off and no link filters exist', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(
      RegExp(r'flutter_deeplinking_enabled"\s+android:value="false"')
          .hasMatch(manifest),
      isTrue,
    );
    expect(manifest, isNot(contains('android.intent.action.VIEW')));
    expect(manifest, isNot(contains('android:autoVerify')));
  });
}
