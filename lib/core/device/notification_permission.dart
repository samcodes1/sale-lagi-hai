import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Whether the app may show notifications.
enum AlertPermission {
  granted,
  denied,

  /// Android won't show the dialog again: only the settings page can turn
  /// notifications on.
  permanentlyDenied,

  /// This platform can't tell (or has no plugin).
  unavailable,
}

/// The notification permission (Android 13+ POST_NOTIFICATIONS). The
/// system dialog is requested only from the priming screen's "Turn on
/// alerts" button, never at launch, and never again in a loop.
abstract interface class NotificationPermissionService {
  Future<AlertPermission> status();

  /// Shows the system dialog (if Android still allows it).
  Future<AlertPermission> request();

  /// Opens the app's system settings.
  Future<bool> openSettings();
}

final class PlatformNotificationPermission
    implements NotificationPermissionService {
  const new();

  static AlertPermission _map(ph.PermissionStatus status) => switch (status) {
    ph.PermissionStatus.granted ||
    ph.PermissionStatus.limited ||
    ph.PermissionStatus.provisional => AlertPermission.granted,
    ph.PermissionStatus.permanentlyDenied ||
    ph.PermissionStatus.restricted => AlertPermission.permanentlyDenied,
    ph.PermissionStatus.denied => AlertPermission.denied,
  };

  static Future<AlertPermission> _guard(
    Future<ph.PermissionStatus> Function() call,
  ) async {
    try {
      return _map(await call());
    } on MissingPluginException {
      return AlertPermission.unavailable;
    } on PlatformException {
      return AlertPermission.unavailable;
    }
  }

  @override
  Future<AlertPermission> status() =>
      _guard(() => ph.Permission.notification.status);

  @override
  Future<AlertPermission> request() =>
      _guard(() => ph.Permission.notification.request());

  @override
  Future<bool> openSettings() async {
    try {
      return await ph.openAppSettings();
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
