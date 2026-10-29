// QA (sub-phase 1.3): typography under the real AppTheme.
// - Every text run that common widgets render uses a bundled family (no
//   Roboto or other platform fallback as the primary family).
// - The Urdu theme leaves no style without Nastaliq/Naskh.
// - Urdu components render with real fonts at 1x and 2x without overflow.
//   With QA_DUMP=true the renders are written to docs/qa/screens/1.3/flutter/
//   for review by eye (Nastaliq clipping is only visible with real fonts).
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of a bug
// that is open in docs/qa/1.3.md (see known_bugs.dart).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_tab_bar.dart';

const Set<String> _bundled = {
  BrandFonts.display,
  BrandFonts.title,
  BrandFonts.ui,
  BrandFonts.urdu,
  BrandFonts.urduCompact,
};
const _iconFonts = {'MaterialIcons'};

final _dump = Platform.environment['QA_DUMP'] == 'true';

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
  // Icons, so renders show real glyphs.
  final icons = FontLoader('MaterialIcons');
  final iconPath =
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
      '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconPath).existsSync()) {
    icons.addFont(
      Future.value(ByteData.sublistView(File(iconPath).readAsBytesSync())),
    );
    await icons.load();
  }
}

List<TextStyle> _allStyles(TextTheme t) => [
  t.displayLarge!,
  t.displayMedium!,
  t.displaySmall!,
  t.headlineLarge!,
  t.headlineMedium!,
  t.headlineSmall!,
  t.titleLarge!,
  t.titleMedium!,
  t.titleSmall!,
  t.bodyLarge!,
  t.bodyMedium!,
  t.bodySmall!,
  t.labelLarge!,
  t.labelMedium!,
  t.labelSmall!,
];

/// Every (text, family) pair painted in the current tree.
List<(String, String?)> _paintedFamilies(WidgetTester tester) {
  final out = <(String, String?)>[];
  for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
    p.text.visitChildren((span) {
      if (span is TextSpan && (span.text?.trim().isNotEmpty ?? false)) {
        out.add((
          span.text!,
          span.style?.fontFamily ?? p.text.style?.fontFamily,
        ));
      }
      return true;
    });
  }
  for (final e in tester.allRenderObjects.whereType<RenderEditable>()) {
    final span = e.text!;
    if (span.toPlainText().trim().isNotEmpty) {
      out.add((span.toPlainText(), span.style?.fontFamily));
    }
  }
  return out;
}

Widget _kitchenSink() => Builder(
  builder: (context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      FilledButton(onPressed: () {}, child: const Text('الرٹ لگائیں')),
      OutlinedButton(onPressed: () {}, child: const Text('شیئر کریں')),
      TextButton(onPressed: () {}, child: const Text('شرائط دیکھیں')),
      ElevatedButton(onPressed: () {}, child: const Text('ڈیل لیں')),
      Wrap(
        spacing: 8,
        children: [
          FilterChip(label: const Text('کھانا'), onSelected: (_) {}),
          FilterChip(
            label: const Text('فیشن'),
            selected: true,
            onSelected: (_) {},
          ),
          ActionChip(label: const Text('گھنٹے پہلے'), onPressed: () {}),
          ChoiceChip(
            label: const Text('کلفٹن'),
            selected: true,
            onSelected: (_) {},
          ),
        ],
      ),
      const TextField(
        decoration: InputDecoration(
          labelText: 'ڈیل تلاش کریں',
          hintText: 'برانڈ یا دکان',
          helperText: 'مثلاً: کھاڈی، گل احمد',
        ),
      ),
      TextFormField(
        initialValue: 'گھنٹے پہلے تصدیق شدہ',
        decoration: const InputDecoration(labelText: 'شہر'),
      ),
      const ListTile(
        leading: Icon(Icons.local_offer_outlined),
        title: Text('گھنٹے پہلے تصدیق شدہ'),
        subtitle: Text('کلفٹن، کراچی · اتوار رات تک'),
      ),
      // Developer edit (1.6): AppTabBar, the design-system tab row that
      // fixes BUG-10. Raw TabBar is banned in lib/ by the guard test.
      const DefaultTabController(
        length: 2,
        child: AppTabBar(labels: ['قریب', 'آن لائن']),
      ),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('قریب')),
          ButtonSegment(value: 1, label: Text('پورا شہر')),
        ],
        selected: const {0},
        onSelectionChanged: (_) {},
      ),
      const Badge(label: Text('۳'), child: Icon(Icons.notifications)),
      NavigationBar(
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'ہوم'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'تلاش'),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: 'الرٹس',
          ),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'محفوظ'),
          NavigationDestination(icon: Icon(Icons.person), label: 'پروفائل'),
        ],
      ),
      const SizedBox(
        width: 160,
        child: Text(
          'سفائر کی سردیوں کی سیل شروع ہو گئی ہے',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const Tooltip(message: 'محفوظ کریں', child: Icon(Icons.bookmark)),
    ],
  ),
);

Future<void> _pumpUrdu(
  WidgetTester tester, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(412, 1400),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('shot'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(brightness: brightness, script: AppScript.urdu),
        locale: const Locale('ur'),
        supportedLocales: const [Locale('ur'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          appBar: AppBar(
            title: const Text('سیل لگی ہے!'),
            actions: [
              IconButton(
                tooltip: 'تلاش',
                onPressed: () {},
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          body: _kitchenSink(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_dump) return;
  await tester.runAsync(() async {
    final image = await captureImage(
      tester.element(find.byKey(const ValueKey('shot'))),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('docs/qa/screens/1.3/flutter')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  group('Urdu theme', () {
    test('every TextTheme style uses Nastaliq (or Naskh) with tall lines', () {
      for (final b in Brightness.values) {
        final styles = _allStyles(
          AppTheme.build(brightness: b, script: AppScript.urdu).textTheme,
        );
        for (final (i, s) in styles.indexed) {
          expect(
            s.fontFamily,
            anyOf(BrandFonts.urdu, BrandFonts.urduCompact),
            reason: 'style #$i',
          );
          expect(s.fontFamilyFallback, contains(BrandFonts.ui));
          // Edited by the developer for the 1.3 BUG-11 fix: dense UI styles
          // moved to Naskh, which needs 1.5-1.6 (theming.md), not 1.9.
          expect(
            s.height,
            greaterThanOrEqualTo(s.fontFamily == BrandFonts.urdu ? 1.9 : 1.6),
            reason: 'style #$i',
          );
          expect(s.letterSpacing ?? 0, 0, reason: 'never letter-space Urdu');
        }
      }
    });

    test('Latin theme: every style is a bundled family with Urdu fallback', () {
      for (final s in _allStyles(AppTheme.light().textTheme)) {
        expect(_bundled, contains(s.fontFamily));
        expect(s.fontFamilyFallback, contains(BrandFonts.urdu));
      }
    });

    for (final b in Brightness.values) {
      testWidgets('${b.name}: every painted run uses a bundled family', (
        tester,
      ) async {
        await _pumpUrdu(tester, brightness: b);
        final wrong = _paintedFamilies(tester)
            .where(
              (r) => !_bundled.contains(r.$2) && !_iconFonts.contains(r.$2),
            )
            .toList();
        expect(wrong, isEmpty);
        await _shot(tester, 'urdu_components_${b.name}');
      });
    }

    testWidgets('Latin: every painted run uses a bundled family', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(824, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            appBar: AppBar(title: const Text('Deals')),
            body: ListView(
              children: [
                ElevatedButton(onPressed: () {}, child: const Text('Get')),
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'Search',
                    helperText: 'Brand or shop',
                  ),
                ),
                const ListTile(title: Text('a'), subtitle: Text('b')),
                const Badge(label: Text('3'), child: Icon(Icons.home)),
                ActionChip(label: const Text('Offers'), onPressed: () {}),
                const DefaultTabController(
                  length: 1,
                  child: TabBar(tabs: [Tab(text: 'Tab')]),
                ),
                SearchBar(hintText: 'Search', onTap: () {}),
                const DropdownMenu<int>(
                  label: Text('City'),
                  dropdownMenuEntries: [
                    DropdownMenuEntry(value: 1, label: 'Karachi'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final wrong = _paintedFamilies(tester)
          .where((r) => !_bundled.contains(r.$2) && !_iconFonts.contains(r.$2))
          .toList();
      expect(wrong, isEmpty);
    });

    testWidgets('no overflow at 200% text, 360dp wide, Urdu', (tester) async {
      await _pumpUrdu(tester, textScale: 2, size: const Size(360, 2600));
      expect(tester.takeException(), isNull);
      await _shot(tester, 'urdu_components_light_ts2');
    });

    testWidgets('NavigationBar: five Urdu labels at 200% stay inside the bar', (
      tester,
    ) async {
      await _pumpUrdu(tester, textScale: 2, size: const Size(360, 2600));
      final bar = tester.getRect(find.byType(NavigationBar));
      for (final label in ['ہوم', 'تلاش', 'الرٹس', 'محفوظ', 'پروفائل']) {
        final r = tester.getRect(find.text(label));
        expect(
          bar.top <= r.top && r.bottom <= bar.bottom,
          isTrue,
          reason: '$label $r is outside the bar $bar',
        );
      }
    });

    testWidgets('TabBar: Urdu labels at 200% fit the tab', (tester) async {
      await _pumpUrdu(tester, textScale: 2, size: const Size(360, 2600));
      final problems = <String>[];
      // A paragraph laid out shorter than its text needs is clipped (Tab
      // and SegmentedButton labels use overflow: fade/clip/ellipsis).
      void check(Finder label) {
        final p = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: label,
            matching: find.byType(RichText),
            matchRoot: true,
          ),
        );
        final needed = p.getMaxIntrinsicHeight(double.infinity);
        if (needed > p.size.height + 0.5 ||
            p.getMaxIntrinsicWidth(double.infinity) > p.size.width + 0.5) {
          problems.add(
            '$label: needs ${needed.toStringAsFixed(1)} x '
            '${p.getMaxIntrinsicWidth(double.infinity).toStringAsFixed(1)}, '
            'got ${p.size}',
          );
        }
      }

      check(
        find.descendant(
          of: find.byType(AppTabBar),
          matching: find.text('قریب'),
        ),
      );
      check(find.text('آن لائن'));
      expect(problems, isEmpty);
    });

    testWidgets('Latin theme showing Urdu content (fallback to Nastaliq)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(824, 900);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('shot'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Khaadi: گھنٹے پہلے تصدیق شدہ سفائر کی سردیوں کی سیل '
                    'شروع ہو گئی ہے۔ اتوار رات تک',
                  ),
                  const ListTile(
                    title: Text(
                      'گھنٹے پہلے تصدیق شدہ سفائر کی سردیوں کی سیل',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('Clifton · کلفٹن، کراچی'),
                  ),
                  FilterChip(label: const Text('کھانا'), onSelected: (_) {}),
                  FilledButton(
                    onPressed: () {},
                    child: const Text('الرٹ لگائیں'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _shot(tester, 'latin_theme_urdu_content');
    });

    // Round 2: split out of the deferred TabBar test, so the BUG-10 skip
    // does not hide SegmentedButton (which was in BUG-11's fix scope).
    for (final (script, labels) in [
      (AppScript.urdu, ['قریب', 'پورا شہر']),
      (AppScript.latin, ['Near me', 'All city']),
    ]) {
      testWidgets(
        'SegmentedButton: ${script.name} labels at 200% are not clipped',
        (tester) async {
          tester.view.physicalSize = const Size(720, 1600);
          tester.view.devicePixelRatio = 2;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.build(
                brightness: Brightness.light,
                script: script,
              ),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 0, label: Text(labels[0])),
                      ButtonSegment(value: 1, label: Text(labels[1])),
                    ],
                    selected: const {0},
                    onSelectionChanged: (_) {},
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final problems = <String>[];
          for (final l in labels) {
            final p = tester.renderObject<RenderParagraph>(find.text(l));
            // Wrapping is fine; being laid out shorter than the wrapped
            // text needs is clipping.
            final h = p.getMaxIntrinsicHeight(p.size.width);
            final seg = tester.getRect(find.byType(SegmentedButton<int>));
            final r = tester.getRect(find.text(l));
            if (h > p.size.height + 0.5 ||
                r.left < seg.left ||
                r.right > seg.right) {
              problems.add(
                '$l needs height ${h.toStringAsFixed(1)}, got ${p.size} '
                'at $r in $seg',
              );
            }
          }
          expect(problems, isEmpty);
        },
      );
    }
  });
}
