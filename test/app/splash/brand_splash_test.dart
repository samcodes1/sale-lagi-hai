import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/splash/brand_splash.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

void main() {
  const app = Directionality(
    textDirection: TextDirection.ltr,
    child: Text('the app'),
  );

  Finder splash() => find.byWidgetPredicate(
    (w) => w is ColoredBox && w.color == BrandColors.mirch500,
  );

  testWidgets('covers the app, then leaves it alone', (tester) async {
    await tester.pumpWidget(const BrandSplash(child: app));
    expect(splash(), findsOneWidget);
    // The app is already building underneath.
    expect(find.text('the app'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800));
    expect(splash(), findsOneWidget);

    await tester.pumpAndSettle();
    expect(splash(), findsNothing);
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('blocks taps while it shows', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      BrandSplash(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.tapAt(const Offset(10, 10));
    expect(taps, 0);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    expect(taps, 1);
  });

  testWidgets('is shorter with reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(const BrandSplash(child: app));
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(splash(), findsNothing);
  });

  testWidgets('leaves nothing running when closed early', (tester) async {
    await tester.pumpWidget(const BrandSplash(child: app));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
