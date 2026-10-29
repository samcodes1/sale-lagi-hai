import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/gallery/theme_preview_page.dart';

import '../helpers/golden_host.dart';
import '../helpers/test_app.dart';

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

  group('ThemePreviewPage accessibility', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: tap targets, labels and contrast', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        tester.view.physicalSize = const Size(1080, 4800);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          testApp(const ThemePreviewPage(), brightness: brightness),
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('no overflow at 200% text on a 360dp-wide phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: testApp(const ThemePreviewPage()),
        ),
      );
      // Scroll through the whole page so every section lays out.
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });
  });
}
