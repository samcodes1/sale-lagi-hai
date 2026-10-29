import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';

/// Hosts a widget for an alchemist golden scenario.
///
/// alchemist builds its own app from the SDK's old Material library, so
/// material_ui widgets need their own localizations and theme around them
/// (see the qa-testing skill). The locale also sets the text direction:
/// `ur` renders right-to-left with the Urdu type scale. A [ProviderScope]
/// is included, with the app locale set to [locale].
Widget goldenHost(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  bool highContrast = false,
}) => ProviderScope(
  overrides: [savedLocaleProvider.overrideWithValue(locale)],
  child: Localizations(
    locale: locale,
    delegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    child: Theme(
      data: AppTheme.build(
        brightness: brightness,
        script: locale.languageCode == 'ur' ? AppScript.urdu : AppScript.latin,
        highContrast: highContrast,
      ),
      child: Builder(
        builder: (context) => ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    ),
  ),
);
