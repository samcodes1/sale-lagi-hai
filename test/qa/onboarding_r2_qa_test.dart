// QA, sub-phase 4.1 round 2: the BUG-1 recovery (`PreferencesController.
// _recover`), the BUG-5 redirect change, and 4.2's effect on 4.1. Written by
// the QA engineer (docs/qa/4.1.md, "Round 2").
//
// The round-1 persistence reproducer now fails the *language* read (the
// first read), so it no longer reaches the preferences path. These tests
// fail the preferences read itself.
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug; run them with `--dart-define=QA_KNOWN_BUGS=true`.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/bootstrap.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/app/router/app_router.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/device/notification_permission.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/data/preferences_store.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/alerts_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/brands_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/city_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/interests_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/language_step.dart';

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/fakes.dart';

const _returning = ShopperPreferences(
  onboarded: true,
  cityId: 'lahore',
  interestIds: ['food'],
  brandIds: ['brand-a', 'brand-b'],
);

/// A store whose reads of the preferences key fail [failPrefsReads] times;
/// after that, reads of that key can be held until [gate] completes.
final class PrefsFlakyStore implements KeyValueStore {
  new(this.inner, {this.failPrefsReads = 0});

  final InMemoryKeyValueStore inner;
  int failPrefsReads;
  Completer<void>? gate;
  int prefsReads = 0;
  int prefsWrites = 0;

  @override
  Future<String?> getString(String key) async {
    if (key == PreferencesStore.key) {
      prefsReads++;
      if (failPrefsReads > 0) {
        failPrefsReads--;
        throw PlatformException(code: 'io', message: 'read failed');
      }
      if (gate case final g?) await g.future;
    }
    return await inner.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    if (key == PreferencesStore.key) prefsWrites++;
    await inner.setString(key, value);
  }

  @override
  Future<void> remove(String key) => inner.remove(key);

  @override
  Future<Set<String>> keys() => inner.keys();

  @override
  Future<void> clear() => inner.clear();
}

Future<ProviderContainer> _boot(
  WidgetTester tester,
  KeyValueStore store, {
  AppLogger? logger,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final log = logger ?? AppLogger(sinks: []);
  final settings = await loadStartupSettings(log, openStore: () => store);
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          flavor: Flavor.dev,
          appName: 'SLH',
          supabaseUrl: '',
          supabasePublishableKey: '',
        ),
      ),
      backendGatewayProvider.overrideWithValue(DemoGateway()),
      deviceLocaleProvider.overrideWithValue(AppLocales.english),
      keyValueStoreProvider.overrideWithValue(store),
      loggerProvider.overrideWithValue(log),
      savedLocaleProvider.overrideWithValue(settings.locale),
      savedPreferencesProvider.overrideWithValue(settings.preferences),
      locationServiceProvider.overrideWithValue(
        FakeLocation(const LocationUnavailable()),
      ),
      notificationPermissionProvider.overrideWithValue(
        FakeAlerts(AlertPermission.denied),
      ),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  if (settle) await tester.pumpAndSettle();
  return container;
}

Future<void> _skipToEnd(WidgetTester tester) async {
  await tapText(tester, 'Continue');
  await tapText(tester, 'Skip');
  await tapText(tester, 'Skip');
  await tapText(tester, 'Skip');
  await tapText(tester, 'Not now');
}

void main() {
  group('BUG-1 recovery: the preferences read itself fails', () {
    testWidgets('fails once at launch → the re-read restores the returning '
        'shopper and the app opens Home; nothing is overwritten', (
      tester,
    ) async {
      final inner = InMemoryKeyValueStore();
      await PreferencesStore(inner).write(_returning);
      final store = PrefsFlakyStore(inner, failPrefsReads: 1);
      final container = await _boot(tester, store);
      expect(store.prefsReads, 2, reason: 'launch read failed, re-read ran');
      expect(container.read(preferencesProvider), _returning);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(store.prefsWrites, 0);
      expect(await PreferencesStore(inner).read(), _returning);
    });

    testWidgets('fails every time → the shopper can finish onboarding for '
        'the session, and the saved choices are never touched', (tester) async {
      final sink = MemoryLogSink();
      final inner = InMemoryKeyValueStore();
      await PreferencesStore(inner).write(_returning);
      final store = PrefsFlakyStore(inner, failPrefsReads: 1000);
      final container = await _boot(
        tester,
        store,
        logger: AppLogger(sinks: [sink]),
      );
      expect(find.byType(LanguageStep), findsOneWidget);
      await tapText(tester, 'Continue');
      await tapText(tester, 'Karachi');
      await tapText(tester, 'Continue');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Not now');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(container.read(preferencesProvider).onboarded, isTrue);
      expect(store.prefsWrites, 0);
      expect(await PreferencesStore(inner).read(), _returning);
      expect(
        sink.records.map((r) => r.message),
        contains('Saved preferences still unreadable; not saving this session'),
      );
    });

    testWidgets('first launch whose read failed: once the re-read works, '
        "this session's choices are saved", (tester) async {
      final inner = InMemoryKeyValueStore(); // nothing saved
      final store = PrefsFlakyStore(inner, failPrefsReads: 1)
        ..gate = Completer<void>();
      final container = await _boot(tester, store);
      // The re-read is held: the shopper starts onboarding meanwhile.
      await tapText(tester, 'Continue');
      await tapText(tester, 'Karachi');
      expect(store.prefsWrites, 0, reason: 'nothing is written while unknown');
      store.gate!.complete();
      await tester.pumpAndSettle();
      final saved = await PreferencesStore(inner).read();
      expect(saved.cityId, container.read(preferencesProvider).cityId);
      expect(saved.cityId, isNotNull);
      // Later changes are saved normally.
      await tapText(tester, 'Continue');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Not now');
      expect((await PreferencesStore(inner).read()).onboarded, isTrue);
    });

    testWidgets('a returning shopper acting during a slow re-read: the saved '
        'choices win, and the app moves to Home', (tester) async {
      final inner = InMemoryKeyValueStore();
      await PreferencesStore(inner).write(_returning);
      final store = PrefsFlakyStore(inner, failPrefsReads: 1)
        ..gate = Completer<void>();
      final container = await _boot(tester, store);
      expect(find.byType(LanguageStep), findsOneWidget);
      await tapText(tester, 'Continue');
      await tapText(tester, 'Karachi');
      store.gate!.complete();
      await tester.pumpAndSettle();
      expect(container.read(preferencesProvider), _returning);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(await PreferencesStore(inner).read(), _returning);
      expect(find.byType(CityStep, skipOffstage: false), findsNothing);
    });

    testWidgets('disposing during the re-read: no error, no write', (
      tester,
    ) async {
      final inner = InMemoryKeyValueStore();
      await PreferencesStore(inner).write(_returning);
      final store = PrefsFlakyStore(inner, failPrefsReads: 1)
        ..gate = Completer<void>();
      final container = await _boot(tester, store);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      store.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(store.prefsWrites, 0);
      expect(await PreferencesStore(inner).read(), _returning);
    });

    testWidgets('the re-read fails after a user change, then a later change: '
        'still nothing written', (tester) async {
      final inner = InMemoryKeyValueStore();
      await PreferencesStore(inner).write(_returning);
      final store = PrefsFlakyStore(inner, failPrefsReads: 2);
      final container = await _boot(tester, store);
      expect(store.prefsReads, 2);
      final prefs = container.read(preferencesProvider.notifier);
      await prefs.setCity('karachi');
      await prefs.toggleBrand('brand-x');
      await prefs.completeOnboarding();
      expect(store.prefsWrites, 0);
      expect(await PreferencesStore(inner).read(), _returning);
    });

    testWidgets('a corrupt (unparseable) file is a first launch, and the '
        'new choices replace it', (tester) async {
      final inner = InMemoryKeyValueStore();
      await inner.setString(PreferencesStore.key, '{broken');
      final container = await _boot(tester, inner);
      expect(find.byType(LanguageStep), findsOneWidget);
      await container.read(preferencesProvider.notifier).setCity('karachi');
      expect((await PreferencesStore(inner).read()).cityId, 'karachi');
    });
  });

  group('BUG-5 redirect', () {
    for (final step in [
      '/welcome/city',
      '/welcome/interests',
      '/welcome/brands',
      '/welcome/alerts',
      '/welcome/alerts?x=1',
    ]) {
      testWidgets('$step before a language is chosen → /welcome', (
        tester,
      ) async {
        final h = Harness();
        await h.pump(tester, languageChosen: false);
        h.router.go(step);
        await tester.pumpAndSettle();
        expect(find.byType(LanguageStep), findsOneWidget);
        expect(h.router.state.uri.path, '/welcome');
      });
    }

    testWidgets('Continue confirms the language; later steps are then '
        'reachable, also after going back', (tester) async {
      final h = Harness();
      await h.pump(tester, languageChosen: false);
      await tapText(tester, 'Continue');
      expect(find.byType(CityStep), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      h.router.go('/welcome/alerts');
      await tester.pumpAndSettle();
      expect(find.byType(AlertsStep), findsOneWidget);
    });

    testWidgets('a saved language counts as chosen (a restart mid-flow)', (
      tester,
    ) async {
      final inner = InMemoryKeyValueStore();
      await inner.setString(localeStorageKey, 'en');
      final container = await _boot(tester, inner);
      expect(container.read(languageChosenProvider), isTrue);
      container.read(routerProvider).go('/welcome/alerts');
      await tester.pumpAndSettle();
      expect(find.byType(AlertsStep), findsOneWidget);
    });

    testWidgets('picking a language tile alone does not count as chosen', (
      tester,
    ) async {
      final h = Harness();
      await h.pump(tester, languageChosen: false);
      await tapText(tester, 'اردو');
      h.router.go('/welcome/alerts');
      await tester.pumpAndSettle();
      expect(find.byType(LanguageStep), findsOneWidget);
    });

    testWidgets('a pending deal link still opens after the full flow', (
      tester,
    ) async {
      final h = Harness();
      await h.pump(tester, languageChosen: false);
      h.router.go('/deal/3f2a9c1e-7b4d-4e8a-9c2f-1a2b3c4d5e6f');
      await tester.pumpAndSettle();
      await _skipToEnd(tester);
      expect(h.router.state.uri.path, startsWith('/deal/'));
    });
  });

  group('BUG-6 residual', () {
    testWidgets('same-frame double tap on the app bar back arrow goes back '
        'one step', (tester) async {
      await Harness().pump(tester);
      await tapText(tester, 'Continue');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Skip');
      expect(find.byType(BrandsStep), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.tap(find.byType(BackButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(InterestsStep), findsOneWidget);
      expect(find.byType(CityStep), findsNothing);
    });
  });

  group('4.2 effect on 4.1', () {
    testWidgets(
      'after reset() (account deletion), re-onboarding ends on Home, not on '
      'the screen where the reset happened',
      (tester) async {
        final h = Harness(saved: const ShopperPreferences(onboarded: true));
        await h.pump(tester);
        h.router.go('/profile');
        await tester.pumpAndSettle();
        await h.container.read(preferencesProvider.notifier).reset();
        await tester.pumpAndSettle();
        expect(find.byType(LanguageStep), findsOneWidget);
        await _skipToEnd(tester);
        expect(
          find.byType(HomeScreen),
          findsOneWidget,
          reason: 'landed on ${h.router.state.uri}',
        );
      },
    );

    testWidgets('after reset(), the cleared preferences are not written '
        'back by the next change, and onboarding starts at language', (
      tester,
    ) async {
      final h = Harness(saved: _returning);
      await h.pump(tester);
      await h.store.setString(
        PreferencesStore.key,
        '{"onboarded":true,"brand_ids":["brand-a"]}',
      );
      await h.container.read(preferencesProvider.notifier).reset();
      await tester.pumpAndSettle();
      expect(await h.store.getString(PreferencesStore.key), isNull);
      expect(find.byType(LanguageStep), findsOneWidget);
      expect(h.preferences, const ShopperPreferences());
    });
  });
}
