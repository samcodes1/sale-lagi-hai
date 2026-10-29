import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_refresh_indicator.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/presentation/paged_deal_list.dart';
import 'package:sale_lagi_hai/features/follows/presentation/follow_button.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';

/// A category page: its live deals in the shopper's city, newest first,
/// narrowed by subcategory chips, and Follow. [slug] was validated by the
/// route; an unknown or switched-off category shows Not found.
class CategoryScreen extends ConsumerStatefulWidget {
  const new({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  /// The picked subcategory; `null` is "All".
  String? _sub;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final categories = ref.watch(categoriesProvider);
    return switch (categories) {
      AsyncData(:final value) => () {
        final category = value.where((c) => c.slug == widget.slug).firstOrNull;
        if (category == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.categoryTitle)),
            body: const ErrorView(failure: NotFoundFailure()),
          );
        }
        final subs = [
          for (final c in value)
            if (c.parentId == category.id) c,
        ];
        return _page(context, category, subs, urdu: urdu);
      }(),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(title: Text(l10n.categoryTitle)),
        body: ErrorView(
          failure: error is AppFailure ? error : const UnexpectedFailure(),
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(title: Text(l10n.categoryTitle)),
        body: const Padding(
          padding: EdgeInsetsDirectional.all(BrandSpacing.s5),
          child: DealCardSkeleton(),
        ),
      ),
    };
  }

  Widget _page(
    BuildContext context,
    Category category,
    List<Category> subs, {
    required bool urdu,
  }) {
    final l10n = context.l10n;
    final name = category.name(urdu: urdu);
    final query = CategoryDeals(
      _sub == null ? [category.id, for (final s in subs) s.id] : [_sub!],
      cityId: ref.watch(homeCityProvider),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          FollowButton(
            target: FollowTarget.category,
            id: category.id,
            name: name,
          ),
          const SizedBox(width: BrandSpacing.s3),
        ],
      ),
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
            if (subs.isNotEmpty)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
                  child: Row(
                    children: [
                      for (final (id, label) in [
                        (null, l10n.categoryAll),
                        for (final s in subs) (s.id, s.name(urdu: urdu)),
                      ])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: BrandSpacing.s3,
                          ),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _sub == id,
                            onSelected: (_) => setState(() => _sub = id),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              const SliverToBoxAdapter(
                child: SizedBox(height: BrandSpacing.s5),
              ),
            PagedDealSlivers(query: query, emptyMessage: l10n.categoryNoDeals),
          ],
        ),
      ),
    );
  }
}
