// QA round 2 (sub-phase 1.6 fixes), with the REAL bundled fonts loaded:
// AppStepper's new circle sizing and controls, AppTabBar's scroll switch,
// and the Urdu isolates' layout. Each runs at 100% and 200%, LTR (en) and
// RTL (ur), light and dark, on 360dp and 412dp phones.
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug in docs/qa/1.6.md (see known_bugs.dart). No contrast checks here:
// real fonts confuse textContrastGuideline (see round2_widgets_a11y_qa_test).
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/models/deal_offer.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_stepper.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_tab_bar.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_labels.dart';

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
  Brightness brightness = Brightness.light,
  double textScale = 1,
  double width = 360,
}) async {
  const height = 1600.0;
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        textScaler: TextScaler.linear(textScale),
      ),
      child: testApp(
        Scaffold(body: SingleChildScrollView(child: child)),
        locale: locale,
        brightness: brightness,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

RenderParagraph _paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: text,
        matching: find.byType(RichText),
        matchRoot: true,
      ),
    );

/// Whether the paragraph showing [text] needs more room than it got.
bool _clipped(WidgetTester tester, Finder text) {
  final p = _paragraph(tester, text);
  return p.didExceedMaxLines ||
      p.getMaxIntrinsicWidth(double.infinity) > p.size.width + 0.5 ||
      p.getMinIntrinsicHeight(p.size.width) > p.size.height + 0.5;
}

const List<(double, Brightness)> _modes = [
  (1.0, Brightness.light),
  (1.0, Brightness.dark),
  (2.0, Brightness.light),
  (2.0, Brightness.dark),
];

void main() {
  setUpAll(_loadFonts);

  group('AppStepper (round-2 sizing and controls)', () {
    for (final locale in AppLocales.supported) {
      for (final (scale, brightness) in _modes) {
        final name =
            '${locale.languageCode} ${brightness.name} '
            '${(scale * 100).round()}%';

        testWidgets('$name: digits fit round circles, connector centred, '
            'controls on screen', (tester) async {
          await _pump(
            tester,
            AppStepper(
              currentStep: 1,
              onStepContinue: () {},
              onStepCancel: () {},
              steps: const [
                Step(
                  title: Text('City'),
                  content: SizedBox.shrink(),
                  isActive: true,
                  state: StepState.complete,
                ),
                Step(
                  title: Text('Interests'),
                  content: Text('Pick three or more.'),
                  isActive: true,
                ),
                Step(title: Text('Alerts'), content: SizedBox.shrink()),
                Step(title: Text('Done'), content: SizedBox.shrink()),
              ],
            ),
            locale: locale,
            brightness: brightness,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);

          final circles = <Rect>[];
          for (final digit in ['2', '3', '4']) {
            final label = find.text(digit);
            final circle = tester.getRect(
              find
                  .ancestor(of: label, matching: find.byType(AnimatedContainer))
                  .first,
            );
            circles.add(circle);
            expect(circle.width, closeTo(circle.height, 0.01), reason: digit);
            final p = _paragraph(tester, label);
            expect(
              p.getMaxIntrinsicHeight(double.infinity),
              lessThanOrEqualTo(circle.height),
              reason: 'digit $digit height in ${circle.height}dp',
            );
            expect(
              p.getMaxIntrinsicWidth(double.infinity),
              lessThanOrEqualTo(circle.width),
              reason: 'digit $digit width',
            );
            // The digit is centred in its circle.
            expect(
              tester.getCenter(label).dx,
              closeTo(circle.center.dx, 1),
              reason: 'digit $digit centred',
            );
          }
          // All circles in one column (same x), on the start side.
          for (final c in circles) {
            expect(c.center.dx, closeTo(circles.first.center.dx, 0.5));
          }
          final rtl = locale == AppLocales.urdu;
          expect(
            rtl ? circles.first.center.dx > 180 : circles.first.center.dx < 180,
            isTrue,
            reason: 'circles on the start side',
          );

          // Connector lines (1dp wide) run through the circles' centres.
          final lines = [
            for (final b in tester.widgetList<ColoredBox>(
              find.byType(ColoredBox),
            ))
              tester.getRect(find.byWidget(b)),
          ].where((r) => r.width <= 1.01 && r.height > 8).toList();
          expect(lines, isNotEmpty);
          for (final r in lines) {
            expect(
              r.center.dx,
              closeTo(circles.first.center.dx, 1),
              reason: 'connector at ${r.left}',
            );
          }

          // Controls: only the current step has them; both on screen and
          // not clipped; tap targets at least 48dp.
          expect(find.byType(FilledButton), findsOneWidget);
          final l10n = MaterialLocalizations.of(
            tester.element(find.byType(Stepper)),
          );
          for (final label in [
            l10n.continueButtonLabel,
            l10n.cancelButtonLabel,
          ]) {
            final text = find.text(label);
            expect(text, findsOneWidget, reason: label);
            final r = tester.getRect(text);
            expect(r.left, greaterThanOrEqualTo(0), reason: label);
            expect(r.right, lessThanOrEqualTo(360), reason: label);
            expect(_clipped(tester, text), isFalse, reason: label);
          }
          for (final button in [
            find.byType(FilledButton),
            find.byType(TextButton),
          ]) {
            final size = tester.getSize(button);
            expect(size.height, greaterThanOrEqualTo(48), reason: '$button');
          }
          // Controls start where the content column starts (Material's
          // fixed 60dp start padding); short content itself is centred.
          final continueRect = tester.getRect(find.byType(FilledButton));
          if (rtl) {
            expect(continueRect.right, closeTo(360 - 60, 1));
          } else {
            expect(continueRect.left, closeTo(60, 1));
          }
        });
      }
    }

    testWidgets('horizontal type at 200% Urdu has no overflow', (tester) async {
      await _pump(
        tester,
        SizedBox(
          height: 900,
          child: AppStepper(
            type: StepperType.horizontal,
            onStepContinue: () {},
            onStepCancel: () {},
            steps: const [
              Step(title: Text('شہر'), content: Text('a'), isActive: true),
              Step(title: Text('دلچسپی'), content: Text('b')),
              Step(title: Text('الرٹس'), content: Text('c')),
            ],
          ),
        ),
        locale: AppLocales.urdu,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AppTabBar (round-2 scroll switch)', () {
    const en = ['Near me', 'Online', 'All city', 'Food', 'Cards'];
    const ur = ['قریب', 'آن لائن', 'پورا شہر', 'کھانا', 'کارڈز'];
    for (final locale in AppLocales.supported) {
      for (final width in [360.0, 412.0]) {
        for (final scale in [1.0, 2.0]) {
          for (var count = 2; count <= 5; count++) {
            final labels = (locale == AppLocales.urdu ? ur : en).sublist(
              0,
              count,
            );
            testWidgets('${locale.languageCode} ${width.round()}dp '
                '${(scale * 100).round()}% $count tabs: no label truncated', (
              tester,
            ) async {
              await _pump(
                tester,
                DefaultTabController(
                  length: count,
                  child: AppTabBar(labels: labels),
                ),
                locale: locale,
                textScale: scale,
                width: width,
              );
              expect(tester.takeException(), isNull);
              final bar = tester.widget<TabBar>(find.byType(TabBar));
              for (final l in labels) {
                expect(_clipped(tester, find.text(l)), isFalse, reason: l);
                // Inside its tab, top to bottom.
                final tab = tester.getRect(
                  find.ancestor(of: find.text(l), matching: find.byType(Tab)),
                );
                final text = tester.getRect(find.text(l));
                expect(text.top, greaterThanOrEqualTo(tab.top - 0.5));
                expect(text.bottom, lessThanOrEqualTo(tab.bottom + 0.5));
                expect(tab.height, greaterThanOrEqualTo(48));
              }
              if (!bar.isScrollable) {
                // Fixed tabs: each label sits in its own 1/n slot.
                final slot = width / count;
                for (final (i, l) in labels.indexed) {
                  final slotIndex = locale == AppLocales.urdu
                      ? count - 1 - i
                      : i;
                  expect(
                    tester.getCenter(find.text(l)).dx,
                    closeTo(slot * slotIndex + slot / 2, slot / 2),
                    reason: l,
                  );
                }
              } else {
                // Scrolling starts at the start edge (right in Urdu).
                final first = tester.getRect(find.byType(Tab).first);
                // (16dp is Material's tab label padding.)
                if (locale == AppLocales.urdu) {
                  expect(first.right, closeTo(width - 16, 1));
                } else {
                  expect(first.left, closeTo(16, 1));
                }
                // The last tab can be scrolled into view and selected.
                await tester.tap(find.text(labels.last), warnIfMissed: false);
                await tester.pumpAndSettle();
                final ctl = DefaultTabController.of(
                  tester.element(find.byType(TabBar)),
                );
                if (ctl.index != count - 1) {
                  await tester.drag(
                    find.byType(TabBar),
                    Offset(locale == AppLocales.urdu ? 600 : -600, 0),
                  );
                  await tester.pumpAndSettle();
                  await tester.tap(find.text(labels.last));
                  await tester.pumpAndSettle();
                }
                expect(ctl.index, count - 1);
                final last = tester.getRect(find.text(labels.last));
                expect(last.left, greaterThanOrEqualTo(-0.5));
                expect(last.right, lessThanOrEqualTo(width + 0.5));
              }
            });
          }
        }
      }
    }

    testWidgets('at 100% three short tabs stay fixed (no needless scroll)', (
      tester,
    ) async {
      for (final locale in AppLocales.supported) {
        await _pump(
          tester,
          DefaultTabController(
            length: 3,
            child: AppTabBar(
              labels: locale == AppLocales.urdu
                  ? ur.sublist(0, 3)
                  : en.sublist(0, 3),
            ),
          ),
          locale: locale,
        );
        expect(
          tester.widget<TabBar>(find.byType(TabBar)).isScrollable,
          isFalse,
          reason: locale.languageCode,
        );
      }
    });

    testWidgets('switches to scrolling when the text size grows live', (
      tester,
    ) async {
      var scale = 1.0;
      late StateSetter setScale;
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setScale = setState;
            return MediaQuery(
              data: MediaQueryData(
                size: const Size(360, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: testApp(
                const Scaffold(
                  body: DefaultTabController(
                    length: 3,
                    child: AppTabBar(labels: ['Near me', 'Online', 'All city']),
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.widget<TabBar>(find.byType(TabBar)).isScrollable;
      setScale(() => scale = 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(before, isFalse);
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue);
    });
  });

  group('Urdu isolates (round-2 ARB change) with real fonts', () {
    late AppLocalizations ur;
    setUpAll(() async {
      ur = await AppLocalizations.delegate.load(AppLocales.urdu);
    });

    double width(String text, TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.rtl,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    test('LRI/PDI draw nothing (no tofu box, no extra width)', () {
      const style = TextStyle(
        fontFamily: BrandFonts.urduCompact,
        fontFamilyFallback: [BrandFonts.ui],
        fontSize: 16,
      );
      for (final text in [
        ur.flatPercentOff(30),
        ur.upToPercentOff(70),
        ur.discountBadge(40),
        ur.emptySearch('Khaadi 50%'),
      ]) {
        final plain = text.replaceAll(RegExp('[\u2066-\u2069]'), '');
        expect(
          width(text, style),
          closeTo(width(plain, style), 0.5),
          reason: text,
        );
      }
    });

    testWidgets('the badge row in Urdu shows each percentage as "N%"', (
      tester,
    ) async {
      await _pump(
        tester,
        const Wrap(
          children: [
            DiscountBadge(offer: FlatPercentOff(30)),
            DiscountBadge(offer: UpToPercentOff(70)),
            DiscountBadge(offer: PercentOff(40)),
          ],
        ),
        locale: AppLocales.urdu,
      );
      for (final (text, digits) in [
        (ur.flatPercentOff(30), '30'),
        (ur.upToPercentOff(70), '70'),
        (ur.discountBadge(40), '40'),
      ]) {
        final p = _paragraph(tester, find.text(text));
        double x(int i) => p
            .getBoxesForSelection(
              TextSelection(baseOffset: i, extentOffset: i + 1),
            )
            .first
            .left;
        final d = text.indexOf(digits);
        final pct = text.indexOf('%');
        expect(x(d), lessThan(x(d + 1)), reason: text);
        expect(x(d + 1), lessThan(x(pct)), reason: text);
        if (text.contains('-')) {
          expect(x(text.indexOf('-')), lessThan(x(d)), reason: text);
        }
      }
    });

    test('a query with Urdu and Latin stays one unit in the sentence', () {
      // FSI…PDI keeps "Khaadi 50%" together inside both languages.
      for (final query in ['Khaadi 50%', 'کھاڈی 50%', '(Sale)']) {
        final text = ur.emptySearch(query);
        final start = text.indexOf('\u2068');
        final end = text.indexOf('\u2069');
        expect(start, greaterThan(0), reason: query);
        expect(text.substring(start + 1, end), query);
      }
    });
  });
}
