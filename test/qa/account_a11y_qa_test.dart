// QA (sub-phase 4.2 gate): accessibility of the account states the
// developer's guideline tests don't reach: the code step (with its resend
// countdown and an error), the fresh sign-in before deletion, and the
// delete confirmation dialog. en + ur, light + dark, and 200% text at
// 360 × 800.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../features/onboarding/onboarding_harness.dart';

Future<Harness> _open(
  WidgetTester tester, {
  required Locale locale,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(412, 915),
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final h = Harness(saved: const ShopperPreferences(onboarded: true));
  await h.pump(tester, device: locale, size: size);
  return h;
}

/// The code step with an error showing and the countdown running.
Future<void> _codeStepWithError(WidgetTester tester, Harness h) async {
  h.router.go('/sign-in');
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '03001234567');
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '000000');
  await tester.pumpAndSettle();
}

Future<void> _deleteDialog(WidgetTester tester, Harness h) async {
  await h.auth.sendPhoneCode('+923001234567');
  await h.auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
  h.router.go('/profile/account/delete');
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}

Future<void> _reauth(WidgetTester tester, Harness h) async {
  await h.auth.sendPhoneCode('+923001234567');
  await h.auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
  h.router.go('/profile');
  await tester.pumpAndSettle();
  // ignore: unawaited_futures, the route stays open for the test
  h.router.push('/sign-in?reauth=true');
  await tester.pumpAndSettle();
}

void main() {
  final states = {
    'code step with an error': _codeStepWithError,
    'delete confirmation': _deleteDialog,
    'fresh sign-in before deletion': _reauth,
  };

  for (final (name, locale, brightness) in const [
    ('en light', AppLocales.english, Brightness.light),
    ('en dark', AppLocales.english, Brightness.dark),
    ('ur light', AppLocales.urdu, Brightness.light),
    ('ur dark', AppLocales.urdu, Brightness.dark),
  ]) {
    for (final MapEntry(key: state, value: go) in states.entries) {
      testWidgets('$name, $state: tap targets, labels and contrast', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final h = await _open(tester, locale: locale, brightness: brightness);
        await go(tester, h);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  for (final locale in AppLocales.supported) {
    for (final MapEntry(key: state, value: go) in states.entries) {
      testWidgets('200% text, 360 × 800, ${locale.languageCode}, $state: no '
          'overflow', (tester) async {
        final h = await _open(
          tester,
          locale: locale,
          textScale: 2,
          size: const Size(360, 800),
        );
        await go(tester, h);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the fresh sign-in prefills the number left to right in '
      'Urdu', (tester) async {
    final h = await _open(tester, locale: AppLocales.urdu);
    await _reauth(tester, h);
    final phone = tester.widget<TextField>(find.byType(TextField));
    expect(phone.controller?.text, '300 1234567');
    expect(phone.textDirection, TextDirection.ltr);
  });

  testWidgets("the dialog's delete action is a labelled, enabled button", (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = await _open(tester, locale: AppLocales.english);
    await _deleteDialog(tester, h);
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Delete my account'),
        ),
      ),
      matchesSemantics(
        label: 'Delete my account',
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
      ),
    );
    handle.dispose();
  });
}
