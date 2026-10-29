import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';

class _MockConnectivity extends Mock implements Connectivity;

void main() {
  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> changes;

  setUp(() {
    connectivity = _MockConnectivity();
    changes = StreamController<List<ConnectivityResult>>();
    // close() only completes once a listener gets the done event, so don't
    // wait for it.
    addTearDown(() => unawaited(changes.close()));
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => changes.stream);
  });

  group('statusFor', () {
    test('offline only when every result is none', () {
      expect(
        ConnectivityService.statusFor([ConnectivityResult.none]),
        NetworkStatus.offline,
      );
      expect(ConnectivityService.statusFor([]), NetworkStatus.offline);
    });

    test('online for any real interface', () {
      for (final result in [
        ConnectivityResult.wifi,
        ConnectivityResult.mobile,
        ConnectivityResult.ethernet,
        ConnectivityResult.vpn,
      ]) {
        expect(ConnectivityService.statusFor([result]), NetworkStatus.online);
      }
      expect(
        ConnectivityService.statusFor([
          ConnectivityResult.none,
          ConnectivityResult.mobile,
        ]),
        NetworkStatus.online,
      );
    });
  });

  test('check() reports the current status', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    expect(
      await ConnectivityService(connectivity).check(),
      NetworkStatus.online,
    );
  });

  test('watch() emits the current status, then only real changes', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    final statuses = <NetworkStatus>[];
    final sub = ConnectivityService(connectivity).watch().listen(statuses.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    changes
      ..add([ConnectivityResult.mobile]) // still online: no event
      ..add([ConnectivityResult.none])
      ..add([ConnectivityResult.none]) // duplicate: no event
      ..add([ConnectivityResult.wifi]);
    await pumpEventQueue();

    expect(statuses, [
      NetworkStatus.online,
      NetworkStatus.offline,
      NetworkStatus.online,
    ]);
  });

  test('a change before the initial check wins over the check', () async {
    final initial = Completer<List<ConnectivityResult>>();
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) => initial.future);

    final statuses = <NetworkStatus>[];
    final sub = ConnectivityService(connectivity).watch().listen(statuses.add);
    addTearDown(sub.cancel);

    changes.add([ConnectivityResult.none]);
    await pumpEventQueue();
    initial.complete([ConnectivityResult.wifi]); // stale by now
    await pumpEventQueue();

    expect(statuses, [NetworkStatus.offline]);
  });

  test('errors from the platform are forwarded', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => throw StateError('plugin missing'));

    final errors = <Object>[];
    final sub = ConnectivityService(connectivity)
        .watch()
        .listen((_) {}, onError: errors.add);
    addTearDown(sub.cancel);
    changes.addError(StateError('stream failed'));
    await pumpEventQueue();

    expect(errors, hasLength(2));
  });

  test('cancelling watch() completes and stops listening', () async {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.wifi]);

    final sub = ConnectivityService(connectivity).watch().listen((_) {});
    await pumpEventQueue();

    await expectLater(sub.cancel(), completes);
    expect(changes.hasListener, isFalse);
  });
}
