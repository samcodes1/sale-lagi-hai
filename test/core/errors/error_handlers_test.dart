import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/errors/error_handlers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryLogSink sink;
  late AppLogger logger;

  setUp(() {
    sink = MemoryLogSink();
    logger = AppLogger(sinks: [sink]);

    // These handlers are global; restore them so other tests are unaffected.
    final flutterOnError = FlutterError.onError;
    final dispatcherOnError = PlatformDispatcher.instance.onError;
    final errorWidgetBuilder = ErrorWidget.builder;
    addTearDown(() {
      FlutterError.onError = flutterOnError;
      PlatformDispatcher.instance.onError = dispatcherOnError;
      ErrorWidget.builder = errorWidgetBuilder;
    });
  });

  test('framework errors are logged, redacted', () {
    installErrorHandlers(logger, isReleaseMode: true);

    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('bad state for 03001234567'),
        stack: StackTrace.current,
        library: 'widgets library',
      ),
    );

    final record = sink.records.single;
    expect(record.level, LogLevel.error);
    expect(record.message, 'Flutter framework error');
    expect(record.errorType, 'StateError');
    expect(record.errorText, contains('[phone]'));
    expect(record.context, {'library': 'widgets library'});
  });

  test("framework errors use Flutter's default library name", () {
    installErrorHandlers(logger, isReleaseMode: true);

    FlutterError.onError!(FlutterErrorDetails(exception: Exception('x')));

    expect(sink.records.single.context, {'library': 'Flutter framework'});
  });

  test('uncaught async errors are logged and marked handled', () {
    installErrorHandlers(logger, isReleaseMode: true);

    final handled = PlatformDispatcher.instance.onError!(
      StateError('async'),
      StackTrace.current,
    );

    expect(handled, isTrue);
    expect(sink.records.single.message, 'Uncaught error');
  });

  test('release builds replace the error widget', () {
    installErrorHandlers(logger, isReleaseMode: true);

    final widget = ErrorWidget.builder(
      FlutterErrorDetails(exception: Exception('x')),
    );

    expect(widget, isA<ReleaseErrorWidget>());
  });

  test('debug builds still log, and also present the error', () {
    final presented = <FlutterErrorDetails>[];
    final originalPresent = FlutterError.presentError;
    FlutterError.presentError = presented.add;
    addTearDown(() => FlutterError.presentError = originalPresent);
    installErrorHandlers(logger);

    final details = FlutterErrorDetails(exception: Exception('x'));
    FlutterError.onError!(details);

    expect(sink.records, hasLength(1));
    expect(presented.single, same(details));
  });

  test('debug builds keep the default error widget', () {
    final before = ErrorWidget.builder;

    installErrorHandlers(logger);

    expect(ErrorWidget.builder, same(before));
  });

  testWidgets('ReleaseErrorWidget shows no error text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ReleaseErrorWidget())),
    );

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byType(Text), findsNothing);
  });
}
