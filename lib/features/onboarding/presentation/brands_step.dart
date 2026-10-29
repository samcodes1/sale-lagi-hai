import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/content_text.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/onboarding_scaffold.dart';

/// Step 4: favourite brands, from the interests picked in step 3 (or all
/// brands). Following is kept on the phone until the shopper signs in.
class BrandsStep extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final interests = ref.watch(
      preferencesProvider.select((p) => interestKey(p.interestIds)),
    );
    final brands = ref.watch(brandsForInterestsProvider(interests));
    final followed = ref.watch(preferencesProvider.select((p) => p.brandIds));
    void next() => const WelcomeAlertsRoute().push<void>(context);

    return OnboardingScaffold(
      step: 4,
      title: l10n.brandsTitle,
      intro: l10n.brandsBody,
      onSkip: next,
      slivers: [
        switch (brands) {
          AsyncData(:final value) when value.isEmpty => SliverFillRemaining(
            hasScrollBody: false,
            child: MessageView(
              icon: Icons.storefront_outlined,
              message: l10n.brandsEmpty,
            ),
          ),
          AsyncData(:final value) => SliverMainAxisGroup(
            slivers: [
              SliverPadding(
                padding: onboardingContentPadding,
                sliver: SliverToBoxAdapter(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.brandsFollowed(
                        value.where((b) => followed.contains(b.id)).length,
                      ),
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: value.length,
                itemBuilder: (context, i) => _BrandTile(
                  brand: value[i],
                  urdu: urdu,
                  followed: followed.contains(value[i].id),
                  onToggle: () => ref
                      .read(preferencesProvider.notifier)
                      .toggleBrand(value[i].id),
                ),
              ),
            ],
          ),
          AsyncError(:final error) => SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(
              failure: error is AppFailure ? error : const UnexpectedFailure(),
              onRetry: () =>
                  ref.invalidate(brandsForInterestsProvider(interests)),
            ),
          ),
          _ => SliverList.list(
            children: [
              for (var i = 0; i < 6; i++)
                const Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: BrandSpacing.s5,
                    vertical: BrandSpacing.s3,
                  ),
                  child: SkeletonBox(height: 48),
                ),
            ],
          ),
        },
      ],
      primaryLabel: l10n.actionContinue,
      onPrimary: next,
    );
  }
}

class _BrandTile extends StatelessWidget {
  const new({
    required this.brand,
    required this.urdu,
    required this.followed,
    required this.onToggle,
  });

  final Brand brand;
  final bool urdu;
  final bool followed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final name = brand.displayName(urdu: urdu);
    // One target: the whole row toggles, and reads as a toggle. At large
    // text sizes the pill moves under the name instead of squeezing it.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 15;
    final avatar = ExcludeSemantics(
      child: CircleAvatar(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        child: Text(name.characters.first),
      ),
    );
    final pill = ExcludeSemantics(
      child: _FollowPill(
        followed: followed,
        label: followed ? l10n.actionFollowing : l10n.actionFollow,
      ),
    );
    final title = ContentText(
      name,
      style: Theme.of(context).textTheme.bodyLarge,
    );
    return MergeSemantics(
      child: Semantics(
        toggled: followed,
        button: true,
        child: InkWell(
          onTap: onToggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BrandSpacing.s5,
                vertical: BrandSpacing.s3,
              ),
              child: stacked
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        avatar,
                        const SizedBox(width: BrandSpacing.s4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              title,
                              const SizedBox(height: BrandSpacing.s3),
                              pill,
                            ],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        avatar,
                        const SizedBox(width: BrandSpacing.s4),
                        Expanded(child: title),
                        const SizedBox(width: BrandSpacing.s3),
                        pill,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FollowPill extends StatelessWidget {
  const new({required this.followed, required this.label});

  final bool followed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: followed ? scheme.secondary : null,
        borderRadius: BorderRadius.circular(BrandRadii.full),
        border: Border.all(color: followed ? scheme.secondary : scheme.outline),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BrandSpacing.s4,
          vertical: BrandSpacing.s2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              followed ? Icons.check : Icons.add,
              size: 18,
              color: followed ? scheme.onSecondary : scheme.onSurface,
            ),
            const SizedBox(width: BrandSpacing.s2),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: followed ? scheme.onSecondary : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
