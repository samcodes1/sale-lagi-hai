// QA (sub-phase 1.2): ConnectivityService.watch() races and cancellation.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';

class _MockConnectivity extends Mock implements Connectivity;

void main() {
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> changes;
  late Completer<List<ConnectivityResult>> initial;

  setUp(() {
    connectivity = _MockConnectivity();
    changes = StreamController<List<ConnectivityResult>>();
    initial = Completer<List<ConnectivityResult>>();
    addTearDown(() => unawaited(changes.close()));
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => changes.stream);
    when(connectivity.checkConnectivity).thenAnswer((_) => initial.future);
  });

  test(
    'an initial check that finishes after cancel is dropped quietly',
    () async {
      // Any uncaught error (e.g. "add after close") would fail this test.
      final statuses = <NetworkStatus>[];
      final sub = ConnectivityService(connectivity)
          .watch()
          .listen(statuses.add);
      await pumpEventQueue();
      await sub.cancel();

      initial.complete([ConnectivityResult.wifi]);
      await pumpEventQueue();

      expect(statuses, isEmpty);
    },
  );

  test('an initial check that fails after cancel is dropped quietly', () async {
    final errors = <Object>[];
    final sub = ConnectivityService(connectivity)
        .watch()
        .listen((_) {}, onError: errors.add);
    await pumpEventQueue();
    await sub.cancel();

    initial.completeError(StateError('plugin gone'));
    await pumpEventQueue();

    expect(errors, isEmpty);
  });

  test('a first change equal to the initial check emits once', () async {
    final statuses = <NetworkStatus>[];
    final sub = ConnectivityService(connectivity).watch().listen(statuses.add);
    addTearDown(sub.cancel);

    initial.complete([ConnectivityResult.mobile]);
    await pumpEventQueue();
    // connectivity_plus on Android also emits the current state on listen.
    changes.add([ConnectivityResult.wifi]);
    await pumpEventQueue();

    expect(statuses, [NetworkStatus.online]);
  });

  test(
    'an error does not end the stream; later changes still arrive',
    () async {
      initial.complete([ConnectivityResult.none]);
      final statuses = <NetworkStatus>[];
      final errors = <Object>[];
      final sub = ConnectivityService(connectivity)
          .watch()
          .listen(statuses.add, onError: errors.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      changes
        ..addError(StateError('glitch'))
        ..add([ConnectivityResult.wifi]);
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect(statuses, [NetworkStatus.offline, NetworkStatus.online]);
    },
  );

  test('each watch() is independent (one platform listener each)', () async {
    final broadcast = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(broadcast.close);
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => broadcast.stream);
    initial.complete([ConnectivityResult.wifi]);
    final service = ConnectivityService(connectivity);

    final a = <NetworkStatus>[];
    final b = <NetworkStatus>[];
    final subA = service.watch().listen(a.add);
    final subB = service.watch().listen(b.add);
    await pumpEventQueue();
    await subA.cancel();
    broadcast.add([ConnectivityResult.none]);
    await pumpEventQueue();
    await subB.cancel();

    expect(a, [NetworkStatus.online]);
    expect(b, [NetworkStatus.online, NetworkStatus.offline]);
    expect(broadcast.hasListener, isFalse);
  });

  test('a watch() stream is single-subscription', () {
    final stream = ConnectivityService(connectivity).watch();
    final sub = stream.listen((_) {});
    addTearDown(sub.cancel);

    expect(() => stream.listen((_) {}), throwsStateError);
  });
}
