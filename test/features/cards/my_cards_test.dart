import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/cards/application/my_cards_providers.dart';
import 'package:sale_lagi_hai/features/cards/presentation/my_cards_screen.dart';
import 'package:sale_lagi_hai/features/catalog/data/backend_catalog_repository.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../../helpers/fakes.dart';
import '../onboarding/onboarding_harness.dart';

String _bank(String slug) =>
    demoBanks.firstWhere((b) => b['slug'] == slug)['id']! as String;

String _card(String bank, String slug) =>
    demoCardProducts.firstWhere(
          (p) => p['bank_id'] == _bank(bank) && p['slug'] == slug,
        )['id']!
        as String;

final String _hblCredit = _card('hbl', 'visa-credit');
final String _meezanDebit = _card('meezan-bank', 'visa-debit');

String _title(int n) => demoDeals.firstWhere((d) => d.n == n).titleEn;

void main() {
  group('my cards on the phone', () {
    late InMemoryKeyValueStore store;
    late DemoGateway backend;
    late DemoAuthRepository auth;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          backendGatewayProvider.overrideWithValue(backend),
          authRepositoryProvider.overrideWithValue(auth),
          savedPreferencesProvider.overrideWithValue(
            const ShopperPreferences(onboarded: true, cityId: karachiId),
          ),
        ],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      store = InMemoryKeyValueStore();
      backend = DemoGateway();
      auth = DemoAuthRepository();
    });

    Future<void> signIn() async {
      await auth.sendPhoneCode('+923001234567');
      await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
    }

    test(
      'a guest keeps card products on the phone, never anything else',
      () async {
        final c = container();
        expect(await c.read(myCardsProvider.notifier).add(_hblCredit), isTrue);
        expect(await c.read(myCardsProvider.notifier).add(_hblCredit), isTrue);
        expect(c.read(myCardsProvider), [_hblCredit]);
        expect(jsonDecode(store.values[myCardsKey]!), [_hblCredit]);
        expect(await backend.select(const TableQuery('user_cards')), isEmpty);
        await c.read(myCardsProvider.notifier).remove(_hblCredit);
        expect(jsonDecode(store.values[myCardsKey]!), isEmpty);
      },
    );

    test('at most 20 cards', () async {
      final c = container();
      final ids = [for (final p in demoCardProducts) p['id']! as String];
      for (var i = 0; i < MyCards.max; i++) {
        expect(await c.read(myCardsProvider.notifier).add('card-$i'), isTrue);
      }
      expect(await c.read(myCardsProvider.notifier).add(ids.first), isFalse);
      expect(c.read(myCardsProvider), hasLength(MyCards.max));
    });

    test('signed in, cards go to the account (with their owner) and come '
        'out of it', () async {
      await signIn();
      final c = container();
      await c.read(myCardsProvider.notifier).add(_meezanDebit);
      final rows = await backend.select(const TableQuery('user_cards'));
      expect(rows.single['card_product_id'], _meezanDebit);
      expect(rows.single['user_id'], auth.currentUser!.id);
      await c.read(myCardsProvider.notifier).remove(_meezanDebit);
      expect(await backend.select(const TableQuery('user_cards')), isEmpty);
    });

    test('cards added as a guest move into the account at sign-in', () async {
      final c = container();
      await c.read(myCardsProvider.notifier).add(_hblCredit);
      await signIn();
      await c.read(guestSyncProvider)();
      expect(
        (await backend.select(const TableQuery('user_cards')))
            .map((r) => r['card_product_id']),
        [_hblCredit],
      );
    });

    test('a fresh start (account deleted) forgets them', () async {
      final c = container();
      await c.read(myCardsProvider.notifier).add(_hblCredit);
      await store.clear();
      await c.read(preferencesProvider.notifier).reset();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(myCardsProvider), isEmpty);
      expect(store.values, isNot(contains(myCardsKey)));
    });

    test("deals for the cards: only their bank's offers", () async {
      final c = container();
      Future<List<String>> titles(List<String> cards) async {
        final list = dealListProvider(CardDeals(cards, cityId: karachiId));
        final sub = c.listen(list, (_, _) {});
        addTearDown(sub.close);
        return [for (final d in (await c.read(list.future)).deals) d.titleEn];
      }

      expect(await titles([_hblCredit]), [_title(7)]);
      expect(await titles([_meezanDebit]), [_title(9)]);
      expect(await titles([]), isEmpty);
      expect(
        CardDeals([_hblCredit, _meezanDebit]),
        CardDeals([_meezanDebit, _hblCredit]),
      );
    });

    test('card products from the catalog, with network and kind', () async {
      final products = await BackendCatalogRepository(backend).cardProducts();
      final hbl = products.firstWhere((p) => p.id == _hblCredit);
      expect(hbl.network, CardNetwork.visa);
      expect(hbl.kind, CardKind.credit);
      expect(
        products.where((p) => p.bankId == _bank('meezan-bank')),
        hasLength(2),
      );
    });
  });

  group('the screens', () {
    Future<Harness> app(
      WidgetTester tester, {
      Locale locale = AppLocales.english,
      String at = '/cards',
    }) async {
      final h = Harness(
        saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
      );
      await h.pump(tester, device: locale);
      h.router.go(at);
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('empty: the promise, then add a card in two steps; its '
        'offers show; remove it', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await app(tester);
      expect(
        find.textContaining('We never ask for card numbers'),
        findsOneWidget,
      );
      await tapText(tester, 'Add a card');
      expect(find.text('Which bank?'), findsOneWidget);
      await tapText(tester, 'HBL');
      expect(find.text('Which HBL card?'), findsOneWidget);
      await tapText(tester, 'Visa Credit');
      expect(find.byType(AddCardSheet), findsNothing);
      expect(h.container.read(myCardsProvider), [_hblCredit]);
      expect(find.text('HBL Visa Credit (Credit)'), findsOneWidget);
      expect(find.text('Offers for your cards'), findsOneWidget);
      expect(find.text(_title(7)), findsOneWidget);

      // Added cards are marked, not offered twice; Back returns to banks.
      await tapText(tester, 'Add a card');
      // In the sheet: deal cards show "HBL" too.
      await tester.tap(
        find.descendant(
          of: find.byType(AddCardSheet),
          matching: find.text('HBL'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Already added'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AddCardSheet),
          matching: find.byTooltip('Back'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Which bank?'), findsOneWidget);
      Navigator.of(tester.element(find.byType(AddCardSheet))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove HBL Visa Credit (Credit)'));
      await tester.pumpAndSettle();
      expect(h.container.read(myCardsProvider), isEmpty);
      expect(
        find.text('Add your cards to see the discounts they get you.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('privacy: no screen of My Cards has anywhere to type', (
      tester,
    ) async {
      await app(tester);
      expect(find.byType(EditableText), findsNothing);
      await tapText(tester, 'Add a card');
      expect(find.byType(EditableText), findsNothing);
      await tapText(tester, 'HBL');
      expect(find.byType(EditableText), findsNothing);
    });

    testWidgets('Profile and Explore open My Cards', (tester) async {
      final h = await app(tester, at: '/profile');
      await tapText(tester, 'My cards');
      expect(find.byType(MyCardsScreen), findsOneWidget);
      h.router.go('/explore');
      await tester.pumpAndSettle();
      await tapText(tester, 'My cards: see your card discounts');
      expect(find.byType(MyCardsScreen), findsOneWidget);
    });

    for (final locale in AppLocales.supported) {
      for (final (name, setUp)
          in <(String, Future<void> Function(WidgetTester, Harness))>[
            ('empty', (_, _) async {}),
            (
              'with a card',
              (tester, h) async {
                await h.container
                    .read(myCardsProvider.notifier)
                    .add(_hblCredit);
                await tester.pumpAndSettle();
              },
            ),
            (
              'picking a card',
              (tester, h) async {
                await tester.tap(
                  find.descendant(
                    of: find.byType(MessageView),
                    matching: find.byWidgetPredicate(
                      (w) => w is ButtonStyleButton,
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                await tester.tap(find.text('HBL'));
                await tester.pumpAndSettle();
              },
            ),
          ]) {
        testWidgets('${locale.languageCode} $name: guidelines, and 200% '
            'text without overflow', (tester) async {
          final handle = tester.ensureSemantics();
          final h = await app(tester, locale: locale);
          await setUp(tester, h);
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
  });
}
