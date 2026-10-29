import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, offline }

/// Reports whether the device has a network connection.
///
/// "Online" means a network interface (Wi-Fi, mobile data, Ethernet, VPN)
/// is up, not that the internet is reachable: a captive portal or a dead
/// mobile connection still counts as online. Requests must therefore still
/// handle `OfflineFailure` and `TimeoutFailure`; this is for UI hints such as
/// the offline banner.
final class ConnectivityService {
  new([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<NetworkStatus> check() async =>
      statusFor(await _connectivity.checkConnectivity());

  /// Emits the current status first, then every change.
  ///
  /// Built on a [StreamController] rather than `async*`: cancelling an
  /// `async*` stream that is suspended in `await for` never completes, which
  /// would leak the platform subscription when the provider is disposed.
  Stream<NetworkStatus> watch() {
    StreamSubscription<List<ConnectivityResult>>? changes;
    NetworkStatus? last;
    late final StreamController<NetworkStatus> controller;

    void emit(NetworkStatus status) {
      if (status == last || controller.isClosed) return;
      last = status;
      controller.add(status);
    }

    controller = StreamController<NetworkStatus>(
      onListen: () {
        changes = _connectivity.onConnectivityChanged.listen(
          (results) => emit(statusFor(results)),
          onError: controller.addError,
        );
        // A change that arrives first is newer than this initial check.
        unawaited(
          check().then((status) {
            if (last == null) emit(status);
          }, onError: controller.addError),
        );
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  static NetworkStatus statusFor(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none)
      ? NetworkStatus.online
      : NetworkStatus.offline;
}
