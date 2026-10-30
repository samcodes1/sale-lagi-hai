// QA, Phase 4 gate round 2 (381aaae): the fixes for P4-F1, P4-J1, P4-P1,
// 4.9-N6 and 4.8 BUG-7, hunted for regressions through the real app on
// the server-faithful fake (phase4_harness.dart):
// - the sign-in and sign-out sync with 0, 1, 200, 201 and 401 follows;
// - the offline deal page with and without a copy, then a reconnect;
// - the offline settings queue across a restart and two accounts;
// - a follow made while the Following list loads is never dropped;
// - images are decoded at the size shown.
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug; run them with `--dart-define=QA_KNOWN_BUGS=true`.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/design_system/widgets/network_picture.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/follows/application/follow_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';
import 'package:sale_lagi_hai/features/settings/application/alert_prefs_providers.dart';

import '../helpers/fakes.dart';
import 'phase4_harness.dart';

const _onboarded = ShopperPreferences(onboarded: true, cityId: karachiId);

String _fakeBrand(int i) =>
    '00000000-0000-4000-00bb-${i.toString().padLeft(12, '0')}';

final _threads = brandBySlug('demo-threads')['id']! as String;

/// [ServerGateway] that records every `sync_guest_preferences` call, and
/// can hold the `brands` reads.
class _Recording extends ServerGateway {
  new(super.auth);

  final prefsCalls = <Map<String, Object?>>[];
  Completer<void>? holdBrands;

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    if (function == 'sync_guest_preferences') prefsCalls.add(Map.of(params));
    return await super.rpc(function, params);
  }

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    if (query.table == 'brands' && query.inList.containsKey('id')) {
      if (holdBrands case final h?) await h.future;
    }
    return await super.select(query);
  }

  int get followsSent => [
    for (final c in prefsCalls)
      ((c['brand_ids'] as List?)?.length ?? 0) +
          ((c['category_ids'] as List?)?.length ?? 0),
  ].fold(0, (a, b) => a + b);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  group('P4-F1: the sync at every follow count', () {
    for (final n in [0, 1, 200, 201, 401]) {
      testWidgets('$n follows: sign-in sends them all under the cap, with '
          'the city once; sign-out leaves a guest phone', (tester) async {
        final follows = [
          for (var i = 1; i < n; i++) _fakeBrand(i),
          // A real, active brand last, so it lands in the last chunk.
          if (n > 0) _threads,
        ];
        final j = Journey(
          saved: _onboarded.copyWith(brandIds: follows),
          backend: _Recording.new,
        );
        final server = j.server as _Recording;
        await j.pump(tester);
        await signInWithGoogle(tester);
        final a = j.auth.currentUser!.id;
        final expectedCalls = n == 0 ? 1 : (n / 200).ceil();
        expect(server.prefsCalls, hasLength(expectedCalls));
        expect(server.followsSent, n);
        for (final c in server.prefsCalls) {
          final size =
              ((c['brand_ids'] as List?)?.length ?? 0) +
              ((c['category_ids'] as List?)?.length ?? 0);
          expect(size, lessThanOrEqualTo(200));
        }
        expect(server.prefsCalls.first['city'], karachiId);
        expect(server.prefsCalls.first['lang'], 'en');
        expect(
          server.prefsCalls.skip(1).where((c) => c.containsKey('city')),
          isEmpty,
        );
        expect(server.profiles[a]?['home_city_id'], karachiId);
        if (n > 0) {
          expect(
            [for (final r in await server.rowsOf('follows', a)) r['brand_id']],
            [_threads],
            reason: 'the last chunk reached the account',
          );
        }
        expect(j.server.refused, isEmpty);

        // Sign out: everything goes up again, and the phone is cleared.
        server.prefsCalls.clear();
        j.router.go('/deal/${dealId(4)}');
        await tester.pumpAndSettle();
        await tapText(tester, 'Save');
        j.router.go('/profile');
        await tester.pumpAndSettle();
        await tapText(tester, 'Sign out');
        expect(j.auth.currentUser, isNull);
        expect(server.prefsCalls, hasLength(n == 0 ? 0 : (n / 200).ceil()));
        expect(server.followsSent, n);
        expect(j.preferences.brandIds, isEmpty);
        expect(j.container.read(savedDealsProvider), isEmpty);
        expect(j.store.values[accountOnPhoneKey], isNull);
        expect(j.logText, isNot(contains('Could not send the lists')));
      });
    }
  });

  group('P4-J1: the offline deal page', () {
    Future<InMemoryKeyValueStore> seenOnline(
      WidgetTester tester, {
      bool save = true,
    }) async {
      final store = InMemoryKeyValueStore();
      final first = Journey(saved: _onboarded, store: store);
      await first.pump(tester);
      if (save) {
        first.router.go('/deal/${dealId(4)}');
        await tester.pumpAndSettle();
        await tapText(tester, 'Save');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tapTab(tester, 'Saved');
      }
      await tester.pumpWidget(const SizedBox());
      return store;
    }

    testWidgets('a saved deal: its copy with the banner and its age, then '
        'the whole page once the network is back', (tester) async {
      final store = await seenOnline(tester);
      final j = Journey(saved: _onboarded, store: store);
      await j.pump(tester, online: false);
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      expect(find.text(dealTitle(4)), findsWidgets);
      expect(find.textContaining('No internet.'), findsOneWidget);
      expect(find.textContaining('Updated'), findsOneWidget);
      expect(
        find.text('Details, terms and outlets show when you are back online.'),
        findsOneWidget,
      );
      expect(find.textContaining('A made-up deal'), findsNothing);
      // Save and Share still work on the copy.
      expect(find.text('Remove from saved'), findsOneWidget);
      await tapText(tester, 'Share on WhatsApp');
      expect(j.links.opened.single, contains(dealTitle(4)));

      await j.setOnline(tester, online: true);
      await _settle(tester);
      expect(find.textContaining('No internet.'), findsNothing);
      expect(find.textContaining('A made-up deal'), findsOneWidget);
      expect(
        find.text('Details, terms and outlets show when you are back online.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a deal only seen on Home opens from the Home copy', (
      tester,
    ) async {
      final store = await seenOnline(tester, save: false);
      expect(
        store.values.keys.where((k) => k.startsWith('cache.home.')),
        isNotEmpty,
      );
      final j = Journey(saved: _onboarded, store: store);
      await j.pump(tester, online: false);
      j.router.go('/deal/${dealId(1)}');
      await tester.pumpAndSettle();
      expect(find.text(dealTitle(1)), findsWidgets);
      expect(find.textContaining('Updated'), findsOneWidget);
    });

    testWidgets('no copy: the offline error, and Try again works once the '
        'network is back', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester, online: false);
      j.router.go('/deal/${dealId(8)}');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No internet connection. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      await j.setOnline(tester, online: true);
      await tapText(tester, 'Try again');
      expect(find.text(dealTitle(8)), findsWidgets);
      expect(find.textContaining('A made-up deal'), findsOneWidget);
    });

    testWidgets('P4-R2-2: connected but the server unreachable (Wi-Fi '
        'without internet): once it answers again, the deal page loads in '
        'full', (tester) async {
      final store = await seenOnline(tester);
      final j = Journey(saved: _onboarded, store: store);
      await j.pump(tester);
      // The phone reports online; requests fail as offline.
      j.server.offline = true;
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      expect(find.textContaining('Updated'), findsOneWidget);
      j.server.offline = false;
      // Leave and open it again: no network change ever arrives.
      j.router.go('/');
      await tester.pumpAndSettle();
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      // Today: the copy (and "No internet.") stays for the whole session;
      // the page has no Try again or pull to refresh.
      expect(find.textContaining('A made-up deal'), findsOneWidget);
    });

    // Was "as it is today" (the copy sticking); since the fix it checks
    // that opening the page again asks the server again.
    testWidgets('P4-R2-2: the copy does not stick while the network status '
        'never changes', (tester) async {
      final store = await seenOnline(tester);
      final j = Journey(saved: _onboarded, store: store);
      await j.pump(tester);
      j.server.offline = true;
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      j.server.offline = false;
      j.router.go('/');
      await tester.pumpAndSettle();
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      expect(find.textContaining('Updated'), findsNothing);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('a copy is never shown when the deal is gone (not offline)', (
      tester,
    ) async {
      final store = await seenOnline(tester);
      // The deal is still saved and cached, but the server says not found.
      final j = Journey(
        saved: _onboarded,
        store: store,
        backend: _GoneDeal.new,
      );
      await j.pump(tester);
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      expect(find.textContaining('Updated'), findsNothing);
      expect(find.byType(DealDetailScreen), findsOneWidget);
    });
  });

  group('4.9-N6: the offline settings queue', () {
    Future<void> openNotifications(WidgetTester tester, Journey j) async {
      j.router.go('/settings/notifications');
      await tester.pumpAndSettle();
    }

    // One queue per account since the P4-R2-1 fix.
    Map<String, Object?>? queue(Journey j, String user) {
      final raw = j.store.values[alertPrefsQueueKeyFor(user)];
      return raw == null ? null : jsonDecode(raw) as Map<String, Object?>;
    }

    testWidgets('a change made offline survives a restart and is sent when '
        'the network is back', (tester) async {
      final store = InMemoryKeyValueStore();
      final j = Journey(saved: _onboarded, store: store);
      await j.pump(tester);
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      await openNotifications(tester, j);
      await j.setOnline(tester, online: false);
      await tapText(tester, 'Brands you follow');
      expect(
        find.text(
          'Saved on this phone. It will be sent when you are back online.',
        ),
        findsOneWidget,
      );
      expect(queue(j, a)?['user'], a);
      expect((queue(j, a)?['changes'] as Map?)?['followed_brands'], false);
      expect(j.server.prefsOf(a)?['followed_brands'], true);

      // Restart, still offline, then online.
      await tester.pumpWidget(const SizedBox());
      final again = Journey(
        saved: _onboarded,
        store: store,
        auth: j.auth,
        backend: (_) => j.server,
      );
      await again.pump(tester, online: false);
      await openNotifications(tester, again);
      expect(queue(again, a), isNotNull, reason: 'still waiting');
      await again.setOnline(tester, online: true);
      await _settle(tester);
      // The page reloads on its own, or on Try again.
      if (find.text('Try again').evaluate().isNotEmpty) {
        await tapText(tester, 'Try again');
      }
      await _settle(tester);
      expect(j.server.prefsOf(a)?['followed_brands'], false);
      expect(queue(again, a), isNull);
      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Brands you follow'),
      );
      expect(tile.value, isFalse);
    });

    testWidgets("P4-R2-1: another account never receives A's queued change, "
        'and A still gets it when A is back', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      await openNotifications(tester, j);
      await j.setOnline(tester, online: false);
      await tapText(tester, 'Brands you follow');
      expect(queue(j, a)?['user'], a);
      // A signs out offline; B signs in online and changes a setting
      // offline too.
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');
      await j.setOnline(tester, online: true);
      await signInWithPhone(tester, phoneB);
      final b = j.auth.currentUser!.id;
      await openNotifications(tester, j);
      expect(j.server.prefsOf(b)?['followed_brands'], true);
      final tile = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Brands you follow'),
      );
      expect(tile.value, isTrue, reason: "B doesn't see A's queued change");
      await j.setOnline(tester, online: false);
      await tapText(tester, 'Offers for your cards');
      await j.setOnline(tester, online: true);
      await _settle(tester);
      expect(j.server.prefsOf(b)?['my_cards'], false);
      expect(j.server.prefsOf(b)?['followed_brands'], true);
      // A again, online.
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');
      await signInWithGoogle(tester);
      expect(j.auth.currentUser!.id, a);
      await openNotifications(tester, j);
      await _settle(tester);
      expect(
        j.server.prefsOf(a)?['followed_brands'],
        false,
        reason: "A's change made offline reaches A's account",
      );
    });

    // Was "as it is today" (A's change landing in B's account); since the
    // fix it checks the opposite.
    testWidgets("P4-R2-1: A's queued change is not sent into B's account "
        'when B opens Notifications, and stays queued for A', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester);
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      await openNotifications(tester, j);
      await j.setOnline(tester, online: false);
      await tapText(tester, 'Brands you follow');
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');
      await j.setOnline(tester, online: true);
      await signInWithPhone(tester, phoneB);
      final b = j.auth.currentUser!.id;
      expect(j.server.prefsOf(b), isNull, reason: 'B has not loaded yet');
      await openNotifications(tester, j);
      await _settle(tester);
      expect(j.server.prefsOf(b)?['followed_brands'], true);
      expect(j.server.prefsOf(a)?['followed_brands'], true);
      expect((queue(j, a)?['changes'] as Map?)?['followed_brands'], false);
    });
  });

  group('4.8 BUG-7: dropping follows of what is no longer offered', () {
    testWidgets('a follow made while the list loads is kept', (tester) async {
      final j = Journey(
        saved: _onboarded.copyWith(brandIds: [_threads, _fakeBrand(1)]),
        backend: _Recording.new,
      );
      final server = j.server as _Recording;
      await j.pump(tester);
      server.holdBrands = Completer<void>();
      await tapTab(tester, 'Alerts');
      // While the brands load, follow another one.
      final karahi = brandBySlug('demo-karahi-house')['id']! as String;
      await j.container
          .read(preferencesProvider.notifier)
          .addFollows(brandIds: [karahi]);
      await tester.pump();
      server.holdBrands!.complete();
      await _settle(tester);
      expect(j.preferences.brandIds, contains(karahi));
      expect(j.preferences.brandIds, contains(_threads));
      expect(j.preferences.brandIds, isNot(contains(_fakeBrand(1))));
    });

    testWidgets('a failed load drops nothing', (tester) async {
      final j = Journey(
        saved: _onboarded.copyWith(brandIds: [_threads, _fakeBrand(1)]),
      );
      await j.pump(tester, online: false);
      await tapTab(tester, 'Alerts');
      j.container.read(followedBrandsProvider);
      await _settle(tester);
      expect(j.preferences.brandIds, [_threads, _fakeBrand(1)]);
    });
  });

  group('P4-P1: images are decoded at the size shown', () {
    testWidgets('NetworkPicture asks for the width it is laid out at × the '
        'pixel ratio', (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 200,
              height: 100,
              child: NetworkPicture(
                'https://example.invalid/a.jpg',
                fallback: SizedBox(),
              ),
            ),
          ),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).width, 600);
      // Drain the failed network load.
      await tester.pumpAndSettle();
      tester.takeException();
    });
  });

  group('regressions', () {
    testWidgets('sign-in with an account holding 500 follows, then sign out: '
        'all of them go back up in chunks', (tester) async {
      final j = Journey(saved: _onboarded, backend: _Recording.new);
      final server = j.server as _Recording;
      await j.pump(tester);
      await j.auth.signInWithGoogle();
      final a = j.auth.currentUser!.id;
      for (var i = 1; i <= 500; i++) {
        await server.demo.insert('follows', {
          'user_id': a,
          'brand_id': _fakeBrand(i),
        });
      }
      await j.container.read(guestSyncProvider)();
      expect(j.preferences.brandIds, hasLength(500));
      server.prefsCalls.clear();
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');
      expect(server.prefsCalls, hasLength(3));
      expect(j.preferences.brandIds, isEmpty);
    });

    testWidgets('the Urdu app bar at 200% is tall enough for its title', (
      tester,
    ) async {
      final j = Journey(saved: _onboarded);
      await j.pump(
        tester,
        device: const Locale('ur'),
        size: const Size(360, 800),
        textScale: 2,
      );
      for (final r in ['/settings', '/settings/notifications', '/cards']) {
        j.router.go(r);
        await tester.pumpAndSettle();
        final bar = tester.getRect(find.byType(AppBar).last);
        final title = tester.getRect(
          find
              .descendant(
                of: find.byType(AppBar).last,
                matching: find.byType(Text),
              )
              .first,
        );
        expect(title.bottom, lessThanOrEqualTo(bar.bottom + 0.5), reason: r);
        expect(tester.takeException(), isNull, reason: r);
      }
    });
  });

  setUp(rootBundle.clear);
}

/// The server says deal 4 is gone (not found), while online.
class _GoneDeal extends ServerGateway {
  new(super.auth);

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    final rows = await super.select(query);
    if (query.table == 'deal_cards' || query.table == 'deals') {
      return [
        for (final r in rows)
          if (r['id'] != dealId(4)) r,
      ];
    }
    return rows;
  }
}
