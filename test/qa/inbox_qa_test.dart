// QA, sub-phase 4.8: the Saved tab, the alerts inbox and badge, Following,
// and the account pull at sign-in, against a backend that applies the real
// row rules and scopes reads to the signed-in user, as RLS does
// (docs/qa/4.8.md).
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug; run them with `--dart-define=QA_KNOWN_BUGS=true`.
import 'dart:async';
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/deal_time_labels.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/features/alerts/application/alerts_providers.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/cards/application/my_cards_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';
import 'package:sale_lagi_hai/l10n/gen/app_localizations.dart';

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/fakes.dart';
import 'qa_backend_rules.dart';

String _deal(int n) => demoDeals.firstWhere((d) => d.n == n).id;
const _phoneA = '+923001111111';
const _phoneB = '+923002222222';

Future<void> _signIn(DemoAuthRepository auth, String phone) async {
  await auth.sendPhoneCode(phone);
  await auth.verifyPhoneCode(phone, DemoAuthRepository.code);
}

/// [RulesGateway] whose reads of the user's own tables see only the
/// signed-in user's rows (as RLS does), plus a scripted inbox.
final class _PerUser extends RulesGateway {
  new(super.auth);

  int insertCount = 0;

  /// No network: every request fails as the HTTP client does.
  bool offline = false;

  void _network() {
    if (offline) throw const SocketException('offline');
  }

  /// The inbox: rows for every user; reads see the caller's only.
  final alerts = <Map<String, Object?>>[];
  Completer<void>? holdNextPage;

  static const _own = {'saves', 'user_cards', 'follows'};

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    _network();
    final uid = auth.currentUser?.id;
    if (query.table == 'notifications') {
      if (query.offset > 0) {
        if (holdNextPage case final h?) await h.future;
      }
      return _apply(query, [
        for (final a in alerts)
          if (a['user_id'] == uid) a,
      ]);
    }
    if (_own.contains(query.table)) {
      final rows = await demo.select(TableQuery(query.table));
      return _apply(query, [
        for (final r in rows)
          if (r['user_id'] == uid) r,
      ]);
    }
    return await super.select(query);
  }

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {
    _network();
    insertCount++;
    final existing = await demo.select(TableQuery(table));
    final duplicate = existing.any(
      (r) => row.entries.every((e) => r[e.key] == e.value),
    );
    if (duplicate) throw StateError('23505 duplicate');
    await super.insert(table, {
      ...row,
      if (_own.contains(table))
        'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    _network();
    final uid = auth.currentUser?.id;
    switch (function) {
      case 'unread_alert_count':
        final since = params['since'] as String?;
        return [
          {
            'value': [
              for (final a in alerts)
                if (a['user_id'] == uid &&
                    a['read_at'] == null &&
                    (since == null ||
                        (a['created_at']! as String).compareTo(since) > 0))
                  a,
            ].take(100).length,
          },
        ];
      case 'mark_alerts_read':
        final ids = params['ids'] as List<Object?>?;
        for (final a in alerts) {
          if (a['user_id'] == uid && (ids == null || ids.contains(a['id']))) {
            a['read_at'] ??= DateTime.now().toUtc().toIso8601String();
          }
        }
        return const [];
    }
    return await super.rpc(function, params);
  }

  @override
  Future<void> delete(String table, Map<String, Object?> match) async {
    _network();
    await super.delete(table, match);
  }

  /// equals, inList, order, offset and limit, as PostgREST applies them.
  static List<Map<String, Object?>> _apply(
    TableQuery query,
    List<Map<String, Object?>> rows,
  ) {
    final matching = [
      for (final r in rows)
        if (query.equals.entries.every((e) => r[e.key] == e.value) &&
            query.inList.entries.every((e) => e.value.contains(r[e.key])))
          r,
    ];
    final order = query.orderBy;
    if (order != null) {
      int cmp(Map<String, Object?> a, Map<String, Object?> b) =>
          '${a[order] ?? ''}'.compareTo('${b[order] ?? ''}');
      matching.sort(query.ascending ? cmp : (a, b) => cmp(b, a));
    }
    final page = matching.skip(query.offset).toList();
    return page.take(query.limit ?? page.length).toList();
  }

  void addAlerts(String userId, int count, {DateTime? at}) {
    final base = at ?? DateTime.now().toUtc();
    for (var i = 0; i < count; i++) {
      alerts.add({
        'id': _alertId(alerts.length),
        'user_id': userId,
        'kind': 'deal_alert',
        'title': 'Alert ${alerts.length}',
        'deal_id': _deal(1),
        'created_at': base.subtract(Duration(minutes: i)).toIso8601String(),
        'read_at': null,
      });
    }
  }
}

void main() {
  late DemoAuthRepository auth;
  late _PerUser backend;
  late InMemoryKeyValueStore store;

  ProviderContainer container({DateTime Function()? clock}) {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        loggerProvider.overrideWithValue(AppLogger(sinks: [])),
        backendGatewayProvider.overrideWithValue(backend),
        authRepositoryProvider.overrideWithValue(auth),
        savedPreferencesProvider.overrideWithValue(
          const ShopperPreferences(onboarded: true, cityId: karachiId),
        ),
        if (clock != null) clockProvider.overrideWithValue(clock),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    auth = DemoAuthRepository();
    backend = _PerUser(auth);
    store = InMemoryKeyValueStore();
  });

  Future<List<Object?>> serverSaves() async => [
    for (final r in await backend.demo.select(const TableQuery('saves')))
      '${r['user_id']}/${r['deal_id']}',
  ];

  group('sign-in pull', () {
    test("another phone's saves, cards and follows come in, once each, "
        'and nothing on the phone is lost', () async {
      final c = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      // As a guest on this phone: deals 1 and 2.
      await c.read(savedDealsProvider.notifier).toggle(_deal(1));
      await c.read(savedDealsProvider.notifier).toggle(_deal(2));
      await _signIn(auth, _phoneA);
      final a = auth.currentUser!.id;
      // The account already holds deal 2 (saved on another phone), deal 3,
      // and a followed brand.
      await backend.insert('saves', {'user_id': a, 'deal_id': _deal(2)});
      await backend.insert('saves', {'user_id': a, 'deal_id': _deal(3)});
      final brand = demoBrands.first['id']! as String;
      await backend.insert('follows', {'user_id': a, 'brand_id': brand});
      await c.read(guestSyncProvider)();
      final saved = c.read(savedDealsProvider);
      expect(saved.toSet(), {_deal(1), _deal(2), _deal(3)});
      expect(saved, hasLength(3), reason: 'no duplicates: $saved');
      expect(c.read(preferencesProvider).brandIds, [brand]);
      expect((await serverSaves()).toSet(), {
        '$a/${_deal(1)}',
        '$a/${_deal(2)}',
        '$a/${_deal(3)}',
      });
    });

    test('a failed account read leaves the phone as it was', () async {
      final c = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      await c.read(savedDealsProvider.notifier).toggle(_deal(1));
      await _signIn(auth, _phoneA);
      final broken = _BrokenReads(auth);
      final c2 = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          backendGatewayProvider.overrideWithValue(broken),
          authRepositoryProvider.overrideWithValue(auth),
          savedPreferencesProvider.overrideWithValue(
            const ShopperPreferences(onboarded: true),
          ),
        ],
      );
      addTearDown(c2.dispose);
      c2.listen(savedDealsProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await c2.read(guestSyncProvider)();
      expect(c2.read(savedDealsProvider), [_deal(1)]);
    });

    test('a shared phone: what account A brought onto it does not go into '
        'account B when B signs in after A signed out', () async {
      await _signIn(auth, _phoneA);
      final a = auth.currentUser!.id;
      await backend.insert('saves', {'user_id': a, 'deal_id': _deal(2)});
      final c = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      await c.read(guestSyncProvider)(); // A's pull at sign-in
      expect(c.read(savedDealsProvider), [_deal(2)]);
      await auth.signOut();
      await _signIn(auth, _phoneB);
      final b = auth.currentUser!.id;
      await c.read(guestSyncProvider)();
      final rows = await serverSaves();
      expect(
        rows.where((r) => '$r'.startsWith(b)),
        isEmpty,
        reason: "B never saved anything; A's saved deal is now in B's account",
      );
    });

    test("a shared phone: A's cards are not added to B's account", () async {
      await _signIn(auth, _phoneA);
      final a = auth.currentUser!.id;
      final card = demoCardProducts.first['id']! as String;
      await backend.insert('user_cards', {
        'user_id': a,
        'card_product_id': card,
      });
      final c = container()..read(myCardsProvider);
      await Future<void>.delayed(Duration.zero);
      await c.read(guestSyncProvider)();
      expect(c.read(myCardsProvider), [card]);
      await auth.signOut();
      await _signIn(auth, _phoneB);
      final b = auth.currentUser!.id;
      await c.read(guestSyncProvider)();
      final cards = [
        for (final r in await backend.demo.select(
          const TableQuery('user_cards'),
        ))
          if (r['user_id'] == b) r['card_product_id'],
      ];
      expect(cards, isEmpty, reason: "which bank cards A holds, now B's");
    });

    test(
      'signing in with 500 saved deals does not wait for 500 requests',
      () async {
        final c = container()..read(savedDealsProvider);
        await Future<void>.delayed(Duration.zero);
        for (var i = 0; i < 500; i++) {
          await c.read(savedDealsProvider.notifier).toggle('d$i');
        }
        await _signIn(auth, _phoneA);
        backend.insertCount = 0;
        await c.read(guestSyncProvider)();
        expect(
          backend.insertCount,
          lessThanOrEqualTo(10),
          reason:
              'one request per deal, one after another, before the sign-in '
              'screen closes',
        );
      },
    );
  });

  group('inbox', () {
    test('guests get an empty inbox and a 0 badge, without asking the '
        'server', () async {
      final c = container();
      final inbox = await c.read(inboxProvider.future);
      expect(inbox.signedIn, isFalse);
      expect(inbox.alerts, isEmpty);
      expect(await c.read(alertsBadgeProvider.future), 0);
    });

    test("pages of 30 to the end, no repeats; another user's alerts never "
        'show', () async {
      await _signIn(auth, _phoneA);
      final a = auth.currentUser!.id;
      backend
        ..addAlerts(a, 65)
        ..addAlerts('00000000-0000-4000-9000-00000000beef', 5);
      final c = container();
      final user = c.listen(currentUserProvider, (_, _) {});
      addTearDown(user.close);
      await c.read(currentUserProvider.future);
      await c.read(inboxProvider.future);
      await c.read(inboxProvider.notifier).loadMore();
      await c.read(inboxProvider.notifier).loadMore();
      await c.read(inboxProvider.notifier).loadMore();
      final s = c.read(inboxProvider).requireValue;
      expect(s.alerts, hasLength(65));
      expect(s.alerts.map((x) => x.id).toSet(), hasLength(65));
      expect(s.hasMore, isFalse);
    });

    test('an alert read while the next page is loading stays read', () async {
      await _signIn(auth, _phoneA);
      backend.addAlerts(auth.currentUser!.id, 40);
      final c = container();
      final user = c.listen(currentUserProvider, (_, _) {});
      addTearDown(user.close);
      await c.read(currentUserProvider.future);
      final sub = c.listen(inboxProvider, (_, _) {});
      addTearDown(sub.close);
      final first = await c.read(inboxProvider.future);
      backend.holdNextPage = Completer();
      final more = c.read(inboxProvider.notifier).loadMore();
      await c.read(inboxProvider.notifier).markRead(first.alerts.first);
      expect(c.read(inboxProvider).requireValue.alerts.first.isUnread, isFalse);
      backend.holdNextPage!.complete();
      await more;
      expect(
        c.read(inboxProvider).requireValue.alerts.first.isUnread,
        isFalse,
        reason: 'the page landed and put the old, unread copy back',
      );
    });

    test(
      'mark all read marks every alert, also those not loaded yet',
      () async {
        await _signIn(auth, _phoneA);
        backend.addAlerts(auth.currentUser!.id, 40);
        final c = container();
        final user = c.listen(currentUserProvider, (_, _) {});
        addTearDown(user.close);
        await c.read(currentUserProvider.future);
        await c.read(inboxProvider.future);
        await c.read(inboxProvider.notifier).markAllRead();
        expect(backend.alerts.where((x) => x['read_at'] == null), isEmpty);
      },
    );

    test(
      'the badge counts only alerts after the tab was last opened',
      () async {
        await _signIn(auth, _phoneA);
        final a = auth.currentUser!.id;
        backend.addAlerts(
          a,
          3,
          at: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
        );
        await store.setString(
          alertsSeenKey,
          DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 3))
              .toIso8601String(),
        );
        final c = container();
        final user = c.listen(currentUserProvider, (_, _) {});
        addTearDown(user.close);
        await c.read(currentUserProvider.future);
        final n = await c.read(alertsBadgeProvider.future);
        expect(n, 3);
        await store.setString(
          alertsSeenKey,
          DateTime.now().toUtc().toIso8601String(),
        );
        c.invalidate(alertsBadgeProvider);
        expect(await c.read(alertsBadgeProvider.future), 0);
      },
    );
  });

  group('alert times', () {
    setUpAll(() => initializeDateFormatting('en'));
    final now = DateTime(2026, 10, 29, 12);
    final en = DealTimeLabels(
      lookupAppLocalizations(AppLocales.english),
      AppFormatters(
        lookupAppLocalizations(AppLocales.english),
        AppLocales.english,
      ),
    );
    for (final (age, label) in [
      (const Duration(seconds: -30), 'Just now'), // a phone clock a bit behind
      (const Duration(seconds: 59), 'Just now'),
      (const Duration(minutes: 1), '1 min ago'),
      (const Duration(minutes: 59), '59 min ago'),
      (const Duration(hours: 1), '1 h ago'),
      (const Duration(hours: 11, minutes: 59), '11 h ago'),
    ]) {
      test('$age → $label', () {
        expect(en.received(now.subtract(age), now: now), label);
      });
    }
    test('yesterday by the calendar, then the date', () {
      expect(en.received(DateTime(2026, 10, 28, 9), now: now), 'Yesterday');
      expect(en.received(DateTime(2026, 10, 26, 9), now: now), '26 Oct');
    });
  });

  group('screens', () {
    Future<Harness> open(
      WidgetTester tester,
      String path, {
      bool signedIn = true,
      Locale locale = AppLocales.english,
      DateTime Function()? clock,
      List<String> saved = const [],
      List<String> brandIds = const [],
    }) async {
      if (signedIn) await _signIn(auth, _phoneA);
      if (saved.isNotEmpty) {
        await store.setString(
          savedDealsKey,
          '[${saved.map((s) => '"$s"').join(',')}]',
        );
      }
      final h = Harness(
        saved: ShopperPreferences(
          onboarded: true,
          cityId: karachiId,
          brandIds: brandIds,
        ),
        auth: auth,
        backend: backend,
        store: store,
        overrides: [if (clock != null) clockProvider.overrideWithValue(clock)],
      );
      await h.pump(tester, device: locale);
      h.router.go(path);
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('Remove ended deals also removes them from the account', (
      tester,
    ) async {
      final later = DateTime.now().add(const Duration(days: 6));
      // Deal 5 ends in 5 days: ended 6 days on.
      await _signIn(auth, _phoneA);
      final a = auth.currentUser!.id;
      await backend.insert('saves', {'user_id': a, 'deal_id': _deal(5)});
      await open(tester, '/saved', clock: () => later, saved: [_deal(5)]);
      await tester.tap(find.text('Ended (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove ended deals'));
      await tester.pumpAndSettle();
      expect(
        await serverSaves(),
        isNot(contains('$a/${_deal(5)}')),
        reason: 'the next sign-in pull would bring it back',
      );
    });

    testWidgets('Undo puts a deal back where it was', (tester) async {
      final h = await open(
        tester,
        '/saved',
        signedIn: false,
        saved: [_deal(1), _deal(7), _deal(4)],
      );
      final bookmarks = find.byIcon(Icons.bookmark);
      expect(bookmarks, findsWidgets);
      // Unsave the second card, then Undo.
      await tester.tap(bookmarks.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(h.container.read(savedDealsProvider), [
        _deal(1),
        _deal(7),
        _deal(4),
      ]);
    });

    testWidgets('re-opening the Alerts tab clears a badge that came since', (
      tester,
    ) async {
      final h = await open(tester, '/alerts');
      h.router.go('/');
      await tester.pumpAndSettle();
      backend.addAlerts(
        auth.currentUser!.id,
        2,
        at: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      h.container.invalidate(alertsBadgeProvider);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsWidgets);
      h.router.go('/alerts');
      await tester.pumpAndSettle();
      h.router.go('/');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('2')),
        findsNothing,
      );
    });

    testWidgets(
      'the badge is heard as "Alerts, N new alerts" (not "99+ Alerts"), '
      'and a capped one never as "100"',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _signIn(auth, _phoneA);
        backend.addAlerts(
          auth.currentUser!.id,
          150,
          at: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
        );
        await open(tester, '/');
        expect(find.text('99+'), findsWidgets);
        // What TalkBack reads for the tab: its label and tooltip.
        final heard = <String>[];
        void walk(SemanticsNode node) {
          final d = node.getSemanticsData();
          heard.add('${d.label} ${d.tooltip}');
          node.visitChildren((child) {
            walk(child);
            return true;
          });
        }

        walk(
          tester
              .binding
              .renderViews
              .first
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        final alertsTab = heard.where((h) => h.contains('new alert')).toList();
        final tab = heard.where((h) => h.contains('Alert') || h.contains('99'));
        // Today it is heard as "99+ Alerts": the tooltip never reaches the
        // semantics tree.
        expect(alertsTab, isNotEmpty, reason: '${tab.toList()}');
        expect(
          alertsTab.where((h) => h.contains('100')),
          isEmpty,
          reason: '$alertsTab',
        );
        handle.dispose();
      },
    );

    testWidgets('a followed brand that has gone can still be unfollowed, and '
        'the count matches the list', (tester) async {
      const gone = '00000000-0000-4000-b000-00000000dead';
      final live = demoBrands.first['id']! as String;
      final h = await open(
        tester,
        '/following',
        signedIn: false,
        brandIds: [live, gone],
      );
      expect(find.byIcon(Icons.check), findsNWidgets(1)); // one Following
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      h.router.go('/alerts');
      await tester.pumpAndSettle();
      expect(find.text('1 brand · no categories'), findsOneWidget);
    });

    for (final (name, locale, brightness, hc, scale) in const [
      ('en dark', AppLocales.english, Brightness.dark, false, 1.0),
      ('en light HC', AppLocales.english, Brightness.light, true, 1.0),
      ('ur dark HC', AppLocales.urdu, Brightness.dark, true, 1.0),
      ('ur 200%', AppLocales.urdu, Brightness.light, false, 2.0),
    ]) {
      for (final (path, signedIn) in const [
        ('/alerts', true),
        ('/alerts', false),
        ('/saved', false),
        ('/following', false),
      ]) {
        testWidgets('$name $path${signedIn ? '' : ' (guest)'}: guidelines, '
            'no overflow', (tester) async {
          tester.platformDispatcher
            ..platformBrightnessTestValue = brightness
            ..textScaleFactorTestValue = scale
            ..accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
              highContrast: hc,
            );
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final handle = tester.ensureSemantics();
          if (signedIn) {
            await _signIn(auth, _phoneA);
            backend
              ..addAlerts(auth.currentUser!.id, 3)
              ..addAlerts(
                auth.currentUser!.id,
                3,
                at: DateTime.now().toUtc().subtract(const Duration(days: 2)),
              );
          }
          await open(
            tester,
            path,
            signedIn: false,
            locale: locale,
            saved: [_deal(1), _deal(7)],
            brandIds: [demoBrands.first['id']! as String],
          );
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          // The test font has no Urdu glyphs; contrast is checked in English.
          if (locale != AppLocales.urdu) {
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          }
          handle.dispose();
        });
      }
    }

    testWidgets('unread alerts say "Unread" to a screen reader; read ones '
        'do not; tapping one marks it read and opens its deal', (tester) async {
      final handle = tester.ensureSemantics();
      await _signIn(auth, _phoneA);
      backend.addAlerts(auth.currentUser!.id, 2);
      final h = await open(tester, '/alerts', signedIn: false);
      expect(find.bySemanticsLabel(RegExp('^Unread')), findsNWidgets(2));
      await tester.tap(find.text('Alert 0'));
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, '/deal/${_deal(1)}');
      expect(backend.alerts.first['read_at'], isNotNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('^Unread')), findsNWidgets(1));
      handle.dispose();
    });

    // Round 2 (c91434c).
    testWidgets('R2: the Alerts tab is heard with its count: "2 new alerts", '
        'and past 99 "More than 99 new alerts"', (tester) async {
      final handle = tester.ensureSemantics();
      await _signIn(auth, _phoneA);
      final a = auth.currentUser!.id;
      backend.addAlerts(
        a,
        2,
        at: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
      final h = await open(tester, '/', signedIn: false);
      expect(find.bySemanticsLabel(RegExp('2 new alerts')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^2$')), findsNothing);
      backend.addAlerts(
        a,
        120,
        at: DateTime.now().toUtc().subtract(const Duration(minutes: 1)),
      );
      h.container.invalidate(alertsBadgeProvider);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp('More than 99 new alerts')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'99\+')), findsNothing);
      handle.dispose();
    });

    testWidgets('R2: entering Alerts clears the badge even when the phone '
        'clock is an hour behind the server', (tester) async {
      await _signIn(auth, _phoneA);
      backend.addAlerts(auth.currentUser!.id, 3);
      final behind = DateTime.now().subtract(const Duration(hours: 1));
      final h = await open(tester, '/', signedIn: false, clock: () => behind);
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('3')),
        findsOneWidget,
      );
      h.router.go('/alerts');
      await tester.pumpAndSettle();
      h.router.go('/');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('3')),
        findsNothing,
      );
    });

    testWidgets('R2: entering Alerts offline still clears the badge', (
      tester,
    ) async {
      await _signIn(auth, _phoneA);
      backend.addAlerts(
        auth.currentUser!.id,
        2,
        at: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      );
      final h = await open(tester, '/', signedIn: false);
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('2')),
        findsOneWidget,
      );
      backend.offline = true;
      h.router.go('/alerts');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      backend.offline = false;
      h.router.go('/');
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('2')),
        findsNothing,
      );
    });
  });

  group('round 2: sign-in (c91434c)', () {
    Future<ProviderContainer> ready() async {
      final c = container()
        ..listen(savedDealsProvider, (_, _) {})
        ..listen(myCardsProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return c;
    }

    Future<Set<String>> rows(String table, String column) async => {
      for (final r in await backend.demo.select(TableQuery(table)))
        if (r[column] != null) '${r['user_id']}/${r[column]}',
    };

    final card = demoCardProducts.first['id']! as String;
    final card2 = demoCardProducts[1]['id']! as String;
    final brand = demoBrands.firstWhere((b) => b['is_active'] == true)['id']!;

    test('the same account again: what was saved as a guest in between is '
        'kept on the phone and goes up in one call', () async {
      final c = await ready();
      await auth.signInWithGoogle();
      final a = auth.currentUser!.id;
      await c.read(guestSyncProvider)();
      await c.read(savedDealsProvider.notifier).toggle(_deal(1));
      await c.read(signOutProvider)();
      // As a guest, then the same Google account again.
      await c.read(savedDealsProvider.notifier).toggle(_deal(2));
      await c.read(myCardsProvider.notifier).add(card);
      await auth.signInWithGoogle();
      expect(auth.currentUser!.id, a);
      backend
        ..insertCount = 0
        ..guestItemCalls = 0;
      await c.read(guestSyncProvider)();
      expect(c.read(savedDealsProvider), [_deal(2), _deal(1)]);
      expect(c.read(myCardsProvider), [card]);
      expect(await rows('saves', 'deal_id'), {
        '$a/${_deal(1)}',
        '$a/${_deal(2)}',
      });
      expect(await rows('user_cards', 'card_product_id'), {'$a/$card'});
      expect(backend.guestItemCalls, 1);
      expect(backend.insertCount, 0);
      expect(store.values[accountOnPhoneKey], a);
    });

    test('a first-time guest: saves, cards and follows go into the account, '
        'and stay on the phone', () async {
      final c = await ready();
      await c.read(savedDealsProvider.notifier).toggle(_deal(1));
      await c.read(savedDealsProvider.notifier).toggle(_deal(2));
      await c.read(myCardsProvider.notifier).add(card);
      await c
          .read(preferencesProvider.notifier)
          .addFollows(brandIds: [brand as String]);
      expect(store.values[accountOnPhoneKey], isNull);
      await _signIn(auth, _phoneA);
      final a = auth.currentUser!.id;
      await c.read(guestSyncProvider)();
      expect(c.read(savedDealsProvider), [_deal(2), _deal(1)]);
      expect(c.read(myCardsProvider), [card]);
      expect(c.read(preferencesProvider).brandIds, [brand]);
      expect(await rows('saves', 'deal_id'), {
        '$a/${_deal(1)}',
        '$a/${_deal(2)}',
      });
      expect(await rows('user_cards', 'card_product_id'), {'$a/$card'});
      expect(await rows('follows', 'brand_id'), {'$a/$brand'});
      expect(backend.profiles[a]?['home_city_id'], karachiId);
      expect(store.values[accountOnPhoneKey], a);
    });

    test('offline at sign-in: nothing on the phone is dropped, and it goes '
        'up at the next sign-in', () async {
      final c = await ready();
      await c.read(savedDealsProvider.notifier).toggle(_deal(1));
      await c.read(myCardsProvider.notifier).add(card);
      backend.offline = true;
      await auth.signInWithGoogle();
      final a = auth.currentUser!.id;
      await c.read(guestSyncProvider)();
      expect(c.read(savedDealsProvider), [_deal(1)]);
      expect(c.read(myCardsProvider), [card]);
      expect(store.values[accountOnPhoneKey], a);
      backend.offline = false;
      expect(await rows('saves', 'deal_id'), isEmpty);
      await c.read(signOutProvider)();
      await auth.signInWithGoogle();
      await c.read(guestSyncProvider)();
      expect(await rows('saves', 'deal_id'), {'$a/${_deal(1)}'});
      expect(await rows('user_cards', 'card_product_id'), {'$a/$card'});
      expect(c.read(savedDealsProvider), [_deal(1)]);
    });

    test("offline at another account's sign-in: the first account's lists "
        'still never reach it', () async {
      final c = await ready();
      await _signIn(auth, _phoneA);
      final a = auth.currentUser!.id;
      await backend.insert('saves', {'user_id': a, 'deal_id': _deal(3)});
      await c.read(guestSyncProvider)();
      expect(c.read(savedDealsProvider), [_deal(3)]);
      await c.read(signOutProvider)();
      backend.offline = true;
      await _signIn(auth, _phoneB);
      final b = auth.currentUser!.id;
      await c.read(guestSyncProvider)();
      expect(c.read(savedDealsProvider), isEmpty);
      backend.offline = false;
      // A later save of B's goes up, and nothing of A's with it.
      await c.read(savedDealsProvider.notifier).toggle(_deal(4));
      expect((await rows('saves', 'deal_id')).where((r) => r.startsWith(b)), [
        '$b/${_deal(4)}',
      ]);
    });

    test('the same account again keeps the follows; another account does not '
        'get them', () async {
      final c = await ready();
      await auth.signInWithGoogle();
      final a = auth.currentUser!.id;
      await c.read(guestSyncProvider)();
      await c
          .read(preferencesProvider.notifier)
          .addFollows(brandIds: [brand as String]);
      await c.read(signOutProvider)();
      await auth.signInWithGoogle();
      await c.read(guestSyncProvider)();
      expect(c.read(preferencesProvider).brandIds, [brand]);
      expect(await rows('follows', 'brand_id'), {'$a/$brand'});
      await c.read(signOutProvider)();
      await _signIn(auth, _phoneB);
      final b = auth.currentUser!.id;
      await c.read(guestSyncProvider)();
      expect(c.read(preferencesProvider).brandIds, isEmpty);
      expect(
        (await rows('follows', 'brand_id')).where((r) => r.startsWith(b)),
        isEmpty,
      );
    });

    test('a shared phone, both ways: A then B then A again, each account '
        'ends with only its own saves and cards', () async {
      final c = await ready();
      await auth.signInWithGoogle();
      final a = auth.currentUser!.id;
      await c.read(guestSyncProvider)();
      await c.read(savedDealsProvider.notifier).toggle(_deal(1));
      await c.read(myCardsProvider.notifier).add(card);
      await c.read(signOutProvider)();
      await _signIn(auth, _phoneB);
      final b = auth.currentUser!.id;
      await c.read(guestSyncProvider)();
      await c.read(savedDealsProvider.notifier).toggle(_deal(2));
      await c.read(myCardsProvider.notifier).add(card2);
      await c.read(signOutProvider)();
      await auth.signInWithGoogle();
      await c.read(guestSyncProvider)();
      expect(await rows('saves', 'deal_id'), {
        '$a/${_deal(1)}',
        '$b/${_deal(2)}',
      });
      expect(await rows('user_cards', 'card_product_id'), {
        '$a/$card',
        '$b/$card2',
      });
      // A's own come back onto the phone.
      expect(c.read(savedDealsProvider), [_deal(1)]);
      expect(c.read(myCardsProvider), [card]);
    });

    test('BUG-9: after signing out, the account’s saved deals and cards no '
        'longer show on the phone', () async {
      final c = await ready();
      await _signIn(auth, _phoneA);
      final a = auth.currentUser!.id;
      // Saved and added on A's own phone.
      await backend.insert('saves', {'user_id': a, 'deal_id': _deal(3)});
      await backend.insert('user_cards', {
        'user_id': a,
        'card_product_id': card,
      });
      await c.read(guestSyncProvider)();
      expect(c.read(savedDealsProvider), [_deal(3)]);
      await c.read(signOutProvider)();
      expect(
        c.read(savedDealsProvider),
        isNot(contains(_deal(3))),
        reason: 'the next person on the phone sees what A saved',
      );
      expect(
        c.read(myCardsProvider),
        isEmpty,
        reason: "and which bank cards A holds, as 'My Cards'",
      );
    });

    test('BUG-9: what a guest saves after another account signed out goes '
        'into their account when they sign in', () async {
      final c = await ready();
      await _signIn(auth, _phoneA);
      await c.read(guestSyncProvider)();
      await c.read(signOutProvider)();
      // B, as a guest on the same phone.
      await c.read(savedDealsProvider.notifier).toggle(_deal(5));
      await c.read(myCardsProvider.notifier).add(card2);
      await _signIn(auth, _phoneB);
      final b = auth.currentUser!.id;
      await c.read(guestSyncProvider)();
      expect(c.read(savedDealsProvider), [
        _deal(5),
      ], reason: 'dropped from the phone without a word');
      expect(await rows('saves', 'deal_id'), {'$b/${_deal(5)}'});
      expect(await rows('user_cards', 'card_product_id'), {'$b/$card2'});
    });
  });
}

/// Every read of the account fails.
final class _BrokenReads extends RulesGateway {
  new(super.auth);

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async =>
      throw StateError('offline');
}

String _alertId(int n) =>
    '00000000-0000-4000-a1e0-${n.toString().padLeft(12, '0')}';
