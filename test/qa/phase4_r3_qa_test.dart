// QA, Phase 4 gate round 3 (5e6b6bb): the P4-R2-1 (per-account settings
// queue) and P4-R2-2 (the offline copy never sticks, Try again on its
// banner) fixes, and regressions around them:
// - the queue across sign-out and sign-in of two accounts, a restart,
//   Clear everything and account deletion: nothing left behind, nothing
//   sent under the wrong account;
// - a flush still in flight when the account changes;
// - a queued field the server refuses no longer blocks a later change;
// - Try again on the deal copy's banner, and its accessibility in English
//   and Urdu, light and dark, at 100% and 200%.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/settings/application/alert_prefs_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../helpers/fakes.dart';
import 'phase4_harness.dart';

const _onboarded = ShopperPreferences(onboarded: true, cityId: karachiId);

/// [ServerGateway] whose `update_alert_prefs` can be held, can fail as
/// offline on its own ([stuck]: the phone says online, the server can't be
/// reached), or refuse a field ([refuse]). Records who each call was for.
class _Prefs extends ServerGateway {
  new(super.auth);

  Completer<void>? hold;
  bool stuck = false;
  String? refuse;
  final updates = <String>[];

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    if (function == 'update_alert_prefs') {
      final who = auth.currentUser?.id;
      if (hold case final h?) {
        // The request already left with the caller's token: it is applied
        // as that caller, whoever is signed in when it lands.
        await h.future;
        if (prefsOf(who!) case final row?) {
          for (final MapEntry(:key, :value) in params.entries) {
            if (value != null) row[key] = value;
          }
          updates.add('$who ${params.keys.toList()..sort()}');
          return [Map.of(row)];
        }
      }
      if (stuck) throw const SocketException('unreachable');
      if (refuse case final f? when params.containsKey(f)) {
        throw const PostgrestException(message: 'check', code: '23514');
      }
      updates.add('$who ${params.keys.toList()..sort()}');
    }
    return await super.rpc(function, params);
  }
}

Future<void> _openNotifications(WidgetTester tester, Journey j) async {
  j.router.go('/settings/notifications');
  await tester.pumpAndSettle();
}

Map<String, Object?>? _queue(Journey j, String user) {
  final raw = j.store.values[alertPrefsQueueKeyFor(user)];
  return raw == null ? null : jsonDecode(raw) as Map<String, Object?>;
}

Iterable<String> _queueKeys(Journey j) =>
    j.store.values.keys.where((k) => k.startsWith(alertPrefsQueueKey));

bool _switch(WidgetTester tester, String label) => tester
    .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label))
    .value;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUp(rootBundle.clear);

  group('P4-R2-1: the queue belongs to its account', () {
    testWidgets('A and B each queue offline on one phone; each change goes '
        'to its own account only, when that account is back', (tester) async {
      final j = Journey(saved: _onboarded, backend: _Prefs.new);
      final server = j.server as _Prefs;
      await j.pump(tester);
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      await _openNotifications(tester, j);
      await j.setOnline(tester, online: false);
      await tapText(tester, 'Brands you follow');
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');

      // B, online: untouched by A's queue.
      await j.setOnline(tester, online: true);
      await signInWithPhone(tester, phoneB);
      final b = j.auth.currentUser!.id;
      await _openNotifications(tester, j);
      await _settle(tester);
      expect(server.updates, isEmpty, reason: 'nothing sent as B');
      expect(j.server.prefsOf(b)?['followed_brands'], true);
      expect(_switch(tester, 'Brands you follow'), isTrue);
      expect(_queue(j, a)?['changes'], {'followed_brands': false});

      // B queues its own offline, then signs out offline.
      await j.setOnline(tester, online: false);
      await tapText(tester, 'Offers for your cards');
      expect(_queue(j, b)?['changes'], {'my_cards': false});
      expect(_queue(j, a)?['changes'], {'followed_brands': false});
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');

      // A again, online: only A's goes, as A.
      await j.setOnline(tester, online: true);
      await signInWithGoogle(tester);
      expect(j.auth.currentUser!.id, a);
      await _openNotifications(tester, j);
      await _settle(tester);
      expect(server.updates, ['$a [followed_brands]']);
      expect(j.server.prefsOf(a)?['followed_brands'], false);
      expect(j.server.prefsOf(a)?['my_cards'], true);
      expect(_switch(tester, 'Brands you follow'), isFalse);
      expect(_queue(j, a), isNull);
      expect(_queue(j, b), isNotNull, reason: "B's still waits for B");

      // B again: B's goes, as B.
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');
      await signInWithPhone(tester, phoneB);
      final b2 = j.auth.currentUser!.id;
      // The demo sign-in makes a new account per phone sign-in.
      if (b2 == b) {
        await _openNotifications(tester, j);
        await _settle(tester);
        expect(server.updates.last, '$b [my_cards]');
        expect(_queue(j, b), isNull);
      } else {
        await _openNotifications(tester, j);
        await _settle(tester);
        expect(
          server.updates.where((u) => u.startsWith(b2)),
          isEmpty,
          reason: "a third account never gets B's queue",
        );
      }
    });

    testWidgets('a flush still in flight when the account changes neither '
        "touches the next account's queue nor sends as it", (tester) async {
      final j = Journey(saved: _onboarded, backend: _Prefs.new);
      final server = j.server as _Prefs;
      await j.pump(tester);
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      await _openNotifications(tester, j);
      await j.setOnline(tester, online: false);
      await tapText(tester, 'Brands you follow');
      // Back online, A's flush starts and is held at the server.
      server.hold = Completer<void>();
      await j.setOnline(tester, online: true);
      // A signs out and B signs in and queues offline meanwhile.
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');
      await signInWithPhone(tester, phoneB);
      final b = j.auth.currentUser!.id;
      await _openNotifications(tester, j);
      await j.setOnline(tester, online: false);
      await tapText(tester, 'Offers for your cards');
      expect(_queue(j, b)?['changes'], {'my_cards': false});
      // A's call completes now.
      server.hold!.complete();
      server.hold = null;
      await _settle(tester);
      expect(_queue(j, b)?['changes'], {'my_cards': false});
      expect(
        server.updates.where((u) => u.startsWith(b)),
        isEmpty,
        reason: 'B is offline: nothing of B was sent',
      );
      expect(j.server.prefsOf(b)?['followed_brands'], true);
      // A's own change: it was sent as A (the call left before sign-out).
      expect(j.server.prefsOf(a)?['followed_brands'], false);
    });

    testWidgets('a restart offline keeps the queue; online, it is sent and '
        'removed', (tester) async {
      final store = InMemoryKeyValueStore();
      final j = Journey(saved: _onboarded, store: store, backend: _Prefs.new);
      await j.pump(tester);
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      await _openNotifications(tester, j);
      await j.setOnline(tester, online: false);
      await tapText(tester, 'Brands you follow');
      await tester.pumpWidget(const SizedBox());

      final again = Journey(
        saved: _onboarded,
        store: store,
        auth: j.auth,
        backend: (_) => j.server,
      );
      await again.pump(tester, online: false);
      await _openNotifications(tester, again);
      expect(_queue(again, a), isNotNull);
      await again.setOnline(tester, online: true);
      await _settle(tester);
      if (find.text('Try again').evaluate().isNotEmpty) {
        await tapText(tester, 'Try again');
      }
      expect(j.server.prefsOf(a)?['followed_brands'], false);
      expect(_queue(again, a), isNull);
      expect(_switch(tester, 'Brands you follow'), isFalse);
    });

    for (final how in ['clear', 'delete']) {
      testWidgets('$how: no queue is left behind on the phone', (tester) async {
        final j = Journey(saved: _onboarded, backend: _Prefs.new);
        await j.pump(tester);
        await signInWithGoogle(tester);
        final a = j.auth.currentUser!.id;
        await _openNotifications(tester, j);
        await j.setOnline(tester, online: false);
        await tapText(tester, 'Brands you follow');
        expect(_queueKeys(j), [alertPrefsQueueKeyFor(a)]);
        // Still offline, with the change pending.
        if (how == 'clear') {
          j.router.go('/settings/privacy');
          await tester.pumpAndSettle();
          await tapText(tester, 'Clear everything on this phone');
          await tapText(tester, 'Clear');
        } else {
          j.router.go('/profile/account/delete');
          await tester.pumpAndSettle();
          await tapText(tester, 'Delete my account');
          await tester.tap(find.text('Delete my account').last);
          await tester.pumpAndSettle();
        }
        expect(_queueKeys(j), isEmpty);
        expect(
          j.store.values.keys.where((k) => !k.startsWith('cache.')),
          isEmpty,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('sign-out keeps only the own account’s queue, under its id', (
      tester,
    ) async {
      final j = Journey(saved: _onboarded, backend: _Prefs.new);
      await j.pump(tester);
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      await _openNotifications(tester, j);
      await j.setOnline(tester, online: false);
      await tapText(tester, 'Brands you follow');
      j.router.go('/profile');
      await tester.pumpAndSettle();
      await tapText(tester, 'Sign out');
      expect(_queueKeys(j), [alertPrefsQueueKeyFor(a)]);
      expect(_queue(j, a), {
        'user': a,
        'changes': {'followed_brands': false},
      });
      // The guest view of Notifications sends nothing.
      await j.setOnline(tester, online: true);
      await _openNotifications(tester, j);
      expect((j.server as _Prefs).updates, isEmpty);
    });
  });

  group('the blocked-changes note: a refused queued field', () {
    testWidgets('no longer blocks a later change, and is dropped', (
      tester,
    ) async {
      final j = Journey(saved: _onboarded, backend: _Prefs.new);
      final server = j.server as _Prefs;
      await j.pump(tester);
      await signInWithGoogle(tester);
      final a = j.auth.currentUser!.id;
      await _openNotifications(tester, j);
      await j.setOnline(tester, online: false);
      await tapText(tester, 'Brands you follow');
      // A flaky reconnect: the phone says online, the flush fails as
      // offline, so the queue stays.
      server.stuck = true;
      await j.setOnline(tester, online: true);
      server.offline = false;
      await _settle(tester);
      expect(_queue(j, a), isNotNull);
      // Now the server answers, but refuses the queued field.
      server
        ..stuck = false
        ..refuse = 'followed_brands';
      await tapText(tester, 'Offers for your cards');
      await _settle(tester);
      expect(j.server.prefsOf(a)?['my_cards'], false, reason: 'saved');
      expect(find.text("Couldn't save that. Try again."), findsNothing);
      expect(_queue(j, a), isNull, reason: 'the refused field is dropped');
      expect(j.server.prefsOf(a)?['followed_brands'], true);
      expect(_switch(tester, 'Brands you follow'), isTrue);
      expect(_switch(tester, 'Offers for your cards'), isFalse);
    });
  });

  group('P4-R2-2: Try again on the deal copy', () {
    Future<InMemoryKeyValueStore> savedOnline(WidgetTester tester) async {
      final store = InMemoryKeyValueStore();
      final first = Journey(saved: _onboarded, store: store);
      await first.pump(tester);
      first.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapTab(tester, 'Saved');
      await tester.pumpWidget(const SizedBox());
      return store;
    }

    testWidgets('still unreachable: the copy again; reachable: the full page, '
        'without leaving it', (tester) async {
      final store = await savedOnline(tester);
      final j = Journey(saved: _onboarded, store: store);
      await j.pump(tester);
      j.server.offline = true; // the phone says online
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      expect(find.byType(OfflineBanner), findsOneWidget);
      await tapText(tester, 'Try again');
      expect(find.textContaining('Updated'), findsOneWidget);
      expect(tester.takeException(), isNull);
      j.server.offline = false;
      await tapText(tester, 'Try again');
      expect(find.byType(OfflineBanner), findsNothing);
      expect(find.textContaining('A made-up deal'), findsOneWidget);
      // Saved state survives the reloads.
      expect(find.text('Remove from saved'), findsOneWidget);
    });

    testWidgets('the Home offline banner has no Try again', (tester) async {
      final j = Journey(saved: _onboarded);
      await j.pump(tester, online: false);
      final banner = tester.widget<OfflineBanner>(find.byType(OfflineBanner));
      expect(banner.onRetry, isNull);
    });

    for (final locale in AppLocales.supported) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          final mode =
              '${locale.languageCode} ${brightness.name} '
              '${(scale * 100).round()}%';
          testWidgets('$mode: the copy with its Try again meets the '
              'guidelines, with no overflow', (tester) async {
            final store = await savedOnline(tester);
            final handle = tester.ensureSemantics();
            final j = Journey(saved: _onboarded, store: store);
            await j.pump(
              tester,
              device: locale,
              size: const Size(360, 800),
              textScale: scale,
              platformBrightness: brightness,
              online: false,
            );
            j.router.go('/deal/${dealId(4)}');
            await tester.pumpAndSettle();
            expect(find.byType(OfflineBanner), findsOneWidget);
            expect(tester.takeException(), isNull);
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            final retry = find.descendant(
              of: find.byType(OfflineBanner),
              matching: find.byType(TextButton),
            );
            expect(retry, findsOneWidget);
            final size = tester.getSize(retry);
            expect(size.height, greaterThanOrEqualTo(48));
            // Inside the screen, in either direction.
            final r = tester.getRect(retry);
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right, lessThanOrEqualTo(360));
            handle.dispose();
          });
        }
      }
    }

    // Was "as it is today" (the overflow); since the fix it checks that
    // the banner fits and Try again is on screen.
    testWidgets('P4-R3-1: in Urdu at 200% the banner fits and Try again is in '
        'view', (tester) async {
      final store = await savedOnline(tester);
      final j = Journey(saved: _onboarded, store: store);
      await j.pump(
        tester,
        device: AppLocales.urdu,
        size: const Size(360, 800),
        textScale: 2,
        online: false,
      );
      j.router.go('/deal/${dealId(4)}');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final retry = find.descendant(
        of: find.byType(OfflineBanner),
        matching: find.byType(TextButton),
      );
      final r = tester.getRect(retry);
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(360));
      // The message has the banner's width (it wraps over several lines
      // at 200%, as it should), not the sliver beside a wide button.
      final message = find.descendant(
        of: find.byType(OfflineBanner),
        matching: find.textContaining('انٹرنیٹ'),
      );
      expect(tester.getSize(message).width, greaterThan(250));
    });
  });
}
