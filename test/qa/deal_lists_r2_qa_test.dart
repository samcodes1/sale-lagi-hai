// QA, sub-phases 4.4 and 4.5 round 2: the new `StoredStringList` (saved
// deals) under a slow or failing store, local outlets with mixed targets,
// and the now auto-disposed deal lists on brand pages (docs/qa/4.4.md,
// docs/qa/4.5.md, "Round 2").
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug; run them with `--dart-define=QA_KNOWN_BUGS=true`.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/deals/data/backend_deal_repository.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/fakes.dart';
import 'qa_backend_rules.dart';

String _deal(int n) => demoDeals.firstWhere((d) => d.n == n).id;

/// The saved file: reads can fail [failReads] times, or wait for [gate].
final class _Store implements KeyValueStore {
  new(this.inner);

  final InMemoryKeyValueStore inner;
  int failReads = 0;
  Completer<void>? gate;
  int writes = 0;

  @override
  Future<String?> getString(String key) async {
    if (key == savedDealsKey) {
      if (failReads > 0) {
        failReads--;
        throw PlatformException(code: 'io', message: 'saved.v1 ["secret"]');
      }
      if (gate case final g?) await g.future;
    }
    return await inner.getString(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    if (key == savedDealsKey) writes++;
    await inner.setString(key, value);
  }

  @override
  Future<void> remove(String key) => inner.remove(key);

  @override
  Future<Set<String>> keys() => inner.keys();

  @override
  Future<void> clear() => inner.clear();
}

void main() {
  group('saved deals on a slow or failing store', () {
    late InMemoryKeyValueStore disk;
    late _Store store;
    late MemoryLogSink logs;

    ProviderContainer container() {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          loggerProvider.overrideWithValue(AppLogger(sinks: [logs])),
          backendGatewayProvider.overrideWithValue(
            RulesGateway(DemoAuthRepository()),
          ),
          authRepositoryProvider.overrideWithValue(DemoAuthRepository()),
          savedPreferencesProvider.overrideWithValue(
            const ShopperPreferences(onboarded: true),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<List<String>> onDiskAfterRestart() async {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(disk),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          savedPreferencesProvider.overrideWithValue(
            const ShopperPreferences(onboarded: true),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      final saved = c.read(savedDealsProvider);
      return saved;
    }

    setUp(() {
      disk = InMemoryKeyValueStore();
      store = _Store(disk);
      logs = MemoryLogSink();
    });

    test('a save tapped while the file is still loading is kept '
        '(round-1 BUG-2)', () async {
      await disk.setString(savedDealsKey, '["${_deal(1)}"]');
      store.gate = Completer();
      final c = container()..read(savedDealsProvider);
      await c.read(savedDealsProvider.notifier).toggle(_deal(2));
      store.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(savedDealsProvider), [_deal(2), _deal(1)]);
      expect(await onDiskAfterRestart(), [_deal(2), _deal(1)]);
    });

    test('tapping Save on a deal that is already saved, before the file '
        'has loaded, leaves it saved', () async {
      // On screen the deal looks unsaved until the file is read, so the
      // tap means "save it".
      await disk.setString(savedDealsKey, '["${_deal(1)}"]');
      store.gate = Completer();
      final c = container()..read(savedDealsProvider);
      await c.read(savedDealsProvider.notifier).toggle(_deal(1));
      expect(c.read(savedDealsProvider), [_deal(1)]);
      store.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(savedDealsProvider), contains(_deal(1)));
      expect(await onDiskAfterRestart(), contains(_deal(1)));
    });

    test('an unreadable file is never overwritten (round-1 BUG-2)', () async {
      await disk.setString(savedDealsKey, '["${_deal(1)}"]');
      store.failReads = 1000;
      final c = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      await c.read(savedDealsProvider.notifier).toggle(_deal(2));
      await c.read(savedDealsProvider.notifier).toggle(_deal(3));
      expect(store.writes, 0);
      expect(await onDiskAfterRestart(), [_deal(1)]);
      expect(c.read(savedDealsProvider), [_deal(3), _deal(2)]);
    });

    test('saves made while the file was unreadable survive once it reads '
        'again', () async {
      await disk.setString(savedDealsKey, '["${_deal(1)}"]');
      // The first read and the re-read on the first save fail; the next
      // works.
      store.failReads = 2;
      final c = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      await c.read(savedDealsProvider.notifier).toggle(_deal(2));
      expect(c.read(savedDealsProvider), [_deal(2)]);
      await c.read(savedDealsProvider.notifier).toggle(_deal(3));
      expect((await onDiskAfterRestart()).toSet(), {
        _deal(1),
        _deal(2),
        _deal(3),
      }, reason: 'deal 2 was saved, and shown as saved, while storage failed');
    });

    test('logs name only the error type, never the file', () async {
      store.failReads = 1;
      final c = container()..read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(savedDealsProvider), isEmpty);
      final text = [
        for (final r in logs.records)
          '${r.message} ${r.context} ${r.errorText}',
      ].join('\n');
      expect(text, contains('PlatformException'));
      expect(text, isNot(contains('secret')));
    });

    test(
      'a corrupt file reads as empty and the next save replaces it',
      () async {
        await disk.setString(savedDealsKey, '{"not": "a list"');
        final c = container()..read(savedDealsProvider);
        await Future<void>.delayed(Duration.zero);
        await c.read(savedDealsProvider.notifier).toggle(_deal(2));
        expect(await onDiskAfterRestart(), [_deal(2)]);
      },
    );
  });

  group('outlets of a local deal with mixed targets', () {
    test("a city-wide target plus an area in a big chain's home city: "
        'both sets of outlets are listed', () async {
      final repository = BackendDealRepository(
        _MixedChain(),
        AppLogger(sinks: []),
      );
      final detail = (await repository.detail(_MixedChain.dealId)).valueOrNull!;
      expect(detail.outlets.map((o) => o.id).toSet(), {
        'q0',
        'q1',
        'q2',
        'c0',
        'c1',
      });
    });
  });

  group('brand page deal lists (auto-disposed since 4.6)', () {
    testWidgets('leaving and reopening a brand page loads it again; pull to '
        'refresh reloads; leaving mid-page throws nothing', (tester) async {
      final auth = DemoAuthRepository();
      final backend = _CountingBrandDeals(auth);
      final h = Harness(
        saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
        auth: auth,
        backend: backend,
      );
      await h.pump(tester);
      final slug = demoBrands.first['slug']! as String;
      h.router.go('/brand/$slug');
      await tester.pumpAndSettle();
      expect(backend.calls, 1);
      h.router.go('/');
      await tester.pumpAndSettle();
      h.router.go('/brand/$slug');
      await tester.pumpAndSettle();
      expect(backend.calls, 2, reason: 'a fresh list, not a stale one');
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(backend.calls, 3);
      // Leave while a load is in flight.
      backend.hold = Completer();
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 400),
        1000,
      );
      await tester.pump(const Duration(milliseconds: 600));
      h.router.go('/');
      await tester.pumpAndSettle();
      backend.hold!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

/// Counts `brand_deals` calls; one can be held.
final class _CountingBrandDeals extends RulesGateway {
  new(super.auth);

  int calls = 0;
  Completer<void>? hold;

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    if (function == 'brand_deals') {
      calls++;
      if (hold case final h?) await h.future;
    }
    return await super.rpc(function, params);
  }
}

/// A local deal for all of Quetta and for Clifton (Karachi), from a chain
/// with 145 other Karachi outlets named before Clifton's.
final class _MixedChain implements BackendGateway {
  static const dealId = '00000000-0000-4000-8000-00000000c4a2';
  static const quetta = '00000000-0000-4000-a000-0000000000q1';
  static const clifton = '00000000-0000-4000-a000-0000000000c1';

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    final now = DateTime.now().toUtc();
    switch (query.table) {
      case 'deal_cards':
        return [
          {
            'id': dealId,
            'brand_id': 'b-chain',
            'brand_slug': 'chain',
            'brand_name': 'Chain',
            'category_id': 'c',
            'category_slug': 'food',
            'scope': 'local',
            'status': 'published',
            'title_en': 'Quetta and Clifton',
            'offer_kind': 'percent_off',
            'percent': 20,
            'starts_at': now
                .subtract(const Duration(days: 1))
                .toIso8601String(),
          },
        ];
      case 'deals':
        return [{}];
      case 'deal_targets':
        return [
          {'city_id': quetta, 'area_id': null},
          {'city_id': karachiId, 'area_id': clifton},
        ];
      case 'outlets':
        Map<String, Object?> o(
          String id,
          String name,
          String city, [
          String? area,
        ]) => {
          'id': id,
          'name': name,
          'address': 'Somewhere $id',
          'city_id': city,
          'area_id': area,
          'latitude': 24.8,
          'longitude': 67.0,
        };
        final all =
            [
              for (var i = 0; i < 145; i++)
                o('k$i', 'A${i.toString().padLeft(3, '0')} Karachi', karachiId),
              for (var i = 0; i < 2; i++)
                o('c$i', 'Zamzama $i', karachiId, clifton),
              for (var i = 0; i < 3; i++) o('q$i', 'Zarghoon $i', quetta),
            ]..sort(
              (a, b) => (a['name']! as String).compareTo(b['name']! as String),
            );
        // equals (brand, active) holds for every row; inList as PostgREST.
        final matching = [
          for (final row in all)
            if (query.inList.entries.every((e) => e.value.contains(row[e.key])))
              row,
        ];
        return matching.take(query.limit ?? matching.length).toList();
    }
    return const [];
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async => const [];

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {}

  @override
  Future<void> delete(String table, Map<String, Object?> match) async {}
}
