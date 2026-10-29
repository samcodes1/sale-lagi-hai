import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';
import 'package:sale_lagi_hai/design_system/theme/deal_colors.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// WCAG 2.2 contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) * 1.0;
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final variants = <String, ThemeData>{
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
    'light high contrast': AppTheme.build(
      brightness: Brightness.light,
      highContrast: true,
    ),
    'dark high contrast': AppTheme.build(
      brightness: Brightness.dark,
      highContrast: true,
    ),
  };

  test('contrast helper matches known values', () {
    expect(contrast(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(
      contrast(BrandColors.mirch500, BrandColors.surma0),
      closeTo(4.71, 0.01),
    );
  });

  group('colour roles come from the brand tokens', () {
    test('light', () {
      final scheme = AppTheme.light().colorScheme;
      expect(scheme.primary, BrandLight.primary);
      expect(scheme.onPrimary, BrandLight.onPrimary);
      expect(scheme.secondary, BrandLight.secondary);
      expect(scheme.surface, BrandLight.surface);
      expect(scheme.onSurface, BrandLight.textPrimary);
      expect(scheme.onSurfaceVariant, BrandLight.textSecondary);
      expect(scheme.error, BrandLight.error);
      expect(AppTheme.light().scaffoldBackgroundColor, BrandLight.background);
    });

    test('dark', () {
      final scheme = AppTheme.dark().colorScheme;
      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, BrandDark.primary);
      expect(scheme.secondary, BrandDark.secondary);
      expect(scheme.surface, BrandDark.surface);
      expect(scheme.onSurface, BrandDark.textPrimary);
      expect(AppTheme.dark().scaffoldBackgroundColor, BrandDark.background);
    });

    test('no dynamic colour or surface tint', () {
      for (final theme in variants.values) {
        expect(theme.useMaterial3, isTrue);
        expect(theme.colorScheme.surfaceTint, Colors.transparent);
      }
    });
  });

  for (final MapEntry(key: name, value: theme) in variants.entries) {
    group('$name: contrast (WCAG 2.2 AA)', () {
      final s = theme.colorScheme;
      final deal = theme.extension<DealColors>()!;
      final highContrast = name.contains('high contrast');

      final textPairs = <String, (Color, Color)>{
        'onPrimary on primary': (s.onPrimary, s.primary),
        'onSecondary on secondary': (s.onSecondary, s.secondary),
        'onSurface on surface': (s.onSurface, s.surface),
        'onSurface on background': (s.onSurface, theme.scaffoldBackgroundColor),
        'onSurfaceVariant on surface': (s.onSurfaceVariant, s.surface),
        'onSurface on highest container': (
          s.onSurface,
          s.surfaceContainerHighest,
        ),
        'text button (secondary) on surface': (s.secondary, s.surface),
        'onError on error': (s.onError, s.error),
        'onInverseSurface on inverseSurface': (
          s.onInverseSurface,
          s.inverseSurface,
        ),
        'onPrimaryContainer on primaryContainer': (
          s.onPrimaryContainer,
          s.primaryContainer,
        ),
        'onSecondaryContainer on secondaryContainer': (
          s.onSecondaryContainer,
          s.secondaryContainer,
        ),
        'onDeal on deal': (deal.onDeal, deal.deal),
        'onDealContainer on dealContainer': (
          deal.onDealContainer,
          deal.dealContainer,
        ),
        'onFeatured on featured': (deal.onFeatured, deal.featured),
      };
      for (final MapEntry(key: pair, value: (fg, bg)) in textPairs.entries) {
        test('$pair ≥ 4.5:1', () => expect(contrast(fg, bg), greaterThan(4.5)));
      }

      final uiPairs = <String, (Color, Color)>{
        'outline on surface': (s.outline, s.surface),
        'focus ring on surface': (deal.focus, s.surface),
        'progress (secondary) on surface': (s.secondary, s.surface),
      };
      for (final MapEntry(key: pair, value: (fg, bg)) in uiPairs.entries) {
        test('$pair ≥ 3:1', () => expect(contrast(fg, bg), greaterThan(3)));
      }

      if (highContrast) {
        test('secondary text reaches 7:1', () {
          expect(contrast(s.onSurfaceVariant, s.surface), greaterThan(7));
        });
      }
    });
  }

  group('Haldi yellow is a fill, never a thin mark on a light surface', () {
    final theme = AppTheme.light();

    test('text buttons and links use Neel', () {
      final style = theme.textButtonTheme.style!;
      expect(style.foregroundColor!.resolve({}), theme.colorScheme.secondary);
    });

    test('progress, selection controls and focus use Neel', () {
      final s = theme.colorScheme;
      expect(theme.progressIndicatorTheme.color, s.secondary);
      expect(
        theme.checkboxTheme.fillColor!.resolve({WidgetState.selected}),
        s.secondary,
      );
      expect(
        theme.radioTheme.fillColor!.resolve({WidgetState.selected}),
        s.secondary,
      );
      expect(
        theme.switchTheme.trackColor!.resolve({WidgetState.selected}),
        s.secondary,
      );
      expect(theme.sliderTheme.activeTrackColor, s.secondary);
      expect(theme.textSelectionTheme.cursorColor, BrandLight.focus);
    });

    test('filled buttons put dark text on yellow', () {
      final style = theme.filledButtonTheme.style!;
      expect(style.backgroundColor!.resolve({}), BrandColors.haldi500);
      expect(style.foregroundColor!.resolve({}), BrandColors.surma900);
    });
  });

  group('touch targets are at least 48dp', () {
    final theme = AppTheme.light();

    test('buttons', () {
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.outlinedButtonTheme.style!,
        theme.textButtonTheme.style!,
      ]) {
        expect(style.minimumSize!.resolve({})!.height, 48);
      }
      expect(theme.iconButtonTheme.style!.minimumSize!.resolve({})!.height, 48);
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    });
  });

  group('typography', () {
    test('Latin uses Instrument Sans for UI and Bricolage for display', () {
      final text = AppTheme.light().textTheme;
      expect(text.bodyLarge!.fontFamily, BrandFonts.ui);
      expect(text.labelLarge!.fontFamily, BrandFonts.ui);
      expect(text.displayMedium!.fontFamily, BrandFonts.display);
      expect(
        text.bodyLarge!.fontFamilyFallback,
        containsAll([BrandFonts.urduCompact, BrandFonts.urdu]),
      );
    });

    test(
      'Urdu: Nastaliq for headings and reading text, Naskh for controls',
      () {
        final text = AppTheme.light(script: AppScript.urdu).textTheme;
        for (final style in [
          text.displayLarge,
          text.displayMedium,
          text.headlineMedium,
          text.titleLarge,
          text.titleMedium,
          text.bodyMedium,
        ]) {
          expect(style!.fontFamily, BrandFonts.urdu);
          expect(style.height, greaterThanOrEqualTo(1.9));
        }
        for (final style in [
          text.titleSmall,
          text.bodyLarge,
          text.bodySmall,
          text.labelLarge,
          text.labelMedium,
          text.labelSmall,
        ]) {
          expect(style!.fontFamily, BrandFonts.urduCompact);
          expect(style.height, greaterThanOrEqualTo(1.6));
          expect(style.fontFamilyFallback, [BrandFonts.urdu, BrandFonts.ui]);
        }
      },
    );

    test('Latin styles fall back to Naskh first for Urdu content', () {
      expect(
        AppTheme.light().textTheme.bodyLarge!.fontFamilyFallback!.first,
        BrandFonts.urduCompact,
      );
    });

    test('text colours follow the scheme', () {
      final dark = AppTheme.dark();
      expect(dark.textTheme.bodyLarge!.color, dark.colorScheme.onSurface);
      expect(dark.textTheme.displayMedium!.color, dark.colorScheme.onSurface);
    });

    test('nothing informative is smaller than 12sp', () {
      final text = AppTheme.light().textTheme;
      for (final style in [text.bodySmall, text.labelSmall, text.labelMedium]) {
        expect(style!.fontSize, greaterThanOrEqualTo(12));
      }
    });

    test('prices and badges use tabular figures', () {
      expect(
        BrandTypography.price.fontFeatures,
        contains(const FontFeature.enable('tnum')),
      );
      expect(
        BrandTypography.badge.fontFeatures,
        contains(const FontFeature.enable('tnum')),
      );
    });
  });

  group('DealColors', () {
    test('every theme carries the matching set', () {
      expect(AppTheme.light().extension<DealColors>(), DealColors.light);
      expect(AppTheme.dark().extension<DealColors>(), DealColors.dark);
    });

    test('copyWith replaces only the given colours', () {
      final changed = DealColors.light.copyWith(deal: Colors.black);
      expect(changed.deal, Colors.black);
      expect(changed.onDeal, DealColors.light.onDeal);
      expect(changed.focus, DealColors.light.focus);
      expect(DealColors.light.copyWith().deal, DealColors.light.deal);
    });

    test('lerp interpolates every colour', () {
      const a = DealColors.light;
      const b = DealColors.dark;

      expect(a.lerp(b, 0).deal, a.deal);
      expect(a.lerp(b, 1).infoContainer, b.infoContainer);
      expect(a.lerp(b, 0.5).focus, Color.lerp(a.focus, b.focus, 0.5));
      expect(a.lerp(null, 0.5), same(a));
    });

    testWidgets('of(context) reads them from the theme', (tester) async {
      late DealColors found;
      await tester.pumpWidget(
        Theme(
          data: AppTheme.dark(),
          child: Builder(
            builder: (context) {
              found = DealColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(found, DealColors.dark);
    });
  });

  test('component themes avoid shadows and tints for elevation', () {
    final theme = AppTheme.light();
    expect(theme.cardTheme.elevation, 0);
    expect(theme.appBarTheme.scrolledUnderElevation, 0);
    expect(theme.navigationBarTheme.elevation, 0);
  });

  group('state-dependent component colours', () {
    const selected = {WidgetState.selected};
    const idle = <WidgetState>{};

    test('navigation: selected icons contrast with the indicator', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final nav = theme.navigationBarTheme;
        final indicator = nav.indicatorColor!;
        final selectedIcon = nav.iconTheme!.resolve(selected)!.color!;
        final idleIcon = nav.iconTheme!.resolve(idle)!.color!;

        expect(contrast(selectedIcon, indicator), greaterThan(3));
        expect(idleIcon, theme.colorScheme.onSurfaceVariant);
        expect(
          nav.labelTextStyle!.resolve(selected)!.color,
          theme.colorScheme.onSurface,
        );
        expect(
          nav.labelTextStyle!.resolve(idle)!.color,
          theme.colorScheme.onSurfaceVariant,
        );

        final rail = theme.navigationRailTheme;
        expect(
          contrast(rail.selectedIconTheme!.color!, rail.indicatorColor!),
          greaterThan(3),
        );
      }
    });

    test('selection controls show a visible unselected state', () {
      final theme = AppTheme.light();
      final s = theme.colorScheme;

      expect(theme.checkboxTheme.fillColor!.resolve(idle), Colors.transparent);
      expect(theme.radioTheme.fillColor!.resolve(idle), s.outline);
      expect(theme.switchTheme.thumbColor!.resolve(idle), s.outline);
      expect(theme.switchTheme.thumbColor!.resolve(selected), s.onSecondary);
      expect(
        theme.switchTheme.trackColor!.resolve(idle),
        s.surfaceContainerHighest,
      );
      expect(theme.switchTheme.trackOutlineColor!.resolve(idle), s.outline);
      expect(
        theme.switchTheme.trackOutlineColor!.resolve(selected),
        s.secondary,
      );
      expect(contrast(s.outline, s.surface), greaterThan(3));
    });

    test('Urdu themes keep every component theme', () {
      final urdu = AppTheme.dark(script: AppScript.urdu);
      expect(urdu.textTheme.bodyLarge!.fontFamily, BrandFonts.urduCompact);
      expect(urdu.textTheme.headlineMedium!.fontFamily, BrandFonts.urdu);
      expect(urdu.filledButtonTheme.style, isNotNull);
      expect(urdu.extension<DealColors>(), DealColors.dark);
    });
  });
}
