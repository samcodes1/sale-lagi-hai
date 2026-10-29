import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/links/link_service.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/presentation/sign_in_screen.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_detail_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';

import '../onboarding/onboarding_harness.dart';

final class FakeLinks implements LinkService {
  final calls = <String>[];
  bool works = true;

  @override
  Future<bool> openWeb(String url) async {
    calls.add('web $url');
    return works;
  }

  @override
  Future<bool> openMap(double latitude, double longitude, String label) async {
    calls.add('map $latitude,$longitude');
    return works;
  }

  @override
  Future<bool> shareOnWhatsApp(String text) async {
    calls.add('whatsapp $text');
    return works;
  }

  @override
  Future<bool> call(String e164) async {
    calls.add('call $e164');
    return works;
  }
}

String _deal(int n) => demoDeals.firstWhere((d) => d.n == n).id;

/// The list that scrolls (the page), not the outlets' text.
final Finder _page = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

Future<void> _reach(WidgetTester tester, Finder finder) async {
  for (var i = 0; finder.hitTestable().evaluate().isEmpty; i++) {
    if (i == 40) fail('never reached $finder');
    await tester.drag(_page.first, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
}

Future<(Harness, FakeLinks)> _open(
  WidgetTester tester,
  int deal, {
  Locale locale = AppLocales.english,
  DateTime Function()? clock,
}) async {
  final links = FakeLinks();
  final h = Harness(
    saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
    overrides: [
      linkServiceProvider.overrideWithValue(links),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
  );
  await h.pump(tester, device: locale);
  h.router.go('/deal/${_deal(deal)}');
  await tester.pumpAndSettle();
  return (h, links);
}

void main() {
  testWidgets('the page: offer, validity, verified, text, terms, outlets', (
    tester,
  ) async {
    await _open(tester, 1);
    expect(find.byType(DealDetailScreen), findsOneWidget);
    expect(find.text('Family karahi for 4'), findsOneWidget);
    expect(find.text('Karahi House (Demo)'), findsOneWidget);
    expect(find.textContaining('Verified'), findsOneWidget);
    await _reach(tester, find.text('Where to use it'));
    expect(find.text('About this deal'), findsOneWidget);
    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Karahi House (Demo) · Clifton'), findsOneWidget);
    expect(find.text('Karahi House (Demo) · Gulshan-e-Iqbal'), findsOneWidget);
  });

  testWidgets('Directions opens the map at that outlet', (tester) async {
    final (_, links) = await _open(tester, 7);
    await _reach(tester, find.text('Directions'));
    await tester.tap(find.text('Directions').hitTestable());
    await tester.pumpAndSettle();
    expect(links.calls, ['map 24.815,67.031']);
  });

  testWidgets('online deals: the promo code copies, the offer opens', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final (_, links) = await _open(tester, 5);
    expect(find.text('WINTER30'), findsOneWidget);
    await tester.tap(find.byTooltip('Copy code'));
    await tester.pumpAndSettle();
    expect(find.text('Code copied.'), findsOneWidget);
    expect(copied, 'WINTER30');
    await tester.tap(find.text('Open the offer'));
    await tester.pumpAndSettle();
    expect(links.calls.single, startsWith('web https://'));
    await _reach(tester, find.text('Where to use it'));
    expect(
      find.text("Online only: use it on the brand's website or app."),
      findsOneWidget,
    );
  });

  testWidgets('a link that fails to open says so', (tester) async {
    final (_, links) = await _open(tester, 5);
    links.works = false;
    await tester.tap(find.text('Open the offer'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open that. Try again later."), findsOneWidget);
  });

  testWidgets('save toggles, with a note each way', (tester) async {
    final (h, _) = await _open(tester, 4);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved.'), findsOneWidget);
    expect(h.container.read(savedDealsProvider), [_deal(4)]);
    await tester.tap(find.text('Remove from saved'));
    await tester.pumpAndSettle();
    expect(find.text('Removed from saved.'), findsOneWidget);
    expect(h.container.read(savedDealsProvider), isEmpty);
  });

  testWidgets('share on WhatsApp sends brand, offer, title and the link', (
    tester,
  ) async {
    final (_, links) = await _open(tester, 5);
    await tester.tap(find.text('Share on WhatsApp'));
    await tester.pumpAndSettle();
    final text = links.calls.single;
    expect(text, startsWith('whatsapp Threads (Demo): '));
    expect(text, contains('Online exclusive: flat 30% off'));
    expect(text, contains('Found on Sale Lagi Hai!'));
    expect(text, contains('https://'));
  });

  testWidgets('report as a guest: sign in first, then the reasons, then '
      'thanks; a second report is acknowledged', (tester) async {
    final (h, _) = await _open(tester, 2);
    await _reach(tester, find.text('Report a problem'));
    await tester.tap(find.text('Report a problem').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), '03001234567');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();

    expect(find.text("What's wrong with this deal?"), findsOneWidget);
    // Send stays off until a reason is picked.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('It has ended'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    expect(find.text("Thanks. We'll check it."), findsOneWidget);
    expect(h.auth.currentUser, isNotNull);

    ScaffoldMessenger.of(tester.element(find.byType(DealDetailScreen)))
        .hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await _reach(tester, find.text('Report a problem'));
    await tester.tap(find.text('Report a problem').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('The shop is closed'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    expect(
      find.text("You've already reported this deal. Thanks!"),
      findsOneWidget,
    );
  });

  testWidgets('"something else" asks for a note', (tester) async {
    final (h, _) = await _open(tester, 3);
    await h.auth.sendPhoneCode('+923001234567');
    await h.auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
    await _reach(tester, find.text('Report a problem'));
    await tester.tap(find.text('Report a problem').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Something else'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();
    expect(find.text("Please say what's wrong."), findsOneWidget);
  });

  testWidgets('an ended deal still opens, clearly marked, with no code', (
    tester,
  ) async {
    // Deal 5 ends in 120 hours; look at it 6 days later.
    await _open(
      tester,
      5,
      clock: () => DateTime.now().add(const Duration(days: 6)),
    );
    expect(find.textContaining('This deal has ended'), findsOneWidget);
    expect(find.text('WINTER30'), findsNothing);
  });

  testWidgets('an unknown deal shows a clear error, never a blank page', (
    tester,
  ) async {
    final (h, _) = await _open(tester, 1);
    h.router.go('/deal/00000000-0000-4000-8000-00000000dead');
    await tester.pumpAndSettle();
    expect(find.byType(ErrorView), findsOneWidget);
  });

  for (final locale in AppLocales.supported) {
    testWidgets('${locale.languageCode}: guidelines, and 200% text without '
        'overflow', (tester) async {
      final handle = tester.ensureSemantics();
      await _open(tester, 7, locale: locale);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      tester.view.physicalSize = const Size(360, 800) * 2;
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        expect(tester.takeException(), isNull);
        await tester.drag(_page.first, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
    });
  }
}
