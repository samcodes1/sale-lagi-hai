// QA, sub-phase 4.3: Home on the real app (demo backend or a scripted
// repository): offline copies, Near me, paging under fast scrolling, pull
// to refresh, the city sheet, headings and card semantics, and the
// distance labels (docs/qa/4.3.md).
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug; run them with `--dart-define=QA_KNOWN_BUGS=true`.
import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_providers.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/l10n/gen/app_localizations.dart';

import '../features/onboarding/onboarding_harness.dart';
import 'home_fakes.dart';

const _shopper = ShopperPreferences(onboarded: true, cityId: karachiId);
const _end = "You've seen all the new deals. Check back soon.";

final Finder _vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

Future<void> _scrollTo(WidgetTester tester, Finder f, {int max = 200}) async {
  for (var i = 0; f.hitTestable().evaluate().isEmpty; i++) {
    if (i == max) fail('never reached $f');
    await tester.drag(_vertical.first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
}

List<String> _readingOrder(WidgetTester tester, {bool headersOnly = false}) {
  final out = <String>[];
  void walk(SemanticsNode node) {
    final d = node.getSemanticsData();
    final isHeader = d.flagsCollection.isHeader;
    if (d.label.isNotEmpty && !node.isInvisible && (!headersOnly || isHeader)) {
      out.add(d.label);
    }
    node
        .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
        .forEach(walk);
  }

  walk(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return out;
}

void main() {
  group('offline copy of For you', () {
    testWidgets('a saved first page does not claim to be the end of the '
        'list', (tester) async {
      final deals = GatedDeals();
      final first = Harness(
        saved: _shopper,
        overrides: [dealRepositoryProvider.overrideWithValue(deals)],
      );
      await first.pump(tester);
      deals.offline = true;
      final second = Harness(
        saved: _shopper,
        store: first.store,
        network: NetworkStatus.offline,
        overrides: [dealRepositoryProvider.overrideWithValue(deals)],
      );
      await second.pump(tester);
      expect(find.byType(OfflineBanner), findsOneWidget);
      // Scroll to the bottom of the saved page.
      await _scrollTo(tester, find.text('Deal $karachiId 19'), max: 100);
      await tester.drag(_vertical.first, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(
        find.text(_end),
        findsNothing,
        reason: 'only the first page was saved; more deals exist',
      );
    });
  });

  group('near me', () {
    for (final (name, outcome, message, settings) in [
      (
        'denied',
        const LocationDenied(),
        "We couldn't get your location. Pick your city to see local deals.",
        false,
      ),
      (
        'blocked',
        const LocationDenied(permanently: true),
        'Location is off for this app. Turn it on in settings, or pick your '
            'city.',
        true,
      ),
      (
        'service off',
        const LocationServiceOff(),
        "We couldn't get your location. Pick your city to see local deals.",
        false,
      ),
      (
        'unavailable',
        const LocationUnavailable(),
        "We couldn't get your location. Pick your city to see local deals.",
        false,
      ),
    ]) {
      testWidgets('$name: says so, and offers the right next step', (
        tester,
      ) async {
        final h = Harness(saved: _shopper, location: outcome);
        await h.pump(tester);
        await _scrollTo(tester, find.text('Show deals near me'));
        await tester.tap(find.text('Show deals near me'));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(h.location.asked, 1);
        if (settings) {
          await tester.tap(find.text('Open settings'));
          expect(h.location.settingsOpened, 1);
        } else {
          expect(find.text('Show deals near me'), findsOneWidget);
        }
      });
    }

    testWidgets('pull to refresh never asks for location', (tester) async {
      final h = Harness(saved: _shopper);
      await h.pump(tester);
      await tester.fling(_vertical.first, const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(h.location.asked, 0);
    });

    testWidgets('after the account is deleted (onboarding reset), Near you '
        'no longer shows the earlier results', (tester) async {
      final h = Harness(saved: _shopper);
      await h.pump(tester);
      final button = find.text('Show deals near me');
      await _scrollTo(tester, button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(button, findsNothing);
      // What _forgetThisPhone does after the server deleted the account.
      await h.store.clear();
      await h.container.read(preferencesProvider.notifier).reset();
      await tester.pumpAndSettle();
      await tapText(tester, 'Continue');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Skip');
      await tapText(tester, 'Not now');
      expect(find.byType(HomeScreen), findsOneWidget);
      await _scrollTo(tester, find.text('Near you'));
      await tester.pumpAndSettle();
      expect(
        find.text('Show deals near me'),
        findsOneWidget,
        reason: "the deleted account's location-based results stay on screen",
      );
    });
  });

  group('paging under fast scrolling', () {
    testWidgets('flinging to the end: each page is asked for once, and '
        'the list settles', (tester) async {
      final deals = GatedDeals();
      final h = Harness(
        saved: _shopper,
        overrides: [dealRepositoryProvider.overrideWithValue(deals)],
      );
      await h.pump(tester);
      for (var i = 0; i < 80 && find.text(_end).evaluate().isEmpty; i++) {
        await tester.fling(_vertical.first, const Offset(0, -3000), 8000);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text(_end));
      final feed = deals.calls.where((c) => c.startsWith('feed'));
      expect(feed.toSet(), hasLength(feed.length), reason: '$feed');
      // 100 deals in pages of 20: 5 full pages, then one empty page (a
      // full page always has a next cursor).
      expect(feed, hasLength(6));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('after a failed page, scrolling around does not retry on '
        'its own', (tester) async {
      final deals = GatedDeals();
      final h = Harness(
        saved: _shopper,
        overrides: [dealRepositoryProvider.overrideWithValue(deals)],
      );
      await h.pump(tester);
      deals.offline = true;
      await _scrollTo(tester, find.byType(InlineErrorBanner), max: 300);
      final before = deals.calls.length;
      for (var i = 0; i < 5; i++) {
        await tester.drag(_vertical.first, const Offset(0, 600));
        await tester.pumpAndSettle();
        await tester.drag(_vertical.first, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(deals.calls.length, before);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('pull to refresh keeps the cards on screen while it '
        'reloads (no flash to skeletons)', (tester) async {
      final deals = GatedDeals();
      final h = Harness(
        saved: _shopper,
        overrides: [dealRepositoryProvider.overrideWithValue(deals)],
      );
      await h.pump(tester);
      deals.holdFirst = Completer();
      await tester.fling(_vertical.first, const Offset(0, 400), 1000);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DealCardSkeleton), findsNothing);
      expect(find.byType(DealCard), findsWidgets);
      deals.holdFirst!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('city sheet', () {
    for (final (name, locale, brightness, scale, size) in const [
      ('en light', AppLocales.english, Brightness.light, 1.0, Size(412, 915)),
      ('ur dark', AppLocales.urdu, Brightness.dark, 1.0, Size(412, 915)),
      ('en 200%', AppLocales.english, Brightness.light, 2.0, Size(360, 800)),
      ('ur 200%', AppLocales.urdu, Brightness.light, 2.0, Size(360, 800)),
    ]) {
      testWidgets('$name: every city reachable, guidelines met, the current '
          'one selected', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final handle = tester.ensureSemantics();
        final h = Harness(saved: _shopper);
        await h.pump(tester, device: locale, size: size);
        await tester.tap(find.byIcon(Icons.arrow_drop_down));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final tiles = find.byType(ListTile);
        expect(tiles, findsAtLeastNWidgets(4));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        if (scale == 1) {
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
        final selected = tiles.evaluate().where(
          (e) => (e.widget as ListTile).selected,
        );
        expect(selected, hasLength(1));
        // The last city can be reached and picked.
        final last = tiles.last;
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        expect(last.hitTestable(), findsOneWidget);
        final bar = find.byType(NavigationBar);
        if (bar.evaluate().isNotEmpty) {
          expect(
            tester.getRect(last).bottom,
            lessThanOrEqualTo(tester.getRect(bar).top + 0.5),
          );
        }
        await tester.tap(last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(h.container.read(preferencesProvider).cityId, isNot(karachiId));
        handle.dispose();
      });
    }
  });

  group('screen reader', () {
    for (final locale in [AppLocales.english, AppLocales.urdu]) {
      testWidgets('${locale.languageCode}: a screen reader can activate the '
          'city button, and it opens the city sheet', (tester) async {
        final handle = tester.ensureSemantics();
        final h = Harness(saved: _shopper);
        await h.pump(tester, device: locale);
        final city = locale == AppLocales.urdu ? 'کراچی' : 'Karachi';
        final label = lookupAppLocalizations(locale).homeCityLabel(city);
        final node = tester.getSemantics(find.bySemanticsLabel(label).first);
        final data = node.getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(
          data.hasAction(SemanticsAction.tap),
          isTrue,
          reason:
              'TalkBack double-tap sends this action; without it the '
              'button does nothing',
        );
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(find.byType(ListTile), findsAtLeastNWidgets(4));
        expect(h.location.asked, 0);
        handle.dispose();
      });
    }

    testWidgets('row headings come in screen order', (tester) async {
      final handle = tester.ensureSemantics();
      final h = Harness(saved: _shopper);
      await h.pump(tester, size: const Size(412, 4000));
      final headings = _readingOrder(tester, headersOnly: true);
      // The app bar title (the city button) is a heading too.
      expect(headings.first, 'Deals in Karachi');
      expect(headings.skip(1), [
        'Featured',
        'Trending today',
        'Near you',
        'Ending soon',
        'For you',
      ]);
      expect(h.location.asked, 0);
      handle.dispose();
    });

    for (final locale in [AppLocales.english, AppLocales.urdu]) {
      testWidgets('${locale.languageCode}: a card is one button that says '
          'brand, title and offer', (tester) async {
        final handle = tester.ensureSemantics();
        final h = Harness(saved: _shopper);
        await h.pump(tester, device: locale);
        final card = find.byType(DealCard).first;
        final node = tester.getSemantics(
          find
              .descendant(
                of: card,
                matching: find.byWidgetPredicate(
                  (w) => w is Semantics && (w.properties.button ?? false),
                ),
              )
              .first,
        );
        final data = node.getSemanticsData();
        final shown = tester.widget<DealCard>(card).deal;
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.label, contains(shown.title));
        expect(data.label, contains(shown.brandName));
        handle.dispose();
        expect(h.location.asked, 0);
      });
    }

    for (final (name, locale, brightness) in const [
      ('en light HC', AppLocales.english, Brightness.light),
      ('ur dark HC', AppLocales.urdu, Brightness.dark),
    ]) {
      testWidgets('$name: guidelines met down the whole list', (tester) async {
        tester.platformDispatcher
          ..platformBrightnessTestValue = brightness
          ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
            highContrast: true,
          );
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final handle = tester.ensureSemantics();
        final h = Harness(saved: _shopper);
        await h.pump(tester, device: locale);
        var scrolls = 0;
        for (var i = 0; i < 60; i++) {
          if (i % 4 == 0) {
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          }
          final pos = tester.state<ScrollableState>(_vertical.first).position;
          if (pos.pixels >= pos.maxScrollExtent) break;
          await tester.drag(_vertical.first, const Offset(0, -400));
          await tester.pumpAndSettle();
          scrolls++;
        }
        expect(scrolls, greaterThan(5));
        handle.dispose();
      });
    }

    testWidgets('offline dark: banner, saved-copy ages and errors meet the '
        'guidelines', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final handle = tester.ensureSemantics();
      final deals = GatedDeals();
      final first = Harness(
        saved: _shopper,
        overrides: [dealRepositoryProvider.overrideWithValue(deals)],
      );
      await first.pump(tester);
      deals.offline = true;
      final second = Harness(
        saved: _shopper,
        store: first.store,
        network: NetworkStatus.offline,
        overrides: [dealRepositoryProvider.overrideWithValue(deals)],
      );
      await second.pump(tester);
      expect(find.byType(OfflineBanner), findsOneWidget);
      expect(find.textContaining('Updated'), findsWidgets);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('distance labels', () {
    final en = AppFormatters(
      lookupAppLocalizations(AppLocales.english),
      AppLocales.english,
    );
    final ur = AppFormatters(
      lookupAppLocalizations(AppLocales.urdu),
      AppLocales.urdu,
    );
    for (final (m, expected) in [
      (0, '50 m'),
      (24, '50 m'),
      (340, '350 m'),
      (949, '950 m'),
      (1000, '1 km'),
      (1049, '1 km'),
      (1250, '1.3 km'),
      (9940, '9.9 km'),
      (9960, '10 km'),
      (14400, '14 km'),
      (123456, '123 km'),
    ]) {
      test('$m m → $expected', () => expect(en.distance(m), expected));
    }

    test('975 m shows as 1 km, not "1,000 m"', () {
      expect(en.distance(975), '1 km');
      expect(en.distance(999), '1 km');
    });

    test('Urdu units, with the number isolated', () {
      expect(ur.distance(350), '\u2066350\u2069 میٹر');
      expect(ur.distance(1250), '\u20661.3\u2069 کلومیٹر');
      final digits = AppFormatters(
        lookupAppLocalizations(AppLocales.urdu),
        AppLocales.urdu,
        urduDigits: true,
      );
      expect(digits.distance(14400), contains('۱۴'));
    });
  });
}
