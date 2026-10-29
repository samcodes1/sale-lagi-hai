# Theming reference: tokens → Material 3 `ThemeData`

The source of truth is `design/tokens/brand_tokens.json`, generated into `design/flutter/brand_tokens.dart`, and the contrast proof is `design/tokens/contrast-report.md`. When you change a token, regenerate both files and re-run the contrast script. Never edit hex values in `lib/`.

## 1. Colour roles

The palette:
- **Haldi** (turmeric yellow): brand primary, CTA fills, the Featured badge.
- **Neel** (indigo): secondary, links, selected chips, focus ring.
- **Mirch** (chilli red): deal and discount badges only.
- **Surma** (kohl neutrals): surfaces and text.
- **Kaghaz** (paper cream): inverse text.

| M3 role | Light | Dark | Notes |
|---|---|---|---|
| `primary` / `onPrimary` | Haldi 500 / Surma 900 | token `dark.primary` | Yellow fills always carry **dark** labels (11:1). Never use white on Haldi |
| `primaryContainer` / `on…` | Haldi 100 / Haldi 900 | token | Tonal buttons and the selected nav indicator |
| `secondary` / `onSecondary` | Neel 500 / white | token | Links, selected filter chips, focus |
| `surface` / `onSurface` | white / Surma 900 | Surma 900 / Surma 50 | |
| `surfaceContainerLowest…Highest` | Surma 0 → 200 | Surma 950 → 700 | Elevation by tone. Cards are `surfaceContainerLow` |
| `onSurfaceVariant` | Surma 600 | token | Secondary text (6.9:1) |
| `outline` / `outlineVariant` | Surma 500 / Surma 200 | token | Input borders need ≥3:1 (`outlineStrong` is 4.44:1) |
| `error` / `onError` | error 500 / white | token | |
| `inverseSurface` / `onInverseSurface` | Surma 900 / Kaghaz | token | Snackbars |

Put brand-specific semantic colours that M3 has no role for in a `ThemeExtension`:

```dart
@immutable
class DealColors extends ThemeExtension<DealColors> {
  const new({
    required this.deal, required this.onDeal,
    required this.dealContainer, required this.onDealContainer,
    required this.featured, required this.onFeatured,
    required this.success, required this.warning, required this.info,
  });
  final Color deal, onDeal, dealContainer, onDealContainer;
  final Color featured, onFeatured, success, warning, info;

  @override
  DealColors copyWith({Color? deal /* … */}) => DealColors(deal: deal ?? this.deal /* … */);

  @override
  DealColors lerp(DealColors? other, double t) => other == null ? this : DealColors(
    deal: Color.lerp(deal, other.deal, t)!, /* …every field… */
  );
}
// Usage: Theme.of(context).extension<DealColors>()!.deal
```

**High contrast:** pass `highContrastTheme` and `highContrastDarkTheme` built with `contrastLevel: 1.0` or darker token variants, so that secondary text and outlines reach at least 7:1 and 4.5:1. Since 3.47, `MaterialApp` picks them up automatically when Android's high-contrast setting is on.

## 2. Typography

M3 type scale baseline (sp). We map our families onto it:

| Role | Size / weight | Family (en) | Family (ur) |
|---|---|---|---|
| displayLarge / Medium / Small | 57 / 45 / 36, regular | Bricolage Grotesque | Noto Nastaliq Urdu |
| headlineLarge / Medium / Small | 32 / 28 / 24, regular | Bricolage Grotesque (Bold for brand) | Noto Nastaliq Urdu |
| titleLarge | 22, regular | Instrument Sans SemiBold | Noto Nastaliq Urdu |
| titleMedium / Small | 16 / 14, medium | Instrument Sans | Noto Naskh Arabic |
| bodyLarge / Medium / Small | 16 / 14 / 12, regular | Instrument Sans | Noto Naskh Arabic (dense) or Nastaliq (reading) |
| labelLarge / Medium / Small | 14 / 12 / 11, medium | Instrument Sans | Noto Naskh Arabic |

Rules:
- **Switch families by locale, not per widget.** Build two `TextTheme`s and pick one in `buildTheme` from `Localizations.localeOf(context)`, or use `fontFamilyFallback` for mixed strings.
- **Line height:** Latin uses `height: 1.3–1.5`. Nastaliq uses `height: 1.6–1.9` plus a matching `StrutStyle(forceStrutHeight: false, height: …)`, and Naskh uses 1.5–1.6. See rtl-urdu.md.
- **Variable fonts:** use the `[wght]` files from `design/fonts/variable/` with `FontVariation('wght', 600)` where needed. Declare the static files too, as a fallback for `FontWeight`.
- **Bundle the fonts** in `pubspec.yaml` under `flutter: fonts:`, and declare the licences from `design/fonts/licenses/` with `LicenseRegistry.addLicense`. Don't use google_fonts at runtime. If google_fonts is used at all, set `GoogleFonts.config.allowRuntimeFetching = false` and bundle the files.
- **Prices use tabular figures** (`FontFeature.tabularFigures()`) so countdowns and prices don't jitter.

## 3. Spacing, radii, elevation

| Token | dp | Use |
|---|---|---|
| `space4` | 4 | Icon to label |
| `space8` | 8 | Gap between related items and adjacent targets |
| `space12` | 12 | Inside chips and badges |
| `space16` | 16 | Screen gutters (compact) and card padding |
| `space24` | 24 | Section gaps; gutters on medium |
| `space32/48` | 32/48 | Hero and empty-state spacing |

Radii: chips and badges 8, cards 16, sheets 28 (top), buttons stadium (full). In M3, elevation is shown by tone (surface containers), not shadows. Use shadows only on the FAB and dragged items.

## 4. Component theme checklist (set once in `ThemeData`)
- **Buttons.** Set `filledButtonTheme`, `outlinedButtonTheme` and `textButtonTheme` with `minimumSize: Size(64, 48)`, padding of 24 horizontal, a stadium shape and the `labelLarge` text style.
- **`chipTheme`.** Use 48dp hit area (`materialTapTargetSize: padded`), a selected colour of secondaryContainer, and label padding that survives Nastaliq height.
- **`cardTheme`.** Use `surfaceContainerLow`, radius 16, `clipBehavior: Clip.antiAlias` (images), and margin 0. Let the layout decide spacing.
- **`inputDecorationTheme`.** Use outlined, `outlineStrong` borders, a 2dp Neel focus ring, and `errorMaxLines: 3` (Urdu errors are long).
- **`navigationBarTheme`.** Use height 80, the indicator in primaryContainer, and labels always shown (`NavigationDestinationLabelBehavior.alwaysShow`), because icon-only navigation fails users who don't recognise the icons.
- **`snackBarTheme`.** Use floating behavior, inverse surface colours and `showCloseIcon` for long messages. Snackbars never carry the *only* path to an action.
- **`bottomSheetTheme`.** Use `showDragHandle: true` and a radius of 28. The drag handle gives the sheet a semantic dismiss action.
- **`badgeTheme`**, **`progressIndicatorTheme`** and **`appBarTheme`.** For the app bar, set `scrolledUnderElevation: 0` and the surface tint from `surfaceContainer`.
- **`pageTransitionsTheme`.** Use Android: `FadeForwardsPageTransitionsBuilder` (or the M3 default), and iOS: Cupertino.

## 5. Motion tokens

Flutter exposes the M3 tokens as `Durations.*` and `Easing.*`:

| Token | ms | Use |
|---|---|---|
| short1–short4 | 50 / 100 / 150 / 200 | Ripples, selection, small toggles (save heart) |
| medium1–medium4 | 250 / 300 / 350 / 400 | Chips, expanding a card, sheets |
| long1–long4 | 450 / 500 / 550 / 600 | Full-screen container transform (card → detail) |
| extralong1–4 | 700–1000 | Rare: onboarding illustrations |

| Easing | Curve | Use |
|---|---|---|
| `Easing.emphasizedDecelerate` | cubic(0.05, 0.7, 0.1, 1) | Entering elements |
| `Easing.emphasizedAccelerate` | cubic(0.3, 0, 0.8, 0.15) | Exiting elements |
| `Easing.standard` | cubic(0.2, 0, 0, 1) | Utility motion that starts and ends on screen |
| `Easing.linear` | | Progress or opacity only |

Wrap every custom animation with a helper:

```dart
Duration motion(BuildContext c, Duration d) =>
    MediaQuery.disableAnimationsOf(c) ? Duration.zero : d;
```

## Sources
- [Material Components motion tokens](https://github.com/material-components/material-components-android/blob/master/docs/theming/Motion.md) and [type scale](https://github.com/material-components/material-components-android/blob/master/docs/theming/Typography.md)
- material_ui API: [ColorScheme.fromSeed](https://pub.dev/documentation/material_ui/latest/material_ui/ColorScheme/ColorScheme.fromSeed.html), [DynamicSchemeVariant](https://pub.dev/documentation/material_ui/latest/material_ui/DynamicSchemeVariant.html), [CHANGELOG](https://github.com/flutter/packages/blob/main/packages/material_ui/CHANGELOG.md)
- [What's new in Flutter 3.47](https://flutter.dev/blog/whats-new-in-flutter-3-47) (high-contrast detection), read through the flutter/website source
- Project files: `design/tokens/brand_tokens.json`, `design/tokens/contrast-report.md`
