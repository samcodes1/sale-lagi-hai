// QA, sub-phase 4.1 (Onboarding): flow edge cases, persistence, location
// and permission outcomes, privacy, semantics order and the modes the
// developer's tests skip. Written by the QA engineer (docs/qa/4.1.md).
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug; run them with `--dart-define=QA_KNOWN_BUGS=true`.
//
// No alchemist goldens in this file: it uses textContrastGuideline.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/bootstrap.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/app/router/app_router.dart';
import 'package:sale_lagi_hai/app/router/not_found_screen.dart';
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
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/data/preferences_store.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/alerts_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/brands_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/city_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/interests_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/language_step.dart';
import 'package:sale_lagi_hai/features/profile/presentation/profile_screen.dart';

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/fakes.dart';

const _dealId = '3f2a9c1e-7b4d-4e8a-9c2f-1a2b3c4d5e6f';

String _short(String s) => s.length > 60 ? '${s.substring(0, 60)}…' : s;

/// A store whose reads fail [failReads] times, then work.
final class FlakyStore implements KeyValueStore {
  new(this.inner, {this.failReads = 0, this.failWrites = false});

  final InMemoryKeyValueStore inner;
  int failReads;
  bool failWrites;

  @override
  Future<String?> getString(String key) async {
    if (failReads > 0) {
      failReads--;
      throw PlatformException(code: 'io', message: 'DataStore read failed');
    }
    return await inner.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    if (failWrites) throw PlatformException(code: 'io', message: 'disk full');
    await inner.setString(key, value);
  }

  @override
  Future<void> remove(String key) => inner.remove(key);

  @override
  Future<Set<String>> keys() => inner.keys();

  @override
  Future<void> clear() => inner.clear();
}

/// Boots [App] the way `bootstrap()` does: startup settings read from
/// [store]; when that read fails, bootstrap leaves `keyValueStoreProvider`
/// at its default, which is the same SharedPreferences, so [fallback]
/// stands in for it.
Future<ProviderContainer> _boot(
  WidgetTester tester, {
  required KeyValueStore store,
  KeyValueStore? fallback,
  Locale device = AppLocales.english,
  LocationService? location,
  NotificationPermissionService? alerts,
  AppLogger? logger,
  // Most tests open a step directly; a shopper gets there after choosing a
  // language (4.1 BUG-5 fix). The BUG-5 test passes false.
  bool languageChosen = true,
  AppConfig config = const AppConfig(
    flavor: Flavor.dev,
    appName: 'SLH',
    supabaseUrl: '',
    supabasePublishableKey: '',
  ),
}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final log = logger ?? AppLogger(sinks: []);
  final settings = await loadStartupSettings(log, openStore: () => store);
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(config),
      backendGatewayProvider.overrideWithValue(DemoGateway()),
      deviceLocaleProvider.overrideWithValue(device),
      keyValueStoreProvider.overrideWithValue(
        settings.store ?? fallback ?? store,
      ),
      loggerProvider.overrideWithValue(log),
      savedLocaleProvider.overrideWithValue(settings.locale),
      savedPreferencesProvider.overrideWithValue(settings.preferences),
      locationServiceProvider.overrideWithValue(
        location ?? FakeLocation(const LocationUnavailable()),
      ),
      notificationPermissionProvider.overrideWithValue(
        alerts ?? FakeAlerts(AlertPermission.denied),
      ),
      // Added with 4.3: Home now needs a sign-in backend and network status.
      guestAuth(),
      onlineNetwork(),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  if (languageChosen) container.read(languageChosenProvider.notifier).confirm();
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Skips through every step after language.
Future<void> _skipToEnd(WidgetTester tester) async {
  await tapText(tester, 'Continue'); // language
  await tapText(tester, 'Skip'); // city
  await tapText(tester, 'Skip'); // interests
  await tapText(tester, 'Skip'); // brands
  await tapText(tester, 'Not now'); // alerts
}

int _count(Type type) =>
    find.byType(type, skipOffstage: false).evaluate().length;

/// Labels of the semantics tree in screen-reader (traversal) order.
List<String> _readingOrder(WidgetTester tester) {
  final out = <String>[];
  void walk(SemanticsNode node) {
    final d = node.getSemanticsData();
    final text = [d.label, d.tooltip].where((s) => s.isNotEmpty).join(' ');
    if (text.isNotEmpty && !node.isInvisible) out.add(text);
    node
        .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
        .forEach(walk);
  }

  walk(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return out;
}

final class _ThrowingGeolocator extends Fake implements GeolocatorPlatform {
  new(this.error, {this.inRequest = false});

  final Object error;
  final bool inRequest;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      inRequest ? LocationPermission.denied : LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      Error.throwWithStackTrace(error, StackTrace.current);

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Error.throwWithStackTrace(error, StackTrace.current);
}

/// A location service that waits until [answer] completes.
final class _SlowLocation implements LocationService {
  final answer = Completer<LocationOutcome>();
  int asked = 0;

  @override
  Future<LocationOutcome> approximateLocation() {
    asked++;
    return answer.future;
  }

  @override
  Future<bool> openAppSettings() async => true;
}

final class _SlowAlerts implements NotificationPermissionService {
  final answer = Completer<AlertPermission>();
  int requested = 0;

  @override
  Future<AlertPermission> status() async => AlertPermission.denied;

  @override
  Future<AlertPermission> request() {
    requested++;
    return answer.future;
  }

  @override
  Future<bool> openSettings() async => true;
}

void main() {
  group('double taps (a human double tap, 100 ms apart)', () {
    const gap = Duration(milliseconds: 100);

    testWidgets('Continue twice on the language step pushes one city step', (
      tester,
    ) async {
      final h = Harness();
      await h.pump(tester);
      final at = tester.getCenter(find.text('Continue'));
      await tester.tapAt(at);
      await tester.pump(gap);
      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(_count(CityStep), 1);
      expect(
        _count(InterestsStep),
        0,
        reason:
            'the 2nd tap must not land on '
            "the next step's Continue",
      );
      expect(h.router.state.uri.path, '/welcome/city');
    });

    testWidgets('Turn on alerts twice asks the system once', (tester) async {
      final alerts = _SlowAlerts();
      final container = await _boot(
        tester,
        store: InMemoryKeyValueStore(),
        alerts: alerts,
      );
      container.read(routerProvider).go('/welcome/alerts');
      await tester.pumpAndSettle();
      final at = tester.getCenter(find.text('Turn on alerts'));
      await tester.tapAt(at);
      await tester.pump(gap);
      await tester.tapAt(at);
      await tester.pump(gap);
      // "Not now" is disabled while the system dialog is up, too.
      await tester.tap(find.text('Not now'), warnIfMissed: false);
      await tester.pump();
      expect(alerts.requested, 1);
      expect(container.read(preferencesProvider).onboarded, isFalse);
      alerts.answer.complete(AlertPermission.granted);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Detect my city twice asks for location once', (tester) async {
      final location = _SlowLocation();
      final container = await _boot(
        tester,
        store: InMemoryKeyValueStore(),
        location: location,
      );
      container.read(routerProvider).go('/welcome/city');
      await tester.pumpAndSettle();
      final at = tester.getCenter(find.text('Detect my city'));
      await tester.tapAt(at);
      await tester.pump(gap);
      await tester.tapAt(at);
      await tester.pump();
      expect(location.asked, 1);
      location.answer.complete(const Located(24.8138, 67.03));
      await tester.pumpAndSettle();
      expect(find.text("You're in Karachi."), findsOneWidget);
    });

    // Two pointer events inside ONE frame (a two-finger tap): the handlers
    // run before the rebuild that disables the button or starts the route
    // transition. Low likelihood, recorded as S4 (BUG-6).
    for (final (name, location, label) in const [
      ('Continue (language)', '/welcome', 'Continue'),
      ('Turn on alerts', '/welcome/alerts', 'Turn on alerts'),
    ]) {
      testWidgets('same-frame double tap on $name acts once', (tester) async {
        final alerts = FakeAlerts(AlertPermission.denied);
        final container = await _boot(
          tester,
          store: InMemoryKeyValueStore(),
          alerts: alerts,
        );
        container.read(routerProvider).go(location);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.tap(find.text(label), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(_count(CityStep), lessThanOrEqualTo(1));
        expect(alerts.requested, lessThanOrEqualTo(1));
      });
    }
  });

  group('back and predictive back', () {
    testWidgets('system back walks the steps back, then leaves the app', (
      tester,
    ) async {
      await Harness().pump(tester);
      await tapText(tester, 'Continue');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Skip');
      expect(find.byType(BrandsStep), findsOneWidget);
      for (final step in [InterestsStep, CityStep, LanguageStep]) {
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        expect(find.byType(step), findsOneWidget);
      }
      expect(await tester.binding.handlePopRoute(), isFalse);
    });

    testWidgets('after onboarding, back on Home leaves the app (no way back '
        'into the steps)', (tester) async {
      final h = Harness();
      await h.pump(tester);
      await _skipToEnd(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(h.router.state.uri.path, '/');
      expect(await tester.binding.handlePopRoute(), isFalse);
      expect(_count(LanguageStep) + _count(AlertsStep), 0);
    });

    testWidgets('the step back button has a label in Urdu', (tester) async {
      final handle = tester.ensureSemantics();
      await Harness().pump(tester, device: AppLocales.urdu);
      await tapText(tester, 'آگے چلیں');
      final back = find.byType(BackButton);
      expect(back, findsOneWidget);
      final label = tester.getSemantics(back).getSemanticsData();
      expect('${label.label}${label.tooltip}', isNotEmpty);
      handle.dispose();
    });
  });

  group('deep links during onboarding', () {
    for (final location in [
      '//evil.example/steal',
      '/deal/not-a-uuid',
      '/deal/$_dealId/%2e%2e/%2e%2e/profile/dev/gallery',
      '/brand/%3Cscript%3Ealert(1)%3C%2Fscript%3E',
      '/brand/${'x' * 5000}',
      '/totally-unknown?next=https://evil.example',
      '/welcome/../deal/$_dealId',
      '/profile/dev/gallery',
    ]) {
      testWidgets(
        'pending "${_short(location)}" never shows itself and lands safely',
        (tester) async {
          final container = await _boot(
            tester,
            store: InMemoryKeyValueStore(),
            config: const AppConfig(
              flavor: Flavor.prod,
              appName: 'Sale Lagi Hai!',
              supabaseUrl: 'https://abc.supabase.co',
              supabasePublishableKey: 'sb_publishable_abc123',
            ),
          );
          container.read(routerProvider).go(location);
          await tester.pumpAndSettle();
          expect(find.byType(LanguageStep), findsOneWidget);
          await _skipToEnd(tester);
          expect(tester.takeException(), isNull);
          final onHome = find.byType(HomeScreen).evaluate().isNotEmpty;
          final notFound = find.byType(NotFoundScreen).evaluate().isNotEmpty;
          final profile = find.byType(ProfileScreen).evaluate().isNotEmpty;
          // `/welcome/../deal/<uuid>` normalises to a valid deal link.
          final validDeal =
              location.contains('/../deal/') &&
              find.byType(DealDetailScreen).evaluate().isNotEmpty;
          expect(onHome || notFound || profile || validDeal, isTrue);
          if (validDeal) return;
          expect(find.textContaining('evil'), findsNothing);
          expect(find.textContaining('script'), findsNothing);
          expect(find.byType(DealDetailScreen), findsNothing);
        },
      );
    }

    testWidgets('a valid deal link survives every step and opens once', (
      tester,
    ) async {
      final container = await _boot(tester, store: InMemoryKeyValueStore());
      final router = container.read(routerProvider)
        ..go('/deal/$_dealId?utm_source=whatsapp');
      await tester.pumpAndSettle();
      await _skipToEnd(tester);
      expect(find.byType(DealDetailScreen), findsOneWidget);
      // Opened once: back goes Home, and /welcome no longer replays it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      router.go('/welcome');
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets(
      'a link straight to /welcome/alerts cannot skip the language step',
      (tester) async {
        final container = await _boot(
          tester,
          store: InMemoryKeyValueStore(),
          languageChosen: false,
        );
        container.read(routerProvider).go('/welcome/alerts');
        await tester.pumpAndSettle();
        expect(find.byType(LanguageStep), findsOneWidget);
      },
    );
  });

  group('kill mid-flow and language switch mid-flow', () {
    testWidgets('a restart mid-flow restarts at language, keeping choices', (
      tester,
    ) async {
      final store = InMemoryKeyValueStore();
      var container = await _boot(tester, store: store);
      await tapText(tester, 'اردو');
      await tapText(tester, 'آگے چلیں');
      await tapText(tester, 'لاہور');
      // "Kill": drop the app, boot again from the same storage.
      await tester.pumpWidget(const SizedBox());
      container = await _boot(tester, store: store);
      expect(find.byType(LanguageStep), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(LanguageStep))),
        TextDirection.rtl,
      );
      final prefs = container.read(preferencesProvider);
      expect(prefs.onboarded, isFalse);
      expect(prefs.cityId, isNotNull);
    });

    testWidgets('switching language mid-flow keeps the step stack', (
      tester,
    ) async {
      final h = Harness();
      await h.pump(tester);
      await tapText(tester, 'Continue');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Skip');
      expect(find.byType(BrandsStep), findsOneWidget);
      await h.container
          .read(localeControllerProvider.notifier)
          .select(AppLocales.urdu);
      await tester.pumpAndSettle();
      expect(find.byType(BrandsStep), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(BrandsStep))),
        TextDirection.rtl,
      );
      expect(find.text('پسندیدہ برانڈز'), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(InterestsStep), findsOneWidget);
    });
  });

  group('location outcomes (service contract: never throws)', () {
    for (final (name, error, inRequest) in [
      (
        'position update failure',
        const PositionUpdateException('fused'),
        false,
      ),
      ('activity missing', const ActivityMissingException('none'), true),
      (
        'request already running',
        const PermissionRequestInProgressException('x'),
        true,
      ),
      (
        'no manifest permission',
        const PermissionDefinitionsNotFoundException('x'),
        true,
      ),
      ('invalid permission', const InvalidPermissionException(7), false),
    ]) {
      test('$name becomes an outcome', () async {
        final service = GeolocatorLocationService(
          platform: _ThrowingGeolocator(error, inRequest: inRequest),
        );
        expect(await service.approximateLocation(), isA<LocationOutcome>());
      });
    }

    testWidgets('the city step recovers when the location call fails', (
      tester,
    ) async {
      final container = await _boot(
        tester,
        store: InMemoryKeyValueStore(),
        location: GeolocatorLocationService(
          platform: _ThrowingGeolocator(const PositionUpdateException('fused')),
        ),
      );
      container.read(routerProvider).go('/welcome/city');
      await tester.pumpAndSettle();
      await tapText(tester, 'Detect my city');
      expect(tester.takeException(), isNull);
      expect(find.text('Finding your city…'), findsNothing);
      final detect = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Detect my city'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(detect.onPressed, isNotNull, reason: 'can try again');
    });

    testWidgets('a location far from every city says "not covered"', (
      tester,
    ) async {
      final container = await _boot(
        tester,
        store: InMemoryKeyValueStore(),
        location: FakeLocation(const Located(51.5, -0.12)), // London
      );
      container.read(routerProvider).go('/welcome/city');
      await tester.pumpAndSettle();
      await tapText(tester, 'Detect my city');
      expect(find.textContaining("isn't near a city we cover"), findsOneWidget);
      expect(container.read(preferencesProvider).cityId, isNull);
    });

    testWidgets('leaving the step while detecting does not crash', (
      tester,
    ) async {
      final location = _SlowLocation();
      final container = await _boot(
        tester,
        store: InMemoryKeyValueStore(),
        location: location,
      );
      final router = container.read(routerProvider)..go('/welcome');
      await tester.pumpAndSettle();
      await tapText(tester, 'Continue');
      await tester.tap(find.text('Detect my city'));
      await tester.pump();
      await tester.binding.handlePopRoute(); // back to language
      await tester.pumpAndSettle();
      location.answer.complete(const Located(24.8138, 67.03));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(router.state.uri.path, '/welcome');
      expect(find.byType(LanguageStep), findsOneWidget);
    });
  });

  group('alerts outcomes', () {
    for (final answer in AlertPermission.values) {
      testWidgets('Turn on alerts → ${answer.name}', (tester) async {
        final alerts = FakeAlerts(answer);
        final container = await _boot(
          tester,
          store: InMemoryKeyValueStore(),
          alerts: alerts,
        );
        container.read(routerProvider).go('/welcome/alerts');
        await tester.pumpAndSettle();
        await tapText(tester, 'Turn on alerts');
        expect(alerts.requested, 1);
        final prefs = container.read(preferencesProvider);
        expect(prefs.alertsAskedAt, isNotNull);
        if (answer == AlertPermission.permanentlyDenied) {
          expect(prefs.onboarded, isFalse);
          expect(find.text('Open settings'), findsOneWidget);
          await tapText(tester, 'Continue');
        }
        expect(container.read(preferencesProvider).onboarded, isTrue);
        expect(find.byType(HomeScreen), findsOneWidget);
      });
    }
  });

  group('persistence', () {
    testWidgets('a transient read failure at launch does not wipe a returning '
        "shopper's saved choices", (tester) async {
      final inner = InMemoryKeyValueStore();
      const saved = ShopperPreferences(
        onboarded: true,
        cityId: 'lahore',
        interestIds: ['food'],
        brandIds: ['brand-a', 'brand-b'],
      );
      await PreferencesStore(inner).write(saved);
      await inner.setString(localeStorageKey, 'ur');

      final store = FlakyStore(inner, failReads: 1);
      await _boot(tester, store: store, fallback: inner);
      // Whatever the app shows now, finishing the flow it shows must not
      // destroy what was saved.
      if (find.byType(LanguageStep).evaluate().isNotEmpty) {
        await _skipToEnd(tester);
      }
      final after = await PreferencesStore(inner).read();
      expect(after.brandIds, saved.brandIds);
      expect(after.cityId, saved.cityId);
    });

    testWidgets('a failure reading the language alone does not hide the '
        'saved preferences', (tester) async {
      final inner = InMemoryKeyValueStore();
      await PreferencesStore(inner)
          .write(const ShopperPreferences(onboarded: true));
      final store = FlakyStore(inner, failReads: 1); // the locale read
      await _boot(tester, store: store, fallback: inner);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    for (final (name, raw, expected) in [
      ('not JSON', '{onboarded: true', const ShopperPreferences()),
      ('a JSON list', '[true]', const ShopperPreferences()),
      ('JSON null', 'null', const ShopperPreferences()),
      ('a string', '"onboarded"', const ShopperPreferences()),
      (
        'wrong field types',
        '{"onboarded": "true", "city_id": 7, "interest_ids": "food", '
            '"brand_ids": [1, null, "", "b"], "alerts_asked_at": "soon"}',
        const ShopperPreferences(brandIds: ['b']),
      ),
      (
        'valid, with unknown extra keys',
        '{"onboarded": true, "city_id": "c", "x": {"deep": [1, 2]}}',
        const ShopperPreferences(onboarded: true, cityId: 'c'),
      ),
    ]) {
      testWidgets('corrupt preferences ($name) boot safely', (tester) async {
        final inner = InMemoryKeyValueStore();
        await inner.setString(PreferencesStore.key, raw);
        final container = await _boot(tester, store: inner);
        expect(tester.takeException(), isNull);
        expect(container.read(preferencesProvider), expected);
        expect(
          find.byType(expected.onboarded ? HomeScreen : LanguageStep),
          findsOneWidget,
        );
      });
    }

    testWidgets('every save failing: the flow still completes for the '
        'session, and each failure is logged without values', (tester) async {
      final sink = MemoryLogSink();
      final inner = InMemoryKeyValueStore();
      final store = FlakyStore(inner, failWrites: true);
      await _boot(
        tester,
        store: store,
        logger: AppLogger(sinks: [sink]),
      );
      await tapText(tester, 'Continue');
      await tapText(tester, 'Lahore');
      await tapText(tester, 'Continue');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Not now');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(inner.values, isEmpty);
      final logged = sink.records.map((r) => '$r ${r.message}').join('\n');
      expect(logged, contains('Could not save the shopper preferences'));
      expect(logged, isNot(contains('lahore')));
    });
  });

  group('privacy', () {
    testWidgets('a detected location is never logged or stored', (
      tester,
    ) async {
      final sink = MemoryLogSink();
      final store = InMemoryKeyValueStore();
      final container = await _boot(
        tester,
        store: store,
        logger: AppLogger(sinks: [sink]),
        location: FakeLocation(const Located(24.81384, 67.03021)),
      );
      container.read(routerProvider).go('/welcome/city');
      await tester.pumpAndSettle();
      await tapText(tester, 'Detect my city');
      await tapText(tester, 'Continue');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Not now');
      final everything = [
        ...store.values.entries.map((e) => '${e.key}=${e.value}'),
        ...sink.records.map((r) => '${r.message} ${r.errorText} ${r.context}'),
      ].join('\n');
      for (final fragment in ['24.81', '67.03', '24,81', '67,03']) {
        expect(everything, isNot(contains(fragment)), reason: fragment);
      }
      // Only the two documented keys are written, plus (since 4.3) the
      // home rows' offline copies: public deal data under `cache.home.`
      // (the coordinates check above covers them too).
      expect(
        store.values.keys
            .where((k) => !k.startsWith('cache.home.'))
            .toSet()
            .difference({localeStorageKey, PreferencesStore.key}),
        isEmpty,
      );
      final prefs = jsonDecode(store.values[PreferencesStore.key]!) as Map;
      expect(prefs.keys.toSet(), {
        'onboarded',
        'city_id',
        'interest_ids',
        'brand_ids',
        // 4.5: followed categories (ids of public rows, like brand_ids).
        'category_follow_ids',
        'alerts_asked_at',
      });
    });
  });

  group('screen-reader order and the modes the developer tests skip', () {
    for (final (location, first, last) in const [
      ('/welcome', 'Step 1 of 5', 'Continue'),
      ('/welcome/city', 'Step 2 of 5', 'Continue'),
      ('/welcome/alerts', 'Step 5 of 5', 'Not now'),
    ]) {
      testWidgets('$location reads progress first, the actions last', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final h = Harness();
        await h.pump(tester);
        h.router.go(location);
        await tester.pumpAndSettle();
        final order = _readingOrder(tester)
          ..removeWhere((s) => s.startsWith('Back'));
        expect(order.first, contains(first), reason: '$order');
        expect(order.last, contains(last), reason: '$order');
        handle.dispose();
      });
    }

    for (final (name, locale, brightness, hc) in const [
      ('en dark', AppLocales.english, Brightness.dark, false),
      ('ur light', AppLocales.urdu, Brightness.light, false),
      ('en light HC', AppLocales.english, Brightness.light, true),
      ('ur dark HC', AppLocales.urdu, Brightness.dark, true),
    ]) {
      for (final step in const [
        '/welcome',
        '/welcome/city',
        '/welcome/interests',
        '/welcome/brands',
        '/welcome/alerts',
      ]) {
        testWidgets('$name $step: guidelines', (tester) async {
          final handle = tester.ensureSemantics();
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              FakeAccessibilityFeatures(highContrast: hc);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final h = Harness();
          await h.pump(tester, device: locale);
          h.router.go(step);
          await tester.pumpAndSettle();
          // At the end of the list, so no row is cut by the bottom bar
          // (a half-hidden row confuses the contrast sampler).
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -2000),
          );
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    }
  });
}
