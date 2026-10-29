import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/device/notification_permission.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/data/preferences_store.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/alerts_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/brands_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/city_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/interests_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/language_step.dart';

import 'onboarding_harness.dart';

void main() {
  testWidgets(
    'first launch opens on the language step, in the phone language',
    (tester) async {
      await Harness().pump(tester);
      expect(find.byType(LanguageStep), findsOneWidget);
      expect(
        find.text('Every sale in Pakistan, in one place.'),
        findsOneWidget,
      );
      // Both readers understand the first screen.
      expect(find.textContaining('Choose your language'), findsOneWidget);
      expect(find.textContaining('اپنی زبان منتخب کریں'), findsOneWidget);
      expect(find.bySemanticsLabel('Step 1 of 5'), findsOneWidget);
      // Language is the one step that can't be skipped.
      expect(find.text('Skip'), findsNothing);
    },
  );

  testWidgets('the whole flow: language, detected city, interests, brands, '
      'alerts, then Home, all saved', (tester) async {
    final h = Harness();
    await h.pump(tester);

    // Urdu applies at once: the screen turns right to left.
    await tapText(tester, 'اردو');
    expect(h.container.read(localeControllerProvider), AppLocales.urdu);
    expect(
      Directionality.of(tester.element(find.byType(LanguageStep))),
      TextDirection.rtl,
    );
    await tapText(tester, 'English');
    await tapText(tester, 'Continue');

    expect(find.byType(CityStep), findsOneWidget);
    expect(h.location.asked, 0, reason: 'location is never asked unprompted');
    await tapText(tester, 'Detect my city');
    expect(h.location.asked, 1);
    expect(find.text("You're in Karachi."), findsOneWidget);
    expect(h.preferences.cityId, karachiId);
    await tapText(tester, 'Continue');

    expect(find.byType(InterestsStep), findsOneWidget);
    expect(find.text('None picked yet'), findsOneWidget);
    await tapText(tester, 'Food & Restaurants');
    expect(find.text('1 picked'), findsOneWidget);
    await tapText(tester, 'Continue');

    // Brands from the picked interest only.
    expect(find.byType(BrandsStep), findsOneWidget);
    expect(find.text('Karahi House (Demo)'), findsOneWidget);
    expect(find.text('Threads (Demo)'), findsNothing);
    await tapText(tester, 'Karahi House (Demo)');
    expect(find.text('Following 1 brand'), findsOneWidget);
    await tapText(tester, 'Continue');

    expect(find.byType(AlertsStep), findsOneWidget);
    expect(h.alerts.requested, 0, reason: 'no system dialog before the button');
    await tapText(tester, 'Turn on alerts');
    expect(h.alerts.requested, 1);

    expect(find.byType(HomeScreen), findsOneWidget);
    final saved = await PreferencesStore(h.store).read();
    expect(saved.onboarded, isTrue);
    expect(saved.cityId, karachiId);
    expect(saved.interestIds, [categoryId('food-and-restaurants')]);
    expect(saved.brandIds, [brandBySlug('demo-karahi-house')['id']]);
    expect(saved.alertsAskedAt, isNotNull);
  });

  testWidgets('every step after language can be skipped; Not now never asks', (
    tester,
  ) async {
    final h = Harness();
    await h.pump(tester);
    await tapText(tester, 'Continue');
    await tapText(tester, 'Skip');
    await tapText(tester, 'Skip');
    // No interests: every brand is offered.
    expect(find.text('Threads (Demo)'), findsOneWidget);
    await tapText(tester, 'Skip');
    await tapText(tester, 'Not now');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(h.alerts.requested, 0);
    expect(h.location.asked, 0);
    expect(h.preferences.cityId, isNull);
    expect(h.preferences.alertsAskedAt, isNotNull);
  });

  testWidgets('back returns to the previous step', (tester) async {
    final h = Harness();
    await h.pump(tester);
    await tapText(tester, 'Continue');
    await tapText(tester, 'Continue');
    expect(find.byType(InterestsStep), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CityStep), findsOneWidget);
  });

  testWidgets('a returning shopper opens on Home, and /welcome sends them '
      'there', (tester) async {
    final h = Harness(saved: const ShopperPreferences(onboarded: true));
    await h.pump(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    h.router.go('/welcome/city');
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a link that opened the app waits until onboarding is done', (
    tester,
  ) async {
    final h = Harness();
    await h.pump(tester);
    final deal = demoDeals.first.id;
    h.router.go('/deal/$deal');
    await tester.pumpAndSettle();
    expect(find.byType(LanguageStep), findsOneWidget);

    h.router.go('/welcome/alerts');
    await tester.pumpAndSettle();
    await tapText(tester, 'Not now');
    expect(find.byType(DealDetailScreen), findsOneWidget);
  });

  group('city detection outcomes', () {
    for (final (outcome, message) in [
      (const LocationDenied(), 'No problem. Pick your city below.'),
      (
        const LocationServiceOff(),
        "Your phone's location is off. Pick your city below.",
      ),
      (
        const LocationUnavailable(),
        "We couldn't find your location. Pick your city below.",
      ),
      (
        const Located(25.12, 62.32), // Gwadar: no covered city near
        "Your location isn't near a city we cover yet. Pick one below.",
      ),
    ]) {
      testWidgets('${outcome.runtimeType}: says so; the list still works', (
        tester,
      ) async {
        final h = Harness(location: outcome);
        await h.pump(tester);
        await tapText(tester, 'Continue');
        await tapText(tester, 'Detect my city');
        expect(find.text(message), findsOneWidget);
        expect(h.preferences.cityId, isNull);
        await tapText(tester, 'Lahore');
        expect(h.preferences.cityId, lahoreId);
        expect(find.text('Local deals coming soon'), findsWidgets);
      });
    }

    testWidgets('blocked for good: offers the settings page', (tester) async {
      final h = Harness(location: const LocationDenied(permanently: true));
      await h.pump(tester);
      await tapText(tester, 'Continue');
      await tapText(tester, 'Detect my city');
      expect(
        find.textContaining('Location is off for this app'),
        findsOneWidget,
      );
      await tapText(tester, 'Open settings');
      expect(h.location.settingsOpened, 1);
    });
  });

  testWidgets('alerts blocked by Android: says so, offers settings, still '
      'finishes', (tester) async {
    final h = Harness(alerts: AlertPermission.permanentlyDenied);
    await h.pump(tester);
    h.router.go('/welcome/alerts');
    await tester.pumpAndSettle();
    await tapText(tester, 'Turn on alerts');
    expect(find.textContaining('Alerts are blocked'), findsOneWidget);
    expect(find.byType(AlertsStep), findsOneWidget);
    await tapText(tester, 'Open settings');
    expect(h.alerts.settingsOpened, 1);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('offline: the step says so and recovers on Try again', (
    tester,
  ) async {
    final backend = FlakyGateway();
    final h = Harness(backend: backend);
    await h.pump(tester);
    await tapText(tester, 'Continue');
    expect(find.text('Try again'), findsOneWidget);
    backend.fail = false;
    await tapText(tester, 'Try again');
    expect(find.text('Karachi'), findsOneWidget);
  });
}
