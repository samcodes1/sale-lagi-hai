import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/links/open_link.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_refresh_indicator.dart';
import 'package:sale_lagi_hai/design_system/widgets/content_text.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/presentation/paged_deal_list.dart';
import 'package:sale_lagi_hai/features/follows/presentation/follow_button.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';

/// A brand page (the public face of a business): name, verified badge,
/// category, website, Follow, and its live deals in the shopper's city.
/// [slug] was validated by the route; an unknown or hidden brand shows
/// Not found.
class BrandScreen extends ConsumerWidget {
  const new({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = ref.watch(brandProvider(slug));
    return switch (brand) {
      AsyncData(:final value) => _Page(value),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: Text(l10n.brandTitle)),
        body: ErrorView(
          failure: error is AppFailure ? error : const UnexpectedFailure(),
          onRetry: () => ref.invalidate(brandProvider(slug)),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(title: Text(l10n.brandTitle)),
        body: const Padding(
          padding: EdgeInsetsDirectional.all(BrandSpacing.s5),
          child: DealCardSkeleton(),
        ),
      ),
    };
  }
}

class _Page extends ConsumerWidget {
  const new(this.brand);

  final Brand brand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final name = brand.displayName(urdu: urdu);
    final category = (ref.watch(categoriesProvider).value ?? const <Category>[])
        .where((c) => c.id == brand.categoryId)
        .firstOrNull;
    final query = BrandDeals(brand.slug, cityId: ref.watch(homeCityProvider));
    final website = brand.website;
    return Scaffold(
      appBar: AppBar(title: ContentText(name)),
      body: AppRefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dealListProvider(query));
          await ref
              .read(dealListProvider(query).future)
              .then((_) {}, onError: (_) {});
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: CircleAvatar(
                            radius: 28,
                            child: Text(
                              name.characters.first,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                        ),
                        const SizedBox(width: BrandSpacing.s4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Semantics(
                                header: true,
                                child: ContentText(
                                  name,
                                  style: theme.textTheme.headlineSmall,
                                ),
                              ),
                              if (category != null)
                                Text(
                                  category.name(urdu: urdu),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (brand.isVerified) ...[
                      const SizedBox(height: BrandSpacing.s3),
                      Row(
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              Icons.verified,
                              size: 18,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: BrandSpacing.s2),
                          Flexible(child: Text(l10n.brandVerified)),
                        ],
                      ),
                    ],
                    const SizedBox(height: BrandSpacing.s4),
                    Wrap(
                      spacing: BrandSpacing.s3,
                      runSpacing: BrandSpacing.s3,
                      children: [
                        FollowButton(
                          target: FollowTarget.brand,
                          id: brand.id,
                          name: name,
                        ),
                        if (website != null)
                          TextButton.icon(
                            onPressed: () => openLink(
                              context,
                              ref.read(linkServiceProvider).openWeb(website),
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: Text(l10n.actionVisitWebsite),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PagedDealSlivers(query: query, emptyMessage: l10n.brandNoDeals),
          ],
        ),
      ),
    );
  }
}
