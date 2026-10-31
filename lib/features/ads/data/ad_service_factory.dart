// Only platforms with dart:io can reach the ad plugin; the web build never
// imports it.
export 'ad_service_stub.dart' if (dart.library.io) 'ad_service_mobile.dart';
