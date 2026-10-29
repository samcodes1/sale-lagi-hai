import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/deals/domain/search_filters.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/search/application/search_providers.dart';

/// Opens the filters sheet (screen S12). The choices apply on "Show
/// deals"; closing the sheet any other way changes nothing.
Future<void> showFiltersSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const FiltersSheet(),
    );

class FiltersSheet extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<FiltersSheet> {
  late SearchFilters _draft = ref.read(searchProvider).filters;

  void _set(SearchFilters filters) => setState(() => _draft = filters);

  static List<String> _toggled(List<String> ids, String id) =>
      ids.contains(id) ? [...ids.where((x) => x != id)] : [...ids, id];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final format = AppFormatters.of(context);
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final city = ref.watch(homeCityProvider);

    Widget section(String title, Widget body) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: BrandSpacing.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: BrandSpacing.s3),
          body,
        ],
      ),
    );

    Widget chips(List<Widget> children) => Wrap(
      spacing: BrandSpacing.s3,
      runSpacing: BrandSpacing.s3,
      children: children,
    );

    Widget loading<T>(
      AsyncValue<List<T>> value,
      VoidCallback retry,
      Widget Function(List<T>) build,
    ) => switch (value) {
      AsyncData(:final value) => build(value),
      AsyncError(:final error) => InlineErrorBanner(
        failure: error is AppFailure ? error : const UnexpectedFailure(),
        onRetry: retry,
      ),
      _ => const SkeletonBox(height: 40),
    };

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s5,
        0,
        BrandSpacing.s5,
        BrandSpacing.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.filtersTitle, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: BrandSpacing.s5),
          section(
            l10n.filterArea,
            city == null
                ? Text(l10n.filterAreaNeedsCity)
                : loading(
                    ref.watch(areasProvider(city)),
                    () => ref.invalidate(areasProvider(city)),
                    (areas) => chips([
                      ChoiceChip(
                        label: Text(l10n.filterAnyArea),
                        selected: _draft.areaId == null,
                        onSelected: (_) =>
                            _set(_draft.copyWith(areaId: () => null)),
                      ),
                      for (final area in areas)
                        ChoiceChip(
                          label: Text(area.name(urdu: urdu)),
                          selected: _draft.areaId == area.id,
                          onSelected: (_) =>
                              _set(_draft.copyWith(areaId: () => area.id)),
                        ),
                    ]),
                  ),
          ),
          section(
            l10n.filterCategory,
            loading(
              ref.watch(interestsProvider),
              () => ref.invalidate(categoriesProvider),
              (categories) => chips([
                for (final category in categories)
                  FilterChip(
                    label: Text(category.name(urdu: urdu)),
                    selected: _draft.categoryIds.contains(category.id),
                    onSelected: (_) => _set(
                      _draft.copyWith(
                        categoryIds: _toggled(_draft.categoryIds, category.id),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          section(
            l10n.filterBank,
            loading(
              ref.watch(banksProvider),
              () => ref.invalidate(banksProvider),
              (banks) => chips([
                for (final bank in banks)
                  FilterChip(
                    label: Text(bank.shortName),
                    tooltip: bank.name(urdu: urdu),
                    selected: _draft.bankIds.contains(bank.id),
                    onSelected: (_) => _set(
                      _draft.copyWith(
                        bankIds: _toggled(_draft.bankIds, bank.id),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          section(
            l10n.filterDiscount,
            chips([
              ChoiceChip(
                label: Text(l10n.filterAnyDiscount),
                selected: _draft.minPercent == null,
                onSelected: (_) =>
                    _set(_draft.copyWith(minPercent: () => null)),
              ),
              for (final step in discountSteps)
                ChoiceChip(
                  label: Text(l10n.filterMinPercent(format.number(step))),
                  selected: _draft.minPercent == step,
                  onSelected: (_) =>
                      _set(_draft.copyWith(minPercent: () => step)),
                ),
            ]),
          ),
          SwitchListTile(
            contentPadding: EdgeInsetsDirectional.zero,
            title: Text(l10n.filterEndingSoon),
            subtitle: Text(l10n.filterEndingSoonHint),
            value: _draft.endingSoon,
            onChanged: (on) => _set(_draft.copyWith(endingSoon: on)),
          ),
          const SizedBox(height: BrandSpacing.s5),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: BrandSpacing.s3,
            runSpacing: BrandSpacing.s3,
            children: [
              TextButton(
                onPressed: _draft.isEmpty
                    ? null
                    : () => _set(SearchFilters.none),
                child: Text(l10n.actionClearFilters),
              ),
              FilledButton(
                onPressed: () {
                  ref.read(searchProvider.notifier).setFilters(_draft);
                  Navigator.of(context).pop();
                },
                child: Text(l10n.actionShowDeals),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
