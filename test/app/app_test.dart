import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/design_system/gallery/theme_preview_page.dart';
import 'package:sale_lagi_hai/design_system/theme/deal_colors.dart';

void main() {
  const config = AppConfig(
    flavor: Flavor.dev,
    appName: 'SLH Dev',
    supabaseUrl: '',
    supabaseAnonKey: '',
  );

  testWidgets('App boots with the config it is given', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: const App(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'SLH Dev');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(find.byType(ThemePreviewPage), findsOneWidget);
  });

  testWidgets('App fails loudly if the config was never provided', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: App()));

    // Riverpod wraps provider errors, so check the message, not the type.
    expect(
      tester.takeException().toString(),
      contains('appConfigProvider must be overridden in bootstrap()'),
    );
  });

  testWidgets('ConfigErrorApp lists every problem', (tester) async {
    await tester.pumpWidget(
      const ConfigErrorApp(
        problems: ['FLAVOR is missing.', 'APP_NAME is missing.'],
      ),
    );

    expect(find.text('App configuration error'), findsOneWidget);
    expect(find.text('• FLAVOR is missing.'), findsOneWidget);
    expect(find.text('• APP_NAME is missing.'), findsOneWidget);
  });

  testWidgets('App installs light, dark and high-contrast brand themes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: const App(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
    for (final theme in [
      app.theme,
      app.darkTheme,
      app.highContrastTheme,
      app.highContrastDarkTheme,
    ]) {
      expect(theme?.extension<DealColors>(), isNotNull);
    }
    expect(app.theme!.brightness, Brightness.light);
    expect(app.darkTheme!.brightness, Brightness.dark);
    expect(app.highContrastDarkTheme!.brightness, Brightness.dark);
  });
}
