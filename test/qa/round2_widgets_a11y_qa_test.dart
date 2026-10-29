// QA round 2 (sub-phase 1.6 fixes): accessibility of the fixed widgets with
// the default test font (textContrastGuideline needs it): AppStepper's new
// controls, AppTabBar when it scrolls, and the deal card's semantics tree.
//
// No alchemist goldens and no real fonts in this file.
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/models/deal_card_data.dart';
import 'package:sale_lagi_hai/design_system/models/deal_offer.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_stepper.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_tab_bar.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';

import '../helpers/test_app.dart';

final _now = DateTime(2026, 10, 29, 12);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = AppLocales.english,
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360 * 3, 1600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final script = AppLocales.isRtl(locale) ? AppScript.urdu : AppScript.latin;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 1600),
        textScaler: TextScaler.linear(textScale),
        highContrast: highContrast,
      ),
      child: testApp(
        Builder(
          builder: (context) => Theme(
            data: AppTheme.build(
              brightness: brightness,
              script: script,
              highContrast: highContrast,
            ),
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
        locale: locale,
        brightness: brightness,
        overrides: [clockProvider.overrideWithValue(() => _now)],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _guidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

const List<(String, Brightness, bool)> _modes = [
  ('light', Brightness.light, false),
  ('dark', Brightness.dark, false),
  ('light HC', Brightness.light, true),
  ('dark HC', Brightness.dark, true),
];

void main() {
  group('AppStepper controls', () {
    for (final locale in AppLocales.supported) {
      for (final (name, brightness, hc) in _modes) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('${locale.languageCode} $name ${(scale * 100).round()}%: '
              'tap targets, labels and contrast', (tester) async {
            final handle = tester.ensureSemantics();
            await _pump(
              tester,
              AppStepper(
                currentStep: 1,
                onStepContinue: () {},
                onStepCancel: () {},
                onStepTapped: (_) {},
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
                ],
              ),
              locale: locale,
              brightness: brightness,
              highContrast: hc,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
            await _guidelines(tester);
            handle.dispose();
          });
        }
      }
    }

    testWidgets('Continue and Cancel fire the callbacks; disabled when null', (
      tester,
    ) async {
      var next = 0;
      var back = 0;
      await _pump(
        tester,
        AppStepper(
          onStepContinue: () => next++,
          onStepCancel: () => back++,
          steps: const [
            Step(title: Text('A'), content: SizedBox(), isActive: true),
            Step(title: Text('B'), content: SizedBox()),
          ],
        ),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.tap(find.byType(TextButton));
      expect((next, back), (1, 1));

      await _pump(
        tester,
        const AppStepper(
          steps: [
            Step(title: Text('A'), content: SizedBox(), isActive: true),
            Step(title: Text('B'), content: SizedBox()),
          ],
        ),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('a custom controlsBuilder still wins', (tester) async {
      await _pump(
        tester,
        AppStepper(
          onStepContinue: () {},
          controlsBuilder: (_, _) => const Text('custom'),
          steps: const [
            Step(title: Text('A'), content: SizedBox(), isActive: true),
          ],
        ),
      );
      expect(find.text('custom'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });
  });

  group('AppTabBar when it scrolls', () {
    for (final locale in AppLocales.supported) {
      for (final (name, brightness, hc) in _modes) {
        testWidgets('${locale.languageCode} $name 200% 5 tabs: guidelines', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          await _pump(
            tester,
            DefaultTabController(
              length: 5,
              child: AppTabBar(
                labels: locale == AppLocales.urdu
                    ? const ['قریب', 'آن لائن', 'پورا شہر', 'کھانا', 'کارڈز']
                    : const ['Near me', 'Online', 'All city', 'Food', 'Cards'],
              ),
            ),
            locale: locale,
            brightness: brightness,
            highContrast: hc,
            textScale: 2,
          );
          expect(
            tester.widget<TabBar>(find.byType(TabBar)).isScrollable,
            isTrue,
          );
          await _guidelines(tester);
          handle.dispose();
        });
      }
    }
  });

  group('DealCard semantics tree after the BUG-1 fix', () {
    const deal = DealCardData(
      id: 'd1',
      brandName: 'Sapphire',
      title: 'Winter collection',
      offer: PercentOff(40),
      price: 2999,
      oldPrice: 4999,
      place: 'Clifton',
      featured: true,
    );

    for (final locale in AppLocales.supported) {
      for (final size in DealCardSize.values) {
        testWidgets('${locale.languageCode} ${size.name}: one card node with '
            'tap + Save, a separate save button, nothing read twice', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          var opened = 0;
          var saved = 0;
          await _pump(
            tester,
            DealCard(
              deal: deal,
              size: size,
              onTap: () => opened++,
              onSaveToggle: () => saved++,
            ),
            locale: locale,
          );
          final owner = tester.binding.renderViews.first.owner!.semanticsOwner!;
          final nodes = <SemanticsNode>[];
          void walk(SemanticsNode n) {
            nodes.add(n);
            n.visitChildren((c) {
              walk(c);
              return true;
            });
          }

          walk(owner.rootSemanticsNode!);
          final card = nodes
              .where((n) => n.getSemanticsData().label.startsWith('Sapphire'))
              .toList();
          expect(card, hasLength(1), reason: 'exactly one card node');
          final data = card.single.getSemanticsData();
          expect(data.flagsCollection.isButton, isTrue);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
          expect(data.hasAction(SemanticsAction.customAction), isTrue);

          // The card's own texts are not separate nodes (no double reading).
          for (final text in ['Winter collection', 'Clifton']) {
            expect(
              nodes.where((n) => n.getSemanticsData().label == text),
              isEmpty,
              reason: text,
            );
          }

          // The save button is its own labelled, tappable node.
          final save = nodes.where(
            (n) =>
                n != card.single &&
                n.getSemanticsData().hasAction(SemanticsAction.tap) &&
                n.getSemanticsData().tooltip.isNotEmpty,
          );
          expect(save, hasLength(1));

          owner
            ..performAction(card.single.id, SemanticsAction.tap)
            ..performAction(save.single.id, SemanticsAction.tap);
          expect((opened, saved), (1, 1));
          handle.dispose();
        });
      }
    }

    testWidgets('without a save callback: tap, and no custom actions listed', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, DealCard(deal: deal, onTap: () {}));
      final data = tester
          .getSemantics(find.bySemanticsLabel(RegExp('^Sapphire')))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.customSemanticsActionIds ?? const <int>[], isEmpty);
      handle.dispose();
    });

    testWidgets(
      'without a save callback the node does not advertise customAction',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, DealCard(deal: deal, onTap: () {}));
        final data = tester
            .getSemantics(find.bySemanticsLabel(RegExp('^Sapphire')))
            .getSemanticsData();
        expect(data.hasAction(SemanticsAction.customAction), isFalse);
        handle.dispose();
      },
    );
  });
}
