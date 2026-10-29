import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../onboarding/onboarding_harness.dart';

Future<Harness> _open(
  WidgetTester tester,
  String location, {
  Locale locale = AppLocales.english,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(412, 915),
  bool signedIn = false,
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final h = Harness(saved: const ShopperPreferences(onboarded: true));
  await h.pump(tester, device: locale, size: size);
  if (signedIn) {
    await h.auth.sendPhoneCode('+923001234567');
    await h.auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
  }
  h.router.go(location);
  await tester.pumpAndSettle();
  return h;
}

const _pages = [
  ('/profile', false),
  ('/profile', true),
  ('/sign-in', false),
  ('/profile/account/delete', true),
];

void main() {
  for (final (name, locale, brightness) in const [
    ('en light', AppLocales.english, Brightness.light),
    ('ur dark', AppLocales.urdu, Brightness.dark),
  ]) {
    for (final (page, signedIn) in _pages) {
      testWidgets('$name $page${signedIn ? ' (signed in)' : ''} meets the '
          'tap-target, label and contrast guidelines', (tester) async {
        final handle = tester.ensureSemantics();
        await _open(
          tester,
          page,
          locale: locale,
          brightness: brightness,
          signedIn: signedIn,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  for (final locale in AppLocales.supported) {
    for (final (page, signedIn) in _pages) {
      testWidgets('200% text, 360 × 800, ${locale.languageCode} $page: no '
          'overflow', (tester) async {
        await _open(
          tester,
          page,
          locale: locale,
          textScale: 2,
          size: const Size(360, 800),
          signedIn: signedIn,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the code step at 200% Urdu, with an error, still fits', (
    tester,
  ) async {
    await _open(
      tester,
      '/sign-in',
      locale: AppLocales.urdu,
      textScale: 2,
      size: const Size(360, 800),
    );
    await tester.enterText(find.byType(TextField), '03001234567');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('کوڈ غلط'), findsOneWidget);
  });

  testWidgets('phone and code fields read left to right in Urdu, and the '
      'code field never suggests or learns', (tester) async {
    await _open(tester, '/sign-in', locale: AppLocales.urdu);
    final phone = tester.widget<TextField>(find.byType(TextField));
    expect(phone.textDirection, TextDirection.ltr);
    expect(phone.keyboardType, TextInputType.phone);
    await tester.enterText(find.byType(TextField), '03001234567');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    final code = tester.widget<TextField>(find.byType(TextField));
    expect(code.textDirection, TextDirection.ltr);
    expect(code.autofillHints, [AutofillHints.oneTimeCode]);
    expect(code.enableSuggestions, isFalse);
    expect(code.autocorrect, isFalse);
  });
}
