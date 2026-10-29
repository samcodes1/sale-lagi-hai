import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/brands/presentation/brand_screen.dart';
import 'package:sale_lagi_hai/features/categories/presentation/category_screen.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/deals/presentation/paged_deal_list.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../deals/deal_detail_screen_test.dart' show FakeLinks;
import '../onboarding/onboarding_harness.dart';

Future<(Harness, FakeLinks)> _app(
  WidgetTester tester, {
  Locale locale = AppLocales.english,
}) async {
  final links = FakeLinks();
  final h = Harness(
    saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
    overrides: [linkServiceProvider.overrideWithValue(links)],
  );
  await h.pump(tester, device: locale);
  return (h, links);
}

Future<void> _go(WidgetTester tester, Harness h, String location) async {
  h.router.go(location);
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view (lists and chip rows), then taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  for (final messenger in tester.stateList<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  )) {
    messenger.removeCurrentSnackBar();
  }
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// The query of the deal list on screen.
DealListQuery dealListQueryOnScreen(WidgetTester tester) =>
    tester.widget<PagedDealSlivers>(find.byType(PagedDealSlivers)).query;

void main() {
  testWidgets('Explore lists categories and brands; a category opens', (
    tester,
  ) async {
    final (h, _) = await _app(tester);
    await _go(tester, h, '/explore');
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Food & Restaurants'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Threads (Demo)'), 200);
    expect(find.text('Threads (Demo)'), findsOneWidget);
    await _tap(tester, find.text('Food & Restaurants'));
    expect(find.byType(CategoryScreen), findsOneWidget);
    expect(find.byType(DealCard), findsWidgets);
  });

  testWidgets('a brand row opens its page; Follow on the row works', (
    tester,
  ) async {
    final (h, _) = await _app(tester);
    await _go(tester, h, '/explore');
    final threads = brandBySlug('demo-threads')['id']! as String;
    await tester.scrollUntilVisible(find.text('Threads (Demo)'), 200);
    await _tap(tester, find.bySemanticsLabel('Follow Threads (Demo)'));
    expect(h.preferences.brandIds, contains(threads));
    expect(find.textContaining('Following Threads (Demo)'), findsOneWidget);
    await _tap(tester, find.text('Threads (Demo)'));
    expect(find.byType(BrandScreen), findsOneWidget);
    // The page shows the follow already made.
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('a category page: subcategory chips narrow the deals; Follow', (
    tester,
  ) async {
    final (h, _) = await _app(tester);
    await _go(tester, h, '/category/food-and-restaurants');
    // Count what the list holds, not what fits on screen.
    int shown() => h.container
        .read(dealListProvider(dealListQueryOnScreen(tester)))
        .requireValue
        .deals
        .length;
    final all = shown();
    expect(all, greaterThan(2));
    await _tap(tester, find.text('Burgers & Fast Food'));
    expect(shown(), allOf(greaterThan(0), lessThan(all)));
    await _tap(tester, find.text('All'));
    expect(shown(), all);

    await _tap(tester, find.text('Follow'));
    expect(h.preferences.categoryFollowIds, [
      categoryId('food-and-restaurants'),
    ]);
    expect(find.text('Following'), findsOneWidget);
  });

  testWidgets('a brand page: header, verified, website, deals', (tester) async {
    final (h, links) = await _app(tester);
    await _go(tester, h, '/brand/demo-burger-point');
    expect(find.text('Burger Point (Demo)'), findsWidgets);
    expect(find.text('Verified brand'), findsOneWidget);
    expect(find.byType(DealCard), findsWidgets);
    await _tap(tester, find.byType(DealCard));
    expect(find.byType(DealDetailScreen), findsOneWidget);
    expect(links.calls, isEmpty);
  });

  testWidgets('a brand with no live deals says so', (tester) async {
    final (h, _) = await _app(tester);
    await _go(tester, h, '/brand/demo-glow-salon');
    // Glow Salon's only deal is local to Karachi; nationwide view hides it.
    await h.container.read(preferencesProvider.notifier).setCity(null);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No live deals from this brand'),
      findsOneWidget,
    );
  });

  testWidgets('unknown brands and categories show Not found', (tester) async {
    final (h, _) = await _app(tester);
    await _go(tester, h, '/brand/not-a-real-brand');
    expect(find.byType(ErrorView), findsOneWidget);
    await _go(tester, h, '/category/not-a-real-category');
    expect(find.byType(ErrorView), findsOneWidget);
  });

  for (final locale in AppLocales.supported) {
    for (final page in [
      '/explore',
      '/category/food-and-restaurants',
      '/brand/demo-karahi-house',
    ]) {
      testWidgets('${locale.languageCode} $page: guidelines, and 200% text '
          'without overflow', (tester) async {
        final handle = tester.ensureSemantics();
        final (h, _) = await _app(tester, locale: locale);
        await _go(tester, h, page);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        tester.view.physicalSize = const Size(360, 800) * 2;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
