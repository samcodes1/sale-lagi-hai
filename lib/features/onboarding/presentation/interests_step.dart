import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/icons/category_icons.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/onboarding_scaffold.dart';

/// Step 3: interests (top-level categories). Three or more are suggested,
/// none are required.
class InterestsStep extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final interests = ref.watch(interestsProvider);
    final picked = ref.watch(preferencesProvider.select((p) => p.interestIds));
    void next() => const WelcomeBrandsRoute().push<void>(context);

    return OnboardingScaffold(
      step: 3,
      title: l10n.interestsTitle,
      intro: l10n.interestsBody,
      onSkip: next,
      slivers: [
        switch (interests) {
          AsyncData(:final value) => SliverPadding(
            padding: onboardingContentPadding,
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.interestsPicked(picked.length),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(height: BrandSpacing.s4),
                  Wrap(
                    spacing: BrandSpacing.s3,
                    runSpacing: BrandSpacing.s3,
                    children: [
                      for (final category in value)
                        FilterChip(
                          avatar: Icon(categoryIcon(category.icon)),
                          label: Text(category.name(urdu: urdu)),
                          selected: picked.contains(category.id),
                          onSelected: (_) => ref
                              .read(preferencesProvider.notifier)
                              .toggleInterest(category.id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AsyncError(:final error) => SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(
              failure: error is AppFailure ? error : const UnexpectedFailure(),
              onRetry: () => ref.invalidate(categoriesProvider),
            ),
          ),
          _ => SliverPadding(
            padding: onboardingContentPadding,
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: BrandSpacing.s3,
                runSpacing: BrandSpacing.s3,
                children: [
                  for (var i = 0; i < 8; i++)
                    SkeletonBox(
                      width: 96 + (i % 3) * 24,
                      height: 40,
                      radius: BrandRadii.button,
                    ),
                ],
              ),
            ),
          ),
        },
      ],
      primaryLabel: l10n.actionContinue,
      onPrimary: next,
    );
  }
}
