import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/gallery/widget_gallery_page.dart';

import '../helpers/golden_host.dart';
import '../helpers/test_app.dart';

final _now = DateTime(2026, 10, 29, 12);

Widget _gallery({
  Locale locale = AppLocales.english,
  Brightness brightness = Brightness.light,
}) => ProviderScope(
  overrides: [clockProvider.overrideWithValue(() => _now)],
  child: goldenHost(
    const WidgetGalleryPage(),
    locale: locale,
    brightness: brightness,
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
          for (final (name, locale, brightness) in const [
            ('en light', AppLocales.english, Brightness.light),
            ('en dark', AppLocales.english, Brightness.dark),
            ('ur light', AppLocales.urdu, Brightness.light),
          ])
            GoldenTestScenario(
              name: name,
              child: SizedBox(
                width: 412,
                height: 2900,
                child: _gallery(locale: locale, brightness: brightness),
              ),
            ),
        ],
      ),
    ),
  );

  group('WidgetGalleryPage accessibility', () {
    for (final (name, locale, brightness) in const [
      ('en light', AppLocales.english, Brightness.light),
      ('en dark', AppLocales.english, Brightness.dark),
      ('ur light', AppLocales.urdu, Brightness.light),
    ]) {
      testWidgets('$name: tap targets, labels and contrast', (tester) async {
        final handle = tester.ensureSemantics();
        tester.view.physicalSize = const Size(1080, 8000);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          testApp(
            const WidgetGalleryPage(),
            locale: locale,
            brightness: brightness,
            overrides: [clockProvider.overrideWithValue(() => _now)],
          ),
        );
        await tester.pump();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    for (final locale in AppLocales.supported) {
      testWidgets('${locale.languageCode}: no overflow at 200% text, 360dp', (
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
            child: testApp(
              const WidgetGalleryPage(),
              locale: locale,
              overrides: [clockProvider.overrideWithValue(() => _now)],
            ),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -500));
          await tester.pump();
        }

        expect(tester.takeException(), isNull);
      });
    }
  });
}
