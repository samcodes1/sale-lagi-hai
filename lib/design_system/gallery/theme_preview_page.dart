import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/deal_time_labels.dart';
import 'package:sale_lagi_hai/core/l10n/failure_messages.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';
import 'package:sale_lagi_hai/design_system/theme/deal_colors.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// A developer page showing the theme: type scale, colour roles and themed
/// components, in Latin and Urdu. Visual QA screenshots it.
///
/// Internal tool, so its sample text is not localized. It grows into the
/// full widget gallery in sub-phase 1.6.
class ThemePreviewPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme preview'),
        actions: const [_LanguageToggle()],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(BrandSpacing.screenGutter),
        children: [
          const _Section(title: 'Type scale', child: _TypeScale()),
          const _Section(title: 'Colour roles', child: _ColourRoles()),
          const _Section(title: 'Components', child: _Components()),
          const _Section(title: 'Localization', child: _LocalizationSample()),
          _Section(
            title: 'Urdu (Nastaliq, RTL)',
            child: Theme(
              data: AppTheme.build(
                brightness: theme.brightness,
                script: AppScript.urdu,
              ),
              child: const Directionality(
                textDirection: TextDirection.rtl,
                child: _UrduSample(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: BrandSpacing.s8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: BrandSpacing.s4),
        child,
      ],
    ),
  );
}

class _TypeScale extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final styles = <(String, TextStyle?)>[
      ('Display · Flat 40%', text.displayMedium),
      ('Headline · Rs 2,999', text.headlineMedium),
      ('Title · Sapphire Winter Sale', text.titleLarge),
      ('Title medium · Dolmen Mall Clifton', text.titleMedium),
      ('Body · Ends Sunday, 11:59 pm. Online and in store.', text.bodyLarge),
      ('Body small · Verified 3 hours ago', text.bodySmall),
      ('Label · SET ALERT', text.labelLarge),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (sample, style) in styles)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: BrandSpacing.s3),
            child: Text(sample, style: style),
          ),
      ],
    );
  }
}

class _ColourRoles extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final deal = DealColors.of(context);
    final swatches = <(String, Color, Color)>[
      ('Primary · Haldi', scheme.primary, scheme.onPrimary),
      ('Secondary · Neel', scheme.secondary, scheme.onSecondary),
      ('Deal · Mirch', deal.deal, deal.onDeal),
      ('Deal container', deal.dealContainer, deal.onDealContainer),
      ('Featured', deal.featured, deal.onFeatured),
      ('Surface', scheme.surface, scheme.onSurface),
      ('Container high', scheme.surfaceContainerHighest, scheme.onSurface),
      ('Inverse', scheme.inverseSurface, scheme.onInverseSurface),
      ('Error', scheme.error, scheme.onError),
    ];
    return Wrap(
      spacing: BrandSpacing.s3,
      runSpacing: BrandSpacing.s3,
      children: [
        for (final (name, fill, on) in swatches)
          Container(
            width: 152,
            padding: const EdgeInsetsDirectional.all(BrandSpacing.s4),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BrandRadii.card,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              name,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: on),
            ),
          ),
      ],
    );
  }
}

class _Components extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final deal = DealColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: BrandSpacing.s3,
          runSpacing: BrandSpacing.s3,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Set alert')),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Share on WhatsApp'),
            ),
            TextButton(onPressed: () {}, child: const Text('View terms')),
            const FilledButton(onPressed: null, child: Text('Disabled')),
          ],
        ),
        const SizedBox(height: BrandSpacing.s5),
        Wrap(
          spacing: BrandSpacing.s3,
          runSpacing: BrandSpacing.s3,
          children: [
            FilterChip(label: const Text('Food'), onSelected: (_) {}),
            FilterChip(
              label: const Text('Fashion'),
              selected: true,
              onSelected: (_) {},
            ),
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BrandSpacing.s3,
                vertical: BrandSpacing.s2,
              ),
              decoration: BoxDecoration(
                color: deal.deal,
                borderRadius: BrandRadii.badge,
              ),
              child: Text(
                '-40%',
                style: BrandTypography.badge.copyWith(color: deal.onDeal),
              ),
            ),
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BrandSpacing.s3,
                vertical: BrandSpacing.s2,
              ),
              decoration: BoxDecoration(
                color: deal.featured,
                borderRadius: BrandRadii.badge,
              ),
              child: Text(
                'Featured',
                style: text.labelMedium?.copyWith(color: deal.onFeatured),
              ),
            ),
          ],
        ),
        const SizedBox(height: BrandSpacing.s5),
        const TextField(
          decoration: InputDecoration(
            labelText: 'Search deals',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: BrandSpacing.s4),
        // Selection controls always carry a visible label.
        SwitchListTile(
          title: const Text('Deal alerts'),
          value: true,
          onChanged: (_) {},
        ),
        CheckboxListTile(
          title: const Text('Only deals for my cards'),
          value: true,
          onChanged: (_) {},
        ),
        const LinearProgressIndicator(value: 0.6),
        const SizedBox(height: BrandSpacing.s4),
        const Card(
          child: ListTile(
            leading: Icon(Icons.local_offer_outlined),
            title: Text('Kolachi · HBL cards'),
            subtitle: Text('25% off dinner · Do Darya · ends tonight'),
          ),
        ),
      ],
    );
  }
}

class _UrduSample extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('سیل لگی ہے!', style: text.headlineMedium),
        Text('سیل کی خبر، سب سے پہلے۔', style: text.titleLarge),
        Text(
          'سفائر کی سردیوں کی سیل شروع ہو گئی ہے۔ اتوار رات تک۔',
          style: text.bodyLarge,
        ),
        const SizedBox(height: BrandSpacing.s3),
        Wrap(
          spacing: BrandSpacing.s3,
          children: [
            FilledButton(onPressed: () {}, child: const Text('الرٹ لگائیں')),
            OutlinedButton(onPressed: () {}, child: const Text('شیئر کریں')),
          ],
        ),
      ],
    );
  }
}

/// Switches the whole app between English and Urdu.
class _LanguageToggle extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final l10n = context.l10n;
    final next = AppLocales.isRtl(locale)
        ? AppLocales.english
        : AppLocales.urdu;
    // Full ink, not the link colour: thin Urdu strokes at label size need
    // the extra contrast.
    return OutlinedButton.icon(
      onPressed: () => ref.read(localeControllerProvider.notifier).select(next),
      icon: const Icon(Icons.translate),
      label: Text(
        AppLocales.isRtl(locale) ? l10n.languageEnglish : l10n.languageUrdu,
      ),
    );
  }
}

/// Real strings and formatters in the current language.
class _LocalizationSample extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final format = AppFormatters.of(context);
    final labels = DealTimeLabels(l10n, format);
    final text = Theme.of(context).textTheme;
    final now = DateTime(2026, 10, 29, 12);
    final lines = [
      [
        l10n.navHome,
        l10n.navExplore,
        l10n.navAlerts,
        l10n.navSaved,
        l10n.navProfile,
      ].join(' · '),
      [
        format.price(2999),
        format.discount(40),
        l10n.flatPercentOff(30),
      ].join(' · '),
      labels.expiry(now.add(const Duration(hours: 3)), now: now),
      labels.expiry(DateTime(2026, 10, 30, 20), now: now),
      labels.expiry(DateTime(2026, 11, 3), now: now),
      labels.verified(now.subtract(const Duration(hours: 3)), now: now),
      l10n.featuredLabel,
      const OfflineFailure().message(l10n),
      l10n.emptySaved,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: BrandSpacing.s2),
            child: Text(line, style: text.bodyMedium),
          ),
      ],
    );
  }
}
