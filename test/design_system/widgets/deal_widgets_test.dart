import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/models/deal_card_data.dart';
import 'package:sale_lagi_hai/design_system/models/deal_offer.dart';
import 'package:sale_lagi_hai/design_system/theme/accent_primary.dart';
import 'package:sale_lagi_hai/design_system/theme/deal_colors.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_bottom_sheet.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_stepper.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_tab_bar.dart';
import 'package:sale_lagi_hai/design_system/widgets/content_text.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_labels.dart';
import 'package:sale_lagi_hai/design_system/widgets/price_text.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';

import '../../helpers/test_app.dart';

final _now = DateTime(2026, 10, 29, 12);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = AppLocales.english,
  DateTime Function()? clock,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: testApp(
        Scaffold(body: SingleChildScrollView(child: child)),
        locale: locale,
        overrides: [clockProvider.overrideWithValue(clock ?? () => _now)],
      ),
    ),
  );
  await tester.pump();
}

Color _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

void main() {
  group('DealOffer.fromPrices', () {
    test('rounds down, never up', () {
      expect(DealOffer.fromPrices(was: 4999, now: 2999), const PercentOff(40));
      expect(DealOffer.fromPrices(was: 1000, now: 589), const PercentOff(41));
      expect(DealOffer.fromPrices(was: 999, now: 500), const PercentOff(49));
    });

    test('no real reduction means no badge', () {
      expect(DealOffer.fromPrices(was: 1000, now: 1000), isNull);
      expect(DealOffer.fromPrices(was: 1000, now: 1200), isNull);
      expect(DealOffer.fromPrices(was: 1000, now: 995), isNull);
      expect(DealOffer.fromPrices(was: 0, now: 0), isNull);
      expect(DealOffer.fromPrices(was: 100, now: -1), isNull);
    });

    test('offers compare by value', () {
      expect(const UpToPercentOff(5), const UpToPercentOff(5));
      expect(const FlatPercentOff(5), isNot(const UpToPercentOff(5)));
      expect(
        const TextOffer('B1G1').hashCode,
        const TextOffer('B1G1').hashCode,
      );
      expect(const PercentOff(5).hashCode, const PercentOff(5).hashCode);
      expect(
        const FlatPercentOff(5).hashCode,
        const FlatPercentOff(5).hashCode,
      );
      expect(
        const UpToPercentOff(5).hashCode,
        const UpToPercentOff(5).hashCode,
      );
    });
  });

  group('DiscountBadge', () {
    testWidgets('English wording for every offer kind', (tester) async {
      await _pump(
        tester,
        const Column(
          children: [
            DiscountBadge(offer: PercentOff(40)),
            DiscountBadge(offer: UpToPercentOff(50)),
            DiscountBadge(offer: FlatPercentOff(30)),
            DiscountBadge(offer: TextOffer('Buy 1 Get 1')),
          ],
        ),
      );

      for (final text in [
        '-40%',
        'Up to 50% off',
        'Flat 30% off',
        'Buy 1 Get 1',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
    });

    testWidgets('Urdu wording, with the minus sign kept in front', (
      tester,
    ) async {
      await _pump(
        tester,
        const Column(
          children: [
            DiscountBadge(offer: PercentOff(40)),
            DiscountBadge(offer: UpToPercentOff(50)),
          ],
        ),
        locale: AppLocales.urdu,
      );

      expect(find.text('\u2066-40%\u2069'), findsOneWidget);
      expect(find.text('\u206650%\u2069 تک رعایت'), findsOneWidget);
    });

    testWidgets('uses the deal colours', (tester) async {
      await _pump(tester, const DiscountBadge(offer: PercentOff(40)));

      expect(_textColor(tester, '-40%'), DealColors.light.onDeal);
    });
  });

  testWidgets('FeaturedLabel says Featured / نمایاں', (tester) async {
    await _pump(tester, const FeaturedLabel());
    expect(find.text('Featured'), findsOneWidget);

    await _pump(tester, const FeaturedLabel(), locale: AppLocales.urdu);
    expect(find.text('نمایاں'), findsOneWidget);
  });

  group('ExpiryTag', () {
    testWidgets('shows the label with a clock icon', (tester) async {
      await _pump(tester, ExpiryTag(endsAt: _now.add(const Duration(days: 2))));

      expect(find.text('Ends in 2 days'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('under a day turns the warning colour', (tester) async {
      await _pump(
        tester,
        ExpiryTag(endsAt: _now.add(const Duration(hours: 3))),
      );

      expect(_textColor(tester, 'Ends in 3 hours'), DealColors.light.warning);
    });

    testWidgets('expired deals say so, with a different icon', (tester) async {
      await _pump(
        tester,
        ExpiryTag(endsAt: _now.subtract(const Duration(minutes: 1))),
      );

      expect(find.text('Expired'), findsOneWidget);
      expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
    });

    testWidgets('no end date reads Ongoing', (tester) async {
      await _pump(tester, const ExpiryTag(endsAt: null));

      expect(find.text('Ongoing'), findsOneWidget);
    });

    testWidgets('an urgent tag refreshes every minute, then stops', (
      tester,
    ) async {
      var now = _now;
      await _pump(
        tester,
        ExpiryTag(endsAt: _now.add(const Duration(minutes: 90))),
        clock: () => now,
      );
      expect(find.text('Ends in 2 hours'), findsOneWidget);

      now = _now.add(const Duration(minutes: 31));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Ends in 1 hour'), findsOneWidget);

      // Removing the tag cancels its timer (the test would fail on a
      // pending timer otherwise).
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('VerifiedTag', () {
    testWidgets('fresh: check icon, normal colour', (tester) async {
      await _pump(
        tester,
        VerifiedTag(verifiedAt: _now.subtract(const Duration(hours: 3))),
      );

      expect(find.text('Verified 3 hours ago'), findsOneWidget);
      expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    });

    testWidgets('older than 3 days: warning colour and history icon', (
      tester,
    ) async {
      await _pump(
        tester,
        VerifiedTag(verifiedAt: _now.subtract(const Duration(days: 4))),
      );

      expect(
        _textColor(tester, 'Verified 4 days ago'),
        DealColors.light.warning,
      );
      expect(find.byIcon(Icons.history), findsOneWidget);
    });
  });

  group('PriceText', () {
    testWidgets('reads "was … now …" to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const PriceText(price: 1799, oldPrice: 2999));

      expect(
        find.bySemanticsLabel('was Rs 2,999, now Rs 1,799'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a higher "new" price hides the old one', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const PriceText(price: 2999, oldPrice: 1799));

      expect(find.bySemanticsLabel('Rs 2,999'), findsOneWidget);
      handle.dispose();
    });
  });

  group('DealCard', () {
    final deal = DealCardData(
      id: 'd1',
      brandName: 'Sapphire',
      title: 'Winter collection',
      offer: const PercentOff(40),
      price: 2999,
      oldPrice: 4999,
      endsAt: _now.add(const Duration(days: 2)),
      verifiedAt: _now.subtract(const Duration(hours: 3)),
      place: 'Clifton',
      featured: true,
      cardNames: const ['HBL'],
    );

    for (final size in DealCardSize.values) {
      testWidgets('${size.name}: one summary for screen readers', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          DealCard(deal: deal, onTap: () {}, onSaveToggle: () {}, size: size),
        );

        expect(
          find.bySemanticsLabel(
            'Sapphire. Winter collection. -40%. was Rs 4,999, now Rs 2,999. '
            'Ends in 2 days. Verified 3 hours ago. Clifton. HBL. Featured',
          ),
          findsOneWidget,
        );
        handle.dispose();
      });
    }

    testWidgets('tapping the card opens it; save is separate', (tester) async {
      var opened = 0;
      var saved = 0;
      await _pump(
        tester,
        DealCard(
          deal: deal,
          onTap: () => opened++,
          onSaveToggle: () => saved++,
        ),
      );

      await tester.tap(find.text('Winter collection'));
      await tester.tap(find.byTooltip('Save'));

      expect(opened, 1);
      expect(saved, 1);
    });

    testWidgets('save is also a screen-reader action on the card', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var saved = 0;
      await _pump(
        tester,
        DealCard(deal: deal, onTap: () {}, onSaveToggle: () => saved++),
      );

      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Sapphire')),
      );
      final action = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Save'),
      );
      tester.binding.renderViews.first.owner!.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.customAction,
        action,
      );

      expect(saved, 1);
      handle.dispose();
    });

    testWidgets('a saved deal offers "Remove from saved"', (tester) async {
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

      expect(find.byTooltip('Remove from saved'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('no offer, no badge; no save callback, no button', (
      tester,
    ) async {
      await _pump(
        tester,
        DealCard(
          deal: const DealCardData(id: 'x', brandName: 'Khaadi', title: 'New'),
          onTap: () {},
        ),
      );

      expect(find.byType(DiscountBadge), findsNothing);
      expect(find.byType(FeaturedLabel), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      // The brand plate stands in for the missing image.
      expect(find.text('K'), findsOneWidget);
    });

    testWidgets('a failing image falls back to the brand plate', (
      tester,
    ) async {
      await _pump(
        tester,
        DealCard(
          deal: const DealCardData(
            id: 'x',
            brandName: 'outfitters',
            title: 'Sale',
            imageUrl: 'https://example.invalid/deal.jpg',
          ),
          onTap: () {},
        ),
      );
      await tester.pump();

      expect(find.text('O'), findsOneWidget);
    });

    testWidgets('grows with 200% Urdu text instead of overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360 * 3, 2400 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        Column(
          children: [
            for (final size in DealCardSize.values)
              DealCard(
                deal: DealCardData(
                  id: 'x',
                  brandName: 'سفائر',
                  title: 'سردیوں کی کلیکشن، اسٹور اور آن لائن دونوں پر',
                  offer: const UpToPercentOff(50),
                  price: 2999,
                  oldPrice: 4999,
                  endsAt: _now.add(const Duration(days: 2)),
                  verifiedAt: _now.subtract(const Duration(hours: 3)),
                  place: 'ڈولمن مال کلفٹن',
                  featured: true,
                  cardNames: const ['HBL', 'Meezan'],
                ),
                onTap: () {},
                onSaveToggle: () {},
                size: size,
              ),
          ],
        ),
        locale: AppLocales.urdu,
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('state views', () {
    testWidgets('ErrorView offers retry only when retrying can help', (
      tester,
    ) async {
      var retried = 0;
      await _pump(
        tester,
        SizedBox(
          height: 400,
          child: ErrorView(
            failure: const OfflineFailure(),
            onRetry: () => retried++,
          ),
        ),
      );
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);

      await _pump(
        tester,
        SizedBox(
          height: 400,
          child: ErrorView(
            failure: const NotFoundFailure(),
            onRetry: () => retried++,
          ),
        ),
      );
      expect(find.text('Try again'), findsNothing);
      expect(find.text("We couldn't find this. It may have ended."), findsOne);
    });

    testWidgets('InlineErrorBanner shows the message and retry', (
      tester,
    ) async {
      var retried = 0;
      await _pump(
        tester,
        InlineErrorBanner(
          failure: const TimeoutFailure(),
          onRetry: () => retried++,
        ),
      );

      await tester.tap(find.text('Try again'));
      expect(retried, 1);
      expect(find.textContaining('took too long'), findsOneWidget);
    });

    testWidgets('OfflineBanner is a live region with the content age', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const OfflineBanner(updatedLabel: 'Updated 2 hours ago'),
      );

      expect(find.text('Updated 2 hours ago'), findsOneWidget);
      final node = tester.getSemantics(find.byType(OfflineBanner));
      expect(node.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('DealCardSkeleton announces "Loading deals" once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const DealCardSkeleton());

      expect(find.bySemanticsLabel('Loading deals'), findsOneWidget);
      handle.dispose();
    });
  });

  group('AppTabBar', () {
    testWidgets('tabs grow with the text size', (tester) async {
      double heightAt(double scale) {
        final tab = tester.widget<Tab>(find.byType(Tab).first);
        return tab.height!;
      }

      await _pump(
        tester,
        const DefaultTabController(
          length: 2,
          child: AppTabBar(labels: ['Near me', 'Online']),
        ),
      );
      final normal = heightAt(1);

      await _pump(
        tester,
        const DefaultTabController(
          length: 2,
          child: AppTabBar(labels: ['Near me', 'Online']),
        ),
        textScale: 2,
      );
      final large = heightAt(2);

      expect(normal, greaterThanOrEqualTo(48));
      expect(large, greaterThan(normal));
    });

    testWidgets('Urdu labels at 200% fit their tabs', (tester) async {
      await _pump(
        tester,
        const DefaultTabController(
          length: 2,
          child: AppTabBar(labels: ['قریب', 'آن لائن']),
        ),
        locale: AppLocales.urdu,
        textScale: 2,
      );

      for (final label in ['قریب', 'آن لائن']) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
            matchRoot: true,
          ),
        );
        expect(
          paragraph.getMaxIntrinsicHeight(double.infinity),
          lessThanOrEqualTo(paragraph.size.height + 0.5),
          reason: label,
        );
      }
    });
  });

  group('AppStepper', () {
    const steps = [
      Step(title: Text('City'), content: SizedBox.shrink(), isActive: true),
      Step(title: Text('Alerts'), content: SizedBox.shrink()),
    ];

    Color circle(WidgetTester tester, String digit) {
      final box = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text(digit),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (box.decoration! as BoxDecoration).color!;
    }

    testWidgets('active steps are Neel, the rest a container colour', (
      tester,
    ) async {
      await _pump(tester, const AppStepper(steps: steps));
      final scheme = Theme.of(tester.element(find.text('City'))).colorScheme;
      expect(circle(tester, '1'), scheme.secondary);
      expect(circle(tester, '2'), scheme.surfaceContainerHighest);
      final digit = tester.widget<Text>(find.text('2'));
      expect(digit.style!.color, scheme.onSurface);
    });

    testWidgets('the connector line runs through the circles', (tester) async {
      await _pump(
        tester,
        AppStepper(
          onStepContinue: () {},
          steps: const [
            Step(
              title: Text('City'),
              content: Text('Pick a city'),
              isActive: true,
            ),
            Step(title: Text('Alerts'), content: SizedBox.shrink()),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final circle = tester.getCenter(find.text('2')).dx;
      final lines = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .map((b) => tester.getRect(find.byWidget(b)))
          .where((r) => r.width == 1 && r.height > 20);
      expect(lines, isNotEmpty);
      for (final r in lines) {
        expect(r.center.dx, closeTo(circle, 1), reason: 'line at ${r.left}');
      }
    });

    testWidgets('step numbers follow the Urdu UI', (tester) async {
      await _pump(
        tester,
        const AppStepper(steps: steps),
        locale: AppLocales.urdu,
      );
      expect(find.text('City'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a saved DealCard toggle is Neel, never Haldi', (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => AccentPrimary(
          child: IconButton(
            isSelected: true,
            onPressed: () {},
            icon: const Icon(Icons.bookmark_border),
            selectedIcon: const Icon(Icons.bookmark),
          ),
        ),
      ),
    );
    final scheme = Theme.of(tester.element(find.byType(Scaffold))).colorScheme;
    final icon = tester.widget<IconTheme>(
      find
          .ancestor(
            of: find.byIcon(Icons.bookmark),
            matching: find.byType(IconTheme),
          )
          .first,
    );
    expect(icon.data.color, scheme.secondary);
    expect(icon.data.color, isNot(BrandColors.haldi500));
  });

  testWidgets('showAppBottomSheet shows a heading and the content', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppBottomSheet<void>(
                context: context,
                title: 'Filters',
                builder: (_) => const Text('Body'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Body'), findsOneWidget);
    final heading = tester.getSemantics(find.text('Filters'));
    expect(heading.flagsCollection.isHeader, isTrue);
    handle.dispose();
  });

  group('ContentText', () {
    test('detects the direction of the content itself', () {
      expect(ContentText.directionOf('2 for Rs 999'), TextDirection.ltr);
      expect(ContentText.directionOf('سفائر کی سیل'), TextDirection.rtl);
      expect(ContentText.directionOf('Khaadi'), TextDirection.ltr);
    });

    testWidgets('English in an Urdu screen: LTR text, aligned to the right', (
      tester,
    ) async {
      await _pump(
        tester,
        const ContentText('2 for Rs 999'),
        locale: AppLocales.urdu,
      );

      final text = tester.widget<Text>(find.text('2 for Rs 999'));
      expect(text.textDirection, TextDirection.ltr);
      expect(text.textAlign, TextAlign.right);
    });

    testWidgets('Urdu in an English screen: RTL text, aligned to the left', (
      tester,
    ) async {
      await _pump(tester, const ContentText('سفائر کی سیل'));

      final text = tester.widget<Text>(find.text('سفائر کی سیل'));
      expect(text.textDirection, TextDirection.rtl);
      expect(text.textAlign, TextAlign.left);
    });

    testWidgets('a worded offer badge keeps its own direction', (tester) async {
      await _pump(
        tester,
        const DiscountBadge(offer: TextOffer('2 for Rs 999')),
        locale: AppLocales.urdu,
      );

      expect(
        tester.widget<Text>(find.text('2 for Rs 999')).textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('badges hug their label instead of filling the row', (
      tester,
    ) async {
      await _pump(tester, const DiscountBadge(offer: PercentOff(40)));

      expect(tester.getSize(find.byType(DiscountBadge)).width, lessThan(120));
    });
  });
}
