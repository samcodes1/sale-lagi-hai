import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/design_system/theme/deal_colors.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/profile/presentation/profile_screen.dart';

import '../helpers/fakes.dart';

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
    expect(find.byType(HomeScreen), findsOneWidget);
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

  group('language and direction', () {
    Future<ProviderContainer> pumpApp(
      WidgetTester tester,
      Locale device,
    ) async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          deviceLocaleProvider.overrideWithValue(device),
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('an English phone gets English, left to right', (tester) async {
      await pumpApp(tester, const Locale('en', 'PK'));
      final context = tester.element(find.byType(HomeScreen));

      expect(Localizations.localeOf(context), AppLocales.english);
      expect(Directionality.of(context), TextDirection.ltr);
      expect(
        Theme.of(context).textTheme.headlineMedium!.fontFamily,
        BrandFonts.display,
      );
    });

    testWidgets('an Urdu phone gets Urdu, right to left, Urdu type', (
      tester,
    ) async {
      await pumpApp(tester, const Locale('ur', 'PK'));
      final context = tester.element(find.byType(HomeScreen));

      expect(Localizations.localeOf(context), AppLocales.urdu);
      expect(Directionality.of(context), TextDirection.rtl);
      expect(
        Theme.of(context).textTheme.headlineMedium!.fontFamily,
        BrandFonts.urdu,
      );
      expect(find.text('ہوم'), findsOneWidget);
    });

    testWidgets('choosing Urdu in Profile re-renders the whole app', (
      tester,
    ) async {
      final container = await pumpApp(tester, const Locale('en'));

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();

      expect(container.read(localeControllerProvider), AppLocales.urdu);
      expect(find.text('پروفائل'), findsWidgets);
      expect(
        Directionality.of(tester.element(find.byType(ProfileScreen))),
        TextDirection.rtl,
      );

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(container.read(localeControllerProvider), AppLocales.english);
    });
  });
}
