// QA, Phase 1 full-phase gate: integration across sub-phases 1.1–1.7.
//
// - The real App is booted the way `bootstrap()` boots it (1.2 startup
//   settings, 1.4 saved locale, 1.1 config, 1.2 logger), then driven through
//   the router (1.5) to the developer pages (1.3 theme preview, 1.6 widget
//   gallery) in en/ur × light/dark × normal/high contrast × 100%/200%, with
//   the a11y guidelines and an overflow check over the whole scroll extent.
// - A language switch persists across a "restart".
// - Config errors reach ConfigErrorApp and the logs without leaking values.
// - Logging redaction end to end: framework errors, build errors and
//   uncaught errors reach the crash reporter redacted, in release mode.
//
// No alchemist goldens in this file: it uses textContrastGuideline.
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/bootstrap.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/app/router/app_router.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/errors/error_handlers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/state/retry_policy.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/gallery/theme_preview_page.dart';
import 'package:sale_lagi_hai/design_system/gallery/widget_gallery_page.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/data/preferences_store.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/profile/presentation/profile_screen.dart';

import '../helpers/fakes.dart';
import 'known_bugs.dart';

final _now = DateTime(2026, 10, 29, 12);

const _devConfig = AppConfig(
  flavor: Flavor.dev,
  appName: 'SLH Dev',
  supabaseUrl: '',
  supabasePublishableKey: '',
);

/// Boots [App] with exactly the overrides `bootstrap()` builds
/// (lib/app/bootstrap.dart), reading the saved language from [store].
Future<({GoRouter router, ProviderContainer container})> _boot(
  WidgetTester tester, {
  required InMemoryKeyValueStore store,
  Locale deviceLocale = AppLocales.english,
  AppConfig config = _devConfig,
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  double textScale = 1,
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(highContrast: highContrast);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });

  final crashReporter = RecordingCrashReporter();
  final logger = createLogger(
    crashReporter: crashReporter,
    isReleaseMode: true,
  );
  // Phase 1 scenarios run past first launch (4.1 onboarding).
  final saved = PreferencesStore(store);
  if (!(await saved.read()).onboarded) {
    await saved.write(const ShopperPreferences(onboarded: true));
  }
  final settings = await loadStartupSettings(logger, openStore: () => store);

  final container = ProviderContainer(
    retry: appRetryPolicy,
    overrides: [
      appConfigProvider.overrideWithValue(config),
      loggerProvider.overrideWithValue(logger),
      crashReporterProvider.overrideWithValue(crashReporter),
      if (settings.store case final s?)
        keyValueStoreProvider.overrideWithValue(s),
      savedLocaleProvider.overrideWithValue(settings.locale),
      savedPreferencesProvider.overrideWithValue(settings.preferences),
      guestAuth(),
      onlineNetwork(),
      deviceLocaleProvider.overrideWithValue(deviceLocale),
      clockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await tester.pump();
  return (router: container.read(routerProvider), container: container);
}

Future<void> _guidelines(
  WidgetTester tester,
  String where, {
  bool contrast = true,
}) async {
  await expectLater(
    tester,
    meetsGuideline(androidTapTargetGuideline),
    reason: where,
  );
  await expectLater(
    tester,
    meetsGuideline(labeledTapTargetGuideline),
    reason: where,
  );
  if (!contrast) return;
  await expectLater(
    tester,
    meetsGuideline(textContrastGuideline),
    reason: where,
  );
}

/// True when an [ErrorView]'s retry button is cut off by the view's own
/// bounds (the gallery puts it in a fixed 240dp box: 1.6 S4-5). The
/// contrast guideline then samples a half-hidden button, so it is checked
/// by the dedicated reproducer below instead.
bool _clippedRetryOnScreen(WidgetTester tester) {
  for (final view in find.byType(ErrorView).evaluate()) {
    final box = tester.getRect(find.byElementPredicate((e) => e == view));
    final buttons = find.descendant(
      of: find.byElementPredicate((e) => e == view),
      matching: find.byType(FilledButton),
    );
    for (final b in buttons.evaluate()) {
      final r = tester.getRect(find.byElementPredicate((e) => e == b));
      if (r.top < box.top - 0.5 || r.bottom > box.bottom + 0.5) return true;
    }
  }
  return false;
}

/// True when a button is partly under the app bar or the navigation bar
/// (a scroll stop can land there, more so since the app bar grows with
/// large text: 4.9-V1). The contrast guideline samples the button's whole
/// box, bar included, so it would compare the bar's colour with the
/// button's; tap targets and labels are still checked at that stop.
bool _buttonUnderBar(WidgetTester tester) {
  final bars = [
    for (final bar in [
      ...find.byType(AppBar).evaluate(),
      ...find.byType(NavigationBar).evaluate(),
    ])
      tester.getRect(find.byElementPredicate((e) => e == bar)),
  ];
  for (final b
      in find.byWidgetPredicate((w) => w is ButtonStyleButton).evaluate()) {
    final r = tester.getRect(find.byElementPredicate((e) => e == b));
    for (final bar in bars) {
      final overlap = r.intersect(bar);
      if (overlap.width > 0 && overlap.height > 0 && overlap != r) return true;
    }
  }
  return false;
}

/// Scrolls the page's main list from top to bottom. At every stop: no
/// exception (overflow), and the a11y guidelines on what is on screen.
Future<int> _walk(WidgetTester tester, String name) async {
  final list = find.byType(Scrollable).first;
  var stops = 0;
  for (var i = 0; i < 80; i++) {
    expect(tester.takeException(), isNull, reason: '$name stop $i');
    await _guidelines(
      tester,
      '$name stop $i',
      contrast: !_clippedRetryOnScreen(tester) && !_buttonUnderBar(tester),
    );
    stops++;
    final position = tester.state<ScrollableState>(list).position;
    if (position.pixels >= position.maxScrollExtent - 0.5) break;
    await _dragPage(tester, -500);
  }
  return stops;
}

/// Drags the page's main list from its 4dp side gutter, so nested
/// scrollables (an ErrorView sample in a fixed box scrolls on its own) don't
/// catch the drag.
Future<void> _dragPage(WidgetTester tester, double dy) async {
  final rect = tester.getRect(find.byType(Scrollable).first);
  await tester.dragFrom(Offset(rect.left + 4, rect.center.dy), Offset(0, dy));
  await tester.pumpAndSettle();
}

void main() {
  group('boot → saved language → router → shell', () {
    testWidgets('a saved Urdu choice wins over an English phone; '
        'switching to English persists across a restart', (tester) async {
      final store = InMemoryKeyValueStore();
      await store.setString(localeStorageKey, 'ur');

      final first = await _boot(tester, store: store);
      final home = tester.element(find.byType(HomeScreen));
      expect(Directionality.of(home), TextDirection.rtl);
      expect(Localizations.localeOf(home), AppLocales.urdu);

      first.router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(
        Directionality.of(tester.element(find.byType(ProfileScreen))),
        TextDirection.ltr,
      );
      expect(await store.getString(localeStorageKey), 'en');

      // "Restart": a fresh boot from the same storage.
      await tester.pumpWidget(const SizedBox());
      await _boot(tester, store: store, deviceLocale: AppLocales.urdu);
      expect(
        Localizations.localeOf(tester.element(find.byType(HomeScreen))),
        AppLocales.english,
      );
    });

    testWidgets('unreadable storage still boots, in the phone language', (
      tester,
    ) async {
      final crashReporter = RecordingCrashReporter();
      final logger = createLogger(
        crashReporter: crashReporter,
        isReleaseMode: true,
      );
      final settings = await loadStartupSettings(
        logger,
        openStore: () => throw StateError('prefs unavailable'),
      );
      expect(settings.store, isNull);
      expect(settings.locale, isNull);
      expect(crashReporter.errors, hasLength(1));

      await _boot(
        tester,
        store: InMemoryKeyValueStore(),
        deviceLocale: AppLocales.urdu,
      );
      expect(
        Directionality.of(tester.element(find.byType(HomeScreen))),
        TextDirection.rtl,
      );
    });

    testWidgets('prod: the developer pages are unreachable end to end', (
      tester,
    ) async {
      final app = await _boot(
        tester,
        store: InMemoryKeyValueStore(),
        config: const AppConfig(
          flavor: Flavor.prod,
          appName: 'Sale Lagi Hai!',
          supabaseUrl: 'https://abc.supabase.co',
          supabasePublishableKey: 'sb_publishable_abc123',
        ),
      );
      for (final path in ['/profile/dev/gallery', '/profile/dev/theme']) {
        app.router.go(path);
        await tester.pumpAndSettle();
        expect(find.byType(WidgetGalleryPage), findsNothing);
        expect(find.byType(ThemePreviewPage), findsNothing);
        expect(find.byType(ProfileScreen), findsOneWidget);
      }
    });
  });

  group('developer pages in every mode (no overflow, a11y guidelines)', () {
    for (final (path, page) in [
      ('/profile/dev/gallery', 'gallery'),
      ('/profile/dev/theme', 'theme'),
    ]) {
      for (final locale in AppLocales.supported) {
        for (final brightness in Brightness.values) {
          for (final hc in [false, true]) {
            for (final scale in [1.0, 2.0]) {
              final name =
                  '$page ${locale.languageCode} ${brightness.name}'
                  '${hc ? ' HC' : ''} ${(scale * 100).round()}%';
              testWidgets(name, (tester) async {
                final handle = tester.ensureSemantics();
                final store = InMemoryKeyValueStore();
                await store.setString(localeStorageKey, locale.languageCode);
                final app = await _boot(
                  tester,
                  store: store,
                  brightness: brightness,
                  highContrast: hc,
                  textScale: scale,
                );
                app.router.go(path);
                await tester.pumpAndSettle();
                final ctx = tester.element(
                  find.byType(
                    page == 'gallery' ? WidgetGalleryPage : ThemePreviewPage,
                  ),
                );
                // The modes really applied.
                expect(
                  Directionality.of(ctx),
                  locale == AppLocales.urdu
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                );
                expect(Theme.of(ctx).brightness, brightness);
                expect(MediaQuery.highContrastOf(ctx), hc);
                expect(MediaQuery.textScalerOf(ctx).scale(10), 10 * scale);

                final stops = await _walk(tester, name);
                expect(stops, greaterThan(1), reason: 'page scrolls');

                if (page == 'gallery') {
                  // The bottom sheet, opened from the gallery.
                  for (
                    var i = 0;
                    i < 60 &&
                        find
                            .text('Open bottom sheet')
                            .hitTestable()
                            .evaluate()
                            .isEmpty;
                    i++
                  ) {
                    await _dragPage(tester, 300);
                  }
                  await tester.tap(find.text('Open bottom sheet'));
                  await tester.pumpAndSettle();
                  expect(tester.takeException(), isNull);
                  await _guidelines(tester, '$name sheet');
                }
                handle.dispose();
              });
            }
          }
        }
      }
    }
  });

  testWidgets(
    'gallery: the ErrorView sample keeps its retry button inside its box '
    '(Urdu, 200%)',
    skip: knownBug('1.6 S4-5') != false,
    (tester) async {
      final store = InMemoryKeyValueStore();
      await store.setString(localeStorageKey, 'ur');
      final app = await _boot(tester, store: store, textScale: 2);
      app.router.go('/profile/dev/gallery');
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 60 && find.byType(ErrorView).evaluate().isEmpty;
        i++
      ) {
        await _dragPage(tester, -300);
      }
      await tester.ensureVisible(find.byType(ErrorView));
      await tester.pumpAndSettle();
      expect(_clippedRetryOnScreen(tester), isFalse);
    },
  );

  group('config errors → ConfigErrorApp, without leaking values', () {
    const secret = 'sb_secret_DoNotShip1234567890';
    const serviceJwt =
        'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.c2lnbmF0dXJl';

    for (final (name, values) in [
      (
        'secret key',
        {
          'FLAVOR': 'prod',
          'APP_NAME': 'Sale Lagi Hai!',
          'SUPABASE_URL': 'https://abc.supabase.co',
          'SUPABASE_PUBLISHABLE_KEY': secret,
        },
      ),
      (
        'service_role JWT',
        {
          'FLAVOR': 'staging',
          'APP_NAME': 'SLH Staging',
          'SUPABASE_URL': 'https://abc.supabase.co',
          'SUPABASE_PUBLISHABLE_KEY': serviceJwt,
        },
      ),
      (
        'http URL and missing flavor',
        {
          'FLAVOR': '',
          'APP_NAME': '',
          'SUPABASE_URL': 'http://abc.supabase.co',
          'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_x',
        },
      ),
    ]) {
      testWidgets(name, (tester) async {
        final crashReporter = RecordingCrashReporter();
        final logger = createLogger(
          crashReporter: crashReporter,
          isReleaseMode: true,
        );
        late List<String> problems;
        try {
          AppConfig.fromMap(values);
          fail('config should be rejected');
        } on AppConfigException catch (e) {
          problems = e.problems;
          // What bootstrap() logs.
          logger.error(
            'Invalid app configuration',
            context: {'problems': e.problems},
          );
        }
        await tester.pumpWidget(ConfigErrorApp(problems: problems));
        await tester.pump();

        expect(find.text('App configuration error'), findsWidgets);
        for (final p in problems) {
          expect(find.text('• $p'), findsOneWidget);
        }
        final shown = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join('\n');
        final logged = crashReporter.errors
            .map((e) => '${e.message} ${e.errorText ?? ''}')
            .join('\n');
        for (final value in [secret, serviceJwt, 'abc.supabase.co']) {
          expect(shown, isNot(contains(value)), reason: 'UI shows $value');
          expect(logged, isNot(contains(value)), reason: 'log has $value');
        }
        expect(crashReporter.errors, isNotEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    test('a config never prints its key', () {
      const config = AppConfig(
        flavor: Flavor.prod,
        appName: 'x',
        supabaseUrl: 'https://abc.supabase.co',
        supabasePublishableKey: 'sb_publishable_abc123',
      );
      expect('$config', isNot(contains('sb_publishable_abc123')));
      expect('$config', isNot(contains('abc.supabase.co')));
    });
  });

  group('logging redaction end to end (release mode)', () {
    const pii =
        'user ali.khan@example.com.pk, phone +92 300 1234567, '
        'card 4111 1111 1111 1111, token '
        'eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.abc-_123, '
        'at 24.86073, 67.00114';
    const leaks = [
      'ali.khan@example.com.pk',
      '1234567',
      '4111',
      'eyJhbGciOiJIUzI1NiJ9',
      '24.86073',
    ];

    void expectRedacted(RecordingCrashReporter r) {
      expect(r.errors, isNotEmpty);
      final all = r.errors
          .map((e) => '${e.message} ${e.errorType} ${e.errorText}')
          .join('\n');
      for (final leak in leaks) {
        expect(all, isNot(contains(leak)), reason: leak);
      }
      expect(all, contains('[email]'));
    }

    testWidgets('a widget that throws while building, inside the app', (
      tester,
    ) async {
      final crashReporter = RecordingCrashReporter();
      final logger = createLogger(
        crashReporter: crashReporter,
        isReleaseMode: true,
      );
      final dispatcher = tester.binding.platformDispatcher;
      final onError = FlutterError.onError;
      final dispatcherOnError = dispatcher.onError;
      final builder = ErrorWidget.builder;
      var shownQuietWidget = false;
      var shownPii = true;
      try {
        installErrorHandlers(
          logger,
          dispatcher: dispatcher,
          isReleaseMode: true,
        );
        await tester.pumpWidget(
          MaterialApp(home: Builder(builder: (_) => throw StateError(pii))),
        );
        shownQuietWidget = find
            .byType(ReleaseErrorWidget)
            .evaluate()
            .isNotEmpty;
        shownPii = find.textContaining('ali.khan').evaluate().isNotEmpty;
      } finally {
        // flutter_test requires the handlers back before the test ends.
        FlutterError.onError = onError;
        dispatcher.onError = dispatcherOnError;
        ErrorWidget.builder = builder;
      }
      expectRedacted(crashReporter);
      // Release builds show the quiet error widget, not the red screen
      // with the message.
      expect(shownQuietWidget, isTrue);
      expect(shownPii, isFalse);
    });

    test('an uncaught async error goes through PlatformDispatcher', () {
      // TestPlatformDispatcher's onError setter is a no-op in flutter_test,
      // so this uses the real dispatcher, as error_handlers_test does.
      final crashReporter = RecordingCrashReporter();
      final logger = createLogger(
        crashReporter: crashReporter,
        isReleaseMode: true,
      );
      final dispatcher = PlatformDispatcher.instance;
      final onError = FlutterError.onError;
      final dispatcherOnError = dispatcher.onError;
      final builder = ErrorWidget.builder;
      bool? handled;
      try {
        installErrorHandlers(logger, isReleaseMode: true);
        handled = dispatcher.onError!(
          const FormatException(pii),
          StackTrace.current,
        );
      } finally {
        FlutterError.onError = onError;
        dispatcher.onError = dispatcherOnError;
        ErrorWidget.builder = builder;
      }
      expect(handled, isTrue);
      expectRedacted(crashReporter);
    });

    test('context maps are redacted by key and by value', () {
      final crashReporter = RecordingCrashReporter();
      createLogger(crashReporter: crashReporter, isReleaseMode: true).warning(
        'Login failed',
        error: Exception(pii),
        context: {'phone': '03001234567', 'note': pii},
      );
      expectRedacted(crashReporter);
    });

    test('release builds write nothing to the console', () {
      final printed = <String?>[];
      final saved = debugPrint;
      debugPrint = (m, {wrapWidth}) => printed.add(m);
      try {
        createLogger(
          crashReporter: RecordingCrashReporter(),
          isReleaseMode: true,
        ).error('boom $pii');
      } finally {
        debugPrint = saved;
      }
      expect(printed, isEmpty);
    });
  });

  group('performance sanity: rebuilds', () {
    testWidgets('an idle gallery only rebuilds its ticking expiry tags', (
      tester,
    ) async {
      final app = await _boot(
        tester,
        store: InMemoryKeyValueStore(),
        size: const Size(412, 4000),
      );
      app.router.go('/profile/dev/gallery');
      await tester.pumpAndSettle();

      final rebuilt = <String>[];
      final saved = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) =>
          rebuilt.add(element.widget.runtimeType.toString());
      try {
        // Two minutes of an idle screen (the urgent tags tick each minute).
        await tester.pump(const Duration(minutes: 1));
        await tester.pump(const Duration(minutes: 1));
      } finally {
        debugOnRebuildDirtyWidget = saved;
      }
      final kinds = rebuilt.toSet();
      // Only the expiry tags (and what they build) may rebuild.
      expect(
        kinds.difference({
          'ExpiryTag',
          '_IconLabel',
          'Flexible',
          'Text',
          'Icon',
        }),
        isEmpty,
        reason: '$kinds',
      );
      // 3 urgent/expired tags in the gallery × 2 ticks, with some slack.
      expect(rebuilt.where((k) => k == 'ExpiryTag').length, lessThan(12));
    });

    testWidgets('switching the language keeps the router and the tab', (
      tester,
    ) async {
      final app = await _boot(tester, store: InMemoryKeyValueStore());
      final router = app.container.read(routerProvider);
      app.router.go('/profile');
      await tester.pumpAndSettle();
      var builds = 0;
      final saved = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) => builds++;
      try {
        await tester.tap(find.text('اردو'));
        await tester.pumpAndSettle();
      } finally {
        debugOnRebuildDirtyWidget = saved;
      }
      expect(identical(app.container.read(routerProvider), router), isTrue);
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(router.state.uri.path, '/profile');
      // Recorded in the report; a full-app rebuild is expected here.
      // ignore: avoid_print
      print('QA: language switch rebuilt $builds elements');
      expect(builds, lessThan(5000));
    });
  });
}
