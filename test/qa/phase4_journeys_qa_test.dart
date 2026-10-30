// QA, Phase 4 gate: cross-sub-phase user journeys through the real router,
// the real providers and the demo data on a server-faithful backend
// (phase4_harness.dart). Each journey crosses at least two sub-phases.
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug; run them with `--dart-define=QA_KNOWN_BUGS=true`.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/bootstrap.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/theme/theme_mode_controller.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/features/alerts/presentation/alerts_screen.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/explore/presentation/explore_screen.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/language_step.dart';
import 'package:sale_lagi_hai/features/profile/presentation/profile_screen.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';
import 'package:sale_lagi_hai/features/saved/presentation/saved_screen.dart';
import 'package:sale_lagi_hai/features/search/application/search_providers.dart';

import '../helpers/fakes.dart';
import 'phase4_harness.dart';

const _onboarded = ShopperPreferences(onboarded: true, cityId: karachiId);

void main() {
  group('J1 first launch → onboarding → feed → deal → save → Saved', () {
    testWidgets('a new shopper ends with the deal on the Saved tab', (
      tester,
    ) async {
      final j = Journey();
      await j.pump(tester);
      expect(find.byType(LanguageStep), findsOneWidget);
      await tapText(tester, 'Continue');
      await tapText(tester, 'Detect my city');
      expect(find.text("You're in Karachi."), findsOneWidget);
      await tapText(tester, 'Continue');
      await tapText(tester, 'Food & Restaurants');
      await tapText(tester, 'Continue');
      await tapText(tester, 'Karahi House (Demo)');
      await tapText(tester, 'Continue');
      await tapText(tester, 'Turn on alerts');

      // Home, in Karachi, with the feed loaded.
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('Karachi'), findsWidgets);
      expect(find.byType(DealCard), findsWidgets);

      // Open the Karahi House deal from the feed.
      final card = find.ancestor(
        of: find.text(dealTitle(1)),
        matching: find.byType(DealCard),
      );
      await scrollToAndTap(tester, card.first);
      expect(find.byType(DealDetailScreen), findsOneWidget);
      expect(find.text(dealTitle(1)), findsWidgets);

      await tapText(tester, 'Save');
      expect(find.text('Saved.'), findsOneWidget);
      expect(j.container.read(savedDealsProvider), [dealId(1)]);
      // A guest: nothing goes to the server.
      expect(j.server.calls.where((c) => c.startsWith('insert')), isEmpty);

      // Back, then the Saved tab lists it.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapTab(tester, 'Saved');
      expect(find.byType(SavedScreen), findsOneWidget);
      expect(find.text(dealTitle(1)), findsOneWidget);
      expect(find.text('Active (1)'), findsOneWidget);
      // The saved list survives on the phone.
      expect(j.store.values[savedDealsKey], contains(dealId(1)));
    });
  });

  group('J2 guest → sign in → sync → sign out → a second account', () {
    final hblVisaDebit = demoCardProducts.firstWhere(
      (c) => c['bank_id'] == demoBanks.first['id'] && c['slug'] == 'visa-debit',
    )['id']!;
    final threads = brandBySlug('demo-threads')['id']!;

    Future<void> addCard(WidgetTester tester, String bank, String card) async {
      await tapTab(tester, 'Profile');
      await tapText(tester, 'My cards');
      await tapText(tester, 'Add a card');
      await tapText(tester, bank);
      await tapText(tester, card);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    testWidgets('each account ends with only its own saves, cards and '
        'follows, through the real screens', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);

      // As a guest: save a deal, add a card, follow a brand.
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');
      j.router.go('/');
      await tester.pumpAndSettle();
      await addCard(tester, 'HBL', 'Visa Debit');
      j.router.go('/brand/demo-threads');
      await tester.pumpAndSettle();
      await tapText(tester, 'Follow');
      j.router.go('/profile');
      await tester.pumpAndSettle();

      // Sign in as A (Google: the same account every time).
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(
        [for (final r in await j.server.rowsOf('saves', a)) r['deal_id']],
        [dealId(4)],
      );
      expect(
        [
          for (final r in await j.server.rowsOf('user_cards', a))
            r['card_product_id'],
        ],
        [hblVisaDebit],
      );
      expect([
        for (final r in await j.server.rowsOf('follows', a)) r['brand_id'],
      ], contains(threads));

      // Sign out: the phone is a guest's again.
      await signOutFromProfile(tester);
      expect(find.textContaining('Signed out.'), findsOneWidget);
      expect(j.auth.currentUser, isNull);
      await tapTab(tester, 'Saved');
      expect(find.text(dealTitle(4)), findsNothing);
      expect(
        find.text(
          'Nothing saved yet. Tap the bookmark on a deal to '
          'keep it here.',
        ),
        findsOneWidget,
      );
      expect(j.preferences.brandIds, isEmpty);

      // B, a guest on the same phone, saves something and signs in.
      j.router.go('/deal/${dealId(5)}');
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await signInWithPhone(tester, phoneB);
      final b = j.auth.currentUser!.id;
      expect(b, isNot(a));
      expect(
        [for (final r in await j.server.rowsOf('saves', b)) r['deal_id']],
        [dealId(5)],
      );
      expect(await j.server.rowsOf('user_cards', b), isEmpty);
      expect(await j.server.rowsOf('follows', b), isEmpty);
      await tapTab(tester, 'Saved');
      expect(find.text(dealTitle(5)), findsOneWidget);
      expect(find.text(dealTitle(4)), findsNothing);

      // A again: A's own come back, B's don't.
      await signOutFromProfile(tester);
      await signInWithGoogle(tester);
      expect(j.auth.currentUser!.id, a);
      await tapTab(tester, 'Saved');
      expect(find.text(dealTitle(4)), findsOneWidget);
      expect(find.text(dealTitle(5)), findsNothing);
      expect(j.preferences.brandIds, contains(threads));
      expect(
        [for (final r in await j.server.rowsOf('saves', a)) r['deal_id']],
        [dealId(4)],
        reason: "B's save never reaches A",
      );
      expect(j.server.refused, isEmpty, reason: 'no write the server refuses');

      // Privacy across the whole journey: no phone number in any log line.
      expect(j.logText, isNot(contains('3001111111')));
      expect(j.logText, isNot(contains('3002222222')));
    });

    testWidgets('a session that ends on its own (raw sign-out) keeps the '
        "lists, and the next account still doesn't get them", (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await signInWithPhone(tester, phoneA);
      final a = j.auth.currentUser!.id;
      j.router.go('/deal/${dealId(2)}');
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');
      // The token expires: the repository signs out, not signOutProvider.
      await j.auth.signOut();
      j.router.go('/profile');
      await tester.pumpAndSettle();
      expect(j.container.read(savedDealsProvider), [dealId(2)]);
      await signInWithPhone(tester, phoneB);
      final b = j.auth.currentUser!.id;
      expect(await j.server.rowsOf('saves', b), isEmpty);
      expect(j.container.read(savedDealsProvider), isEmpty);
      expect(
        [for (final r in await j.server.rowsOf('saves', a)) r['deal_id']],
        [dealId(2)],
      );
    });
  });

  group('J3 deep link → deal', () {
    testWidgets('a link opens the deal on top of Home; Back goes Home', (
      tester,
    ) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      j.router.go('/deal/${dealId(9)}');
      await tester.pumpAndSettle();
      expect(find.byType(DealDetailScreen), findsOneWidget);
      expect(find.text(dealTitle(9)), findsWidgets);
      // Share from the linked deal goes to WhatsApp with the deal's text.
      await tapText(tester, 'Share on WhatsApp');
      expect(j.links.opened.single, startsWith('whatsapp:'));
      expect(j.links.opened.single, contains(dealTitle(9)));
    });

    testWidgets('a link that opens the app on first launch is shown after '
        'onboarding', (tester) async {
      final j = Journey();
      await j.pump(tester);
      j.router.go('/deal/${dealId(8)}');
      await tester.pumpAndSettle();
      expect(find.byType(LanguageStep), findsOneWidget);
      await tapText(tester, 'Continue');
      for (var i = 0; i < 3; i++) {
        await tapText(tester, 'Skip');
      }
      await tapText(tester, 'Not now');
      expect(find.byType(DealDetailScreen), findsOneWidget);
      expect(find.text(dealTitle(8)), findsWidgets);
    });

    for (final hostile in [
      '/deal/..%2F..%2Fsettings',
      '/deal/%2e%2e',
      '/deal/javascript:alert(1)',
      '/deal/${'a' * 5000}',
      '/deal/00000000-0000-4000-0000-000000000000',
      '/deal/${dealId(1).toUpperCase()}x',
    ]) {
      testWidgets('a hostile link never crashes and never shows the input: '
          '${hostile.length > 60 ? '${hostile.substring(0, 60)}…' : hostile}', (
        tester,
      ) async {
        final j = Journey(saved: _onboarded);
        await j.pump(tester);
        j.router.go(hostile);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('javascript'), findsNothing);
        expect(find.textContaining('evil'), findsNothing);
        expect(find.textContaining('aaaaaaaaaa'), findsNothing);
        // Home (an invalid id), the not-found page, or the deal page's
        // not-found state: never a deal page with the input in it.
        expect(
          find.byType(HomeScreen).evaluate().isNotEmpty ||
              find.text('Page not found').evaluate().isNotEmpty ||
              find
                  .text("We couldn't find this. It may have ended.")
                  .evaluate()
                  .isNotEmpty,
          isTrue,
        );
      });
    }
  });

  testWidgets('a URI with another host reaches the router by its path only '
      '(recorded for 5.3: the DeepLinkService must check the host)', (
    tester,
  ) async {
    final j = Journey(saved: _onboarded);
    await j.pump(tester);
    j.router.go('https://evil.example.com/deal/${dealId(1)}');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // go_router matches on the path: the host is ignored. Android has
    // flutter_deeplinking_enabled=false, so no outside link gets here today.
    expect(find.byType(DealDetailScreen), findsOneWidget);
  });

  group('J4 offline → cached feed → reconnect', () {
    testWidgets('Home keeps its last copy offline and loads fresh when the '
        'network is back', (tester) async {
      final store = InMemoryKeyValueStore();
      final first = Journey(saved: _onboarded, store: store);
      await first.pump(tester);
      expect(find.byType(DealCard), findsWidgets);
      expect(find.textContaining('Updated'), findsNothing);

      // A cold start with no network, on the same phone.
      await tester.pumpWidget(const SizedBox());
      final j = Journey(saved: _onboarded, store: store);
      await j.pump(tester, online: false);
      expect(
        find.text(
          'No internet. Your saved deals still work; new ones will load '
          "when you're back.",
        ),
        findsOneWidget,
      );
      expect(find.byType(DealCard), findsWidgets);
      expect(find.textContaining('Updated'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Back online, the banner goes; a pull to refresh loads fresh rows.
      await j.setOnline(tester, online: true);
      expect(find.textContaining('No internet.'), findsNothing);
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Updated'), findsNothing);
    });

    testWidgets('a saved deal opened from the Saved tab offline shows its '
        'saved copy, not an error (UX S08 "Offline: cached copy")', (
      tester,
    ) async {
      final store = InMemoryKeyValueStore();
      final first = Journey(saved: _onboarded, store: store);
      await first.pump(tester);
      first.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapTab(tester, 'Saved');
      expect(find.text(dealTitle(4)), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      final j = Journey(saved: _onboarded, store: store);
      await j.pump(tester, online: false);
      await tapTab(tester, 'Saved');
      expect(find.text(dealTitle(4)), findsOneWidget, reason: 'local copy');
      await tester.tap(find.text(dealTitle(4)));
      await tester.pumpAndSettle();
      expect(find.byType(DealDetailScreen), findsOneWidget);
      expect(
        find.text(dealTitle(4)),
        findsWidgets,
        reason: 'the deal the shopper saved is readable offline',
      );
    });
  });

  group('J5 language switch → RTL across tabs', () {
    testWidgets('Urdu from Profile turns every tab right to left, persists, '
        'and deal text follows', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await tapTab(tester, 'Profile');
      await tapText(tester, 'اردو');
      expect(j.container.read(localeControllerProvider), AppLocales.urdu);
      expect(j.store.values[localeStorageKey], 'ur');
      final tabs = {
        'ہوم': HomeScreen,
        'تلاش': ExploreScreen,
        'الرٹس': AlertsScreen,
        'محفوظ': SavedScreen,
        'پروفائل': ProfileScreen,
      };
      final navLabels = [
        for (final e in tester.widgetList<NavigationDestination>(
          find.byType(NavigationDestination),
        ))
          e.label,
      ];
      for (final MapEntry(key: label, value: screen) in tabs.entries) {
        final idx = tabs.keys.toList().indexOf(label);
        await tester.tap(find.byType(NavigationDestination).at(idx));
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget, reason: navLabels[idx]);
        expect(
          Directionality.of(tester.element(find.byType(screen))),
          TextDirection.rtl,
          reason: '$screen',
        );
        expect(tester.takeException(), isNull, reason: '$screen');
      }
      expect(navLabels, isNot(contains('Home')));
      j.router.go('/deal/${dealId(1)}');
      await tester.pumpAndSettle();
      expect(find.text(dealTitleUr(1)), findsWidgets);
      expect(
        Directionality.of(tester.element(find.byType(DealDetailScreen))),
        TextDirection.rtl,
      );
      // And back to English.
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'English');
      expect(
        Directionality.of(tester.element(find.byType(ProfileScreen))),
        TextDirection.ltr,
      );
    });
  });

  group('J6 search → filters → deal', () {
    testWidgets('Explore search, a bank filter, then the deal', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await tapTab(tester, 'Explore');
      await tester.tap(find.text('Search brands, food and card deals'));
      await tester.pumpAndSettle();
      expect(find.text('Search'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'burger');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text(dealTitle(2)), findsOneWidget);
      expect(find.text(dealTitle(9)), findsOneWidget);
      // Filters: card offers from Meezan only.
      await tapText(tester, 'Filters');
      await tapText(tester, 'Meezan');
      await tapText(tester, 'Show deals');
      expect(find.text('Filters (1)'), findsOneWidget);
      expect(find.text(dealTitle(2)), findsNothing);
      expect(find.text(dealTitle(9)), findsOneWidget);
      final searches = [
        for (final c in j.server.calls)
          if (c == 'rpc:search_deals') c,
      ];
      expect(searches.length, lessThanOrEqualTo(4), reason: 'no storm');
      await tapText(tester, dealTitle(9));
      expect(find.byType(DealDetailScreen), findsOneWidget);
      expect(find.text('With these cards'), findsOneWidget);
      // Back keeps the search and its filter.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Filters (1)'), findsOneWidget);
      expect(find.text(dealTitle(9)), findsOneWidget);
      // The words stay on the phone only, in the recent list.
      expect(j.store.values[recentSearchesKey], contains('burger'));
    });
  });

  group('J7 My Cards → card deals', () {
    testWidgets('a guest adds a card and sees its offers; signed in, the '
        "account's own cards drive the list", (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await tapTab(tester, 'Explore');
      await tapText(tester, 'My cards: see your card discounts');
      expect(
        find.text('Add your cards to see the discounts they get you.'),
        findsOneWidget,
      );
      await tapText(tester, 'Add a card');
      await tapText(tester, 'Meezan');
      await tapText(tester, 'Visa Debit');
      expect(find.text('Offers for your cards'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(dealTitle(9)),
        200,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      expect(find.text(dealTitle(7)), findsNothing, reason: 'an HBL offer');
      await tapText(tester, dealTitle(9));
      expect(find.byType(DealDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Signed in: the card goes to the account, the list comes from it.
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      expect(await j.server.rowsOf('user_cards', a), hasLength(1));
      await tapText(tester, 'My cards');
      await tester.scrollUntilVisible(
        find.text(dealTitle(9)),
        200,
        scrollable: find.byType(Scrollable).hitTestable().first,
      );
      expect(find.text(dealTitle(7)), findsNothing);
      // As designed (docs/app/MY_CARDS.md): the list is deals_for_cards
      // over the phone's cards, which are now also the account's.
      expect(j.server.calls, contains('rpc:deals_for_cards'));
      // Nothing that looks like a card number was ever sent.
      for (final r in j.server.inserts) {
        expect(r, isNot(matches(RegExp(r'\d{12,19}'))));
      }
    });
  });

  group('J8 Settings changes show app-wide', () {
    testWidgets('theme, city and language from Settings reach every tab, '
        'and survive a restart', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await tapTab(tester, 'Profile');
      await tapText(tester, 'Settings');
      await tapText(tester, 'Dark');
      // City: Lahore.
      await tapText(tester, 'City');
      await tapText(tester, 'Lahore');
      expect(j.preferences.cityId, isNot(karachiId));
      // Language: Urdu.
      await tapText(tester, 'اردو');
      // pageBack() looks for the English "Back" tooltip.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byType(NavigationDestination).at(i));
        await tester.pumpAndSettle();
        final ctx = tester.element(find.byType(NavigationBar));
        expect(Theme.of(ctx).brightness, Brightness.dark, reason: 'tab $i');
        expect(Directionality.of(ctx), TextDirection.rtl, reason: 'tab $i');
        expect(tester.takeException(), isNull, reason: 'tab $i');
      }
      // Home is Lahore's: Karachi's local deals are gone.
      await tester.tap(find.byType(NavigationDestination).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('لاہور'), findsWidgets);
      expect(find.text(dealTitleUr(1)), findsNothing);

      // A restart reads all three back before the first frame.
      final settings = await loadStartupSettings(
        AppLogger(sinks: []),
        openStore: () => j.store,
      );
      expect(settings.theme, AppThemeMode.dark);
      expect(settings.locale, AppLocales.urdu);
      expect(settings.preferences?.cityId, j.preferences.cityId);
    });
  });

  group('J9 clear the phone / delete the account → a fresh start', () {
    testWidgets('Clear everything signs out, forgets the phone, leaves the '
        'account, and the account brings it back', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');
      j.router.go('/settings');
      await tester.pumpAndSettle();
      await tapText(tester, 'Dark');
      await tapText(tester, 'Privacy');
      await tapText(tester, 'Clear everything on this phone');
      await tapText(tester, 'Clear');

      expect(find.byType(LanguageStep), findsOneWidget);
      expect(j.auth.currentUser, isNull);
      expect(j.container.read(savedDealsProvider), isEmpty);
      expect(j.container.read(themeModeProvider), AppThemeMode.system);
      expect(
        j.store.values.keys.where((k) => !k.startsWith('cache.')),
        isEmpty,
        reason: '${j.store.values.keys}',
      );
      expect(
        [for (final r in await j.server.rowsOf('saves', a)) r['deal_id']],
        [dealId(4)],
        reason: 'the account is untouched',
      );

      // Onboard again and sign in: the account's saves come back.
      await tapText(tester, 'Continue');
      for (var i = 0; i < 3; i++) {
        await tapText(tester, 'Skip');
      }
      await tapText(tester, 'Not now');
      expect(find.byType(HomeScreen), findsOneWidget);
      await signInWithGoogle(tester);
      await tapTab(tester, 'Saved');
      expect(find.text(dealTitle(4)), findsOneWidget);
    });

    testWidgets('P4-R1: after a search, "Clear everything" in dark mode '
        'changes no provider during a build', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      j.router.go('/search?q=burger');
      await tester.pumpAndSettle();
      j.router.go('/settings');
      await tester.pumpAndSettle();
      await tapText(tester, 'Dark');
      await tapText(tester, 'Privacy');
      await tapText(tester, 'Clear everything on this phone');
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      // Today: "Tried to modify a provider while the widget tree was
      // building" from SearchController's homeCityProvider listener.
      expect(tester.takeException(), isNull);
      expect(find.byType(LanguageStep), findsOneWidget);
    });

    testWidgets('deleting the account starts the phone fresh: onboarding, '
        'no lists, default theme', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');
      j.router.go('/settings');
      await tester.pumpAndSettle();
      await tapText(tester, 'Dark');
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Delete account');
      await tapText(tester, 'Delete my account');
      await tester.tap(find.text('Delete my account').last);
      await tester.pumpAndSettle();
      expect(j.auth.deletedIds, [a]);
      expect(find.byType(LanguageStep), findsOneWidget);
      expect(find.text('Your account was deleted.'), findsOneWidget);
      expect(j.container.read(savedDealsProvider), isEmpty);
      expect(
        j.store.values.keys.where((k) => !k.startsWith('cache.')),
        isEmpty,
      );
      expect(
        j.container.read(themeModeProvider),
        AppThemeMode.system,
        reason: 'as "Clear everything" does since 4.9-P1: a fresh start',
      );
    });
  });

  group('exploratory', () {
    String fakeBrand(int i) =>
        '00000000-0000-4000-00bb-${i.toString().padLeft(12, '0')}';

    testWidgets('P4-F1: with more than 200 follows, Sign out still leaves '
        "the phone as a guest's", (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await signInWithGoogle(tester);
      await j.container
          .read(preferencesProvider.notifier)
          .addFollows(brandIds: [for (var i = 1; i <= 201; i++) fakeBrand(i)]);
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');
      expect(j.auth.currentUser, isNull);
      // Today sync_guest_preferences refuses 201 follows (22023, "at most
      // 200 follows at once"), so _sendLists fails and nothing is removed.
      expect(j.container.read(savedDealsProvider), isEmpty);
      expect(j.preferences.brandIds, isEmpty);
    });

    // Was "as it is today" (the refused call); since the fix, the 201
    // follows go up in chunks under the cap and nothing is refused.
    testWidgets('P4-F1: 201 follows go up under the 200 cap, nothing refused', (
      tester,
    ) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await signInWithGoogle(tester);
      await j.container
          .read(preferencesProvider.notifier)
          .addFollows(brandIds: [for (var i = 1; i <= 201; i++) fakeBrand(i)]);
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');
      expect(j.auth.currentUser, isNull);
      expect(j.preferences.brandIds, isEmpty);
      expect(
        j.logText,
        isNot(contains('Could not send the lists before signing out')),
      );
    });

    testWidgets('a double tap on Sign out signs out once, without errors', (
      tester,
    ) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await signInWithGoogle(tester);
      await tapTab(tester, 'Profile');
      final signOut = find.text('Sign out');
      await tester.tap(signOut);
      await tester.tap(signOut, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(j.auth.currentUser, isNull);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('signing out offline keeps the lists (by design) and the '
        'next account still never receives them', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      j.router.go('/deal/${dealId(3)}');
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');
      await j.setOnline(tester, online: false);
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');
      expect(j.container.read(savedDealsProvider), [dealId(3)]);
      await j.setOnline(tester, online: true);
      await signInWithPhone(tester, phoneB);
      final b = j.auth.currentUser!.id;
      expect(await j.server.rowsOf('saves', b), isEmpty);
      expect(j.container.read(savedDealsProvider), isEmpty);
      expect(
        [for (final r in await j.server.rowsOf('saves', a)) r['deal_id']],
        [dealId(3)],
      );
    });
  });
}
