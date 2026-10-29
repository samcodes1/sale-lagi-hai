import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/icons/category_icons.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/content_text.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/follows/presentation/follow_button.dart';

/// Explore tab (screen S04): search, every category, then the brands to
/// follow.
class ExploreScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final interests = ref.watch(interestsProvider);
    final brands = ref.watch(exploreBrandsProvider);

    Widget heading(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s5,
        BrandSpacing.s6,
        BrandSpacing.s5,
        BrandSpacing.s3,
      ),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleLarge),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navExplore)),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _SearchEntry()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BrandSpacing.s5,
                BrandSpacing.s3,
                BrandSpacing.s5,
                0,
              ),
              // A row, not a chip: chips can't wrap at large text sizes
              // (QA 4.7-A7).
              child: Semantics(
                button: true,
                child: InkWell(
                  onTap: () => const MyCardsRoute().push<void>(context),
                  borderRadius: BrandRadii.card,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        const ExcludeSemantics(child: Icon(Icons.credit_card)),
                        const SizedBox(width: BrandSpacing.s4),
                        Expanded(child: Text(l10n.myCardsEntry)),
                        const ExcludeSemantics(
                          child: Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: heading(l10n.exploreCategories)),
          switch (interests) {
            AsyncData(:final value) => SliverPadding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BrandSpacing.s5,
              ),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: BrandSpacing.s3,
                  runSpacing: BrandSpacing.s3,
                  children: [
                    for (final category in value)
                      ActionChip(
                        avatar: Icon(categoryIcon(category.icon)),
                        label: Text(category.name(urdu: urdu)),
                        onPressed: () =>
                            CategoryRoute(slug: category.slug)
                                .push<void>(context),
                      ),
                  ],
                ),
              ),
            ),
            AsyncError(:final error) => SliverToBoxAdapter(
              child: InlineErrorBanner(
                failure: error is AppFailure
                    ? error
                    : const UnexpectedFailure(),
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
            ),
            _ => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsetsDirectional.all(BrandSpacing.s5),
                child: SkeletonBox(height: 40),
              ),
            ),
          },
          SliverToBoxAdapter(child: heading(l10n.exploreBrands)),
          switch (brands) {
            AsyncData(:final value) => SliverMainAxisGroup(
              slivers: [
                SliverList.builder(
                  itemCount: value.brands.length,
                  itemBuilder: (context, i) {
                    // The next 60 load about 10 rows before the end; never
                    // after a failure (the retry row asks instead).
                    if (i >= value.brands.length - 10 &&
                        value.hasMore &&
                        !value.loadingMore &&
                        value.moreFailure == null) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) =>
                            ref.read(exploreBrandsProvider.notifier).loadMore(),
                      );
                    }
                    return _BrandRow(value.brands[i], urdu: urdu);
                  },
                ),
                if (value.hasMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
                      child: switch (value) {
                        BrandPages(loadingMore: true) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        BrandPages(moreFailure: final failure?) =>
                          InlineErrorBanner(
                            failure: failure,
                            onRetry: () => ref
                                .read(exploreBrandsProvider.notifier)
                                .loadMore(),
                          ),
                        // Waiting to be scrolled to: nothing to show.
                        _ => const SizedBox.shrink(),
                      },
                    ),
                  ),
              ],
            ),
            AsyncError(:final error) => SliverToBoxAdapter(
              child: InlineErrorBanner(
                failure: error is AppFailure
                    ? error
                    : const UnexpectedFailure(),
                onRetry: () => ref.invalidate(exploreBrandsProvider),
              ),
            ),
            _ => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsetsDirectional.all(BrandSpacing.s5),
                child: SkeletonBox(height: 48),
              ),
            ),
          },
          const SliverToBoxAdapter(child: SizedBox(height: BrandSpacing.s8)),
        ],
      ),
    );
  }
}

/// A brand: tap the name to open its page; Follow beside it, or under it
/// at large text sizes so neither is squeezed.
class _BrandRow extends StatelessWidget {
  const new(this.brand, {required this.urdu});

  final Brand brand;
  final bool urdu;

  @override
  Widget build(BuildContext context) {
    final name = brand.displayName(urdu: urdu);
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 15;
    final follow = FollowButton(
      target: FollowTarget.brand,
      id: brand.id,
      name: name,
    );
    final open = InkWell(
      onTap: () => BrandRoute(slug: brand.slug).push<void>(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            ExcludeSemantics(
              child: CircleAvatar(child: Text(name.characters.first)),
            ),
            const SizedBox(width: BrandSpacing.s4),
            Expanded(
              child: ContentText(
                name,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BrandSpacing.s5,
        vertical: BrandSpacing.s2,
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [open, follow],
            )
          : Row(
              children: [
                Expanded(child: open),
                const SizedBox(width: BrandSpacing.s3),
                follow,
              ],
            ),
    );
  }
}

/// Looks like a search field; opens Search.
class _SearchEntry extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s5,
        BrandSpacing.s3,
        BrandSpacing.s5,
        0,
      ),
      child: Semantics(
        button: true,
        label: l10n.searchFieldLabel,
        hint: l10n.exploreHint,
        excludeSemantics: true,
        onTap: () => const SearchRoute().push<void>(context),
        child: Material(
          color: theme.colorScheme.surfaceContainerHigh,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => const SearchRoute().push<void>(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: BrandSpacing.s5,
                  vertical: BrandSpacing.s3,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: BrandSpacing.s4),
                    Expanded(
                      child: Text(
                        l10n.exploreHint,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
