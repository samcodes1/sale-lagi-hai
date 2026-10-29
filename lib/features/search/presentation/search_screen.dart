import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/design_system/icons/category_icons.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/deals/domain/search_filters.dart';
import 'package:sale_lagi_hai/features/deals/presentation/paged_deal_list.dart';
import 'package:sale_lagi_hai/features/search/application/search_providers.dart';
import 'package:sale_lagi_hai/features/search/presentation/filters_sheet.dart';

/// Search (screen S11): words with suggestions as you type, filters
/// (S12), recent searches, and the matching deals.
class SearchScreen extends ConsumerStatefulWidget {
  const new({this.initialQuery = '', super.key});

  /// Words to search straight away (`/search?q=`).
  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();

  @override
  void initState() {
    super.initState();
    final search = ref.read(searchProvider.notifier);
    if (widget.initialQuery.isNotEmpty) {
      _field.text = widget.initialQuery;
      // Not during build: it changes a provider others watch.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) search.submit(widget.initialQuery);
      });
    } else {
      _field.text = ref.read(searchProvider).text;
    }
  }

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    // A new `?q=` while Search is open.
    final words = widget.initialQuery;
    if (words != old.initialQuery && words.isNotEmpty) {
      _field.text = words;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(searchProvider.notifier).submit(words);
      });
    }
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _searchFor(String words) {
    _field.text = words;
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(searchProvider.notifier).submit(words);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final search = ref.watch(searchProvider);
    final offline =
        ref.watch(networkStatusProvider).value == NetworkStatus.offline;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (offline) const SliverToBoxAdapter(child: OfflineBanner()),
          SliverToBoxAdapter(child: _searchField(l10n, search)),
          const SliverToBoxAdapter(child: _FilterBar()),
          if (search.hasResults) ..._results(l10n, search) else ..._start(l10n),
        ],
      ),
    );
  }

  Widget _searchField(AppLocalizations l10n, SearchState search) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      BrandSpacing.s5,
      BrandSpacing.s3,
      BrandSpacing.s5,
      BrandSpacing.s2,
    ),
    child: TextField(
      controller: _field,
      autofocus: widget.initialQuery.isEmpty && search.text.isEmpty,
      textInputAction: TextInputAction.search,
      inputFormatters: [LengthLimitingTextInputFormatter(100)],
      decoration: InputDecoration(
        labelText: l10n.searchFieldLabel,
        hintText: l10n.exploreHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: search.text.isEmpty
            ? null
            : IconButton(
                tooltip: l10n.actionClearSearch,
                icon: const Icon(Icons.close),
                onPressed: () {
                  _field.clear();
                  ref.read(searchProvider.notifier).clearText();
                },
              ),
      ),
      onChanged: ref.read(searchProvider.notifier).type,
      onSubmitted: _searchFor,
    ),
  );

  Widget _heading(String text, {Widget? trailing}) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      BrandSpacing.s5,
      BrandSpacing.s5,
      BrandSpacing.s3,
      BrandSpacing.s2,
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: BrandSpacing.s3,
      children: [
        Semantics(
          header: true,
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
        ?trailing,
      ],
    ),
  );

  /// Before searching: recent searches, then popular categories.
  List<Widget> _start(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final recent = ref.watch(recentSearchesProvider);
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final interests = ref.watch(interestsProvider).value ?? const [];
    return [
      if (recent.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: _heading(
            l10n.searchRecent,
            trailing: TextButton(
              onPressed: () =>
                  ref.read(recentSearchesProvider.notifier).clear(),
              child: Text(l10n.actionClearRecent),
            ),
          ),
        ),
        SliverList.list(
          children: [
            for (final words in recent)
              _Row(
                icon: Icons.history,
                title: words,
                onTap: () => _searchFor(words),
                trailing: IconButton(
                  tooltip: l10n.actionRemoveRecent(words),
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      ref.read(recentSearchesProvider.notifier).remove(words),
                ),
              ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BrandSpacing.s5,
            ),
            child: Text(
              l10n.searchRecentPrivacy,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
      if (interests.isNotEmpty) ...[
        SliverToBoxAdapter(child: _heading(l10n.searchPopular)),
        SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            BrandSpacing.s5,
            0,
            BrandSpacing.s5,
            BrandSpacing.s8,
          ),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: BrandSpacing.s3,
              runSpacing: BrandSpacing.s3,
              children: [
                for (final category in interests)
                  ActionChip(
                    avatar: Icon(categoryIcon(category.icon)),
                    label: Text(category.name(urdu: urdu)),
                    onPressed: () =>
                        CategoryRoute(slug: category.slug).push<void>(context),
                  ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  /// Searching: suggestions for the words, then the deals.
  List<Widget> _results(AppLocalizations l10n, SearchState search) {
    final query = ref.watch(searchResultsQueryProvider);
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final suggestions = search.query.isEmpty
        ? const <SearchSuggestion>[]
        : ref.watch(searchSuggestionsProvider(search.query)).value ??
              const <SearchSuggestion>[];
    return [
      if (suggestions.isNotEmpty) ...[
        SliverToBoxAdapter(child: _heading(l10n.searchSuggestions)),
        SliverList.list(
          children: [
            for (final suggestion in suggestions)
              switch (suggestion) {
                BrandSuggestion(:final brand) => _Row(
                  icon: Icons.storefront_outlined,
                  title: brand.displayName(urdu: urdu),
                  subtitle: l10n.searchKindBrand,
                  onTap: () => BrandRoute(slug: brand.slug).push<void>(context),
                ),
                CategorySuggestion(:final category) => _Row(
                  icon: categoryIcon(category.icon),
                  title: category.name(urdu: urdu),
                  subtitle: l10n.searchKindCategory,
                  onTap: () =>
                      CategoryRoute(slug: category.slug).push<void>(context),
                ),
                AreaSuggestion(:final area) => _Row(
                  icon: Icons.place_outlined,
                  title: area.name(urdu: urdu),
                  subtitle: l10n.searchKindArea,
                  onTap: () {
                    // The area is the filter now, not the words.
                    _field.clear();
                    ref.read(searchProvider.notifier)
                      ..setFilters(
                        search.filters.copyWith(areaId: () => area.id),
                      )
                      ..clearText();
                  },
                ),
              },
          ],
        ),
      ],
      SliverToBoxAdapter(child: _heading(l10n.searchDeals)),
      if (query != null)
        PagedDealSlivers(
          query: query,
          emptyMessage: query.query.isEmpty
              ? l10n.searchNoFilterResults
              : l10n.emptySearch(query.query),
          emptyActionLabel: search.filters.isEmpty
              ? null
              : l10n.actionClearFilters,
          onEmptyAction: search.filters.isEmpty
              ? null
              : () => ref
                    .read(searchProvider.notifier)
                    .setFilters(SearchFilters.none),
        ),
    ];
  }
}

/// The quick filters under the field: the sheet with every filter (and
/// how many are on), plus one-tap "Ending soon" and "50%+ off".
class _FilterBar extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = AppFormatters.of(context);
    final filters = ref.watch(searchProvider.select((s) => s.filters));
    final notifier = ref.read(searchProvider.notifier);
    final top = discountSteps.last;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BrandSpacing.s5,
      ),
      child: Row(
        children: [
          ActionChip(
            avatar: const Icon(Icons.tune),
            label: Text(
              filters.isEmpty
                  ? l10n.filtersTitle
                  : l10n.filtersOn(filters.count),
            ),
            onPressed: () => showFiltersSheet(context),
          ),
          const SizedBox(width: BrandSpacing.s3),
          FilterChip(
            label: Text(l10n.filterEndingSoon),
            selected: filters.endingSoon,
            onSelected: (on) =>
                notifier.setFilters(filters.copyWith(endingSoon: on)),
          ),
          const SizedBox(width: BrandSpacing.s3),
          FilterChip(
            label: Text(l10n.filterMinPercent(format.number(top))),
            selected: filters.minPercent == top,
            onSelected: (on) => notifier.setFilters(
              filters.copyWith(minPercent: () => on ? top : null),
            ),
          ),
          if (!filters.isEmpty) ...[
            const SizedBox(width: BrandSpacing.s3),
            ActionChip(
              avatar: const Icon(Icons.filter_alt_off_outlined),
              label: Text(l10n.actionClearFilters),
              onPressed: () => notifier.setFilters(SearchFilters.none),
            ),
          ],
        ],
      ),
    );
  }
}

/// One tappable row: an icon, a title that wraps, an optional subtitle
/// and trailing action. Not a ListTile: its trailing slot overflows at
/// large text sizes.
class _Row extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  BrandSpacing.s5,
                  BrandSpacing.s3,
                  BrandSpacing.s3,
                  BrandSpacing.s3,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        icon,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: BrandSpacing.s4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.bodyLarge),
                          if (subtitle case final subtitle?)
                            Text(
                              subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ?trailing,
        if (trailing != null) const SizedBox(width: BrandSpacing.s2),
      ],
    );
  }
}
