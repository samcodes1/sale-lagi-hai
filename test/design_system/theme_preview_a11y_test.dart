// Accessibility checks live apart from the golden tests: alchemist loads the
// real fonts for the whole file, and the contrast guideline then samples
// anti-aliased pixels of thin Urdu strokes instead of the text colour.
// Real-font legibility is reviewed in the goldens.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/gallery/theme_preview_page.dart';

import '../helpers/test_app.dart';

void main() {
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
