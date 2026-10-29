import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/onboarding_scaffold.dart';

/// Step 1, the only required one: English or Urdu. The choice applies at
/// once (the whole screen switches script and direction), defaulting to
/// the phone's language.
class LanguageStep extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final locale = ref.watch(localeControllerProvider);
    final dark = theme.brightness == Brightness.dark;
    return OnboardingScaffold(
      step: 1,
      leading: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: BrandSpacing.s7),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Image.asset(
            dark
                ? 'assets/brand/lockup_dark.png'
                : 'assets/brand/lockup_light.png',
            width: 200,
            semanticLabel: l10n.appTitle,
          ),
        ),
      ),
      title: l10n.welcomeTitle,
      intro:
          '${l10n.welcomeLanguagePrompt}\n${l10n.welcomeLanguagePromptOther}',
      slivers: [
        SliverPadding(
          padding: onboardingContentPadding,
          sliver: SliverList.list(
            children: [
              for (final (option, label) in [
                (AppLocales.english, l10n.languageEnglish),
                (AppLocales.urdu, l10n.languageUrdu),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: BrandSpacing.s4,
                  ),
                  child: _LanguageTile(
                    label: label,
                    locale: option,
                    selected: locale == option,
                    onTap: () => ref
                        .read(localeControllerProvider.notifier)
                        .select(option),
                  ),
                ),
            ],
          ),
        ),
      ],
      primaryLabel: l10n.actionContinue,
      onPrimary: () {
        ref.read(languageChosenProvider.notifier).confirm();
        unawaited(const WelcomeCityRoute().push<void>(context));
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const new({
    required this.label,
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Locale locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BrandRadii.md),
          side: BorderSide(
            color: selected ? scheme.secondary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BrandSpacing.s5,
                vertical: BrandSpacing.s4,
              ),
              child: Row(
                children: [
                  Expanded(
                    // Each name in its own script, type scale and
                    // direction, whatever the UI language.
                    child: Text(
                      label,
                      textDirection: AppLocales.isRtl(locale)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      // Lined up with the UI's start edge.
                      textAlign: Directionality.of(context) == TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                      style:
                          (AppLocales.isRtl(locale)
                                  ? AppTheme.urduTextTheme.titleLarge
                                  : BrandTypography.textTheme.titleLarge)
                              ?.copyWith(
                                color: selected
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurface,
                              ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? scheme.secondary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
