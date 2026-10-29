// QA, sub-phase 4.1: every onboarding step in Urdu with the REAL bundled
// fonts (Nastaliq and Naskh), at 100% and 200% text on a 360 × 800 phone:
// no clipped or ellipsised text, no overflow, over the whole scroll extent.
// The default test font hides Nastaliq's tall ascenders and descenders.
//
// No contrast checks here: real fonts confuse textContrastGuideline.
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

import '../features/onboarding/onboarding_harness.dart';

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
      loader.addFont(
        Future.value(
          ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync()),
        ),
      );
    }
    await loader.load();
  }
}

/// Paragraphs on screen that need more room than they got.
List<String> _clippedText(WidgetTester tester) {
  final out = <String>[];
  for (final e in find.byType(RichText).evaluate()) {
    if (e.renderObject case final RenderParagraph p
        when p.attached && p.hasSize && p.size.width > 0) {
      final needed = p.getMinIntrinsicHeight(p.size.width);
      if (p.didExceedMaxLines || needed > p.size.height + 0.5) {
        final text = p.text.toPlainText();
        out.add('"$text" needs ${needed.toStringAsFixed(1)} in ${p.size}');
      }
    }
  }
  return out;
}

void main() {
  setUpAll(_loadFonts);

  for (final scale in [1.0, 2.0]) {
    for (final step in const [
      '/welcome',
      '/welcome/city',
      '/welcome/interests',
      '/welcome/brands',
      '/welcome/alerts',
    ]) {
      testWidgets('ur ${(scale * 100).round()}% $step: nothing clipped', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final h = Harness();
        await h.pump(
          tester,
          device: AppLocales.urdu,
          size: const Size(360, 800),
        );
        h.router.go(step);
        await tester.pumpAndSettle();
        final problems = <String>{};
        final list = find.byType(Scrollable).first;
        for (var i = 0; i < 30; i++) {
          expect(tester.takeException(), isNull);
          problems.addAll(_clippedText(tester));
          final pos = tester.state<ScrollableState>(list).position;
          if (pos.pixels >= pos.maxScrollExtent - 0.5) break;
          await tester.drag(list, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
        expect(problems, isEmpty);
      });
    }
  }
}
