// QA (sub-phases 1.4/1.5): accessibility guidelines on the real app's
// screens: the five tabs (bottom bar and rail), a deal page and Not found,
// in English and Urdu, light and dark, plus 200% text. No widget test ran
// meetsGuideline on these screens before.
//
// No alchemist goldens in this file: it uses textContrastGuideline.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/app/router/app_router.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';

import '../helpers/fakes.dart';

const _locations = [
  '/',
  '/explore',
  '/alerts',
  '/saved',
  '/profile',
  '/deal/3f2a9c1e-7b4d-4e8a-9c2f-1a2b3c4d5e6f',
  '/no-such-page',
];

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  required Locale locale,
  required Brightness brightness,
  Size size = const Size(412, 915),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final container = ProviderContainer(
    overrides: [
      onboardedShopper,
      guestAuth(),
      onlineNetwork(),
      appConfigProvider.overrideWithValue(
        const AppConfig(
          flavor: Flavor.dev,
          appName: 'SLH',
          supabaseUrl: '',
          supabasePublishableKey: '',
        ),
      ),
      deviceLocaleProvider.overrideWithValue(locale),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      loggerProvider.overrideWithValue(AppLogger(sinks: [])),
    ],
  );
  addTearDown(container.dispose);
  final router = container.read(routerProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const App()),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final locale in AppLocales.supported) {
    for (final brightness in Brightness.values) {
      for (final (layout, size) in const [
        ('bar', Size(412, 915)),
        ('rail', Size(900, 700)),
      ]) {
        final name = '${locale.languageCode} ${brightness.name} $layout';
        testWidgets('$name: every screen meets the guidelines', (tester) async {
          final handle = tester.ensureSemantics();
          final router = await _pumpApp(
            tester,
            locale: locale,
            brightness: brightness,
            size: size,
          );
          for (final location in _locations) {
            router.go(location);
            await tester.pumpAndSettle();
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
              reason: location,
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
              reason: location,
            );
            await expectLater(
              tester,
              meetsGuideline(textContrastGuideline),
              reason: location,
            );
          }
          handle.dispose();
        });
      }
    }

    testWidgets('${locale.languageCode}: 200% text at 360dp, no overflow', (
      tester,
    ) async {
      final router = await _pumpApp(
        tester,
        locale: locale,
        brightness: Brightness.light,
        size: const Size(360, 800),
        textScale: 2,
      );
      for (final location in _locations) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: location);
      }
    });
  }
}
