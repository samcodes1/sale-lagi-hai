// QA (sub-phase 1.1): accessibility guidelines and 200% text scale for the
// two screens that exist so far (placeholder App and ConfigErrorApp).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';

const _config = AppConfig(
  flavor: Flavor.dev,
  appName: 'SLH Dev',
  supabaseUrl: '',
  supabasePublishableKey: '',
);

Widget _app() => ProviderScope(
  overrides: [appConfigProvider.overrideWithValue(_config)],
  child: const App(),
);

final List<String> _manyProblems = [
  for (var i = 0; i < 30; i++)
    'Problem $i: SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be set '
        'together.',
];

void main() {
  for (final entry in {
    'App': _app,
    'ConfigErrorApp': () => ConfigErrorApp(problems: _manyProblems),
  }.entries) {
    testWidgets('${entry.key} meets a11y guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(entry.value());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('${entry.key} has no overflow at 200% text on 360x800', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(entry.value());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ConfigErrorApp scrolls to the last problem', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ConfigErrorApp(problems: _manyProblems));
    final last = find.textContaining('Problem 29:');
    await tester.scrollUntilVisible(last, 200);
    expect(last, findsOneWidget);
  });
}
