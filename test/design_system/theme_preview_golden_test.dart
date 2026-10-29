import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/gallery/theme_preview_page.dart';

import '../helpers/golden_host.dart';

void main() {
  // goldenTest registers its test synchronously; the Future only tracks
  // setup, so it is not awaited (alchemist's documented usage).
  unawaited(
    goldenTest(
      'Theme preview in light, dark and high contrast',
      fileName: 'theme_preview',
      constraints: const BoxConstraints.tightFor(width: 1300),
      builder: () => GoldenTestGroup(
        columns: 3,
        children: [
          for (final (name, brightness, highContrast) in const [
            ('light', Brightness.light, false),
            ('dark', Brightness.dark, false),
            ('dark high contrast', Brightness.dark, true),
          ])
            GoldenTestScenario(
              name: name,
              child: SizedBox(
                width: 412,
                height: 1900,
                child: goldenHost(
                  const ThemePreviewPage(),
                  brightness: brightness,
                  highContrast: highContrast,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  unawaited(
    goldenTest(
      'Theme preview in Urdu (right to left)',
      fileName: 'theme_preview_urdu',
      constraints: const BoxConstraints.tightFor(width: 870),
      builder: () => GoldenTestGroup(
        columns: 2,
        children: [
          for (final brightness in Brightness.values)
            GoldenTestScenario(
              name: 'ur ${brightness.name}',
              child: SizedBox(
                width: 412,
                height: 1900,
                child: goldenHost(
                  const ThemePreviewPage(),
                  locale: AppLocales.urdu,
                  brightness: brightness,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
