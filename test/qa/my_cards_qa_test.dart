// QA (sub-phase 4.7 gate): My Cards. Stored cards the catalog no longer
// lists, double taps in the add sheet, system Back in the sheet, adding
// while the stored list is still loading, StoredStringList under storage
// errors, offline, and screen-reader labels.
//
// "QA BUG" tests fail until the bug in docs/qa/4.7.md is fixed; S4
// findings are skipped with their bug id.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/cards/application/my_cards_providers.dart';
import 'package:sale_lagi_hai/features/cards/presentation/my_cards_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/fakes.dart';

String _bank(String slug) =>
    demoBanks.firstWhere((b) => b['slug'] == slug)['id']! as String;

String _card(String bank, String slug) =>
    demoCardProducts.firstWhere(
          (p) => p['bank_id'] == _bank(bank) && p['slug'] == slug,
        )['id']!
        as String;

/// A card product id the catalog doesn't (or no longer does) list.
const _retired = '00000000-0000-4000-0005-0000000000ff';

/// The demo backend, with an offline switch.
final class SwitchableGateway implements BackendGateway {
  final _demo = DemoGateway();
  bool offline = false;

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    if (offline) throw const OfflineFailure();
    return await _demo.select(query);
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    if (offline) throw const OfflineFailure();
    return await _demo.rpc(function, params);
  }

  @override
  Future<void> insert(String table, Map<String, Object?> row) =>
      _demo.insert(table, row);

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      _demo.delete(table, match);
}

/// The demo backend, recording every insert.
final class RecordingGateway implements BackendGateway {
  final _demo = DemoGateway();
  final inserts = <(String, Map<String, Object?>)>[];

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) =>
      _demo.select(query);

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) => _demo.rpc(function, params);

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {
    inserts.add((table, row));
    await _demo.insert(table, row);
  }

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      _demo.delete(table, match);
}

/// A store whose first read is held, then answered with what was stored
/// when it was asked.
final class SlowFirstReadStore implements KeyValueStore {
  final inner = InMemoryKeyValueStore();
  final firstRead = Completer<void>();
  bool _first = true;

  @override
  Future<String?> getString(String key) async {
    final value = inner.values[key];
    if (_first) {
      _first = false;
      await firstRead.future;
    }
    return value;
  }

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

/// A store whose first [failures] reads throw (a storage error).
final class FlakyReadStore implements KeyValueStore {
  new(this.failures);

  int failures;
  final inner = InMemoryKeyValueStore();

  @override
  Future<String?> getString(String key) async {
    if (failures > 0) {
      failures--;
      throw StateError('storage unavailable');
    }
    return inner.values[key];
  }

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

void main() {
  final hblCredit = _card('hbl', 'visa-credit');
  final hblDebit = _card('hbl', 'visa-debit');

  Future<Harness> app(
    WidgetTester tester, {
    List<String> stored = const [],
    BackendGateway? backend,
  }) async {
    final h = Harness(
      backend: backend,
      saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
    );
    if (stored.isNotEmpty) h.store.values[myCardsKey] = jsonEncode(stored);
    await h.pump(tester);
    h.router.go('/cards');
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> openSheetAt(WidgetTester tester, String bankShortName) async {
    await tester.tap(find.text('Add a card').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(bankShortName).last);
    await tester.pumpAndSettle();
  }

  // QA BUG 4.7-A1 (S3): a stored card the catalog no longer lists (a
  // product the bank retired, or a demo id from before this build) is not
  // shown, so it can't be removed. It still counts toward the 20, the
  // page shows "Your cards" with nothing under it, and the empty state
  // with Add a card never comes back (my_cards_screen.dart:78-92).
  testWidgets('QA BUG 4.7-A1: a card no longer in the catalog can still be '
      'removed (or is dropped)', (tester) async {
    final h = await app(tester, stored: [_retired]);
    final removable = find.byTooltip(RegExp('^Remove'));
    final empty = find.text(
      'Add your cards to see the discounts they get you.',
    );
    expect(
      removable.evaluate().isNotEmpty || empty.evaluate().isNotEmpty,
      isTrue,
      reason: 'neither a row to remove nor the empty state',
    );
    expect(
      h.container.read(myCardsProvider),
      isNot(contains(_retired)),
      reason: 'it still counts toward the limit',
    );
  });

  // Checked: two quick taps on a card type pop the sheet once (the second
  // add finishes after the sheet is gone).
  testWidgets('a double tap on a card type adds it once and stays on My '
      'Cards', (tester) async {
    await app(tester);
    await openSheetAt(tester, 'HBL');
    final card = find.text('Visa Credit');
    await tester.tap(card);
    await tester.tap(card, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(MyCardsScreen), findsOneWidget);
    expect(find.byTooltip(RegExp('^Remove HBL Visa Credit')), findsOneWidget);
  });

  // QA BUG 4.7-A3 (S4): system Back on the card-type step closes the
  // sheet instead of returning to the banks (no PopScope).
  testWidgets(
    'QA BUG 4.7-A3: system Back on the card types returns to the banks',
    (tester) async {
      await app(tester);
      await openSheetAt(tester, 'HBL');
      expect(find.byType(AddCardSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AddCardSheet), findsOneWidget);
      expect(find.text('Which bank?'), findsOneWidget);
    },
  );

  testWidgets('already-added cards are marked, not offered, and say so to '
      'screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await app(tester, stored: [hblCredit]);
    await tester.tap(find.text('Add a card').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('HBL').last);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Already added'), findsOneWidget);
    // Tapping the added one does nothing.
    await tester.tap(find.text('Visa Credit').last);
    await tester.pumpAndSettle();
    expect(find.byType(AddCardSheet), findsOneWidget);
    handle.dispose();
  });

  testWidgets('offline: stored cards keep the page usable; the lists show '
      'Try again and recover', (tester) async {
    final backend = SwitchableGateway()..offline = true;
    await app(tester, stored: [hblDebit], backend: backend);
    expect(tester.takeException(), isNull);
    expect(find.byType(InlineErrorBanner), findsWidgets);
    backend.offline = false;
    await tester.tap(find.text('Try again').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Visa Debit'), findsWidgets);
  });

  testWidgets('the remove button names the card for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await app(tester, stored: [hblCredit]);
    expect(find.byTooltip(RegExp('^Remove HBL Visa Credit')), findsOneWidget);
    handle.dispose();
  });

  group('StoredStringList via myCardsProvider', () {
    late MemoryLogSink logs;

    ProviderContainer container(KeyValueStore store) {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          loggerProvider.overrideWithValue(AppLogger(sinks: [logs])),
          backendGatewayProvider.overrideWithValue(DemoGateway()),
          authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
          savedPreferencesProvider.overrideWithValue(
            const ShopperPreferences(onboarded: true, cityId: karachiId),
          ),
        ],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() => logs = MemoryLogSink());

    test('a card added while the list loads is kept with the stored ones, '
        'on the phone too', () async {
      final store = SlowFirstReadStore();
      store.inner.values[myCardsKey] = jsonEncode([hblDebit]);
      final c = container(store)..listen(myCardsProvider, (_, _) {});
      final added = c.read(myCardsProvider.notifier).add(hblCredit);
      store.firstRead.complete();
      expect(await added, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(myCardsProvider), [hblDebit, hblCredit]);
      expect(jsonDecode(store.inner.values[myCardsKey]!), [
        hblDebit,
        hblCredit,
      ]);
    });

    // QA BUG 4.7-A4 (S4): `add` decides "added" on the in-memory list.
    // While the stored list is still loading that list is empty, so with
    // 20 stored cards a 21st is reported added (and mirrored to the
    // account) but dropped when replayed onto the stored 20.
    test(
      'QA BUG 4.7-A4: adding while the list loads respects the 20 stored',
      () async {
        final store = SlowFirstReadStore();
        final twenty = [
          for (var i = 0; i < 20; i++)
            '00000000-0000-4000-0005-${i.toString().padLeft(12, '0')}',
        ];
        store.inner.values[myCardsKey] = jsonEncode(twenty);
        final c = container(store)..listen(myCardsProvider, (_, _) {});
        final added = c.read(myCardsProvider.notifier).add(hblCredit);
        store.firstRead.complete();
        await Future<void>.delayed(Duration.zero);
        expect(await added, isFalse, reason: 'the list was already full');
      },
    );

    // QA BUG 4.7-A5 (S4): while storage can't be read, changes stay in
    // memory; when a later change finds it readable again, only that
    // change is applied to the stored copy, and the earlier ones vanish
    // (stored_string_list.dart:108-114).
    test('QA BUG 4.7-A5: changes made while storage was unreadable are kept '
        'once it reads again', () async {
      final store = FlakyReadStore(2);
      final c = container(store)..listen(myCardsProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero); // first read fails
      await c.read(myCardsProvider.notifier).add(hblCredit); // fails again
      await c.read(myCardsProvider.notifier).add(hblDebit); // reads now
      expect(c.read(myCardsProvider), [hblCredit, hblDebit]);
      expect(jsonDecode(store.inner.values[myCardsKey]!), [
        hblCredit,
        hblDebit,
      ]);
    });

    test('an unreadable store is never overwritten, and logs say only the '
        'error type', () async {
      final store = FlakyReadStore(100)
        ..inner.values[myCardsKey] = jsonEncode([hblDebit]);
      final c = container(store)..listen(myCardsProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await c.read(myCardsProvider.notifier).add(hblCredit);
      expect(jsonDecode(store.inner.values[myCardsKey]!), [hblDebit]);
      expect(logs.records, isNotEmpty);
      for (final r in logs.records) {
        final text = '${r.message} ${r.context} ${r.errorText}';
        expect(text, isNot(contains(hblCredit)));
        expect(text, isNot(contains(hblDebit)));
      }
    });

    test('a corrupt file reads as none and its contents never reach the '
        'logs', () async {
      final store = InMemoryKeyValueStore()
        ..values[myCardsKey] = '["$hblDebit", broken';
      final c = container(store)..listen(myCardsProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(myCardsProvider), isEmpty);
      for (final r in logs.records) {
        expect(
          '${r.message} ${r.context} ${r.errorText}',
          isNot(contains(hblDebit)),
        );
      }
    });

    test('stored entries beyond 20 and odd values are dropped', () async {
      final store = InMemoryKeyValueStore()
        ..values[myCardsKey] = jsonEncode([
          '',
          42,
          null,
          for (var i = 0; i < 30; i++) 'id-$i',
        ]);
      final c = container(store)..listen(myCardsProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(c.read(myCardsProvider), hasLength(20));
      expect(c.read(myCardsProvider).first, 'id-0');
    });
  });

  // QA BUG 4.7-A6 (S3): the guest sync reads `myCardsProvider` right after
  // sign-in. If My Cards hasn't been opened since the app started, that
  // first read is the empty list the provider starts with (the stored copy
  // is still loading), so the guest's cards are never copied into
  // user_cards, and card alerts, which the planner builds from user_cards,
  // never come (auth_providers.dart:76-77).
  test('QA BUG 4.7-A6: cards added as a guest reach the account at '
      'sign-in, even when My Cards was not opened this session', () async {
    final store = InMemoryKeyValueStore()
      ..values[myCardsKey] = jsonEncode([hblCredit]);
    final backend = RecordingGateway();
    final auth = DemoAuthRepository();
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
    await auth.sendPhoneCode('+923001234567');
    await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
    await c.read(guestSyncProvider)();
    expect(
      backend.inserts
          .where((i) => i.$1 == 'user_cards')
          .map((i) => i.$2['card_product_id']),
      [hblCredit],
    );
  });
}
