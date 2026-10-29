import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';

/// Hosts a widget for an alchemist golden scenario.
///
/// alchemist builds its own app from the SDK's old Material library, so
/// material_ui widgets need their own localizations and theme around them
/// (see the qa-testing skill). The locale also sets the text direction:
/// `ur` renders right-to-left with the Urdu type scale.
Widget goldenHost(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  bool highContrast = false,
}) => Localizations(
  locale: locale,
  delegates: GlobalMaterialLocalizations.delegates,
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
);
