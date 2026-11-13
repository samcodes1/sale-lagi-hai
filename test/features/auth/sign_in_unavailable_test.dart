import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../onboarding/onboarding_harness.dart';

/// A build with no way to sign in (PHONE_SIGN_IN=false, no Google client):
/// the app works as a guest and never offers a "Sign in" that can't work.
Future<Harness> _open(WidgetTester tester, String location) async {
  final h = Harness(
    saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
    overrides: [signInAvailableProvider.overrideWithValue(false)],
  );
  await h.pump(tester);
  h.router.go(location);
  await tester.pumpAndSettle();
  return h;
}

final Finder _comingSoon = find.textContaining('Alerts are coming');

void main() {
  testWidgets('Profile has no account card, the rest stays', (tester) async {
    await _open(tester, '/profile');
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Account'), findsNothing);
    expect(find.text('My cards'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Alerts says they are coming, with no Sign in', (tester) async {
    await _open(tester, '/alerts');
    expect(_comingSoon, findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('notification settings say the same', (tester) async {
    await _open(tester, '/settings/notifications');
    expect(_comingSoon, findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('a deal has no "Report a problem" (it needs an account)', (
    tester,
  ) async {
    final id = demoDeals.firstWhere((d) => d.n == 2).id;
    await _open(tester, '/deal/$id');
    expect(find.byType(DealDetailScreen), findsOneWidget);
    final page = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    for (var i = 0; find.text('Where to use it').evaluate().isEmpty; i++) {
      if (i == 40) fail('never reached the end of the deal');
      await tester.drag(page.first, const Offset(0, -250));
      await tester.pumpAndSettle();
    }
    // The button sat in the same column as "Where to use it".
    expect(find.text('Report a problem'), findsNothing);
  });
}
