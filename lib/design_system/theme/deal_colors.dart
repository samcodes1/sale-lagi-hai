import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// Brand colours that Material 3's [ColorScheme] has no role for: deal and
/// discount badges, the "Featured" label, and status colours.
///
/// Read with `DealColors.of(context)`. As a [ThemeExtension] it animates
/// with theme changes.
@immutable
final class DealColors extends ThemeExtension<DealColors> {
  const new({
    required this.deal,
    required this.onDeal,
    required this.dealContainer,
    required this.onDealContainer,
    required this.featured,
    required this.onFeatured,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.focus,
  });

  static const light = DealColors(
    deal: BrandLight.deal,
    onDeal: BrandLight.onDeal,
    dealContainer: BrandLight.dealContainer,
    onDealContainer: BrandLight.onDealContainer,
    featured: BrandLight.featured,
    onFeatured: BrandLight.onFeatured,
    success: BrandLight.success,
    successContainer: BrandLight.successContainer,
    warning: BrandLight.warning,
    warningContainer: BrandLight.warningContainer,
    info: BrandLight.info,
    infoContainer: BrandLight.infoContainer,
    focus: BrandLight.focus,
  );

  static const dark = DealColors(
    deal: BrandDark.deal,
    onDeal: BrandDark.onDeal,
    dealContainer: BrandDark.dealContainer,
    onDealContainer: BrandDark.onDealContainer,
    featured: BrandDark.featured,
    onFeatured: BrandDark.onFeatured,
    success: BrandDark.success,
    successContainer: BrandDark.successContainer,
    warning: BrandDark.warning,
    warningContainer: BrandDark.warningContainer,
    info: BrandDark.info,
    infoContainer: BrandDark.infoContainer,
    focus: BrandDark.focus,
  );

  /// For Android's high-contrast setting: every text pair reaches 7:1
  /// (WCAG 1.4.6), e.g. the deal badge is Mirch 700 with white (8.8:1).
  static const highContrastLight = DealColors(
    deal: BrandColors.mirch700,
    onDeal: BrandColors.surma0,
    dealContainer: BrandColors.mirch50,
    onDealContainer: BrandColors.mirch800,
    featured: BrandLight.featured,
    onFeatured: BrandLight.onFeatured,
    success: BrandColors.success800,
    successContainer: BrandColors.success50,
    warning: BrandColors.warning800,
    warningContainer: BrandColors.warning50,
    info: BrandColors.neel800,
    infoContainer: BrandColors.info50,
    focus: BrandColors.neel700,
  );

  static const highContrastDark = DealColors(
    deal: BrandColors.mirch300,
    onDeal: BrandColors.surma950,
    dealContainer: BrandColors.mirch900,
    onDealContainer: BrandColors.mirch100,
    featured: BrandDark.featured,
    onFeatured: BrandDark.onFeatured,
    success: BrandColors.success50,
    successContainer: BrandColors.success800,
    warning: BrandColors.warning300,
    warningContainer: BrandColors.warning800,
    info: BrandColors.neel100,
    infoContainer: BrandColors.info800,
    focus: BrandColors.neel200,
  );

  /// Discount badge fill and its label. Fill only: never use [deal] for
  /// small text on tinted surfaces (4.7:1 on white is the limit).
  final Color deal;
  final Color onDeal;

  /// Tinted deal surfaces and the text on them.
  final Color dealContainer;
  final Color onDealContainer;

  /// The "Featured" (sponsored) label.
  final Color featured;
  final Color onFeatured;

  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;

  /// Keyboard focus ring.
  final Color focus;

  /// The colours of the nearest [Theme]. Throws if the theme was not built
  /// by `AppTheme`, which always installs them.
  static DealColors of(BuildContext context) =>
      Theme.of(context).extension<DealColors>()!;

  @override
  DealColors copyWith({
    Color? deal,
    Color? onDeal,
    Color? dealContainer,
    Color? onDealContainer,
    Color? featured,
    Color? onFeatured,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? focus,
  }) => DealColors(
    deal: deal ?? this.deal,
    onDeal: onDeal ?? this.onDeal,
    dealContainer: dealContainer ?? this.dealContainer,
    onDealContainer: onDealContainer ?? this.onDealContainer,
    featured: featured ?? this.featured,
    onFeatured: onFeatured ?? this.onFeatured,
    success: success ?? this.success,
    successContainer: successContainer ?? this.successContainer,
    warning: warning ?? this.warning,
    warningContainer: warningContainer ?? this.warningContainer,
    info: info ?? this.info,
    infoContainer: infoContainer ?? this.infoContainer,
    focus: focus ?? this.focus,
  );

  @override
  DealColors lerp(DealColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return DealColors(
      deal: mix(deal, other.deal),
      onDeal: mix(onDeal, other.onDeal),
      dealContainer: mix(dealContainer, other.dealContainer),
      onDealContainer: mix(onDealContainer, other.onDealContainer),
      featured: mix(featured, other.featured),
      onFeatured: mix(onFeatured, other.onFeatured),
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      warning: mix(warning, other.warning),
      warningContainer: mix(warningContainer, other.warningContainer),
      info: mix(info, other.info),
      infoContainer: mix(infoContainer, other.infoContainer),
      focus: mix(focus, other.focus),
    );
  }
}
