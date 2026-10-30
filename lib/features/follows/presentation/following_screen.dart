import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/icons/category_icons.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/follows/application/follow_providers.dart';
import 'package:sale_lagi_hai/features/follows/presentation/follow_button.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

/// Following (screen S16): the brands and categories the shopper
/// follows, each with its Follow button to stop following.
class FollowingScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final preferences = ref.watch(preferencesProvider);
    final brands = ref.watch(followedBrandsProvider);
    final categories = ref.watch(followedCategoriesProvider);
    final nothing =
        preferences.brandIds.isEmpty && preferences.categoryFollowIds.isEmpty;

    Widget heading(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s5,
        BrandSpacing.s6,
        BrandSpacing.s5,
        BrandSpacing.s2,
      ),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );

    Widget row({
      required Widget leading,
      required String name,
      required VoidCallback onOpen,
      required Widget follow,
    }) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BrandSpacing.s5,
        vertical: BrandSpacing.s2,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: BrandSpacing.s3,
        runSpacing: BrandSpacing.s2,
        children: [
          TextButton.icon(onPressed: onOpen, icon: leading, label: Text(name)),
          follow,
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.followingTitle)),
      body: nothing
          ? MessageView(
              icon: Icons.favorite_border,
              message: l10n.followingEmpty,
              actionLabel: l10n.actionExplore,
              onAction: () => const ExploreRoute().go(context),
            )
          : ListView(
              children: [
                if (preferences.brandIds.isNotEmpty) ...[
                  heading(l10n.followingBrands),
                  switch (brands) {
                    AsyncData(:final value) => Column(
                      children: [
                        for (final b in value)
                          row(
                            leading: const Icon(Icons.storefront_outlined),
                            name: b.displayName(urdu: urdu),
                            onOpen: () =>
                                BrandRoute(slug: b.slug).push<void>(context),
                            follow: FollowButton(
                              target: FollowTarget.brand,
                              id: b.id,
                              name: b.displayName(urdu: urdu),
                            ),
                          ),
                      ],
                    ),
                    AsyncError(:final error) => InlineErrorBanner(
                      failure: error is AppFailure
                          ? error
                          : const UnexpectedFailure(),
                      onRetry: () => ref.invalidate(followedBrandsProvider),
                    ),
                    _ => const Padding(
                      padding: EdgeInsetsDirectional.all(BrandSpacing.s5),
                      child: SkeletonBox(height: 48),
                    ),
                  },
                ],
                if (categories.isNotEmpty) ...[
                  heading(l10n.followingCategories),
                  for (final c in categories)
                    row(
                      leading: Icon(categoryIcon(c.icon)),
                      name: c.name(urdu: urdu),
                      onOpen: () =>
                          CategoryRoute(slug: c.slug).push<void>(context),
                      follow: FollowButton(
                        target: FollowTarget.category,
                        id: c.id,
                        name: c.name(urdu: urdu),
                      ),
                    ),
                ],
                const SizedBox(height: BrandSpacing.s8),
              ],
            ),
    );
  }
}
