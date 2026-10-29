import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/theme/deal_colors.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// Which script the UI is set in. Urdu uses Nastaliq for headings and
/// display text, and the more compact Naskh for dense UI text.
enum AppScript { latin, urdu }

/// Builds the app's Material 3 themes from the brand tokens.
///
/// Rules (see the flutter-ui-ux skill):
/// - Colours come only from the tokens; there is no seed colour and no
///   dynamic (wallpaper) colour.
/// - Haldi yellow is a **fill** colour. It fails contrast as text or as a
///   thin mark on white (1.6:1), so text buttons, links, focus rings,
///   progress indicators and selection controls use Neel instead.
/// - Components are styled here, never per widget. Material 3 defaults pull
///   `primary` (yellow) into text and thin marks in many widgets, so every
///   such widget gets a component theme here, and each is covered by a
///   contrast test.
/// - Exception: `RefreshIndicator` ignores the theme; use
///   `AppRefreshIndicator`.
abstract final class AppTheme {
  static ThemeData light({AppScript script = AppScript.latin}) =>
      build(brightness: Brightness.light, script: script);

  static ThemeData dark({AppScript script = AppScript.latin}) =>
      build(brightness: Brightness.dark, script: script);

  static ThemeData build({
    required Brightness brightness,
    AppScript script = AppScript.latin,
    bool highContrast = false,
  }) {
    final isLight = brightness == Brightness.light;
    final scheme = colorScheme(brightness, highContrast: highContrast);
    final deal = switch ((isLight, highContrast)) {
      (true, false) => DealColors.light,
      (false, false) => DealColors.dark,
      (true, true) => DealColors.highContrastLight,
      (false, true) => DealColors.highContrastDark,
    };
    final textTheme = _textTheme(script, scheme);

    const buttonShape = RoundedRectangleBorder(borderRadius: BrandRadii.button);
    const buttonMinSize = Size(64, BrandSpacing.minTouchTarget);
    const buttonPadding = EdgeInsetsDirectional.symmetric(
      horizontal: BrandSpacing.s6,
      vertical: BrandSpacing.s4,
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: script == AppScript.urdu ? BrandFonts.urdu : BrandFonts.ui,
      scaffoldBackgroundColor: isLight
          ? BrandLight.background
          : BrandDark.background,
      extensions: [deal],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      focusColor: deal.focus.withValues(alpha: 0.16),
      dividerColor: scheme.outlineVariant,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.38),
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerLow,
          foregroundColor: scheme.onSurface,
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.secondaryContainer
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurface,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          minimumSize: const WidgetStatePropertyAll(buttonMinSize),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        ),
      ),
      toggleButtonsTheme: ToggleButtonsThemeData(
        color: scheme.onSurface,
        selectedColor: scheme.onSecondaryContainer,
        fillColor: scheme.secondaryContainer,
        borderColor: scheme.outline,
        selectedBorderColor: scheme.secondary,
        borderRadius: BrandRadii.button,
        textStyle: textTheme.labelLarge,
        constraints: const BoxConstraints(
          minWidth: BrandSpacing.minTouchTarget,
          minHeight: BrandSpacing.minTouchTarget,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.secondary,
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      // Only the selected (toggle) state is recoloured: Material defaults it
      // to yellow. Other states resolve to null, so each variant keeps its
      // own default (e.g. dark ink on the yellow filled variant).
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.square(BrandSpacing.minTouchTarget),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? scheme.secondary : null,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: const RoundedRectangleBorder(borderRadius: BrandRadii.card),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BrandRadii.card,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        selectedColor: scheme.secondaryContainer,
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
        checkmarkColor: scheme.onSecondaryContainer,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 18),
        side: BorderSide(color: scheme.outline),
        shape: const RoundedRectangleBorder(borderRadius: BrandRadii.button),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BrandSpacing.s3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: BrandSpacing.s5,
          vertical: BrandSpacing.s4,
        ),
        border: _inputBorder(scheme.outline),
        enabledBorder: _inputBorder(scheme.outline),
        focusedBorder: _inputBorder(deal.focus, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
        labelStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 80,
        indicatorColor: isLight ? BrandLight.indicator : BrandDark.indicator,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? (isLight ? BrandColors.haldi500 : BrandColors.surma900)
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: isLight ? BrandLight.indicator : BrandDark.indicator,
        selectedIconTheme: IconThemeData(
          color: isLight ? BrandColors.haldi500 : BrandColors.surma900,
        ),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: isLight ? BrandLight.indicator : BrandDark.indicator,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
        dividerColor: scheme.outlineVariant,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surfaceContainerLow,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(borderRadius: BrandRadii.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(BrandRadii.xl)),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: const RoundedRectangleBorder(borderRadius: BrandRadii.button),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: deal.deal,
        textColor: deal.onDeal,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.secondary,
        linearTrackColor: scheme.secondaryContainer,
        circularTrackColor: Colors.transparent,
        refreshBackgroundColor: scheme.surfaceContainerLowest,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onSecondary),
        side: BorderSide(color: scheme.outline, width: 2),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.outline,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onSecondary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.outline,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.secondary,
        thumbColor: scheme.secondary,
        inactiveTrackColor: scheme.secondaryContainer,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: deal.focus,
        selectionColor: deal.focus.withValues(alpha: 0.3),
        selectionHandleColor: deal.focus,
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: 56,
        iconColor: scheme.onSurfaceVariant,
        selectedColor: scheme.secondary,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        textColor: scheme.onSurface,
        collapsedTextColor: scheme.onSurface,
        iconColor: scheme.onSurface,
        collapsedIconColor: scheme.onSurfaceVariant,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.onSurface,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedLabelStyle: textTheme.labelMedium,
        unselectedLabelStyle: textTheme.labelMedium,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.surfaceContainerLow,
        headerForegroundColor: scheme.onSurface,
        dividerColor: scheme.outlineVariant,
        dayForegroundColor: _selected(scheme.onPrimary, scheme.onSurface),
        dayBackgroundColor: _selected(scheme.primary, Colors.transparent),
        todayForegroundColor: _selected(scheme.onPrimary, scheme.secondary),
        todayBackgroundColor: _selected(scheme.primary, Colors.transparent),
        todayBorder: BorderSide(color: scheme.secondary),
        yearForegroundColor: _selected(scheme.onPrimary, scheme.onSurface),
        yearBackgroundColor: _selected(scheme.primary, Colors.transparent),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        dialHandColor: scheme.secondary,
        dialBackgroundColor: scheme.surfaceContainerHighest,
        dialTextColor: _selected(scheme.onSecondary, scheme.onSurface),
        hourMinuteColor: _selected(
          scheme.secondaryContainer,
          scheme.surfaceContainerHighest,
        ),
        hourMinuteTextColor: _selected(
          scheme.onSecondaryContainer,
          scheme.onSurface,
        ),
        dayPeriodColor: _selected(
          scheme.secondaryContainer,
          Colors.transparent,
        ),
        dayPeriodTextColor: _selected(
          scheme.onSecondaryContainer,
          scheme.onSurfaceVariant,
        ),
        entryModeIconColor: scheme.onSurfaceVariant,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
          border: _inputBorder(Colors.transparent),
          enabledBorder: _inputBorder(Colors.transparent),
          focusedBorder: _inputBorder(deal.focus, width: 2),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BrandRadii.badge,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }

  /// The colour scheme for [brightness], straight from the tokens, with the
  /// surface-container roles filled from the Surma neutrals.
  ///
  /// [highContrast] (Android's high-contrast text setting) darkens secondary
  /// text and outlines to the primary text colour.
  static ColorScheme colorScheme(
    Brightness brightness, {
    bool highContrast = false,
  }) {
    final isLight = brightness == Brightness.light;
    final base = isLight ? BrandColorSchemes.light : BrandColorSchemes.dark;
    final scheme = isLight
        ? base.copyWith(
            surfaceContainerLowest: BrandColors.surma0,
            surfaceContainerLow: BrandColors.surma50,
            surfaceContainer: BrandColors.surma100,
            surfaceContainerHigh: BrandColors.surma100,
            surfaceContainerHighest: BrandColors.surma200,
            surfaceDim: BrandColors.surma100,
            surfaceBright: BrandColors.surma0,
          )
        // Dark: even the lowest container is lighter than the Surma 950
        // background, so cards, chips and inputs stay visible on it.
        : base.copyWith(
            surfaceContainerLowest: BrandColors.surma900,
            surfaceContainerLow: BrandColors.surma800,
            surfaceContainer: BrandColors.surma800,
            surfaceContainerHigh: BrandColors.surma700,
            surfaceContainerHighest: BrandColors.surma700,
            surfaceDim: BrandColors.surma950,
            surfaceBright: BrandColors.surma800,
          );
    if (!highContrast) return scheme;
    // Every text role reaches 7:1 (WCAG 1.4.6), outlines 4.5:1.
    return isLight
        ? scheme.copyWith(
            onSurfaceVariant: scheme.onSurface,
            outline: BrandColors.surma800,
            outlineVariant: BrandColors.surma500,
            secondary: BrandColors.neel700,
            onSecondary: BrandColors.surma0,
            error: BrandColors.error800,
            onError: BrandColors.surma0,
          )
        : scheme.copyWith(
            onSurfaceVariant: scheme.onSurface,
            outline: BrandColors.surma200,
            outlineVariant: BrandColors.surma400,
            secondary: BrandColors.neel200,
            onSecondary: BrandColors.neel900,
            inversePrimary: BrandColors.haldi900,
          );
  }

  static TextTheme _textTheme(AppScript script, ColorScheme scheme) {
    final base = script == AppScript.urdu
        ? urduTextTheme
        : BrandTypography.textTheme;
    return base.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
  }

  /// The Urdu type scale. Nastaliq (tall, calligraphic) for display,
  /// headlines and large titles; Naskh for everything denser (titles,
  /// body, labels, chips, inputs, tabs), where Nastaliq's ascenders and
  /// descenders overflow component bounds even at 1.9–2.1 line height.
  static final TextTheme urduTextTheme = BrandTypography.urduTextTheme.copyWith(
    // Naskh reads smaller than Latin at the same size: +1sp over Latin.
    titleMedium: _naskh(17, FontWeight.w700),
    titleSmall: _naskh(16, FontWeight.w700),
    bodyLarge: _naskh(17, FontWeight.w400, height: 1.7),
    bodyMedium: _naskh(16, FontWeight.w400, height: 1.7),
    bodySmall: _naskh(14, FontWeight.w400, height: 1.7),
    labelLarge: _naskh(16, FontWeight.w700),
    labelMedium: _naskh(14, FontWeight.w700),
    labelSmall: _naskh(13, FontWeight.w700),
  );

  static TextStyle _naskh(
    double size,
    FontWeight weight, {
    double height = 1.6,
  }) => TextStyle(
    fontFamily: BrandFonts.urduCompact,
    fontFamilyFallback: const [BrandFonts.urdu, BrandFonts.ui],
    fontSize: size,
    height: height,
    fontWeight: weight,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// A colour that depends on the selected state. As a [WidgetStateColor]
  /// it fits both `Color` and `WidgetStateProperty<Color>` parameters.
  static WidgetStateColor _selected(Color selected, Color idle) =>
      WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected) ? selected : idle,
      );

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BrandRadii.button,
        borderSide: BorderSide(color: color, width: width),
      );
}
