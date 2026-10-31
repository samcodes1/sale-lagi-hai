// QA, sub-phase 4.3: Home in Urdu with the REAL bundled fonts (Nastaliq
// and Naskh) and long merchant titles, at 100% and 200% text on a
// 360 × 800 phone, down the whole list: nothing clipped vertically, no
// overflow, carousels start on the right. Card titles stop at 3 lines with
// an ellipsis by design; those are counted, not failed.
//
// With `--dart-define=QA_SHOTS=true` each run also saves screenshots to
// docs/qa/screens/4.3/ (docs/qa/4.3.md).
//
// No contrast checks here: real fonts confuse textContrastGuideline.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/sponsors/application/sponsor_providers.dart';
import 'package:sale_lagi_hai/features/sponsors/domain/sponsor_banner.dart';
import 'package:sale_lagi_hai/features/sponsors/presentation/sponsor_carousel.dart';

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/test_app.dart';
import 'home_fakes.dart';

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
    Directory('docs/qa/screens/4.3').createSync(recursive: true);
    File('docs/qa/screens/4.3/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

final Finder _vertical = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

void main() {
  setUpAll(_loadFonts);

  for (final (scale, brightness) in [
    (1.0, Brightness.light),
    (2.0, Brightness.light),
    (1.0, Brightness.dark),
  ]) {
    final tag = 'ur_${(scale * 100).round()}_${brightness.name}_long_titles';
    testWidgets('$tag: nothing clipped down the whole list; carousels '
        'start on the right', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final deals = GatedDeals()..longUrdu = true;
      final h = Harness(
        saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
        overrides: [dealRepositoryProvider.overrideWithValue(deals)],
      );
      await h.pump(tester, device: AppLocales.urdu, size: const Size(360, 800));
      expect(tester.takeException(), isNull);

      // The first carousel card sits at the right edge (RTL).
      final first = tester.getRect(find.byType(DealCard).first);
      expect(first.right, greaterThan(300), reason: '$first');

      final ellipsised = <String>{};
      final problems = <String>[];
      var i = 0;
      await _shot(tester, '${tag}_0');
      for (; i < 40; i++) {
        problems.addAll(_clipped(tester, ellipsised));
        final pos = tester.state<ScrollableState>(_vertical.first).position;
        if (pos.pixels >= pos.maxScrollExtent) break;
        await tester.drag(_vertical.first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (i < 3) await _shot(tester, '${tag}_${i + 1}');
      }
      expect(problems.toSet(), isEmpty);
      // Long titles do stop at three lines (the card design), and only
      // titles do.
      expect(
        ellipsised.where((t) => t != qaLongUrduTitle),
        isEmpty,
        reason: '$ellipsised',
      );
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('ur ${(scale * 100).round()}%: the longest sponsor copy is '
        'not clipped', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      // The longest the database allows: 80 and 120 characters.
      final banner = SponsorBanner(
        id: '1',
        sponsorName: 'Acme',
        titleEn: 'Title',
        titleUr: 'بڑی سیل ' * 10,
        subtitleUr: 'بڑی سیل ' * 15,
      );
      await tester.pumpWidget(
        testApp(
          const Scaffold(body: SponsorCarousel()),
          locale: AppLocales.urdu,
          overrides: [
            appConfigProvider.overrideWithValue(
              const AppConfig(
                flavor: Flavor.dev,
                appName: 'Test',
                supabaseUrl: '',
                supabasePublishableKey: '',
              ),
            ),
            sponsorBannersProvider.overrideWith((ref) async => [banner]),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(RichText), findsWidgets);
      expect(_clipped(tester, <String>{}), isEmpty);
    });
  }

  testWidgets('ur 200%: the city sheet, nothing clipped', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final h = Harness(
      saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
    );
    await h.pump(tester, device: AppLocales.urdu, size: const Size(360, 800));
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_clipped(tester, <String>{}), isEmpty);
    await _shot(tester, 'ur_200_city_sheet');
  });
}
