// QA, Phase 4 gate: the accessibility audit across every Phase 4 screen
// (4.1–4.9), through the real router, in English and Urdu, light and dark,
// at 100% and 200% text on a 360×800 phone. Per screen:
// - androidTapTargetGuideline, labeledTapTargetGuideline and
//   textContrastGuideline;
// - no layout exception (overflow);
// - at least one heading for screen readers on content screens;
// - the reading order: the screen's content before the bottom navigation.
//
// Screens are visited both as a guest and signed in with data (saves, a
// card, follows, alerts), so empty and filled states are both covered.
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/features/cards/application/my_cards_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';

import 'phase4_harness.dart';

const _onboarded = ShopperPreferences(onboarded: true, cityId: karachiId);

/// Screens reached as a signed-in shopper with data.
final _signedIn = [
  '/',
  '/explore',
  '/alerts',
  '/saved',
  '/profile',
  '/deal/${dealId(1)}',
  '/deal/${dealId(7)}',
  '/brand/demo-threads',
  '/category/food-and-restaurants',
  '/search',
  '/search?q=burger',
  '/cards',
  '/following',
  '/settings',
  '/settings/notifications',
  '/settings/privacy',
  '/settings/legal/terms',
  '/settings/about',
  '/profile/account/delete',
];

/// Screens with a guest's (empty) state.
const _guest = [
  '/alerts',
  '/saved',
  '/profile',
  '/cards',
  '/following',
  '/settings/notifications',
  '/sign-in',
];

const _welcome = [
  '/welcome',
  '/welcome/city',
  '/welcome/interests',
  '/welcome/brands',
  '/welcome/alerts',
];

/// Pages that are lists of choices or forms, where the app bar title is
/// the only heading that would make sense (checked separately).
const _noHeadingNeeded = {'/sign-in', '/search', '/settings/about'};

Future<List<String>> _audit(
  WidgetTester tester,
  Journey j,
  List<String> locations, {
  required String mode,
}) async {
  final problems = <String>[];
  for (final location in locations) {
    j.router.go(location);
    // The legal texts are bundled assets: real file I/O, outside fake time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    // pumpAndSettle throws a FlutterError when it times out: record it.
    final settled = await tester.pumpAndSettle().then(
      (_) => true,
      onError: (Object _) => false,
    );
    if (!settled) {
      problems.add('$mode $location: never settles (a running animation)');
      continue;
    }
    final error = tester.takeException();
    if (error != null) problems.add('$mode $location: exception $error');
    for (final (name, guideline) in [
      ('tap target', androidTapTargetGuideline),
      ('label', labeledTapTargetGuideline),
      ('contrast', textContrastGuideline),
    ]) {
      var result = await guideline.evaluate(tester);
      if (!result.passed && name == 'contrast') {
        // textContrastGuideline samples a node's whole rect, so text that
        // runs on below a pinned bottom button is measured against the
        // button (a false 1.5:1 on the onboarding steps at 360dp/200%).
        // Measure again with the text scrolled into view.
        final scrollable = find.byType(Scrollable).hitTestable();
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -3000));
          await tester.pumpAndSettle();
          result = await guideline.evaluate(tester);
        }
      }
      if (!result.passed) {
        problems.add(
          '$mode $location: $name: '
          '${result.reason?.split('\n').take(3).join(' | ')}',
        );
      }
    }
    if (!_noHeadingNeeded.contains(location)) {
      final headers = find.semantics.byPredicate(
        (node) => node.flagsCollection.isHeader,
      );
      if (headers.evaluate().isEmpty) {
        problems.add('$mode $location: no heading');
      }
    }
  }
  return problems;
}

void main() {
  // rootBundle caches loadString futures; one made in an earlier test's
  // fake-async zone never completes in the next test.
  setUp(rootBundle.clear);

  for (final locale in AppLocales.supported) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        final percent = (scale * 100).round();
        final mode = '${locale.languageCode} ${brightness.name} $percent%';
        testWidgets('$mode: every Phase 4 screen passes the audit', (
          tester,
        ) async {
          final handle = tester.ensureSemantics();
          final problems = <String>[];

          // Onboarding, on a first launch.
          final first = Journey();
          await first.pump(
            tester,
            device: locale,
            size: const Size(360, 800),
            textScale: scale,
            platformBrightness: brightness,
          );
          first.container.read(languageChosenProvider.notifier).confirm();
          problems.addAll(
            await _audit(tester, first, _welcome, mode: '$mode first'),
          );
          await tester.pumpWidget(const SizedBox());

          // A guest past onboarding.
          final guest = Journey(saved: _onboarded);
          await guest.pump(
            tester,
            device: locale,
            size: const Size(360, 800),
            textScale: scale,
            platformBrightness: brightness,
          );
          problems.addAll(
            await _audit(tester, guest, _guest, mode: '$mode guest'),
          );
          await tester.pumpWidget(const SizedBox());

          // Signed in, with data everywhere.
          final j = Journey(
            saved: _onboarded.copyWith(
              brandIds: [brandBySlug('demo-threads')['id']! as String],
            ),
          );
          await j.pump(
            tester,
            device: locale,
            size: const Size(360, 800),
            textScale: scale,
            platformBrightness: brightness,
          );
          await j.auth.signInWithGoogle();
          final uid = j.auth.currentUser!.id;
          j.server
            ..addAlert(uid, 1)
            ..addAlert(uid, 9, minutesAgo: 60 * 30);
          await j.container.read(savedDealsProvider.notifier).toggle(dealId(4));
          await j.container
              .read(myCardsProvider.notifier)
              .add(demoCardProducts.first['id']! as String);
          await tester.pumpAndSettle();
          problems.addAll(
            await _audit(tester, j, _signedIn, mode: '$mode signed in'),
          );
          handle.dispose();
          expect(problems, isEmpty, reason: problems.join('\n'));
        });
      }
    }
  }

  testWidgets('reading order: content before the bottom navigation, in '
      'English and Urdu', (tester) async {
    final handle = tester.ensureSemantics();
    for (final locale in AppLocales.supported) {
      final j = Journey(saved: _onboarded);
      await j.pump(tester, device: locale, size: const Size(360, 800));
      for (final location in ['/', '/explore', '/saved', '/profile']) {
        j.router.go(location);
        await tester.pumpAndSettle();
        final order = <String>[];
        void visit(SemanticsNode node) {
          final label = node.label;
          if (label.isNotEmpty) order.add(label);
          node
              .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
              .forEach(visit);
        }

        visit(
          tester
              .binding
              .renderViews
              .first
              .owner!
              .semanticsOwner!
              .rootSemanticsNode!,
        );
        final nav = order.indexWhere(
          (l) => l.contains(locale == AppLocales.urdu ? 'ہوم' : 'Home'),
        );
        expect(nav, greaterThan(0), reason: '$location ${locale.languageCode}');
        // Something of the screen is read before the tabs.
        expect(
          order.take(nav),
          isNotEmpty,
          reason: '$location ${locale.languageCode}: $order',
        );
      }
      await tester.pumpWidget(const SizedBox());
    }
    handle.dispose();
  });
}
