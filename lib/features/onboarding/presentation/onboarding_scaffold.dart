import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// How many onboarding steps there are (language, city, interests, brands,
/// alerts).
const onboardingSteps = 5;

/// The layout every onboarding step shares: progress, an optional Skip, the
/// heading and intro, the step's content and a bottom action bar.
///
/// The heading scrolls with the content (a fixed header would leave no
/// room at 200% text), and the bottom bar stays above the gesture bar.
class OnboardingScaffold extends StatelessWidget {
  const new({
    required this.step,
    required this.title,
    required this.slivers,
    required this.primaryLabel,
    required this.onPrimary,
    this.intro,
    this.onSkip,
    this.secondaryLabel,
    this.onSecondary,
    this.leading,
    super.key,
  });

  /// 1-based.
  final int step;
  final String title;
  final String? intro;

  /// Shown above the heading (the logo on the first step).
  final Widget? leading;

  /// The step's content, after the heading.
  final List<Widget> slivers;

  final String primaryLabel;

  /// `null` disables the primary button.
  final VoidCallback? onPrimary;

  /// Skippable steps show "Skip" in the top bar.
  final VoidCallback? onSkip;

  /// A text button under the primary one; `null` [onSecondary] disables it.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: canPop
            ? BackButton(onPressed: () => Navigator.of(context).maybePop())
            : null,
        title: Semantics(
          label: l10n.onboardingStep(step, onboardingSteps),
          child: ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BrandSpacing.s2),
              child: LinearProgressIndicator(
                value: step / onboardingSteps,
                minHeight: BrandSpacing.s3,
              ),
            ),
          ),
        ),
        actions: [
          if (onSkip != null)
            TextButton(onPressed: onSkip, child: Text(l10n.actionSkip)),
          const SizedBox(width: BrandSpacing.s3),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BrandSpacing.s5,
              BrandSpacing.s5,
              BrandSpacing.s5,
              BrandSpacing.s5,
            ),
            sliver: SliverList.list(
              children: [
                ?leading,
                Semantics(
                  header: true,
                  child: Text(title, style: theme.textTheme.headlineSmall),
                ),
                if (intro case final intro?) ...[
                  const SizedBox(height: BrandSpacing.s3),
                  Text(
                    intro,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...slivers,
          const SliverToBoxAdapter(child: SizedBox(height: BrandSpacing.s5)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: BrandSpacing.s3),
        child: Material(
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BrandSpacing.s5,
              BrandSpacing.s3,
              BrandSpacing.s5,
              BrandSpacing.s3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
                if (secondaryLabel case final label?) ...[
                  const SizedBox(height: BrandSpacing.s2),
                  TextButton(onPressed: onSecondary, child: Text(label)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal padding for step content, matching the heading.
const onboardingContentPadding = EdgeInsetsDirectional.symmetric(
  horizontal: BrandSpacing.s5,
);
