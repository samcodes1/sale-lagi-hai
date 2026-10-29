// QA (sub-phase 4.6 gate): search. Typing and response races, recent
// searches loading while a search is saved, log privacy (recent searches
// and the same pattern elsewhere), /search?q= edge cases, offline, and
// screen-reader labels on chips and suggestion rows.
//
// "QA BUG" tests fail until the bug in docs/qa/4.6.md is fixed; S4
// findings are skipped with their bug id.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/deals/domain/search_filters.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';
import 'package:sale_lagi_hai/features/search/application/search_providers.dart';
import 'package:sale_lagi_hai/features/search/presentation/search_screen.dart';

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/fakes.dart';

/// The demo backend, with search calls that can be held per query and an
/// offline switch.
final class HoldingGateway implements BackendGateway {
  final _demo = DemoGateway();
  final holds = <String, Completer<void>>{};
  final searched = <String>[];
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
    if (function == 'search_deals') {
      final words = params['query'] as String? ?? '';
      searched.add(words);
      await holds[words]?.future;
    }
    return await _demo.rpc(function, params);
  }

  @override
  Future<void> insert(String table, Map<String, Object?> row) =>
      _demo.insert(table, row);

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      _demo.delete(table, match);
}

/// A store whose first read is held, like a slow disk on first launch.
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

void main() {
  group('providers', () {
    late MemoryLogSink logs;

    ProviderContainer container(KeyValueStore store) {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          loggerProvider.overrideWithValue(AppLogger(sinks: [logs])),
          backendGatewayProvider.overrideWithValue(DemoGateway()),
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

    test('rapid typing settles once, on the last words only', () async {
      final c = container(InMemoryKeyValueStore());
      final seen = <String>[];
      c.listen(searchProvider.select((s) => s.query), (_, q) => seen.add(q));
      final search = c.read(searchProvider.notifier);
      for (final words in ['k', 'ka', 'kar', 'kara', 'karah', 'karahi']) {
        search.type(words);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(seen, isEmpty, reason: 'still typing');
      await Future<void>.delayed(searchDebounce);
      expect(seen, ['karahi']);
    });

    test('submit wins over a pending settle, and a later settle of old '
        'words never comes', () async {
      final c = container(InMemoryKeyValueStore());
      c.read(searchProvider.notifier)
        ..type('pizz')
        ..submit('pizza');
      await Future<void>.delayed(searchDebounce * 2);
      expect(c.read(searchProvider).query, 'pizza');
    });

    test('clearing the field cancels a pending settle', () async {
      final c = container(InMemoryKeyValueStore());
      c.read(searchProvider.notifier)
        ..type('biryani')
        ..clearText();
      await Future<void>.delayed(searchDebounce * 2);
      expect(c.read(searchProvider).query, isEmpty);
      expect(c.read(searchResultsQueryProvider), isNull);
    });

    // QA BUG 4.6-A1 (S4): a search saved before the stored list has been
    // read (a `?q=` link opening Search, or a quick first search) writes a
    // list with only the new words: the older recent searches are gone
    // from the phone until the next change (search_providers.dart:161,
    // _save with the not-yet-loaded state).
    test('QA BUG 4.6-A1: a search saved while the list is still loading keeps '
        'the older searches on the phone', () async {
      final store = SlowFirstReadStore();
      store.inner.values[recentSearchesKey] = jsonEncode(['old one', 'older']);
      final c = container(store)
        ..listen(recentSearchesProvider, (_, _) {}); // loads, as Search does
      await c.read(recentSearchesProvider.notifier).add('new one');
      store.firstRead.complete();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(recentSearchesProvider), ['new one', 'old one', 'older']);
      expect(jsonDecode(store.inner.values[recentSearchesKey]!), [
        'new one',
        'old one',
        'older',
      ], reason: 'what is on the phone');
    });

    test('recent searches: case-insensitive dedupe keeps the newest '
        'spelling; remove takes only that entry', () async {
      final c = container(InMemoryKeyValueStore());
      final recent = c.read(recentSearchesProvider.notifier);
      await recent.add('Karahi');
      await recent.add('pizza');
      await recent.add('KARAHI');
      expect(c.read(recentSearchesProvider), ['KARAHI', 'pizza']);
      await recent.remove('KARAHI');
      expect(c.read(recentSearchesProvider), ['pizza']);
    });

    test('nothing searched reaches the logs when saving fails', () async {
      final c = container(_FailingStore());
      await c.read(recentSearchesProvider.notifier).add('my secret search');
      await Future<void>.delayed(Duration.zero);
      expect(logs.records, isNotEmpty);
      for (final r in logs.records) {
        expect(
          '${r.message} ${r.context} ${r.errorText}',
          isNot(contains('secret')),
        );
      }
    });

    // QA BUG 4.6-A2 (S4): the leak fixed for recent searches is still in
    // saved deals: a corrupt `saved.v1` logs the FormatException, whose
    // text quotes the stored list of what the shopper saved
    // (saved_providers.dart:45-48).
    test('QA BUG 4.6-A2: a corrupt saved-deals file is logged without its '
        'contents', () async {
      final store = InMemoryKeyValueStore()
        ..values[savedDealsKey] = '["deal-the-shopper-saved", oops';
      container(store).read(savedDealsProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(logs.records, isNotEmpty);
      for (final r in logs.records) {
        expect(
          '${r.message} ${r.context} ${r.errorText}',
          isNot(contains('deal-the-shopper-saved')),
        );
      }
    });

    test('SearchFilters: equality ignores order, not the kind of id; no '
        'ids in toString', () {
      expect(
        const SearchFilters(categoryIds: ['a', 'b'], bankIds: ['x']),
        const SearchFilters(categoryIds: ['b', 'a'], bankIds: ['x']),
      );
      expect(
        const SearchFilters(categoryIds: ['a']),
        isNot(const SearchFilters(bankIds: ['a'])),
      );
      expect(
        const SearchFilters(areaId: 'clifton').toString(),
        isNot(contains('clifton')),
      );
    });
  });

  group('screen', () {
    Future<Harness> app(
      WidgetTester tester,
      HoldingGateway backend, {
      String at = '/search',
    }) async {
      final h = Harness(
        backend: backend,
        saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
      );
      await h.pump(tester);
      h.router.go(at);
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('a slow answer for older words never replaces the newer '
        'results', (tester) async {
      final backend = HoldingGateway();
      await app(tester, backend);
      backend.holds['karahi'] = Completer<void>();
      await tester.enterText(find.byType(TextField), 'karahi');
      await tester.pump(searchDebounce);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'burger');
      await tester.pump(searchDebounce);
      await tester.pumpAndSettle();
      final burgerCards = tester.widgetList(find.byType(DealCard)).length;
      backend.holds['karahi']!.complete();
      await tester.pumpAndSettle();
      expect(tester.widgetList(find.byType(DealCard)).length, burgerCards);
      expect(backend.searched, containsAllInOrder(['karahi', 'burger']));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'burger',
      );
    });

    testWidgets('offline: the banner shows, recent searches still run, and '
        'results show an error with Try again', (tester) async {
      final backend = HoldingGateway()..offline = true;
      final h = Harness(
        backend: backend,
        network: NetworkStatus.offline,
        saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
      );
      h.store.values[recentSearchesKey] = jsonEncode(['karahi']);
      await h.pump(tester);
      h.router.go('/search');
      await tester.pumpAndSettle();
      expect(find.byType(OfflineBanner), findsOneWidget);
      await tester.tap(find.text('karahi'));
      await tester.pumpAndSettle();
      expect(find.byType(DealCard), findsNothing);
      expect(find.text('Try again'), findsWidgets);
      backend.offline = false;
      await tester.tap(find.text('Try again').first);
      await tester.pumpAndSettle();
      expect(find.byType(DealCard), findsWidgets);
    });

    testWidgets('screen-reader labels: quick chips say on/off; a suggestion '
        'row reads its name and kind', (tester) async {
      final handle = tester.ensureSemantics();
      final backend = HoldingGateway();
      await app(tester, backend);
      expect(
        tester.getSemantics(find.widgetWithText(FilterChip, 'Ending soon')),
        matchesSemantics(
          label: 'Ending soon',
          isButton: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      await tester.enterText(find.byType(TextField), 'karahi');
      await tester.pump(searchDebounce);
      await tester.pumpAndSettle();
      final row = tester.getSemantics(find.text('Brand').first);
      expect(row.label, contains('Brand'));
      expect(row, isSemantics(hasTapAction: true));
      handle.dispose();
    });

    // QA BUG 4.6-A3 (S4): suggestion and recent-search rows are tappable
    // but not marked as buttons, so TalkBack doesn't say "button"
    // (search_screen.dart:350-416, the InkWell in _Row).
    testWidgets('QA BUG 4.6-A3: suggestion rows are announced as buttons', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await app(tester, HoldingGateway());
      await tester.enterText(find.byType(TextField), 'karahi');
      await tester.pump(searchDebounce);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('Brand').first),
        isSemantics(isButton: true),
      );
      handle.dispose();
    });

    testWidgets('the search field: search key, 100-character cap, and the '
        'clear button', (tester) async {
      await app(tester, HoldingGateway());
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textInputAction, TextInputAction.search);
      await tester.enterText(find.byType(TextField), 'x' * 150);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        hasLength(100),
      );
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });

    // QA BUG 4.6-A4 (S4): `/search?q=` is cut at 100 UTF-16 code units,
    // which can split an emoji into a lone surrogate (routes.dart:209).
    testWidgets('QA BUG 4.6-A4: a ?q= cut at 100 never splits a character', (
      tester,
    ) async {
      final h = await app(
        tester,
        HoldingGateway(),
        at: '/search?q=${Uri.encodeQueryComponent('${'a' * 99}🍕🍕')}',
      );
      final words = h.container.read(searchProvider).query;
      expect(
        words.runes.every((r) => r < 0xD800 || r > 0xDFFF),
        isTrue,
        reason: 'no lone surrogate',
      );
    });

    testWidgets('a hostile ?q= is shown as plain words and searched', (
      tester,
    ) async {
      final backend = HoldingGateway();
      final h = await app(
        tester,
        backend,
        at: '/search?q=${Uri.encodeQueryComponent("'); drop table deals;-- <b>x</b>")}',
      );
      expect(find.byType(SearchScreen), findsOneWidget);
      expect(
        h.container.read(searchProvider).query,
        "'); drop table deals;-- <b>x</b>",
      );
      expect(backend.searched.last, "'); drop table deals;-- <b>x</b>");
      expect(tester.takeException(), isNull);
    });
  });
}

final class _FailingStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> setString(String key, String value) async =>
      throw FormatException('cannot write $value');

  @override
  Future<void> remove(String key) async {}

  @override
  Future<Set<String>> keys() async => {};

  @override
  Future<void> clear() async {}
}
