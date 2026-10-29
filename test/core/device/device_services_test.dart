import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/device/notification_permission.dart';

/// A scripted location platform.
final class _FakeGeolocator extends Fake implements GeolocatorPlatform {
  new({
    this.serviceOn = true,
    this.permission = LocationPermission.whileInUse,
    this.afterRequest,
    this.position,
    this.error,
  });

  final bool serviceOn;
  final LocationPermission permission;
  final LocationPermission? afterRequest;
  final Position? position;
  final Object? error;
  int requests = 0;
  LocationSettings? settings;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceOn;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return afterRequest ?? permission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    settings = locationSettings;
    if (error case final e?) Error.throwWithStackTrace(e, StackTrace.current);
    return position!;
  }

  @override
  Future<bool> openAppSettings() async => throw MissingPluginException();
}

Position _at(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.utc(2026),
  accuracy: 2000,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GeolocatorLocationService', () {
    Future<LocationOutcome> locate(_FakeGeolocator platform) =>
        GeolocatorLocationService(platform: platform).approximateLocation();

    test(
      'granted: an approximate fix, low accuracy with a time limit',
      () async {
        final platform = _FakeGeolocator(position: _at(24.86, 67));
        final outcome = await locate(platform);
        expect(outcome, isA<Located>());
        expect((outcome as Located).latitude, 24.86);
        expect(platform.settings?.accuracy, LocationAccuracy.low);
        expect(platform.settings?.timeLimit, isNotNull);
        expect(platform.requests, 0, reason: 'already granted: no dialog');
      },
    );

    test('never prints coordinates', () {
      expect(const Located(24.86, 67).toString(), isNot(contains('24')));
    });

    test('asks once when not yet decided', () async {
      final platform = _FakeGeolocator(
        permission: LocationPermission.denied,
        afterRequest: LocationPermission.whileInUse,
        position: _at(31.5, 74.3),
      );
      expect(await locate(platform), isA<Located>());
      expect(platform.requests, 1);
    });

    test('denied, denied for good, service off, undetermined', () async {
      final denied = await locate(
        _FakeGeolocator(permission: LocationPermission.denied),
      );
      expect(denied, isA<LocationDenied>());
      expect((denied as LocationDenied).permanently, isFalse);

      final forever = await locate(
        _FakeGeolocator(permission: LocationPermission.deniedForever),
      );
      expect((forever as LocationDenied).permanently, isTrue);

      expect(
        await locate(_FakeGeolocator(serviceOn: false)),
        isA<LocationServiceOff>(),
      );
      expect(
        await locate(
          _FakeGeolocator(permission: LocationPermission.unableToDetermine),
        ),
        isA<LocationUnavailable>(),
      );
    });

    test('platform errors become outcomes, never exceptions', () async {
      for (final (error, type) in [
        (TimeoutException('slow'), LocationUnavailable),
        (MissingPluginException(), LocationUnavailable),
        (PlatformException(code: 'x'), LocationUnavailable),
        (const PermissionDeniedException('no'), LocationDenied),
        (const LocationServiceDisabledException(), LocationServiceOff),
      ]) {
        final outcome = await locate(_FakeGeolocator(error: error));
        expect(outcome.runtimeType, type, reason: '$error');
      }
    });

    test('settings: no plugin is false, not a crash', () async {
      expect(
        await GeolocatorLocationService(platform: _FakeGeolocator())
            .openAppSettings(),
        isFalse,
      );
    });
  });

  group('PlatformNotificationPermission', () {
    test(
      'without a plugin (web, tests) it is unavailable, never a crash',
      () async {
        const permission = PlatformNotificationPermission();
        expect(await permission.status(), AlertPermission.unavailable);
        expect(await permission.request(), AlertPermission.unavailable);
        expect(await permission.openSettings(), isFalse);
      },
    );
  });
}
