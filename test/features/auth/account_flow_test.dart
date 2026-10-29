import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/presentation/delete_account_screen.dart';
import 'package:sale_lagi_hai/features/auth/presentation/sign_in_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/data/preferences_store.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/language_step.dart';
import 'package:sale_lagi_hai/features/profile/presentation/profile_screen.dart';

import '../onboarding/onboarding_harness.dart';

final _karahiHouse = brandBySlug('demo-karahi-house')['id']! as String;

/// A shopper past onboarding, who follows a brand as a guest.
Harness _harness({DemoAuthRepository? auth, DemoGateway? backend}) => Harness(
  auth: auth,
  backend: backend,
  saved: ShopperPreferences(
    onboarded: true,
    cityId: karachiId,
    brandIds: [_karahiHouse],
  ),
);

Future<void> _openProfile(WidgetTester tester, Harness h) async {
  h.router.go('/profile');
  await tester.pumpAndSettle();
  expect(find.byType(ProfileScreen), findsOneWidget);
}

Future<void> _signInWithPhone(
  WidgetTester tester, {
  String code = DemoAuthRepository.code,
}) async {
  await tapText(tester, 'Sign in');
  expect(find.byType(SignInScreen), findsOneWidget);
  await tester.enterText(find.byType(TextField), '0300 1234567');
  await tapText(tester, 'Send code');
  expect(
    find.text('We sent a 6-digit code to +92 300 1234567.'),
    findsOneWidget,
  );
  // Six digits submit on their own.
  await tester.enterText(find.byType(TextField), code);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a guest signs in with a texted code; their choices sync', (
    tester,
  ) async {
    final backend = DemoGateway();
    final h = _harness(backend: backend);
    await h.pump(tester);
    await _openProfile(tester, h);
    expect(
      find.text('Sign in to keep your saves on any phone'),
      findsOneWidget,
    );

    await _signInWithPhone(tester);

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text("You're signed in."), findsOneWidget);
    // The number shows partly hidden.
    expect(find.text('+92 300 ••• ••67'), findsOneWidget);
    expect(find.text('Signed in with your phone'), findsOneWidget);
    // The brand followed as a guest is now followed in the account.
    final follows = await backend.select(const TableQuery('follows'));
    expect(follows.map((f) => f['brand_id']), [_karahiHouse]);
  });

  testWidgets(
    'a number that is not a Pakistani mobile is caught on the phone',
    (tester) async {
      final h = _harness();
      await h.pump(tester);
      await _openProfile(tester, h);
      await tapText(tester, 'Sign in');
      await tester.enterText(find.byType(TextField), '021 34567890');
      await tapText(tester, 'Send code');
      expect(
        find.text('Enter a Pakistani mobile number, like 0300 1234567.'),
        findsOneWidget,
      );
      expect(find.text('Enter the code'), findsNothing);
    },
  );

  testWidgets('a wrong code says so; the right one then works', (tester) async {
    final h = _harness();
    await h.pump(tester);
    await _openProfile(tester, h);
    await _signInWithPhone(tester, code: '000000');
    expect(
      find.text(
        'That code is wrong or has expired. Check it, or send a new one.',
      ),
      findsOneWidget,
    );
    expect(h.auth.currentUser, isNull);
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();
    expect(h.auth.currentUser, isNotNull);
  });

  testWidgets('a new code can be asked for after a minute', (tester) async {
    final h = _harness();
    await h.pump(tester);
    await _openProfile(tester, h);
    await tapText(tester, 'Sign in');
    await tester.enterText(find.byType(TextField), '03001234567');
    await tapText(tester, 'Send code');
    expect(find.text('Send a new code in 60 seconds'), findsOneWidget);
    expect(find.text('Send a new code'), findsNothing);
    await tester.pump(resendWait);
    await tester.pumpAndSettle();
    expect(find.text('Send a new code'), findsOneWidget);
    await tapText(tester, 'Change number');
    expect(find.text('Sign in to sync'), findsOneWidget);
  });

  testWidgets('Google: one tap signs in', (tester) async {
    final h = _harness();
    await h.pump(tester);
    await _openProfile(tester, h);
    await tapText(tester, 'Sign in');
    await tapText(tester, 'Continue with Google');
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Signed in with Google'), findsOneWidget);
  });

  testWidgets('Google is hidden when this build has no client ID', (
    tester,
  ) async {
    final h = _harness(auth: DemoAuthRepository(googleAvailable: false));
    await h.pump(tester);
    await _openProfile(tester, h);
    await tapText(tester, 'Sign in');
    expect(find.text('Continue with Google'), findsNothing);
  });

  testWidgets('signing out keeps the choices on this phone', (tester) async {
    final h = _harness();
    await h.pump(tester);
    await _openProfile(tester, h);
    await _signInWithPhone(tester);
    await tapText(tester, 'Sign out');
    expect(h.auth.currentUser, isNull);
    expect(
      find.text('Signed out. Your choices stay on this phone.'),
      findsOneWidget,
    );
    expect(h.preferences.brandIds, [_karahiHouse]);
    expect(h.preferences.onboarded, isTrue);
  });

  testWidgets('deleting the account: what goes, a confirmation, then a fresh '
      'start', (tester) async {
    final h = _harness();
    await h.pump(tester);
    await PreferencesStore(h.store).write(h.preferences);
    await _openProfile(tester, h);
    await _signInWithPhone(tester);

    await tapText(tester, 'Delete account');
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(
      find.text('Saved deals, followed brands and your cards'),
      findsOneWidget,
    );
    expect(find.textContaining('Deals you submitted stay up'), findsOneWidget);

    // Cancel in the dialog changes nothing.
    await tapText(tester, 'Delete my account');
    expect(find.text('Delete your account?'), findsOneWidget);
    await tapText(tester, 'Cancel');
    expect(h.auth.currentUser, isNotNull);

    await tapText(tester, 'Delete my account');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete my account'),
      ),
    );
    await tester.pumpAndSettle();

    expect(h.auth.currentUser, isNull);
    expect(find.text('Your account was deleted.'), findsOneWidget);
    // This phone starts fresh: onboarding, nothing remembered.
    expect(find.byType(LanguageStep), findsOneWidget);
    expect(h.store.values, isEmpty);
    expect(h.preferences, const ShopperPreferences());
  });

  testWidgets('an old sign-in is confirmed again before deleting', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 29, 12);
    final h = _harness(auth: DemoAuthRepository(clock: () => now));
    await h.pump(tester);
    await _openProfile(tester, h);
    await _signInWithPhone(tester);
    now = now.add(const Duration(minutes: 10));

    await tapText(tester, 'Delete account');
    await tapText(tester, 'Delete my account');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete my account'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Confirm it's you"), findsOneWidget);
    // Phone users get their number filled in.
    expect(find.text('300 1234567'), findsOneWidget);
    await tapText(tester, 'Send code');
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();

    expect(h.auth.currentUser, isNull);
    expect(find.byType(LanguageStep), findsOneWidget);
  });

  testWidgets('guests cannot open the delete page', (tester) async {
    final h = _harness();
    await h.pump(tester);
    h.router.go('/profile/account/delete');
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
  });
}
