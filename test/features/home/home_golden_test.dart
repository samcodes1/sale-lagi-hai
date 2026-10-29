import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden_host.dart';

final _now = DateTime.utc(2026, 10, 29, 9);

Widget _home(Locale locale, Brightness brightness) => ProviderScope(
  overrides: [
    appConfigProvider.overrideWithValue(
      const AppConfig(
        flavor: Flavor.dev,
        appName: 'SLH',
        supabaseUrl: '',
        supabasePublishableKey: '',
      ),
    ),
    backendGatewayProvider.overrideWithValue(DemoGateway(clock: () => _now)),
    clockProvider.overrideWithValue(() => _now),
    loggerProvider.overrideWithValue(AppLogger(sinks: [])),
    keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    savedPreferencesProvider.overrideWithValue(
      const ShopperPreferences(onboarded: true, cityId: karachiId),
    ),
    savedLocaleProvider.overrideWithValue(locale),
    onlineNetwork(),
  ],
  child: goldenHost(
    const SizedBox(width: 360, height: 1400, child: HomeScreen()),
    locale: locale,
    brightness: brightness,
  ),
);

void main() {
  // goldenTest registers its test synchronously; the Future only tracks
  // setup (alchemist's documented usage).
  unawaited(
    goldenTest(
      'Home',
      fileName: 'home',
      pumpBeforeTest: precacheImages,
      builder: () => GoldenTestGroup(
        columns: 3,
        children: [
          for (final (name, locale, brightness) in const [
            ('en', AppLocales.english, Brightness.light),
            ('ur', AppLocales.urdu, Brightness.light),
            ('ur dark', AppLocales.urdu, Brightness.dark),
          ])
            GoldenTestScenario(name: name, child: _home(locale, brightness)),
        ],
      ),
    ),
  );
}
