import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_providers.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../onboarding/onboarding_harness.dart';
import 'fake_deals.dart';

const _karachiShopper = ShopperPreferences(onboarded: true, cityId: karachiId);

/// The home list itself (the carousels scroll sideways).
final Finder _vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

/// Text in the app bar (the city button).
Finder _inAppBar(String text) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(text));

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, {
  int maxScrolls = 100,
}) async {
  // Until it can be tapped, not just built: built includes the cache area
  // under the navigation bar.
  for (var i = 0; finder.hitTestable().evaluate().isEmpty; i++) {
    if (i == maxScrolls) fail('never reached $finder');
    await tester.drag(_vertical.first, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('home shows the rows of the chosen city, from the demo data', (
    tester,
  ) async {
    final h = Harness(saved: _karachiShopper);
    await h.pump(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(_inAppBar('Karachi'), findsOneWidget);
    // "Featured" is also the label on paid cards.
    expect(find.text('Featured'), findsWidgets);
    for (final title in ['Trending today', 'Near you', 'For you']) {
      await _scrollTo(tester, find.text(title));
      expect(find.text(title), findsOneWidget);
    }
    expect(find.byType(DealCard), findsWidgets);
    // Nothing asks for location until the button is tapped.
    expect(h.location.asked, 0);
  });

  testWidgets('a card opens its deal', (tester) async {
    final h = Harness(saved: _karachiShopper);
    await h.pump(tester);
    await _scrollTo(tester, find.text('For you'));
    await _scrollTo(tester, find.byType(DealCard));
    await tester.tap(find.byType(DealCard).hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.byType(DealDetailScreen), findsOneWidget);
  });

  testWidgets('changing the city reloads the rows for it', (tester) async {
    final h = Harness(saved: _karachiShopper);
    await h.pump(tester);
    await tester.tap(_inAppBar('Karachi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lahore').last);
    await tester.pumpAndSettle();
    expect(h.preferences.cityId, lahoreId);
    expect(_inAppBar('Lahore'), findsOneWidget);
    await tester.tap(_inAppBar('Lahore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Pakistan').last);
    await tester.pumpAndSettle();
    expect(h.preferences.cityId, isNull);
  });

  testWidgets('near you: asks on tap, then shows deals with distances', (
    tester,
  ) async {
    final h = Harness(
      saved: _karachiShopper,
      location: const Located(24.8150, 67.0310), // Clifton
    );
    await h.pump(tester);
    await _scrollTo(tester, find.text('Show deals near me'));
    await tester.tap(find.text('Show deals near me'));
    await tester.pumpAndSettle();
    expect(h.location.asked, 1);
    expect(find.textContaining(' m'), findsWidgets);
  });

  testWidgets('near you: blocked location offers settings', (tester) async {
    final h = Harness(
      saved: _karachiShopper,
      location: const LocationDenied(permanently: true),
    );
    await h.pump(tester);
    await _scrollTo(tester, find.text('Show deals near me'));
    await tester.tap(find.text('Show deals near me'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Location is off for this app'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    expect(h.location.settingsOpened, 1);
  });

  testWidgets('for you loads the next page near the end, then says it is '
      'the end', (tester) async {
    final deals = FakeDeals(now: DateTime.now().toUtc());
    final h = Harness(
      saved: _karachiShopper,
      overrides: [dealRepositoryProvider.overrideWithValue(deals)],
    );
    await h.pump(tester);
    final end = find.text("You've seen all the new deals. Check back soon.");
    await _scrollTo(tester, end, maxScrolls: 400);
    expect(end, findsOneWidget);
    expect(deals.calls.where((c) => c.startsWith('feed')), hasLength(3));
  });

  testWidgets('a failed page shows a retry row, not a full-screen error', (
    tester,
  ) async {
    final deals = FakeDeals(now: DateTime.now().toUtc())
      ..feedCallsBeforeFailing = 1;
    final h = Harness(
      saved: _karachiShopper,
      overrides: [dealRepositoryProvider.overrideWithValue(deals)],
    );
    await h.pump(tester);
    await _scrollTo(tester, find.byType(InlineErrorBanner), maxScrolls: 200);
    expect(find.byType(DealCard), findsWidgets);
    deals.feedCallsBeforeFailing = null;
    await tester.tap(
      find.descendant(
        of: find.byType(InlineErrorBanner),
        matching: find.text('Try again'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InlineErrorBanner), findsNothing);
  });

  testWidgets('offline: the banner, and the saved rows with their age', (
    tester,
  ) async {
    final deals = FakeDeals(now: DateTime.now().toUtc());
    final first = Harness(
      saved: _karachiShopper,
      overrides: [dealRepositoryProvider.overrideWithValue(deals)],
    );
    await first.pump(tester);
    // A later launch with no network, on the same storage.
    deals.failWith = const OfflineFailure();
    final second = Harness(
      saved: _karachiShopper,
      store: first.store,
      network: NetworkStatus.offline,
      overrides: [dealRepositoryProvider.overrideWithValue(deals)],
    );
    await second.pump(tester);
    expect(find.byType(OfflineBanner), findsOneWidget);
    expect(find.textContaining('Updated just now'), findsWidgets);
    expect(find.byType(DealCard), findsWidgets);
  });

  testWidgets('offline with nothing saved: a clear error with Try again', (
    tester,
  ) async {
    final deals = FakeDeals(now: DateTime.now().toUtc())
      ..failWith = const OfflineFailure();
    final h = Harness(
      saved: _karachiShopper,
      overrides: [dealRepositoryProvider.overrideWithValue(deals)],
    );
    await h.pump(tester);
    await _scrollTo(tester, find.byType(ErrorView));
    expect(find.byType(ErrorView), findsOneWidget);
    deals.failWith = null;
    await tester.tap(
      find.descendant(
        of: find.byType(ErrorView),
        matching: find.text('Try again'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ErrorView), findsNothing);
  });

  testWidgets('pull to refresh reloads every row', (tester) async {
    final deals = FakeDeals(now: DateTime.now().toUtc());
    final h = Harness(
      saved: _karachiShopper,
      overrides: [dealRepositoryProvider.overrideWithValue(deals)],
    );
    await h.pump(tester);
    deals.calls.clear();
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(
      deals.calls,
      containsAll(['featured', 'trending', 'ending', 'feed first']),
    );
  });
}
