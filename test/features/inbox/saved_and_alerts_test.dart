import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/deal_time_labels.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/features/alerts/application/alerts_providers.dart';
import 'package:sale_lagi_hai/features/alerts/domain/app_alert.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/cards/application/my_cards_providers.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/follows/presentation/following_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_view.dart';
import 'package:sale_lagi_hai/l10n/gen/app_localizations_en.dart';

import '../../helpers/fakes.dart';
import '../onboarding/onboarding_harness.dart';

String _deal(int n) => demoDeals.firstWhere((d) => d.n == n).id;
String _title(int n) => demoDeals.firstWhere((d) => d.n == n).titleEn;
const _gone = '00000000-0000-4000-0006-00000000dead';
final _threads = brandBySlug('demo-threads')['id']! as String;

/// [InMemoryKeyValueStore], but whose-lists reads fail.
final class _NoMarkerStore implements KeyValueStore {
  final inner = InMemoryKeyValueStore();

  @override
  Future<String?> getString(String key) => key == accountOnPhoneKey
      ? Future.error(StateError('unreadable'))
      : inner.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      inner.setString(key, value);

  @override
  Future<void> remove(String key) => inner.remove(key);

  @override
  Future<Set<String>> keys() => inner.keys();

  @override
  Future<void> clear() => inner.clear();
}

Future<void> _signIn(DemoAuthRepository auth) async {
  await auth.sendPhoneCode('+923001234567');
  await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
}

void main() {
  group('the Saved view', () {
    late InMemoryKeyValueStore store;
    late BackendGateway backend;
    late DateTime now;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          backendGatewayProvider.overrideWithValue(backend),
          clockProvider.overrideWithValue(() => now),
        ],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      store = InMemoryKeyValueStore()
        ..values[savedDealsKey] = jsonEncode([_deal(2), _gone, _deal(1)]);
      backend = DemoGateway();
      // Deal 2 ends in 5 hours: 6 hours on, it has ended.
      now = DateTime.now().add(const Duration(hours: 6));
    });

    test('on, ended and gone, in the order saved', () async {
      final c = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      final view = await c.read(savedViewProvider.future);
      expect(view.active.map((d) => d.id), [_deal(1)]);
      expect(view.ended.map((d) => d.id), [_deal(2)]);
      expect(view.goneIds, [_gone]);
      expect(view.cachedAt, isNull);
    });

    test('offline: the last copy, without calling anything gone', () async {
      final first = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      await first.read(savedViewProvider.future);
      backend = FlakyGateway();
      final c = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      final view = await c.read(savedViewProvider.future);
      expect(view.active.map((d) => d.id), [_deal(1)]);
      expect(view.goneIds, isEmpty);
      expect(view.failure, isA<AppFailure>());
    });

    test('offline with no copy: the failure', () async {
      backend = FlakyGateway();
      final c = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        c.read(savedViewProvider.future),
        throwsA(isA<AppFailure>()),
      );
    });

    test('nothing saved: empty, without a request', () async {
      store.values.remove(savedDealsKey);
      final c = container();
      expect((await c.read(savedViewProvider.future)).isEmpty, isTrue);
    });
  });

  group('the inbox', () {
    late DemoAuthRepository auth;
    late DemoGateway backend;
    late InMemoryKeyValueStore store;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          backendGatewayProvider.overrideWithValue(backend),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      auth = DemoAuthRepository();
      backend = DemoGateway();
      store = InMemoryKeyValueStore();
    });

    test('guests have none, and no badge', () async {
      final c = container();
      final sub = c.listen(currentUserProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(currentUserProvider.future);
      expect((await c.read(inboxProvider.future)).signedIn, isFalse);
      expect(await c.read(alertsBadgeProvider.future), 0);
    });

    test('signed in: newest first; read one, then all; the badge counts '
        'what came since the tab was opened', () async {
      await _signIn(auth);
      final c = container();
      final sub = c.listen(inboxProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(currentUserProvider.future);
      var inbox = await c.read(inboxProvider.future);
      expect(inbox.alerts, hasLength(3));
      expect(inbox.alerts.first.dealId, _deal(1));
      expect(inbox.alerts.where((a) => a.isUnread), hasLength(2));
      expect(await c.read(alertsBadgeProvider.future), 2);

      await c.read(inboxProvider.notifier).markRead(inbox.alerts.first);
      inbox = c.read(inboxProvider).requireValue;
      expect(inbox.alerts.first.isUnread, isFalse);
      expect(await c.read(alertsBadgeProvider.future), 1);

      await c.read(inboxProvider.notifier).markAllRead();
      expect(c.read(inboxProvider).requireValue.hasUnread, isFalse);
      expect(await c.read(alertsBadgeProvider.future), 0);
      expect(store.values, isNot(contains(alertsSeenKey)));
    });

    test('alerts from rows: unknown kinds are system; bad rows fail', () {
      final alert = AppAlert.fromRow(const {
        'id': 'a',
        'kind': 'something_new',
        'title': 'T',
        'created_at': '2026-10-29T12:00:00Z',
      });
      expect(alert.kind, AlertKind.system);
      expect(alert.toString(), isNot(contains('T')));
      expect(() => AppAlert.fromRow(const {'id': 'a'}), throwsFormatException);
    });
  });

  group('sign-in brings in what the account holds', () {
    test('saves, cards and follows from another phone', () async {
      final backend = DemoGateway();
      final auth = DemoAuthRepository();
      final card = demoCardProducts.first['id']! as String;
      await backend.insert('saves', {'deal_id': _deal(5)});
      await backend.insert('user_cards', {'card_product_id': card});
      await backend.insert('follows', {'brand_id': _threads});
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          backendGatewayProvider.overrideWithValue(backend),
          authRepositoryProvider.overrideWithValue(auth),
          savedPreferencesProvider.overrideWithValue(onboardedPreferences),
        ],
      );
      addTearDown(c.dispose);
      await c.read(savedDealsProvider.notifier).toggle(_deal(1));
      await _signIn(auth);
      await c.read(guestSyncProvider)();
      expect(c.read(savedDealsProvider), containsAll([_deal(1), _deal(5)]));
      expect(c.read(myCardsProvider), [card]);
      expect(c.read(preferencesProvider).brandIds, [_threads]);
    });

    test('follows go up in calls of at most 200 (QA P4-F1)', () {
      final brands = [for (var i = 0; i < 250; i++) 'b$i'];
      final categories = [for (var i = 0; i < 160; i++) 'c$i'];
      final chunks = followChunks(brands, categories);
      expect(chunks, hasLength(3));
      for (final c in chunks) {
        final count =
            (c['brand_ids']! as List).length +
            (c['category_ids']! as List).length;
        expect(count, lessThanOrEqualTo(followsPerCall));
      }
      expect([for (final c in chunks) ...c['brand_ids']! as List], brands);
      expect([
        for (final c in chunks) ...c['category_ids']! as List,
      ], categories);
      expect(followChunks(const [], const []), isEmpty);
    });

    group('whose lists are on the phone (QA 4.8 BUG-1)', () {
      late DemoGateway backend;
      late DemoAuthRepository auth;
      final card = demoCardProducts.first['id']! as String;

      ProviderContainer phone(KeyValueStore store) {
        final c = ProviderContainer(
          overrides: [
            keyValueStoreProvider.overrideWithValue(store),
            loggerProvider.overrideWithValue(AppLogger(sinks: [])),
            backendGatewayProvider.overrideWithValue(backend),
            authRepositoryProvider.overrideWithValue(auth),
            savedPreferencesProvider.overrideWithValue(
              onboardedPreferences.copyWith(brandIds: [_threads]),
            ),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      Future<List<Object?>> inAccount(String table, String column) async => [
        for (final r in await backend.select(TableQuery(table))) r[column],
      ];

      setUp(() {
        backend = DemoGateway();
        auth = DemoAuthRepository();
      });

      test("a guest's lists go up in one call, and the phone is noted as "
          "this account's", () async {
        final store = InMemoryKeyValueStore()
          ..values[savedDealsKey] = jsonEncode([_deal(1), _deal(2)])
          ..values[myCardsKey] = jsonEncode([card]);
        final c = phone(store);
        await _signIn(auth);
        await c.read(guestSyncProvider)();
        expect(await inAccount('saves', 'deal_id'), [_deal(1), _deal(2)]);
        expect(await inAccount('user_cards', 'card_product_id'), [card]);
        expect(store.values[accountOnPhoneKey], auth.currentUser!.id);
      });

      test(
        'the same account again: what was saved meanwhile goes up',
        () async {
          await _signIn(auth);
          final store = InMemoryKeyValueStore()
            ..values[accountOnPhoneKey] = auth.currentUser!.id
            ..values[savedDealsKey] = jsonEncode([_deal(3)]);
          final c = phone(store);
          await c.read(guestSyncProvider)();
          expect(await inAccount('saves', 'deal_id'), [_deal(3)]);
        },
      );

      test("another account's lists are dropped, never sent; this one's "
          'come in', () async {
        await backend.insert('saves', {'deal_id': _deal(5)});
        final store = InMemoryKeyValueStore()
          ..values[accountOnPhoneKey] = 'someone-else'
          ..values[savedDealsKey] = jsonEncode([_deal(1)])
          ..values[myCardsKey] = jsonEncode([card]);
        final c = phone(store);
        await _signIn(auth);
        await c.read(guestSyncProvider)();
        expect(await inAccount('saves', 'deal_id'), [_deal(5)]);
        expect(await inAccount('user_cards', 'card_product_id'), isEmpty);
        expect(await inAccount('follows', 'brand_id'), isEmpty);
        expect(c.read(savedDealsProvider), [_deal(5)]);
        expect(c.read(myCardsProvider), isEmpty);
        expect(c.read(preferencesProvider).brandIds, isEmpty);
        expect(store.values[accountOnPhoneKey], auth.currentUser!.id);
      });

      test("unreadable counts as another account's", () async {
        final store = _NoMarkerStore();
        store.inner.values[savedDealsKey] = jsonEncode([_deal(1)]);
        final c = phone(store);
        await _signIn(auth);
        await c.read(guestSyncProvider)();
        expect(await inAccount('saves', 'deal_id'), isEmpty);
        expect(c.read(savedDealsProvider), isEmpty);
      });
    });
  });

  test('when an alert came', () async {
    await initializeDateFormatting('en');
    final en = AppLocalizationsEn();
    final labels = DealTimeLabels(en, AppFormatters(en, const Locale('en')));
    final now = DateTime(2026, 10, 29, 12);
    expect(labels.received(now, now: now), 'Just now');
    expect(
      labels.received(now.subtract(const Duration(minutes: 5)), now: now),
      '5 min ago',
    );
    expect(
      labels.received(now.subtract(const Duration(hours: 3)), now: now),
      '3 h ago',
    );
    expect(labels.received(DateTime(2026, 10, 28, 9), now: now), 'Yesterday');
    expect(labels.received(DateTime(2026, 10, 20, 9), now: now), '20 Oct');
  });

  group('the screens', () {
    Future<Harness> app(
      WidgetTester tester, {
      Locale locale = AppLocales.english,
      String at = '/saved',
      bool signedIn = false,
      List<String> saved = const [],
      ShopperPreferences? preferences,
    }) async {
      final auth = DemoAuthRepository();
      if (signedIn) await _signIn(auth);
      final h = Harness(
        auth: auth,
        saved:
            preferences ??
            const ShopperPreferences(onboarded: true, cityId: karachiId),
        store: InMemoryKeyValueStore()
          ..values[savedDealsKey] = jsonEncode(saved),
      );
      await h.pump(tester, device: locale);
      h.router.go(at);
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('Saved: empty, then active deals; unsave with Undo', (
      tester,
    ) async {
      final h = await app(tester, saved: [_deal(1), _deal(4)]);
      expect(find.text('Active (2)'), findsOneWidget);
      expect(find.text(_title(1)), findsOneWidget);
      await tester.tap(find.byTooltip('Remove from saved').first);
      await tester.pumpAndSettle();
      expect(h.container.read(savedDealsProvider), [_deal(4)]);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(h.container.read(savedDealsProvider), contains(_deal(1)));
    });

    testWidgets('Saved: gone deals are summed up and can be removed', (
      tester,
    ) async {
      final h = await app(tester, saved: [_gone, _deal(1)]);
      expect(find.text('1 saved deal is no longer available.'), findsOneWidget);
      await tapText(tester, 'Remove them');
      expect(h.container.read(savedDealsProvider), [_deal(1)]);
      expect(find.text('Ended (0)'), findsOneWidget);
      await tapText(tester, 'Ended (0)');
      expect(find.text('None of your saved deals has ended.'), findsOneWidget);
    });

    testWidgets('Saved: nothing saved', (tester) async {
      await app(tester);
      expect(find.textContaining('Nothing saved yet'), findsOneWidget);
    });

    testWidgets('Alerts as a guest: sign in to get them; Following opens', (
      tester,
    ) async {
      await app(
        tester,
        at: '/alerts',
        preferences: ShopperPreferences(
          onboarded: true,
          cityId: karachiId,
          brandIds: [_threads],
        ),
      );
      expect(find.textContaining('Sign in to get alerts here'), findsOneWidget);
      expect(find.text('1 brand · no categories'), findsOneWidget);
      await tapText(tester, 'Following');
      expect(find.byType(FollowingScreen), findsOneWidget);
      expect(find.text('Threads (Demo)'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Follow Threads (Demo)'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("You're not following anything"),
        findsOneWidget,
      );
    });

    testWidgets('Alerts signed in: the badge, unread marks, open one, mark '
        'all read', (tester) async {
      final handle = tester.ensureSemantics();
      final h = await app(tester, at: '/', signedIn: true);
      expect(find.text('2'), findsOneWidget, reason: 'the badge');
      h.router.go('/alerts');
      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing, reason: 'seen: the badge clears');
      expect(find.text('Today'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Unread')), findsNWidgets(2));
      await tester.tap(find.textContaining('Family karahi for 4').first);
      await tester.pumpAndSettle();
      expect(find.byType(DealDetailScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(DealDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('^Unread')), findsOneWidget);
      await tester.tap(find.byTooltip('Mark all as read'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('^Unread')), findsNothing);
      expect(find.byTooltip('Mark all as read'), findsNothing);
      handle.dispose();
    });

    for (final locale in AppLocales.supported) {
      for (final (name, at, signedIn) in [
        ('Saved', '/saved', false),
        ('Alerts', '/alerts', true),
        ('Following', '/following', false),
      ]) {
        testWidgets('${locale.languageCode} $name: guidelines, and 200% '
            'text without overflow', (tester) async {
          final handle = tester.ensureSemantics();
          await app(
            tester,
            locale: locale,
            at: at,
            signedIn: signedIn,
            saved: [_deal(1), _deal(7)],
            preferences: ShopperPreferences(
              onboarded: true,
              cityId: karachiId,
              brandIds: [_threads],
              categoryFollowIds: [categoryId('food-and-restaurants')],
            ),
          );
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

const onboardedPreferences = ShopperPreferences(onboarded: true);
