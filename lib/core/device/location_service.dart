import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:meta/meta.dart';

/// The result of asking for the phone's approximate location.
sealed class LocationOutcome {
  const new();
}

final class Located extends LocationOutcome {
  const new(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  // Never print coordinates, even in debug logs.
  @override
  String toString() => 'Located(…)';
}

/// The shopper said no. [permanently]: Android won't ask again, so the app
/// offers the settings page instead.
final class LocationDenied extends LocationOutcome {
  const new({this.permanently = false});

  final bool permanently;
}

/// Location is switched off on the phone.
final class LocationServiceOff extends LocationOutcome {
  const new();
}

/// No location this time: no plugin on this platform, a timeout, or an
/// error. The shopper picks a city instead.
final class LocationUnavailable extends LocationOutcome {
  const new();
}

/// Approximate location for "Detect my city" and "Near me". Asked only when
/// the shopper taps a button that needs it, never at launch, and only
/// coarse (the app declares ACCESS_COARSE_LOCATION alone). Coordinates are
/// used for the one lookup and never stored or logged.
abstract interface class LocationService {
  Future<LocationOutcome> approximateLocation();

  /// Opens the app's system settings (after a permanent denial).
  Future<bool> openAppSettings();
}

final class GeolocatorLocationService implements LocationService {
  new({
    GeolocatorPlatform? platform,
    this.timeLimit = const Duration(seconds: 15),
  }) : _platform = platform ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _platform;

  @visibleForTesting
  final Duration timeLimit;

  @override
  Future<LocationOutcome> approximateLocation() async {
    try {
      if (!await _platform.isLocationServiceEnabled()) {
        return const LocationServiceOff();
      }
      var permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _platform.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          return const LocationDenied();
        case LocationPermission.deniedForever:
          return const LocationDenied(permanently: true);
        case LocationPermission.unableToDetermine:
          return const LocationUnavailable();
        case LocationPermission.whileInUse || LocationPermission.always:
          break;
      }
      final position = await _platform.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: timeLimit,
        ),
      );
      return Located(position.latitude, position.longitude);
    } on PermissionDeniedException {
      return const LocationDenied();
    } on LocationServiceDisabledException {
      return const LocationServiceOff();
    } on TimeoutException {
      return const LocationUnavailable();
    } on MissingPluginException {
      return const LocationUnavailable();
    } on PlatformException {
      return const LocationUnavailable();
    } on Object {
      // geolocator's own errors (PositionUpdateException,
      // ActivityMissingException, PermissionRequestInProgressException…):
      // the shopper picks a city instead (QA 4.1 BUG-2).
      return const LocationUnavailable();
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await _platform.openAppSettings();
    } on Object {
      return false;
    }
  }
}
