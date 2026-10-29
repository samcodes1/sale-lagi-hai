// QA (sub-phase 1.3): theme wiring, high contrast and font licences.
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of a bug
// that is open in docs/qa/1.3.md (see known_bugs.dart).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/design_system/fonts/font_licenses.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';
import 'package:sale_lagi_hai/design_system/theme/deal_colors.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/features/home/presentation/home_screen.dart';

import '../helpers/fakes.dart';

double _channel(double v) {
  final c = (v * 255).round() / 255;
  return c <= 0.04045
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _contrast(Color a, Color b) {
  double l(Color c) =>
      0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);
  final x = l(a);
  final y = l(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

const _config = AppConfig(
  flavor: Flavor.dev,
  appName: 'SLH Dev',
  supabaseUrl: 'https://example.supabase.co',
  supabasePublishableKey: 'sb_publishable_example',
);

Future<ThemeData> _effectiveTheme(
  WidgetTester tester, {
  required Brightness platform,
  required bool highContrast,
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = platform;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(highContrast: highContrast);
  addTearDown(() {
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        onboardedShopper,
        guestAuth(),
        appConfigProvider.overrideWithValue(_config),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
  // Since 1.5 the home is the Home tab (edited by the developer).
  return Theme.of(tester.element(find.byType(HomeScreen)));
}

void main() {
  group('App picks the right theme from the platform', () {
    for (final platform in Brightness.values) {
      for (final hc in [false, true]) {
        testWidgets('${platform.name}, highContrast=$hc', (tester) async {
          final theme = await _effectiveTheme(
            tester,
            platform: platform,
            highContrast: hc,
          );
          final expected = AppTheme.build(
            brightness: platform,
            highContrast: hc,
          ).colorScheme;
          expect(theme.brightness, platform);
          expect(theme.colorScheme.onSurfaceVariant, expected.onSurfaceVariant);
          expect(theme.colorScheme.outline, expected.outline);
        });
      }
    }
  });

  group('high contrast: every text pair reaches 7:1 (WCAG 1.4.6)', () {
    for (final b in Brightness.values) {
      test(b.name, () {
        final theme = AppTheme.build(brightness: b, highContrast: true);
        final s = theme.colorScheme;
        final d = theme.extension<DealColors>()!;
        final pairs = <String, (Color, Color)>{
          'onSurface/surface': (s.onSurface, s.surface),
          'onSurfaceVariant/surface': (s.onSurfaceVariant, s.surface),
          'secondary (links)/background': (
            s.secondary,
            theme.scaffoldBackgroundColor,
          ),
          'error text/surface': (s.error, s.surface),
          'onError/error': (s.onError, s.error),
          'onDeal/deal': (d.onDeal, d.deal),
          'success/surface': (d.success, s.surface),
          'success/successContainer': (d.success, d.successContainer),
          'warning/surface': (d.warning, s.surface),
          'warning/warningContainer': (d.warning, d.warningContainer),
          'info/infoContainer': (d.info, d.infoContainer),
          'snackbar action (inversePrimary)/inverseSurface': (
            s.inversePrimary,
            s.inverseSurface,
          ),
        };
        final below = [
          for (final MapEntry(key: k, value: (fg, bg)) in pairs.entries)
            if (_contrast(fg, bg) < 7)
              '$k ${_contrast(fg, bg).toStringAsFixed(2)}',
        ];
        expect(below, isEmpty);
      });
    }

    test('what the project asks for (theming.md): secondary text 7:1, '
        'outlines 4.5:1', () {
      for (final b in Brightness.values) {
        final s = AppTheme.build(brightness: b, highContrast: true).colorScheme;
        expect(_contrast(s.onSurfaceVariant, s.surface), greaterThan(7));
        expect(_contrast(s.outline, s.surface), greaterThan(4.5));
      }
    });
  });

  group('snackbar action colour (inversePrimary) on inverseSurface', () {
    for (final b in Brightness.values) {
      test('${b.name} ≥ 4.5:1', () {
        final s = AppTheme.build(brightness: b).colorScheme;
        expect(
          _contrast(s.inversePrimary, s.inverseSurface),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  group('font licences', () {
    test('the real licence assets are bundled and load', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final (font, path) in fontLicenses) {
        final text = await rootBundle.loadString(path);
        expect(text, contains('SIL OPEN FONT LICENSE'), reason: font);
        expect(text.length, greaterThan(3000), reason: font);
      }
    });

    test('registerFontLicenses with the real bundle reaches LicenseRegistry '
        '(what showLicensePage lists)', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      registerFontLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      final packages = entries.expand((e) => e.packages).toSet();
      for (final (font, _) in fontLicenses) {
        expect(packages, contains(font));
      }
      final nastaliq = entries.firstWhere(
        (e) => e.packages.contains('Noto Nastaliq Urdu'),
      );
      expect(
        nastaliq.paragraphs.map((p) => p.text).join('\n'),
        contains('Copyright'),
      );
    });

    test('one licence per bundled family (BricolageCondensed is covered by '
        'the Bricolage Grotesque OFL)', () {
      expect(fontLicenses, hasLength(4));
      expect(BrandFonts.display, 'BricolageCondensed');
    });
  });
}
