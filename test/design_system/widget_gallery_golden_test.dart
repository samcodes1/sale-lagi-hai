import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/gallery/widget_gallery_page.dart';

import '../helpers/golden_host.dart';

final _now = DateTime(2026, 10, 29, 12);

Widget _gallery({
  Locale locale = AppLocales.english,
  Brightness brightness = Brightness.light,
  bool highContrast = false,
}) => ProviderScope(
  overrides: [clockProvider.overrideWithValue(() => _now)],
  child: goldenHost(
    const WidgetGalleryPage(),
    locale: locale,
    brightness: brightness,
    highContrast: highContrast,
  ),
);

void main() {
  // goldenTest registers its test synchronously; the Future only tracks
  // setup (alchemist's documented usage).
  unawaited(
    goldenTest(
      'Widget gallery',
      fileName: 'widget_gallery',
      constraints: const BoxConstraints.tightFor(width: 1300),
      builder: () => GoldenTestGroup(
        columns: 3,
        children: [
          // The plan's matrix: both languages, light and dark, and high
          // contrast in each brightness.
          for (final (name, locale, brightness, highContrast) in const [
            ('en light', AppLocales.english, Brightness.light, false),
            ('en dark', AppLocales.english, Brightness.dark, false),
            ('ur light', AppLocales.urdu, Brightness.light, false),
            ('ur dark', AppLocales.urdu, Brightness.dark, false),
            ('en light HC', AppLocales.english, Brightness.light, true),
            ('ur dark HC', AppLocales.urdu, Brightness.dark, true),
          ])
            GoldenTestScenario(
              name: name,
              child: SizedBox(
                width: 412,
                height: 2900,
                child: _gallery(
                  locale: locale,
                  brightness: brightness,
                  highContrast: highContrast,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
