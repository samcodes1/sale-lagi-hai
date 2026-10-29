import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/domain/search_filters.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';

// ----------------------------------------------------------- the search ---

/// Words are searched once they stop changing for this long.
const searchDebounce = Duration(milliseconds: 350);

/// What is being searched: the words in the field, the words the results
/// are for (settled, trimmed), and the filters.
@immutable
final class SearchState {
  const new({
    this.text = '',
    this.query = '',
    this.filters = SearchFilters.none,
  });

  final String text;
  final String query;
  final SearchFilters filters;

  /// Results show for 2 or more characters, or for filters alone;
  /// otherwise the start page (recent searches).
  bool get hasResults => query.length >= 2 || !filters.isEmpty;

  SearchState copyWith({String? text, String? query, SearchFilters? filters}) =>
      SearchState(
        text: text ?? this.text,
        query: query ?? this.query,
        filters: filters ?? this.filters,
      );
}

final searchProvider = NotifierProvider<SearchController, SearchState>(
  SearchController.new,
);

final class SearchController extends Notifier<SearchState> {
  Timer? _settle;

  @override
  SearchState build() {
    ref
      ..onDispose(() => _settle?.cancel())
      // Areas belong to a city: a new city drops the area filter.
      ..listen(homeCityProvider, (previous, next) {
        if (previous != next) {
          state = state.copyWith(filters: state.filters.forOtherCity());
        }
      });
    return const SearchState();
  }

  /// The field changed: results follow once typing settles.
  void type(String text) {
    state = state.copyWith(text: text);
    _settle?.cancel();
    _settle = Timer(searchDebounce, () {
      if (ref.mounted) state = state.copyWith(query: text.trim());
    });
  }

  /// Search now (the keyboard's search key, a recent search, a link), and
  /// remember the words.
  void submit([String? text]) {
    _settle?.cancel();
    final words = (text ?? state.text).trim();
    state = state.copyWith(text: text ?? state.text, query: words);
    if (words.length >= 2) {
      unawaited(ref.read(recentSearchesProvider.notifier).add(words));
    }
  }

  void clearText() {
    _settle?.cancel();
    state = state.copyWith(text: '', query: '');
  }

  void setFilters(SearchFilters filters) =>
      state = state.copyWith(filters: filters);
}

/// The results list for [SearchState], or `null` when there is nothing to
/// search yet.
final searchResultsQueryProvider = Provider<SearchDeals?>((ref) {
  final search = ref.watch(searchProvider);
  if (!search.hasResults) return null;
  return SearchDeals(
    search.query.length >= 2 ? search.query : '',
    filters: search.filters,
    cityId: ref.watch(homeCityProvider),
  );
});

// ------------------------------------------------------ recent searches ---

/// Where recent searches live: on this phone only, never sent anywhere.
const recentSearchesKey = 'search.recent.v1';

/// The shopper's last searches, newest first.
final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(
  RecentSearches.new,
);

final class RecentSearches extends Notifier<List<String>> {
  static const limit = 8;

  @override
  List<String> build() {
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    try {
      final raw = await ref
          .read(keyValueStoreProvider)
          .getString(recentSearchesKey);
      if (raw == null || !ref.mounted) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      // Searches made before the file was read come first.
      state = _unique([
        ...state,
        for (final q in decoded)
          if (q is String && q.trim().length >= 2) q.trim(),
      ]);
    } on Object catch (error) {
      if (!ref.mounted) return;
      // Only the kind of error: a FormatException's text quotes the
      // file, and searches can be personal.
      ref
          .read(loggerProvider)
          .warning(
            'Could not read recent searches',
            context: {'error': error.runtimeType.toString()},
          );
    }
  }

  /// One entry per search, whatever the letter case; at most [limit].
  static List<String> _unique(List<String> searches) {
    final seen = <String>{};
    return [
      for (final q in searches)
        if (seen.add(q.toLowerCase())) q,
    ].take(limit).toList();
  }

  Future<void> add(String query) => _save(_unique([query.trim(), ...state]));

  Future<void> remove(String query) => _save([
    for (final q in state)
      if (q != query) q,
  ]);

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> searches) async {
    state = searches;
    try {
      await ref
          .read(keyValueStoreProvider)
          .setString(recentSearchesKey, jsonEncode(searches));
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning(
            'Could not save recent searches',
            context: {'error': error.runtimeType.toString()},
          );
    }
  }
}

// ---------------------------------------------------------- suggestions ---

/// Something to jump to while typing.
sealed class SearchSuggestion {
  const new();
}

final class BrandSuggestion extends SearchSuggestion {
  const new(this.brand);

  final Brand brand;
}

final class CategorySuggestion extends SearchSuggestion {
  const new(this.category);

  final Category category;
}

/// An area of the shopper's city: picking it sets the area filter.
final class AreaSuggestion extends SearchSuggestion {
  const new(this.area);

  final Area area;
}

/// Whether [name] has a word starting with [words] (both already
/// lower-cased), or contains it once it is 3 or more characters.
bool _nameMatches(String name, String words) =>
    name.split(RegExp(r'[\s\-&/]+')).any((w) => w.startsWith(words)) ||
    (words.length >= 3 && name.contains(words));

/// Brands, categories and areas for the settled words. Categories and
/// areas match on the phone (both short lists, already loaded); brands
/// come from the server. A failed part is left out: suggestions are a
/// shortcut, the results below still show.
final FutureProviderFamily<List<SearchSuggestion>, String>
searchSuggestionsProvider =
    FutureProvider.family<List<SearchSuggestion>, String>((ref, query) async {
      final words = query.trim().toLowerCase();
      if (words.isEmpty) return const [];
      final city = ref.watch(homeCityProvider);

      Future<List<T>> orNothing<T>(Future<List<T>> future) async {
        try {
          return await future;
        } on Object {
          return const [];
        }
      }

      final (categories, areas, brands) = await (
        orNothing(ref.watch(categoriesProvider.future)),
        city == null
            ? Future.value(const <Area>[])
            : orNothing(ref.watch(areasProvider(city).future)),
        orNothing(
          ref.watch(catalogRepositoryProvider).suggestBrands(words, limit: 5),
        ),
      ).wait;
      return [
        for (final b in brands) BrandSuggestion(b),
        for (final c
            in categories
                .where(
                  (c) =>
                      _nameMatches(c.nameEn.toLowerCase(), words) ||
                      _nameMatches(c.nameUr, words),
                )
                .take(3))
          CategorySuggestion(c),
        for (final a
            in areas
                .where(
                  (a) =>
                      _nameMatches(a.nameEn.toLowerCase(), words) ||
                      _nameMatches(a.nameUr, words),
                )
                .take(2))
          AreaSuggestion(a),
      ];
    });
