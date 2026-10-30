// QA, sub-phase 4.8: the signed-in Alerts inbox and the Saved tab with
// the REAL fonts, in Urdu and English, light and dark, at 100% and 200%:
// nothing clipped or overflowing (docs/qa/4.8.md). The web build can't
// sign in from a script, so these stand in for its signed-in shots.
//
// With `--dart-define=QA_SHOTS=true` each run also saves screenshots to
// docs/qa/screens/4.8/real_fonts/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/fakes.dart';

const _shots = bool.fromEnvironment('QA_SHOTS');

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
  // Material icons, so screenshots show icons rather than boxes.
  final icons = File(
    '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
    '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    await (FontLoader(
          'MaterialIcons',
        )..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
        .load();
  }
}

/// Paragraphs on screen that are cut off vertically; ellipsised ones are
/// added to [ellipsised].
List<String> _clipped(WidgetTester tester, Set<String> ellipsised) {
  final out = <String>[];
  for (final e in find.byType(RichText).evaluate()) {
    if (e.renderObject case final RenderParagraph p
        when p.attached && p.hasSize && p.size.width > 0) {
      final text = p.text.toPlainText();
      if (p.didExceedMaxLines) ellipsised.add(text);
      final needed = p.getMinIntrinsicHeight(p.size.width);
      if (needed > p.size.height + 0.5) {
        out.add('"$text" needs ${needed.toStringAsFixed(1)} in ${p.size}');
      }
    }
  }
  return out;
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory('docs/qa/screens/4.8/real_fonts').createSync(recursive: true);
    File('docs/qa/screens/4.8/real_fonts/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

final Finder _vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

void main() {
  setUpAll(_loadFonts);

  for (final (locale, brightness, scale) in [
    (AppLocales.urdu, Brightness.light, 1.0),
    (AppLocales.urdu, Brightness.dark, 2.0),
    (AppLocales.english, Brightness.dark, 1.0),
    (AppLocales.english, Brightness.light, 2.0),
  ]) {
    for (final page in ['/alerts', '/saved', '/following']) {
      final tag =
          '${page.substring(1)}_${locale.languageCode}_${brightness.name}'
          '_${(scale * 100).round()}';
      testWidgets('$tag: nothing clipped', (tester) async {
        tester.platformDispatcher
          ..textScaleFactorTestValue = scale
          ..platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final auth = DemoAuthRepository();
        await auth.sendPhoneCode('+923001234567');
        await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
        final store = InMemoryKeyValueStore();
        final ids = [
          for (final n in [7, 1, 5, 4])
            demoDeals.firstWhere((d) => d.n == n).id,
        ];
        await store.setString(
          savedDealsKey,
          '[${ids.map((id) => '"$id"').join(',')}]',
        );
        final h = Harness(
          saved: ShopperPreferences(
            onboarded: true,
            cityId: karachiId,
            brandIds: [demoBrands.first['id']! as String],
          ),
          auth: auth,
          store: store,
        );
        await h.pump(tester, device: locale, size: const Size(360, 800));
        h.router.go(page);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final ellipsised = <String>{};
        final problems = <String>[];
        for (var i = 0; i < 12; i++) {
          problems.addAll(_clipped(tester, ellipsised));
          if (i < 3) await _shot(tester, '${tag}_$i');
          final pos = tester.state<ScrollableState>(_vertical.first).position;
          if (pos.pixels >= pos.maxScrollExtent) break;
          await tester.drag(_vertical.first, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(problems.toSet(), isEmpty);
      });
    }
  }
}
