import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/onboarding_scaffold.dart';

import 'onboarding_harness.dart';

/// Every step, with some choices made, so selected states are checked too.
const _steps = [
  '/welcome',
  '/welcome/city',
  '/welcome/interests',
  '/welcome/brands',
  '/welcome/alerts',
];

Future<Harness> _open(
  WidgetTester tester,
  String location, {
  Locale locale = AppLocales.english,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(412, 915),
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final h = Harness();
  await h.pump(tester, device: locale, size: size);
  final preferences = h.container.read(preferencesProvider.notifier);
  await preferences.toggleInterest(
    (await h.container.read(interestsProvider.future)).first.id,
  );
  h.router.go(location);
  await tester.pumpAndSettle();
  return h;
}

void main() {
  for (final (name, locale, brightness) in const [
    ('en light', AppLocales.english, Brightness.light),
    ('ur dark', AppLocales.urdu, Brightness.dark),
  ]) {
    group(name, () {
      for (final step in _steps) {
        testWidgets('$step meets the tap-target, label and contrast '
            'guidelines', (tester) async {
          final handle = tester.ensureSemantics();
          await _open(tester, step, locale: locale, brightness: brightness);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    });
  }

  group('200% text on a 360 × 800 phone', () {
    for (final locale in AppLocales.supported) {
      for (final step in _steps) {
        testWidgets('$step (${locale.languageCode}) lays out without '
            'overflow, and the actions stay reachable', (tester) async {
          await _open(
            tester,
            step,
            locale: locale,
            textScale: 2,
            size: const Size(360, 800),
          );
          expect(tester.takeException(), isNull);
          final primary = find.byType(FilledButton);
          expect(primary, findsOneWidget);
          expect(tester.getRect(primary).bottom, lessThanOrEqualTo(800));
        });
      }
    }
  });

  testWidgets('Urdu mirrors the steps: Skip sits on the left', (tester) async {
    await _open(tester, '/welcome/city', locale: AppLocales.urdu);
    expect(
      Directionality.of(tester.element(find.byType(OnboardingScaffold))),
      TextDirection.rtl,
    );
    final skip = tester.getCenter(find.text('چھوڑیں'));
    expect(skip.dx, lessThan(412 / 2));
  });

  testWidgets('progress is announced as "Step n of 5"', (tester) async {
    final handle = tester.ensureSemantics();
    for (final (i, step) in _steps.indexed) {
      await _open(tester, step);
      expect(find.bySemanticsLabel('Step ${i + 1} of 5'), findsOneWidget);
    }
    handle.dispose();
  });

  testWidgets('headings are marked for screen-reader navigation', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _open(tester, '/welcome/interests');
    expect(
      tester.getSemantics(find.text('What are you into?')),
      isSemantics(label: 'What are you into?', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('choices read as selected or toggled', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await _open(tester, '/welcome/brands');
    await tester.tap(find.text('Karahi House (Demo)'));
    await tester.pumpAndSettle();
    expect(h.preferences.brandIds, hasLength(1));
    expect(
      tester.getSemantics(find.text('Karahi House (Demo)')),
      isSemantics(
        label: 'Karahi House (Demo)',
        hasTapAction: true,
        hasToggledState: true,
        isToggled: true,
      ),
    );

    h.router.go('/welcome');
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('English')),
      isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
    handle.dispose();
  });

  testWidgets('the example alert reads as one sentence', (tester) async {
    final handle = tester.ensureSemantics();
    await _open(tester, '/welcome/alerts');
    expect(
      find.bySemanticsLabel(
        'Example alert: Threads: up to 50% off. '
        'Winter collection sale, ends Sunday',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });
}
