import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/features/brands/presentation/brand_screen.dart';
import 'package:sale_lagi_hai/features/categories/presentation/category_screen.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/domain/search_filters.dart';
import 'package:sale_lagi_hai/features/deals/presentation/paged_deal_list.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/search/application/search_providers.dart';
import 'package:sale_lagi_hai/features/search/presentation/filters_sheet.dart';
import 'package:sale_lagi_hai/features/search/presentation/search_screen.dart';

import '../onboarding/onboarding_harness.dart';

final _hbl = demoBanks.firstWhere((b) => b['slug'] == 'hbl')['id']! as String;
final _clifton =
    demoAreas.firstWhere((a) => a['slug'] == 'clifton')['id']! as String;

Future<Harness> _app(
  WidgetTester tester, {
  Locale locale = AppLocales.english,
  String at = '/search',
}) async {
  final h = Harness(
    saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
  );
  await h.pump(tester, device: locale);
  h.router.go(at);
  await tester.pumpAndSettle();
  return h;
}

/// Scrolls [finder] into view, then taps it.
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

/// Types into the search field and waits for the words to settle.
Future<void> _type(WidgetTester tester, String words) async {
  await tester.enterText(find.byType(TextField), words);
  await tester.pump(searchDebounce);
  await tester.pumpAndSettle();
}

SearchDeals _listOnScreen(WidgetTester tester) =>
    tester.widget<PagedDealSlivers>(find.byType(PagedDealSlivers)).query
        as SearchDeals;

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(FiltersSheet), matching: finder);

void main() {
  testWidgets('Explore opens Search; typing suggests the brand and lists '
      'deals; a suggestion opens its page', (tester) async {
    await _app(tester, at: '/explore');
    await _tap(tester, find.text('Search brands, food and card deals'));
    expect(find.byType(SearchScreen), findsOneWidget);
    await _type(tester, 'karahi');
    expect(find.text('Suggestions'), findsOneWidget);
    // The brand suggestion (its name is on deal cards too).
    expect(find.text('Brand'), findsOneWidget);
    expect(find.byType(DealCard), findsWidgets);
    expect(_listOnScreen(tester).query, 'karahi');
    await _tap(tester, find.text('Brand'));
    expect(find.byType(BrandScreen), findsOneWidget);
  });

  testWidgets('a submitted search is remembered on the phone; recent '
      'searches run again, and can be removed', (tester) async {
    final h = await _app(tester);
    await tester.enterText(find.byType(TextField), 'chai');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(h.container.read(recentSearchesProvider), ['chai']);

    await _tap(tester, find.byTooltip('Clear search'));
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Recent searches stay on this phone.'), findsOneWidget);
    await _tap(tester, find.text('chai'));
    expect(_listOnScreen(tester).query, 'chai');

    await _tap(tester, find.byTooltip('Clear search'));
    await _tap(tester, find.byTooltip('Remove “\u2068chai\u2069”'));
    expect(find.text('Recent searches'), findsNothing);
    expect(h.container.read(recentSearchesProvider), isEmpty);
  });

  testWidgets('before searching: popular categories open their page', (
    tester,
  ) async {
    await _app(tester);
    expect(find.text('Popular categories'), findsOneWidget);
    await _tap(tester, find.text('Food & Restaurants'));
    expect(find.byType(CategoryScreen), findsOneWidget);
  });

  testWidgets('the filters sheet applies on Show deals only; the button '
      'counts them', (tester) async {
    final h = await _app(tester);
    await _tap(tester, find.text('Filters'));
    await _tap(tester, _inSheet(find.text('HBL')));
    await _tap(tester, _inSheet(find.text('Ending soon')));
    // Closing without Show deals changes nothing.
    Navigator.of(tester.element(find.byType(FiltersSheet))).pop();
    await tester.pumpAndSettle();
    expect(h.container.read(searchProvider).filters, SearchFilters.none);

    await _tap(tester, find.text('Filters'));
    await _tap(tester, _inSheet(find.text('HBL')));
    await _tap(tester, _inSheet(find.text('25%+ off')));
    await _tap(tester, _inSheet(find.text('Show deals')));
    expect(find.byType(FiltersSheet), findsNothing);
    expect(
      _listOnScreen(tester).filters,
      SearchFilters(bankIds: [_hbl], minPercent: 25),
    );
    expect(find.text('Filters (2)'), findsOneWidget);
    // Filters alone search: HBL's 20% offer is below 25%.
    expect(find.textContaining('No deals match these filters'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, 'Clear filters'));
    expect(h.container.read(searchProvider).filters, SearchFilters.none);
    expect(find.text('Recent searches'), findsNothing);
    expect(find.text('Popular categories'), findsOneWidget);
  });

  testWidgets('the sheet: an area, then Anywhere and Any again', (
    tester,
  ) async {
    final h = await _app(tester);
    await _tap(tester, find.text('Filters'));
    await _tap(tester, _inSheet(find.text('Clifton')));
    await _tap(tester, _inSheet(find.text('50%+ off')));
    await _tap(tester, _inSheet(find.text('Show deals')));
    expect(
      h.container.read(searchProvider).filters,
      SearchFilters(areaId: _clifton, minPercent: 50),
    );
    await _tap(tester, find.text('Filters (2)'));
    await _tap(tester, _inSheet(find.text('Anywhere')));
    await _tap(tester, _inSheet(find.text('Any')));
    await _tap(tester, _inSheet(find.text('Show deals')));
    expect(h.container.read(searchProvider).filters, SearchFilters.none);
  });

  testWidgets('the sheet: lists that fail to load offer Try again', (
    tester,
  ) async {
    final backend = FlakyGateway();
    final h = Harness(
      saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
      backend: backend,
    );
    await h.pump(tester);
    h.router.go('/search');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Filters'));
    expect(_inSheet(find.text('Try again')), findsNWidgets(3));
    backend.fail = false;
    for (var i = 0; i < 3; i++) {
      await _tap(tester, _inSheet(find.text('Try again')));
    }
    expect(_inSheet(find.text('Clifton')), findsOneWidget);
    expect(_inSheet(find.text('HBL')), findsOneWidget);
    expect(_inSheet(find.text('Food & Restaurants')), findsOneWidget);
  });

  testWidgets('the quick chips: Ending soon and 50%+ off', (tester) async {
    await _app(tester);
    await _tap(tester, find.widgetWithText(FilterChip, '50%+ off'));
    expect(_listOnScreen(tester).filters, const SearchFilters(minPercent: 50));
    // The demo's only 50% deal is "up to 50%", which doesn't count.
    expect(find.textContaining('No deals match these filters'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilterChip, 'Ending soon'));
    expect(_listOnScreen(tester).filters.count, 2);
    await _tap(tester, find.widgetWithText(ActionChip, 'Clear filters'));
    expect(find.byType(PagedDealSlivers), findsNothing);
  });

  testWidgets('an area suggestion becomes the area filter', (tester) async {
    final h = await _app(tester);
    await _type(tester, 'clif');
    await _tap(tester, find.text('Clifton'));
    expect(h.container.read(searchProvider).filters.areaId, _clifton);
    expect(h.container.read(searchProvider).text, isEmpty);
    expect(find.text('Filters (1)'), findsOneWidget);
  });

  testWidgets('no match says so, with the words', (tester) async {
    await _app(tester);
    await _type(tester, 'zzqqxx');
    expect(find.textContaining('No deals for'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);
  });

  testWidgets('/search?q= starts with the words, cut to 100', (tester) async {
    final h = await _app(tester, at: '/search?q=karahi');
    expect(find.text('karahi'), findsOneWidget);
    expect(_listOnScreen(tester).query, 'karahi');
    expect(h.container.read(recentSearchesProvider), ['karahi']);
    h.router.go('/search?q=${'k' * 150}');
    await tester.pumpAndSettle();
    expect(h.container.read(searchProvider).query, hasLength(100));
  });

  for (final locale in AppLocales.supported) {
    for (final (name, setUp) in <(String, Future<void> Function(WidgetTester))>[
      (
        'start page',
        (tester) async {
          await tester.enterText(find.byType(TextField), 'karahi');
          await tester.testTextInput.receiveAction(TextInputAction.search);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), '');
          await tester.pump(searchDebounce);
          await tester.pumpAndSettle();
        },
      ),
      ('results', (tester) => _type(tester, 'karahi')),
      (
        'filters sheet',
        (tester) async {
          await tester.tap(find.byIcon(Icons.tune));
          await tester.pumpAndSettle();
        },
      ),
    ]) {
      testWidgets('${locale.languageCode} $name: guidelines, and 200% text '
          'without overflow', (tester) async {
        final handle = tester.ensureSemantics();
        await _app(tester, locale: locale);
        await setUp(tester);
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
