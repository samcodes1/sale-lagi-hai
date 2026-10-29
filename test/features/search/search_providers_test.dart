import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/domain/search_filters.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/search/application/search_providers.dart';

import '../../helpers/fakes.dart';

final _clifton =
    demoAreas.firstWhere((a) => a['slug'] == 'clifton')['id']! as String;
final _dha = demoAreas.firstWhere((a) => a['slug'] == 'dha')['id']! as String;
final _hbl = demoBanks.firstWhere((b) => b['slug'] == 'hbl')['id']! as String;

String _title(int n) => demoDeals.firstWhere((d) => d.n == n).titleEn;

void main() {
  late InMemoryKeyValueStore store;
  late MemoryLogSink logs;

  ProviderContainer container({String? city = karachiId}) {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        loggerProvider.overrideWithValue(AppLogger(sinks: [logs])),
        backendGatewayProvider.overrideWithValue(DemoGateway()),
        savedPreferencesProvider.overrideWithValue(
          ShopperPreferences(onboarded: true, cityId: city),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    store = InMemoryKeyValueStore();
    logs = MemoryLogSink();
  });

  group('recent searches', () {
    test('newest first, once each whatever the case, at most 8', () async {
      final c = container();
      final recent = c.read(recentSearchesProvider.notifier);
      for (final q in ['karahi', 'burger', 'Karahi', 'chai']) {
        await recent.add(q);
      }
      expect(c.read(recentSearchesProvider), ['chai', 'Karahi', 'burger']);
      for (var i = 0; i < 10; i++) {
        await recent.add('query $i');
      }
      expect(c.read(recentSearchesProvider), hasLength(RecentSearches.limit));
      expect(c.read(recentSearchesProvider).first, 'query 9');
    });

    test('remove, clear, and they survive a restart', () async {
      final first = container();
      final recent = first.read(recentSearchesProvider.notifier);
      await recent.add('karahi');
      await recent.add('burger');
      await recent.remove('karahi');
      expect(jsonDecode(store.values[recentSearchesKey]!), ['burger']);

      final second = container()..read(recentSearchesProvider);
      await Future<void>.delayed(Duration.zero);
      expect(second.read(recentSearchesProvider), ['burger']);
      await second.read(recentSearchesProvider.notifier).clear();
      expect(second.read(recentSearchesProvider), isEmpty);
    });

    test('a corrupt file reads as none; nothing searched is logged', () async {
      store.values[recentSearchesKey] = '{"karahi near me';
      final c = container()..read(recentSearchesProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(recentSearchesProvider), isEmpty);
      expect(logs.records, isNotEmpty);
      expect(
        logs.records.map((r) => '${r.message} ${r.context} ${r.errorText}'),
        everyElement(isNot(contains('karahi'))),
      );
    });

    test('odd stored entries are dropped', () async {
      store.values[recentSearchesKey] = jsonEncode([1, 'a', '  chai ', null]);
      final c = container()..read(recentSearchesProvider);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(recentSearchesProvider), ['chai']);
    });
  });

  group('the search', () {
    test('words settle before they are searched; submit is at once and '
        'remembered', () async {
      final c = container();
      final search = c.read(searchProvider.notifier)..type('kar');
      expect(c.read(searchProvider).text, 'kar');
      expect(c.read(searchResultsQueryProvider), isNull);
      await Future<void>.delayed(
        searchDebounce + const Duration(milliseconds: 50),
      );
      expect(c.read(searchResultsQueryProvider)?.query, 'kar');
      expect(c.read(recentSearchesProvider), isEmpty, reason: 'typing only');

      search.submit('  burger ');
      expect(c.read(searchResultsQueryProvider)?.query, 'burger');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(recentSearchesProvider), ['burger']);
      search.submit('b');
      expect(c.read(searchResultsQueryProvider), isNull, reason: 'one letter');
      expect(c.read(recentSearchesProvider), ['burger']);
    });

    test('filters alone search, with no words', () {
      final c = container();
      c
          .read(searchProvider.notifier)
          .setFilters(const SearchFilters(endingSoon: true));
      expect(
        c.read(searchResultsQueryProvider),
        const SearchDeals(
          '',
          filters: SearchFilters(endingSoon: true),
          cityId: karachiId,
        ),
      );
    });

    test('a new city drops the area filter, keeps the others', () async {
      final c = container();
      c
          .read(searchProvider.notifier)
          .setFilters(SearchFilters(areaId: _clifton, minPercent: 25));
      await c.read(preferencesProvider.notifier).setCity(lahoreId);
      expect(
        c.read(searchProvider).filters,
        const SearchFilters(minPercent: 25),
      );
    });

    test('clearing the words keeps the filters', () {
      final c = container();
      c.read(searchProvider.notifier)
        ..setFilters(const SearchFilters(minPercent: 50))
        ..submit('karahi')
        ..clearText();
      expect(c.read(searchProvider).query, isEmpty);
      expect(c.read(searchResultsQueryProvider)?.filters.minPercent, 50);
    });
  });

  group('results (demo backend)', () {
    Future<List<String>> titles(
      ProviderContainer c,
      String query, [
      SearchFilters filters = SearchFilters.none,
    ]) async {
      final list = dealListProvider(
        SearchDeals(query, filters: filters, cityId: karachiId),
      );
      final sub = c.listen(list, (_, _) {});
      addTearDown(sub.close);
      var state = await c.read(list.future);
      while (!state.atEnd) {
        await c.read(list.notifier).loadMore();
        state = c.read(list).requireValue;
      }
      return [for (final d in state.deals) d.titleEn];
    }

    test('each filter narrows the deals', () async {
      final c = container();
      expect(
        await titles(c, '', SearchFilters(areaId: _dha)),
        allOf(contains(_title(2)), isNot(contains(_title(3)))),
      );
      expect(await titles(c, '', SearchFilters(bankIds: [_hbl])), [_title(7)]);
      expect(await titles(c, '', const SearchFilters(minPercent: 50)), [
        _title(4),
      ]);
      expect(
        await titles(c, '', const SearchFilters(endingSoon: true)),
        allOf(
          contains(_title(1)),
          contains(_title(2)),
          isNot(contains(_title(4))),
        ),
      );
      expect(await titles(c, 'karahi', SearchFilters(areaId: _clifton)), [
        _title(1),
        _title(7),
      ]);
    });

    test('filters alone list the newest first, every deal once', () async {
      final c = container();
      final all = await titles(c, '', const SearchFilters(minPercent: 10));
      expect(all.toSet(), hasLength(all.length));
      expect(all.first, _title(4), reason: 'published 4 hours ago');
    });
  });

  group('suggestions (demo backend)', () {
    test(
      'brands from the server, categories and areas from the catalog',
      () async {
        final c = container();
        final found = await c.read(searchSuggestionsProvider('cl').future);
        expect(found.whereType<AreaSuggestion>().single.area.id, _clifton);

        final brands = await c.read(searchSuggestionsProvider('karahi').future);
        expect(brands.whereType<BrandSuggestion>().map((s) => s.brand.slug), [
          'demo-karahi-house',
        ]);
        final food = await c.read(searchSuggestionsProvider('food').future);
        expect(food.whereType<CategorySuggestion>(), isNotEmpty);
        expect(await c.read(searchSuggestionsProvider('  ').future), isEmpty);
      },
    );

    test('no city: no areas', () async {
      final c = container(city: null);
      final found = await c.read(searchSuggestionsProvider('cl').future);
      expect(found.whereType<AreaSuggestion>(), isEmpty);
    });
  });
}
