// QA (sub-phase 1.6): design-system widgets laid out with the REAL bundled
// fonts at 200% text, where the default test font hides problems (it gives
// every glyph a square 1em box). Found in the web build first
// (docs/qa/screens/1.6/gallery_360x800_light_ur-PK_ts2_p18.png).
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug in docs/qa/1.6.md (see known_bugs.dart). No contrast checks
// here: real fonts confuse textContrastGuideline.
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_stepper.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_tab_bar.dart';

import '../helpers/test_app.dart';

Future<void> _loadFonts() async {
  final byFamily = <String, List<String>>{
    BrandFonts.display: ['BricolageGrotesqueCondensed-ExtraBold.ttf'],
    BrandFonts.title: ['BricolageGrotesque-Bold.ttf'],
    BrandFonts.ui: [
      'InstrumentSans-Regular.ttf',
      'InstrumentSans-Medium.ttf',
      'InstrumentSans-SemiBold.ttf',
      'InstrumentSans-Bold.ttf',
    ],
    BrandFonts.urdu: [
      'NotoNastaliqUrdu-Regular.ttf',
      'NotoNastaliqUrdu-Bold.ttf',
    ],
    BrandFonts.urduCompact: [
      'NotoNaskhArabic-Regular.ttf',
      'NotoNaskhArabic-Bold.ttf',
    ],
  };
  for (final MapEntry(key: family, value: files) in byFamily.entries) {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required Locale locale,
  double textScale = 2,
}) async {
  tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 1600),
        textScaler: TextScaler.linear(textScale),
      ),
      child: testApp(
        Scaffold(body: SingleChildScrollView(child: child)),
        locale: locale,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Whether the paragraph showing [text] needs more room than it got.
bool _clipped(WidgetTester tester, Finder text) {
  final p = tester.renderObject<RenderParagraph>(
    find.descendant(of: text, matching: find.byType(RichText), matchRoot: true),
  );
  return p.didExceedMaxLines ||
      p.getMaxIntrinsicWidth(double.infinity) > p.size.width + 0.5 ||
      p.getMinIntrinsicHeight(p.size.width) > p.size.height + 0.5;
}

/// The painted bounds of [text] stay inside its ancestor of type [T].
bool _inside<T>(WidgetTester tester, Finder text) {
  final box = tester.getRect(
    find.ancestor(of: text, matching: find.byType(T)).first,
  );
  final r = tester.getRect(text);
  return r.top >= box.top - 0.5 &&
      r.bottom <= box.bottom + 0.5 &&
      r.left >= box.left - 0.5 &&
      r.right <= box.right + 0.5;
}

void main() {
  setUpAll(_loadFonts);

  for (final locale in AppLocales.supported) {
    final code = locale.languageCode;

    testWidgets('$code: AppStepper step numbers fit their circles at 200%', (
      tester,
    ) async {
      await _pump(
        tester,
        AppStepper(
          currentStep: 1,
          // No controls: this test is about the circles only (BUG-4 is
          // the controls row).
          controlsBuilder: (_, _) => const SizedBox.shrink(),
          steps: const [
            Step(title: Text('A'), content: SizedBox(), isActive: true),
            Step(title: Text('B'), content: SizedBox(), isActive: true),
            Step(title: Text('C'), content: SizedBox()),
          ],
        ),
        locale: locale,
      );
      for (final digit in ['2', '3']) {
        final label = find.text(digit);
        // The circle is the step icon's sized box (24dp by default).
        final circle = tester.getRect(
          find
              .ancestor(of: label, matching: find.byType(AnimatedContainer))
              .first,
        );
        final p = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: label,
            matching: find.byType(RichText),
            matchRoot: true,
          ),
        );
        final needed = p.getMaxIntrinsicHeight(double.infinity);
        expect(
          needed,
          lessThanOrEqualTo(circle.height),
          reason:
              'step $digit: text needs ${needed.toStringAsFixed(1)}dp in a '
              '${circle.height}dp circle',
        );
      }
    });

    testWidgets('$code: AppStepper Continue/Cancel stay on screen at 200%', (
      tester,
    ) async {
      await _pump(
        tester,
        AppStepper(
          onStepContinue: () {},
          onStepCancel: () {},
          steps: const [
            Step(title: Text('A'), content: SizedBox(), isActive: true),
            Step(title: Text('B'), content: SizedBox()),
          ],
        ),
        locale: locale,
      );
      expect(tester.takeException(), isNull);
      final l10n = MaterialLocalizations.of(
        tester.element(find.byType(Stepper)),
      );
      for (final label in [l10n.continueButtonLabel, l10n.cancelButtonLabel]) {
        final r = tester.getRect(find.text(label));
        expect(r.left, greaterThanOrEqualTo(0), reason: label);
        expect(r.right, lessThanOrEqualTo(360), reason: label);
        expect(_clipped(tester, find.text(label)), isFalse, reason: label);
      }
    });

    testWidgets(
      '$code: AppTabBar labels are not truncated at 200% (3 tabs, 360dp)',
      (tester) async {
        final labels = code == 'ur'
            ? ['قریب', 'آن لائن', 'پورا شہر']
            : ['Near me', 'Online', 'All city'];
        await _pump(
          tester,
          DefaultTabController(length: 3, child: AppTabBar(labels: labels)),
          locale: locale,
        );
        for (final l in labels) {
          expect(_clipped(tester, find.text(l)), isFalse, reason: l);
          expect(_inside<Tab>(tester, find.text(l)), isTrue, reason: l);
        }
      },
    );
  }
}
