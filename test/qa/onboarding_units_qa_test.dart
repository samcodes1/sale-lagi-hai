// QA, sub-phase 4.1: unit gaps in the catalog domain (value equality, used
// by Riverpod selectors and `contains`), the notification-permission
// mapping, and the nearest-city edge cases.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/device/notification_permission.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';

City _city(String id, double lat, double lng, {bool live = true}) => City(
  id: id,
  slug: id,
  nameEn: id,
  nameUr: id,
  isLive: live,
  latitude: lat,
  longitude: lng,
);

/// permission_handler's method channel, answered with a status code
/// (0 denied, 1 granted, 2 restricted, 3 limited, 4 permanently denied,
/// 5 provisional), or a `PlatformException` when `error` is set.
const _channel = MethodChannel('flutter.baseflow.com/permissions/methods');

void _answer(int status, {bool error = false, void Function()? onSettings}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
        if (error) throw PlatformException(code: 'already_running');
        if (call.method == 'openAppSettings') onSettings?.call();
        return switch (call.method) {
          'checkPermissionStatus' => status,
          'requestPermissions' => {17: status},
          'openAppSettings' => true,
          _ => null,
        };
      });
}

void main() {
  group('catalog values compare by id', () {
    test('City', () {
      final a = _city('karachi', 24.86, 67);
      final b = _city('karachi', 0, 0, live: false);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(_city('lahore', 24.86, 67)));
      expect(a.name(urdu: true), 'karachi');
    });

    test('Category and Brand', () {
      const food = Category(
        id: 'c1',
        slug: 'food',
        nameEn: 'Food',
        nameUr: 'کھانا',
        icon: 'restaurant',
      );
      const food2 = Category(
        id: 'c1',
        slug: 'x',
        nameEn: 'x',
        nameUr: 'x',
        icon: 'x',
        parentId: 'p',
      );
      expect(food, food2);
      expect(food.hashCode, food2.hashCode);
      expect(food.isTopLevel, isTrue);
      expect(food2.isTopLevel, isFalse);
      expect(food.name(urdu: true), 'کھانا');

      const b1 = Brand(
        id: 'b1',
        slug: 'khaadi',
        name: 'Khaadi',
        categoryId: 'c1',
      );
      const b2 = Brand(
        id: 'b1',
        slug: 'k',
        name: 'K',
        categoryId: 'c2',
        nameUr: 'کھاڈی',
      );
      expect(b1, b2);
      expect(b1.hashCode, b2.hashCode);
      expect(b1.displayName(urdu: true), 'Khaadi', reason: 'falls back');
      expect(b2.displayName(urdu: true), 'کھاڈی');
    });
  });

  group('nearestCity', () {
    final cities = [
      _city('karachi', 24.8607, 67.0011),
      _city('hyderabad', 25.396, 68.3578),
    ];

    test('picks the nearest centre within 60 km, and nothing beyond', () {
      expect(nearestCity(cities, 24.8138, 67.03)?.id, 'karachi');
      expect(nearestCity(cities, 25.38, 68.37)?.id, 'hyderabad');
      // Thatta is about 85 km from Karachi's centre.
      expect(nearestCity(cities, 24.747, 67.924), isNull);
    });

    test('NaN, the antimeridian and an empty list do not crash', () {
      expect(nearestCity(cities, double.nan, double.nan), isNull);
      expect(nearestCity(cities, 24.86, 67.0011 + 360), isNotNull);
      expect(nearestCity(const [], 24.86, 67), isNull);
    });
  });

  group('PlatformNotificationPermission maps every status', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, null),
    );

    for (final (code, name, expected) in [
      (1, 'granted', AlertPermission.granted),
      (3, 'limited', AlertPermission.granted),
      (5, 'provisional', AlertPermission.granted),
      (0, 'denied', AlertPermission.denied),
      (4, 'permanentlyDenied', AlertPermission.permanentlyDenied),
      (2, 'restricted', AlertPermission.permanentlyDenied),
    ]) {
      test('$name → ${expected.name}', () async {
        _answer(code);
        const service = PlatformNotificationPermission();
        expect(await service.status(), expected);
        expect(await service.request(), expected);
      });
    }

    test('a platform error is "unavailable", never a crash', () async {
      _answer(0, error: true);
      const service = PlatformNotificationPermission();
      expect(await service.request(), AlertPermission.unavailable);
      expect(await service.openSettings(), isFalse);
    });

    test('settings opens through the plugin', () async {
      var opened = false;
      _answer(0, onSettings: () => opened = true);
      expect(await const PlatformNotificationPermission().openSettings(), true);
      expect(opened, isTrue);
    });
  });
}
