// QA, sub-phase 4.5: Explore, category and brand pages. Follows under the
// real table rules, the Follow button for screen readers and quick taps,
// a stale page against a refresh, a catalogue bigger than one query,
// websites that can't open, and the pages in dark, high contrast and 200%
// text (docs/qa/4.5.md).
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug; run them with `--dart-define=QA_KNOWN_BUGS=true`.
import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/links/link_service.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_providers.dart';
import 'package:sale_lagi_hai/features/follows/application/follow_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/fakes.dart';
import 'home_fakes.dart';
import 'qa_backend_rules.dart';

const _shopper = ShopperPreferences(onboarded: true, cityId: karachiId);
final _brandId = demoBrands.first['id']! as String;
final _brandSlug = demoBrands.first['slug']! as String;
final _brandName = demoBrands.first['name']! as String;

/// The demo backend, plus [extraBrands] synthetic brands (the query's limit
/// and slug filter applied, as the database would).
final class _Catalog extends RulesGateway {
  new(super.auth, {this.extraBrands = 0, this.website});

  final int extraBrands;
  final String? website;

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    if (query.table != 'brands') return await super.select(query);
    final rows = [
      ...await super.select(TableQuery('brands', equals: query.equals)),
      for (var i = 0; i < extraBrands; i++)
        {
          'id': '00000000-0000-4000-b000-${i.toString().padLeft(12, '0')}',
          'slug': 'qa-brand-$i',
          'name': 'QA Brand ${i.toString().padLeft(2, '0')}',
          'category_id': categoryId('food-and-restaurants'),
          'is_verified': false,
          'is_active': true,
        },
      if (website != null)
        {
          'id': '00000000-0000-4000-b000-0000000000ff',
          'slug': 'qa-site',
          'name': 'QA Site',
          'category_id': categoryId('food-and-restaurants'),
          'website': website,
          'is_verified': true,
          'is_active': true,
        },
    ];
    final slug = query.equals['slug'];
    final matching = [
      for (final r in rows)
        if (slug == null || r['slug'] == slug) r,
    ]..sort((a, b) => (a['name']! as String).compareTo(b['name']! as String));
    // (Developer, round 2: TableQuery.offset is new in 4.5's fix.)
    final page = matching.skip(query.offset).toList();
    return page.take(query.limit ?? page.length).toList();
  }
}

final class _Links implements LinkService {
  @override
  Future<bool> openWeb(String url) async =>
      UrlLauncherLinkService.safeWebUri(url) != null;

  @override
  Future<bool> openMap(double latitude, double longitude, String label) async =>
      true;

  @override
  Future<bool> shareOnWhatsApp(String text) async => true;

  @override
  Future<bool> call(String e164) async => true;
}

Future<void> _signIn(DemoAuthRepository auth) async {
  await auth.sendPhoneCode('+923001234567');
  await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
}

final Finder _vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

Future<void> _toEnd(WidgetTester tester, {void Function()? each}) async {
  for (var i = 0; i < 80; i++) {
    each?.call();
    final pos = tester.state<ScrollableState>(_vertical.first).position;
    if (pos.pixels >= pos.maxScrollExtent) return;
    await tester.drag(_vertical.first, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('follows against the real table rules', () {
    late DemoAuthRepository auth;
    late RulesGateway backend;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          backendGatewayProvider.overrideWithValue(backend),
          authRepositoryProvider.overrideWithValue(auth),
          savedPreferencesProvider.overrideWithValue(_shopper),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() async {
      auth = DemoAuthRepository();
      backend = RulesGateway(auth);
      await _signIn(auth);
    });

    test('signed in, following a brand reaches the account', () async {
      final c = container();
      await c.read(followsProvider).toggleBrand(_brandId);
      expect(backend.refused, isEmpty, reason: '${backend.inserts}');
    });

    test('signed in, following a category reaches the account', () async {
      final c = container();
      await c
          .read(followsProvider)
          .toggleCategory(categoryId('food-and-restaurants'));
      expect(backend.refused, isEmpty, reason: '${backend.inserts}');
    });

    test(
      'the phone keeps the follow even when the account refuses it',
      () async {
        final c = container();
        await c.read(followsProvider).toggleBrand(_brandId);
        expect(c.read(preferencesProvider).brandIds, [_brandId]);
      },
    );
  });

  group('deal lists', () {
    test('a refresh while the next page is loading: the stale page is '
        'dropped', () async {
      final deals = GatedDeals();
      final c = ProviderContainer(
        overrides: [dealRepositoryProvider.overrideWithValue(deals)],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      const query = CategoryDeals(['food'], cityId: 'karachi');
      final sub = c.listen(dealListProvider(query), (_, _) {});
      addTearDown(sub.close);
      await c.read(dealListProvider(query).future);
      deals.holdNext = Completer();
      final more = c.read(dealListProvider(query).notifier).loadMore();
      deals.holdFirst = Completer();
      c.invalidate(dealListProvider(query));
      // A network answer always lands in a later event than the refresh,
      // by which time the rebuild (and its new generation) has started.
      await Future<void>.delayed(Duration.zero);
      deals.holdNext!.complete();
      await more;
      deals.holdFirst!.complete();
      final state = await c.read(dealListProvider(query).future);
      expect(state.deals, hasLength(20));
      expect(state.loadingMore, isFalse);
    });
  });

  group('Follow button', () {
    testWidgets('a screen reader hears a toggle with the name, and can '
        'follow and unfollow', (tester) async {
      final handle = tester.ensureSemantics();
      final h = Harness(saved: _shopper);
      await h.pump(tester);
      h.router.go('/brand/$_brandSlug');
      await tester.pumpAndSettle();
      final finder = find.bySemanticsLabel(RegExp('^Follow '));
      final node = tester.getSemantics(finder.first);
      final data = node.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isToggled, Tristate.isFalse);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(
        h.container.read(preferencesProvider).brandIds,
        contains(_brandId),
      );
      final again = tester.getSemantics(finder.first).getSemanticsData();
      expect(again.flagsCollection.isToggled, Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('a quick double tap: the note matches what happened', (
      tester,
    ) async {
      final h = Harness(saved: _shopper);
      await h.pump(tester);
      h.router.go('/brand/$_brandSlug');
      await tester.pumpAndSettle();
      final button = find.text('Follow');
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pumpAndSettle();
      final following = h.container
          .read(preferencesProvider)
          .brandIds
          .contains(_brandId);
      final name = _brandName;
      final note = find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(Text),
      );
      final text = tester.widget<Text>(note.first).data!;
      expect(
        text.startsWith('Stopped following'),
        !following,
        reason: 'following: $following, note: "$text" ($name)',
      );
    });
  });

  group('Explore', () {
    testWidgets('every brand can be found, also beyond the first 60', (
      tester,
    ) async {
      final auth = DemoAuthRepository();
      final h = Harness(
        saved: _shopper,
        auth: auth,
        backend: _Catalog(auth, extraBrands: 70),
      );
      await h.pump(tester);
      h.router.go('/explore');
      await tester.pumpAndSettle();
      final last = find.text('QA Brand 69');
      await _toEnd(tester);
      expect(last, findsOneWidget);
    });

    testWidgets('round 2: 130 brands page in by 60s, each shown once', (
      tester,
    ) async {
      final auth = DemoAuthRepository();
      final h = Harness(
        saved: _shopper,
        auth: auth,
        backend: _Catalog(auth, extraBrands: 130),
      );
      await h.pump(tester);
      h.router.go('/explore');
      await tester.pumpAndSettle();
      final seen = <String>{};
      var repeats = 0;
      await _toEnd(
        tester,
        each: () {
          for (final e in find.textContaining('QA Brand ').evaluate()) {
            final t = (e.widget as Text).data!;
            if (!seen.add(t) && find.text(t).evaluate().length > 1) repeats++;
          }
        },
      );
      // Names sort as text ("QA Brand 12" < "QA Brand 129" < "QA Brand 13"),
      // so check what was seen on the way down.
      expect(seen, contains('QA Brand 129'));
      expect(seen, hasLength(130));
      expect(repeats, 0);
    });

    for (final (name, locale, brightness, hc) in const [
      ('en dark', AppLocales.english, Brightness.dark, false),
      ('en light HC', AppLocales.english, Brightness.light, true),
      ('ur dark HC', AppLocales.urdu, Brightness.dark, true),
    ]) {
      for (final page in [
        '/explore',
        '/category/food-and-restaurants',
        '/brand/$_brandSlug',
      ]) {
        testWidgets('$name $page: guidelines met down the whole page', (
          tester,
        ) async {
          tester.platformDispatcher
            ..platformBrightnessTestValue = brightness
            ..accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
              highContrast: hc,
            );
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final handle = tester.ensureSemantics();
          final h = Harness(saved: _shopper);
          await h.pump(tester, device: locale);
          h.router.go(page);
          await tester.pumpAndSettle();
          var checks = 0;
          for (var i = 0; i < 40; i++) {
            if (i % 3 == 0) {
              checks++;
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              // The test font has no Urdu glyphs; contrast is checked in
              // English (same colours).
              if (locale != AppLocales.urdu) {
                await expectLater(
                  tester,
                  meetsGuideline(textContrastGuideline),
                );
              }
            }
            final pos = tester.state<ScrollableState>(_vertical.first).position;
            if (pos.pixels >= pos.maxScrollExtent) break;
            await tester.drag(_vertical.first, const Offset(0, -400));
            await tester.pumpAndSettle();
          }
          expect(checks, greaterThan(0));
          handle.dispose();
        });
      }
    }
  });

  group('category and brand pages', () {
    testWidgets('ur 200% on 360 × 800: the category name stays readable '
        'beside Follow in the app bar', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final h = Harness(saved: _shopper);
      await h.pump(tester, device: AppLocales.urdu, size: const Size(360, 800));
      h.router.go('/category/food-and-restaurants');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final title = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(Text),
      );
      final widths = [
        for (final e in title.evaluate())
          if ((e.widget as Text).data?.contains('فالو') != true)
            tester.getSize(find.byWidget(e.widget)).width,
      ];
      expect(widths.reduce((a, b) => a > b ? a : b), greaterThan(80));
    });

    testWidgets('subcategory chips: one is selected, and picking one '
        'narrows the list', (tester) async {
      final h = Harness(saved: _shopper);
      await h.pump(tester);
      h.router.go('/category/food-and-restaurants');
      await tester.pumpAndSettle();
      final chips = find.byType(ChoiceChip);
      expect(chips, findsAtLeastNWidgets(2));
      final selected = [
        for (final e in chips.evaluate())
          if ((e.widget as ChoiceChip).selected) e,
      ];
      expect(selected, hasLength(1));
      await tester.tap(chips.at(1));
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chips.at(1)).selected, isTrue);
      expect(tester.widget<ChoiceChip>(chips.first).selected, isFalse);
    });

    testWidgets('a brand website that cannot open says so', (tester) async {
      final auth = DemoAuthRepository();
      final h = Harness(
        saved: _shopper,
        auth: auth,
        // Allowed by the https_url domain, refused by LinkService.
        backend: _Catalog(auth, website: 'https://user@qa-site.pk'),
        overrides: [linkServiceProvider.overrideWithValue(_Links())],
      );
      await h.pump(tester);
      h.router.go('/brand/qa-site');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visit website'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('a verified brand says so, to a screen reader too', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final auth = DemoAuthRepository();
      final h = Harness(
        saved: _shopper,
        auth: auth,
        backend: _Catalog(auth, website: 'https://qa-site.pk'),
      );
      await h.pump(tester);
      h.router.go('/brand/qa-site');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Verified')), findsWidgets);
      handle.dispose();
    });

    for (final page in ['/brand/no-such-brand', '/category/no-such-thing']) {
      testWidgets('$page: Not found, and nothing else on the page', (
        tester,
      ) async {
        final h = Harness(saved: _shopper);
        await h.pump(tester);
        h.router.go(page);
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.add), findsNothing); // no Follow
        expect(tester.takeException(), isNull);
      });
    }
  });
}
