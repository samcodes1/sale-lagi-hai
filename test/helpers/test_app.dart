import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';

/// A minimal app around [home] for widget tests: the brand theme, both
/// languages' localizations and a [ProviderScope]. [locale] also selects
/// the Urdu theme and right-to-left layout.
Widget testApp(
  Widget home, {
  Locale locale = AppLocales.english,
  Brightness brightness = Brightness.light,
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: [savedLocaleProvider.overrideWithValue(locale), ...overrides],
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppLocales.supported,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    theme: AppTheme.build(
      brightness: brightness,
      script: AppLocales.isRtl(locale) ? AppScript.urdu : AppScript.latin,
    ),
    home: home,
  ),
);
