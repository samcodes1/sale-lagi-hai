// QA (sub-phase 1.1): bootstrap.dart and main.dart were not imported by any
// test, so they were missing from coverage. These tests cover both paths.
//
// Without defines (plain `flutter test`, as CI runs it) the config error path
// runs. Run with `--dart-define-from-file=env/dev.json` to exercise the
// success path as well.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/bootstrap.dart';
import 'package:sale_lagi_hai/main.dart' as entrypoint;

const _flavor = String.fromEnvironment('FLAVOR');
const _appName = String.fromEnvironment('APP_NAME');
const _noDefines = _flavor == '';

/// True when run as `flutter test --flavor <x>` with a config for another
/// flavor (BUG-4 re-test), e.g.
/// `flutter test --flavor prod --dart-define-from-file=env/dev.json`.
const bool _flavorMismatch =
    !_noDefines && appFlavor != null && appFlavor != _flavor;

void main() {
  group('bootstrap() without compiled-in config', () {
    testWidgets('shows ConfigErrorApp instead of the app', (tester) async {
      await bootstrap();
      await tester.pump();

      expect(find.byType(ConfigErrorApp), findsOneWidget);
      expect(find.byType(App), findsNothing);
      expect(find.text('App configuration error'), findsOneWidget);
      expect(find.textContaining('FLAVOR is missing'), findsOneWidget);
      expect(find.textContaining('APP_NAME is missing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, skip: !_noDefines);

    testWidgets('main() goes through the same path', (tester) async {
      await entrypoint.main();
      await tester.pump();

      expect(find.byType(ConfigErrorApp), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, skip: !_noDefines);
  });

  group('bootstrap() with compiled-in config', () {
    testWidgets('boots App with the configured name', (tester) async {
      // Since 1.2, bootstrap() installs global error handlers. The test
      // framework requires FlutterError.onError to be restored before the
      // test ends, so restore all of them in `finally`.
      final flutterOnError = FlutterError.onError;
      final dispatcherOnError = tester.binding.platformDispatcher.onError;
      try {
        await bootstrap();
        await tester.pump();

        expect(find.byType(App), findsOneWidget);
        expect(find.byType(ConfigErrorApp), findsNothing);
        expect(find.text(_appName), findsOneWidget);
        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(app.title, _appName);
        expect(FlutterError.onError, isNot(same(flutterOnError)));
      } finally {
        FlutterError.onError = flutterOnError;
        tester.binding.platformDispatcher.onError = dispatcherOnError;
      }
    }, skip: _noDefines || _flavorMismatch);

    testWidgets('a --flavor / FLAVOR mismatch shows ConfigErrorApp', (
      tester,
    ) async {
      await bootstrap();
      await tester.pump();

      expect(find.byType(App), findsNothing);
      expect(find.byType(ConfigErrorApp), findsOneWidget);
      expect(
        find.textContaining('Built with --flavor $appFlavor'),
        findsOneWidget,
      );
    }, skip: !_flavorMismatch);
  });
}
