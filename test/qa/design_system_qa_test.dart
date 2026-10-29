// QA tests for sub-phase 1.6 (Design-system widgets), written by the QA
// engineer. Tests marked `skip: knownBug(...)` assert the expected
// behaviour of an open bug (docs/qa/1.6.md); run them with
// `--dart-define=QA_KNOWN_BUGS=true`.
//
// No alchemist goldens in this file: it uses textContrastGuideline.
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/gallery/widget_gallery_page.dart';
import 'package:sale_lagi_hai/design_system/models/deal_card_data.dart';
import 'package:sale_lagi_hai/design_system/models/deal_offer.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';
import 'package:sale_lagi_hai/design_system/theme/deal_colors.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_bottom_sheet.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_labels.dart';

import '../helpers/test_app.dart';

final _now = DateTime(2026, 10, 29, 12);

const _deal = DealCardData(
  id: 'd1',
  brandName: 'Sapphire',
  title: 'Winter collection',
  offer: PercentOff(40),
  price: 2999,
  oldPrice: 4999,
  place: 'Clifton',
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = AppLocales.english,
  Brightness brightness = Brightness.light,
  DateTime Function()? clock,
  double textScale = 1,
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: testApp(
        Scaffold(body: SingleChildScrollView(child: child)),
        locale: locale,
        brightness: brightness,
        overrides: [clockProvider.overrideWithValue(clock ?? () => _now)],
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('DealCard for screen readers', () {
    for (final size in DealCardSize.values) {
      testWidgets('${size.name}: the card node can be activated (tap action)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        var opened = 0;
        await _pump(
          tester,
          DealCard(
            deal: _deal,
            size: size,
            onTap: () => opened++,
            onSaveToggle: () {},
          ),
        );
        final finder = find.bySemanticsLabel(RegExp('^Sapphire'));
        expect(
          tester.getSemantics(finder),
          matchesSemantics(
            label: tester.getSemantics(finder).label,
            isButton: true,
            hasTapAction: true,
            customActions: const [CustomSemanticsAction(label: 'Save')],
          ),
        );
        tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
          tester.getSemantics(finder).id,
          SemanticsAction.tap,
        );
        expect(opened, 1);
        handle.dispose();
      });
    }

    testWidgets('the save button exposes its toggled state', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        DealCard(
          deal: const DealCardData(
            id: 'x',
            brandName: 'A',
            title: 'B',
            saved: true,
          ),
          onTap: () {},
          onSaveToggle: () {},
        ),
      );
      final data = tester
          .getSemantics(find.byTooltip('Remove from saved'))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('DealOffer.fromPrices edge cases', () {
    test('a free item (now = 0) does not trip the 1-99 assertion', () {
      expect(() => DealOffer.fromPrices(was: 500, now: 0), returnsNormally);
    });

    test('99.9% rounds down to 99, never 100', () {
      expect(DealOffer.fromPrices(was: 1000, now: 1), const PercentOff(99));
    });
  });

  group('ExpiryTag refresh', () {
    testWidgets('an urgent tag turns "Expired" without a rebuild from above', (
      tester,
    ) async {
      var now = _now;
      await _pump(
        tester,
        ExpiryTag(endsAt: _now.add(const Duration(seconds: 90))),
        clock: () => now,
      );
      expect(find.text('Ends in 1 hour'), findsOneWidget);
      now = now.add(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Expired'), findsOneWidget);
    });

    testWidgets('a tag mounted 24h+1min out turns urgent once inside 24h', (
      tester,
    ) async {
      var now = _now;
      final endsAt = _now.add(const Duration(hours: 24, minutes: 1));
      await _pump(tester, ExpiryTag(endsAt: endsAt), clock: () => now);
      now = now.add(const Duration(minutes: 5));
      await tester.pump(const Duration(minutes: 5));
      final text = tester.widget<Text>(find.text('Ends tomorrow'));
      final warning = AppTheme.light().extension<DealColors>()!.warning;
      expect(text.style!.color, warning);
    });
  });

  group('gallery accessibility in the combinations the suite skips', () {
    for (final (name, locale, brightness, highContrast) in const [
      ('ur dark', AppLocales.urdu, Brightness.dark, false),
      ('en light HC', AppLocales.english, Brightness.light, true),
      ('ur dark HC', AppLocales.urdu, Brightness.dark, true),
    ]) {
      testWidgets('$name: tap targets, labels and contrast', (tester) async {
        final handle = tester.ensureSemantics();
        tester.view.physicalSize = const Size(1080, 8000);
        tester.view.devicePixelRatio = 2.625;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(1080 / 2.625, 8000 / 2.625),
              highContrast: highContrast,
            ),
            child: testApp(
              highContrast
                  ? Builder(
                      builder: (context) => Theme(
                        data: AppTheme.build(
                          brightness: brightness,
                          script: AppLocales.isRtl(locale)
                              ? AppScript.urdu
                              : AppScript.latin,
                          highContrast: true,
                        ),
                        child: const WidgetGalleryPage(),
                      ),
                    )
                  : const WidgetGalleryPage(),
              locale: locale,
              brightness: brightness,
              overrides: [clockProvider.overrideWithValue(() => _now)],
            ),
          ),
        );
        await tester.pump();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }

    testWidgets('dark Urdu gallery at 200% on 360dp has no overflow', (
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
            locale: AppLocales.urdu,
            brightness: Brightness.dark,
            overrides: [clockProvider.overrideWithValue(() => _now)],
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'scroll step $i');
      }
    });
  });

  group('cards with long Urdu content', () {
    const urduDeal = DealCardData(
      id: 'u1',
      brandName: 'گل احمد',
      title:
          'سردیوں کی کلیکشن پر زبردست رعایت، تمام اسٹورز اور آن لائن، '
          'صرف اس ہفتے کے آخر تک',
      offer: TextOffer('ایک خریدیں ایک مفت'),
      price: 12500,
      oldPrice: 18999,
      place: 'لبرٹی مارکیٹ، لاہور',
      featured: true,
      cardNames: ['HBL', 'میزان بینک', 'Alfalah'],
    );
    for (final size in DealCardSize.values) {
      testWidgets('${size.name}: 200% text, 360dp, no overflow', (
        tester,
      ) async {
        await _pump(
          tester,
          DealCard(
            deal: urduDeal.copyWithEnds(_now.add(const Duration(hours: 3))),
            onTap: () {},
            onSaveToggle: () {},
            size: size,
          ),
          locale: AppLocales.urdu,
          textScale: 2,
          size: const Size(360, 800),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('نمایاں'), findsOneWidget);
      });
    }
  });

  testWidgets('the bottom sheet in Urdu at 200%: handle, header, no overflow', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showAppBottomSheet<void>(
            context: context,
            title: 'فلٹرز',
            builder: (_) => Column(
              children: [
                for (var i = 0; i < 30; i++) Text('فلٹر کا انتخاب نمبر $i'),
              ],
            ),
          ),
          child: const Text('open'),
        ),
      ),
      locale: AppLocales.urdu,
      textScale: 2,
      size: const Size(360, 800),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSemantics(find.text('فلٹرز')),
      matchesSemantics(label: 'فلٹرز', isHeader: true),
    );
    // Drag handle from the theme (showDragHandle: true): a labelled
    // dismiss target.
    final context = tester.element(find.text('فلٹرز'));
    expect(
      find.bySemanticsLabel(
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
      ),
      findsWidgets,
    );
    handle.dispose();
  });
}

extension on DealCardData {
  DealCardData copyWithEnds(DateTime endsAt) => DealCardData(
    id: id,
    brandName: brandName,
    title: title,
    offer: offer,
    price: price,
    oldPrice: oldPrice,
    endsAt: endsAt,
    verifiedAt: verifiedAt,
    place: place,
    featured: featured,
    saved: saved,
    cardNames: cardNames,
  );
}
