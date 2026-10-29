import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/alerts_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/brands_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/city_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/interests_step.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/language_step.dart';

import '../../helpers/fakes.dart';
import '../../helpers/golden_host.dart';

/// Some choices made, so selected states show.
final _chosen = ShopperPreferences(
  cityId: karachiId,
  interestIds: [categoryId('food-and-restaurants')],
  brandIds: [brandBySlug('demo-karahi-house')['id']! as String],
);

Widget _step(Widget step, Locale locale, Brightness brightness) =>
    ProviderScope(
      overrides: [
        backendGatewayProvider.overrideWithValue(DemoGateway()),
        loggerProvider.overrideWithValue(AppLogger(sinks: [])),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        savedPreferencesProvider.overrideWithValue(_chosen),
        // The locale controller lives in this scope, so the language must
        // be set here too (goldenHost's inner scope doesn't reach it).
        savedLocaleProvider.overrideWithValue(locale),
      ],
      child: goldenHost(
        SizedBox(width: 360, height: 760, child: step),
        locale: locale,
        brightness: brightness,
      ),
    );

void main() {
  const steps = <(String, Widget)>[
    ('1 language', LanguageStep()),
    ('2 city', CityStep()),
    ('3 interests', InterestsStep()),
    ('4 brands', BrandsStep()),
    ('5 alerts', AlertsStep()),
  ];
  // goldenTest registers its test synchronously; the Future only tracks
  // setup (alchemist's documented usage).
  unawaited(
    goldenTest(
      'Onboarding steps',
      fileName: 'onboarding',
      pumpBeforeTest: precacheImages,
      builder: () => GoldenTestGroup(
        columns: steps.length,
        children: [
          // English, Urdu (right to left) and Urdu dark.
          for (final (variant, locale, brightness) in const [
            ('en', AppLocales.english, Brightness.light),
            ('ur', AppLocales.urdu, Brightness.light),
            ('ur dark', AppLocales.urdu, Brightness.dark),
          ])
            for (final (name, step) in steps)
              GoldenTestScenario(
                name: '$name $variant',
                child: _step(step, locale, brightness),
              ),
        ],
      ),
    ),
  );
}
