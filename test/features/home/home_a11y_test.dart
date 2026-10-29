import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../onboarding/onboarding_harness.dart';

Future<Harness> _open(
  WidgetTester tester, {
  Locale locale = AppLocales.english,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(412, 915),
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final h = Harness(
    saved: ShopperPreferences(
      onboarded: true,
      cityId: karachiId,
      interestIds: [categoryId('food-and-restaurants')],
    ),
  );
  await h.pump(tester, device: locale, size: size);
  return h;
}

void main() {
  for (final (name, locale, brightness) in const [
    ('en light', AppLocales.english, Brightness.light),
    ('en dark', AppLocales.english, Brightness.dark),
    ('ur light', AppLocales.urdu, Brightness.light),
    ('ur dark', AppLocales.urdu, Brightness.dark),
  ]) {
    testWidgets('$name: home meets the tap-target, label and contrast '
        'guidelines, top and bottom', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, locale: locale, brightness: brightness);
      for (var screen = 0; screen < 3; screen++) {
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
        await tester.pumpAndSettle();
      }
      handle.dispose();
    });
  }

  for (final locale in AppLocales.supported) {
    testWidgets('200% text on 360 × 800 (${locale.languageCode}): every row '
        'lays out without overflow', (tester) async {
      await _open(
        tester,
        locale: locale,
        textScale: 2,
        size: const Size(360, 800),
      );
      for (var screen = 0; screen < 8; screen++) {
        expect(tester.takeException(), isNull, reason: 'screen $screen');
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('row titles are headings; the city button says what it does', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester);
    expect(
      tester.getSemantics(find.text('Trending today')),
      isSemantics(label: 'Trending today', isHeader: true),
    );
    expect(find.bySemanticsLabel('Deals in Karachi'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Urdu: the rows run right to left', (tester) async {
    await _open(tester, locale: AppLocales.urdu);
    expect(
      Directionality.of(tester.element(find.byType(HomeScreen))),
      TextDirection.rtl,
    );
  });
}
