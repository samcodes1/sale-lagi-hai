import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/app.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/app/router/app_router.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/device/notification_permission.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';

import '../../helpers/fakes.dart';

// The real app on the demo backend, with scripted location and
// notification permission, for onboarding tests.

final class FakeLocation implements LocationService {
  new(this.outcome);

  LocationOutcome outcome;
  int asked = 0;
  int settingsOpened = 0;

  @override
  Future<LocationOutcome> approximateLocation() async {
    asked++;
    return outcome;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }
}

final class FakeAlerts implements NotificationPermissionService {
  new(this.answer);

  AlertPermission answer;
  int requested = 0;
  int settingsOpened = 0;

  @override
  Future<AlertPermission> status() async => AlertPermission.denied;

  @override
  Future<AlertPermission> request() async {
    requested++;
    return answer;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

/// A backend whose reads fail until [fail] is cleared.
final class FlakyGateway implements BackendGateway {
  final _demo = DemoGateway();
  bool fail = true;

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    if (fail) throw const OfflineFailure();
    return await _demo.select(query);
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) => _demo.rpc(function, params);

  @override
  Future<void> insert(String table, Map<String, Object?> row) =>
      _demo.insert(table, row);

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      _demo.delete(table, match);
}

final class Harness {
  new({
    LocationOutcome? location,
    AlertPermission alerts = AlertPermission.granted,
    BackendGateway? backend,
    DemoAuthRepository? auth,
    this.saved = const ShopperPreferences(),
    this.overrides = const [],
    InMemoryKeyValueStore? store,
    this.network = NetworkStatus.online,
  }) : store = store ?? InMemoryKeyValueStore(),
       auth = auth ?? DemoAuthRepository(),
       location = FakeLocation(
         location ?? const Located(24.8138, 67.03), // Clifton, Karachi
       ),
       alerts = FakeAlerts(alerts),
       backend = backend ?? DemoGateway();

  final FakeLocation location;
  final FakeAlerts alerts;
  final BackendGateway backend;
  final ShopperPreferences saved;

  /// Extra provider overrides, applied last.
  final List<Override> overrides;
  final InMemoryKeyValueStore store;
  final NetworkStatus network;
  final DemoAuthRepository auth;
  late ProviderContainer container;

  GoRouter get router => container.read(routerProvider);

  /// [languageChosen]: as if the shopper already confirmed a language, so
  /// a test may open a later step directly.
  Future<void> pump(
    WidgetTester tester, {
    bool languageChosen = true,
    Locale device = AppLocales.english,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            flavor: Flavor.dev,
            appName: 'SLH',
            supabaseUrl: '',
            supabasePublishableKey: '',
          ),
        ),
        backendGatewayProvider.overrideWithValue(backend),
        deviceLocaleProvider.overrideWithValue(device),
        keyValueStoreProvider.overrideWithValue(store),
        loggerProvider.overrideWithValue(AppLogger(sinks: [])),
        savedPreferencesProvider.overrideWithValue(saved),
        locationServiceProvider.overrideWithValue(location),
        notificationPermissionProvider.overrideWithValue(alerts),
        authRepositoryProvider.overrideWithValue(auth),
        networkStatusProvider.overrideWith((ref) => Stream.value(network)),
        ...overrides,
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    if (languageChosen) {
      container.read(languageChosenProvider.notifier).confirm();
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
  }

  ShopperPreferences get preferences => container.read(preferencesProvider);
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).first);
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}
