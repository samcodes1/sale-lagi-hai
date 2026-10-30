// QA, Phase 4 gate: the whole app (real router, real providers, the demo
// data) on a backend that behaves like the real server for the things the
// journeys touch, so cross-sub-phase flows can be driven end to end.
//
// `ServerGateway` adds to `RulesGateway` (the column rules and the two
// sync RPCs):
// - per-user RLS: `saves`, `user_cards`, `follows`, `notifications` and
//   `alert_prefs` reads, deletes and per-user RPCs see only the signed-in
//   user's rows; a guest sees none and can't call the account RPCs;
// - an offline switch: every call fails as the HTTP client does;
// - a request log, for request-storm checks.
import 'dart:async';
import 'dart:io';

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
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/device/notification_permission.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/links/link_service.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/core/theme/theme_mode_controller.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../features/onboarding/onboarding_harness.dart'
    show FakeAlerts, FakeLocation;
import '../helpers/fakes.dart';
import 'qa_backend_rules.dart';

String dealId(int n) => demoDeals.firstWhere((d) => d.n == n).id;
String dealTitle(int n) => demoDeals.firstWhere((d) => d.n == n).titleEn;
String dealTitleUr(int n) => demoDeals.firstWhere((d) => d.n == n).titleUr;

const phoneA = '+923001111111';
const phoneB = '+923002222222';

/// [RulesGateway] with per-user RLS, an offline switch and a request log.
class ServerGateway extends RulesGateway {
  new(super.auth);

  bool offline = false;

  /// Every call, as `rpc:name`, `select:table`, `insert:table`,
  /// `delete:table`.
  final calls = <String>[];

  static const _own = {'saves', 'user_cards', 'follows'};

  /// Per-user `alert_prefs` rows (created on first read, as the sign-up
  /// trigger does).
  final _prefs = <String, Map<String, Object?>>{};

  /// Per-user inbox rows.
  final alerts = <Map<String, Object?>>[];

  void _network() {
    if (offline) throw const SocketException('offline');
  }

  String? get _uid => auth.currentUser?.id;

  static List<Map<String, Object?>> _apply(
    TableQuery q,
    List<Map<String, Object?>> rows,
  ) {
    var out = rows.where((row) {
      for (final MapEntry(:key, :value) in q.equals.entries) {
        if (row[key] != value) return false;
      }
      for (final MapEntry(:key, :value) in q.inList.entries) {
        if (!value.contains(row[key])) return false;
      }
      return true;
    }).toList();
    if (q.orderBy case final c?) {
      out.sort((a, b) {
        final x = a[c];
        final y = b[c];
        final o = x is Comparable && y != null ? x.compareTo(y) : 0;
        return q.ascending ? o : -o;
      });
    }
    out = out.skip(q.offset).toList();
    if (q.limit case final l?) out = out.take(l).toList();
    return [for (final r in out) Map.of(r)];
  }

  /// The rows of [table] that belong to [uid], ignoring RLS (test view).
  Future<List<Map<String, Object?>>> rowsOf(String table, String uid) async => [
    for (final r in await demo.select(TableQuery(table)))
      if (r['user_id'] == uid) r,
  ];

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) async {
    calls.add('select:${query.table}');
    _network();
    final uid = _uid;
    if (query.table == 'notifications') {
      return _apply(query, [
        for (final a in alerts)
          if (a['user_id'] == uid) a,
      ]);
    }
    if (_own.contains(query.table)) {
      final rows = await demo.select(TableQuery(query.table));
      return _apply(query, [
        for (final r in rows)
          if (uid != null && r['user_id'] == uid) r,
      ]);
    }
    return await super.select(query);
  }

  @override
  Future<void> insert(String table, Map<String, Object?> row) async {
    calls.add('insert:$table');
    _network();
    if (_own.contains(table)) {
      final existing = await demo.select(TableQuery(table));
      final duplicate = existing.any(
        (r) => row.entries.every((e) => r[e.key] == e.value),
      );
      if (duplicate) {
        throw const PostgrestException(message: 'duplicate', code: '23505');
      }
    }
    await super.insert(table, {
      ...row,
      if (_own.contains(table))
        'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> delete(String table, Map<String, Object?> match) async {
    calls.add('delete:$table');
    _network();
    final uid = _uid;
    if (uid == null) return; // RLS: a guest deletes nothing.
    if (_own.contains(table) && match['user_id'] != uid) {
      // RLS: rows of others are invisible, so nothing matches.
      return;
    }
    await super.delete(table, match);
  }

  Map<String, Object?> _prefsOf(String uid) => _prefs[uid] ??= {
    'push_enabled': false,
    'frequency': 'normal',
    'quiet_start': '22:00:00',
    'quiet_end': '08:00:00',
    'time_zone': 'Asia/Karachi',
    'followed_brands': true,
    'followed_categories': true,
    'my_cards': true,
    'my_city': true,
    'saved_price_drops': true,
    'saved_expiring': true,
  };

  Map<String, Object?>? prefsOf(String uid) => _prefs[uid];

  String _caller() {
    final uid = _uid;
    if (uid == null) {
      throw const PostgrestException(message: 'sign in', code: '42501');
    }
    return uid;
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    calls.add('rpc:$function');
    _network();
    switch (function) {
      case 'my_alert_prefs':
        return [Map.of(_prefsOf(_caller()))];
      case 'update_alert_prefs':
        final row = _prefsOf(_caller());
        for (final MapEntry(:key, :value) in params.entries) {
          if (value != null) row[key] = value;
        }
        return [Map.of(row)];
      case 'unread_alert_count':
        final uid = _caller();
        final since = params['since'] as String?;
        return [
          {
            'value': [
              for (final a in alerts)
                if (a['user_id'] == uid &&
                    a['read_at'] == null &&
                    (since == null ||
                        (a['created_at']! as String).compareTo(since) > 0))
                  a,
            ].take(100).length,
          },
        ];
      case 'mark_alerts_read':
        final uid = _caller();
        final ids = params['ids'] as List<Object?>?;
        var n = 0;
        for (final a in alerts) {
          if (a['user_id'] == uid &&
              a['read_at'] == null &&
              (ids == null || ids.contains(a['id']))) {
            a['read_at'] = DateTime.now().toUtc().toIso8601String();
            n++;
          }
        }
        return [
          {'value': n},
        ];
      case 'deals_for_my_cards':
        // The caller's cards only (the demo reads every user's).
        final uid = _caller();
        final mine = await rowsOf('user_cards', uid);
        if (mine.isEmpty) return const [];
        return await demo.rpc('deals_for_cards', {
          ...params,
          'card_product_ids': [for (final r in mine) r['card_product_id']],
        });
    }
    return await super.rpc(function, params);
  }

  /// An inbox row for [uid] about deal [n].
  void addAlert(String uid, int n, {int minutesAgo = 5}) => alerts.add({
    'id':
        '00000000-0000-4000-0009-'
        '${(alerts.length + 1).toString().padLeft(12, '0')}',
    'user_id': uid,
    'kind': 'deal_alert',
    'title': 'Alert for ${dealTitle(n)}',
    'body': dealTitle(n),
    'deal_id': dealId(n),
    'created_at': DateTime.now()
        .toUtc()
        .subtract(Duration(minutes: minutesAgo))
        .toIso8601String(),
    'read_at': null,
  });
}

/// Records what the app asked to open or share.
final class FakeLinks implements LinkService {
  final opened = <String>[];

  @override
  Future<bool> call(String e164) async {
    opened.add('tel:$e164');
    return true;
  }

  @override
  Future<bool> email(String address) async {
    opened.add('mailto:$address');
    return true;
  }

  @override
  Future<bool> openMap(double latitude, double longitude, String label) async {
    opened.add('map:$label');
    return true;
  }

  @override
  Future<bool> openWeb(String url) async {
    opened.add('web:$url');
    return true;
  }

  @override
  Future<bool> shareOnWhatsApp(String text) async {
    opened.add('whatsapp:$text');
    return true;
  }
}

/// The real app on [ServerGateway], with scripted device services and a
/// network that can drop and come back.
final class Journey {
  new({
    this.saved = const ShopperPreferences(),
    InMemoryKeyValueStore? store,
    DemoAuthRepository? auth,
    this.extra = const [],
    ServerGateway Function(DemoAuthRepository auth)? backend,
    this.config = const AppConfig(
      flavor: Flavor.dev,
      appName: 'SLH',
      supabaseUrl: '',
      supabasePublishableKey: '',
    ),
  }) : store = store ?? InMemoryKeyValueStore(),
       auth = auth ?? DemoAuthRepository() {
    server = (backend ?? ServerGateway.new)(this.auth);
  }

  final ShopperPreferences saved;
  final InMemoryKeyValueStore store;
  final DemoAuthRepository auth;
  final List<Override> extra;
  final AppConfig config;
  late final ServerGateway server;
  final location = FakeLocation(const Located(24.8138, 67.03)); // Clifton
  final alerts = FakeAlerts(AlertPermission.granted);
  final links = FakeLinks();
  final logs = MemoryLogSink();
  final _network = StreamController<NetworkStatus>.broadcast();
  NetworkStatus _status = NetworkStatus.online;
  late ProviderContainer container;

  GoRouter get router => container.read(routerProvider);
  ShopperPreferences get preferences => container.read(preferencesProvider);

  /// Drops (or restores) the network: the banner's stream and the server.
  Future<void> setOnline(WidgetTester tester, {required bool online}) async {
    _status = online ? NetworkStatus.online : NetworkStatus.offline;
    server.offline = !online;
    _network.add(_status);
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester, {
    Locale device = AppLocales.english,
    Size size = const Size(412, 915),
    double textScale = 1,
    Brightness platformBrightness = Brightness.light,
    AppThemeMode theme = AppThemeMode.system,
    Locale? savedLocale,
    bool online = true,
  }) async {
    _status = online ? NetworkStatus.online : NetworkStatus.offline;
    server.offline = !online;
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    tester.platformDispatcher.platformBrightnessTestValue = platformBrightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    addTearDown(_network.close);
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        backendGatewayProvider.overrideWithValue(server),
        deviceLocaleProvider.overrideWithValue(device),
        keyValueStoreProvider.overrideWithValue(store),
        loggerProvider.overrideWithValue(AppLogger(sinks: [logs])),
        savedPreferencesProvider.overrideWithValue(saved),
        savedLocaleProvider.overrideWithValue(savedLocale),
        savedThemeModeProvider.overrideWithValue(theme),
        locationServiceProvider.overrideWithValue(location),
        notificationPermissionProvider.overrideWithValue(alerts),
        authRepositoryProvider.overrideWithValue(auth),
        linkServiceProvider.overrideWithValue(links),
        networkStatusProvider.overrideWith(
          (ref) => Stream.multi((c) {
            c.add(_status);
            final sub = _network.stream.listen(c.add);
            c.onCancel = sub.cancel;
          }),
        ),
        demoModeProvider.overrideWithValue(true),
        ...extra,
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
  }

  /// Every log line, flattened, for privacy checks.
  String get logText => [
    for (final r in logs.records)
      '${r.message} ${r.context} ${r.errorType} ${r.errorText}',
  ].join('\n');
}

/// Taps the bottom-navigation destination labelled [label].
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  // The last match: a sheet or dialog on top wins over the page below.
  final f = find.text(text);
  await tester.ensureVisible(f.last);
  await tester.pumpAndSettle();
  await tester.tap(f.last);
  await tester.pumpAndSettle();
}

/// Scrolls the first scrollable until [finder] is built, then taps it.
Future<void> scrollToAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).hitTestable().first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Signs in through the real sign-in page with [phone] and the demo code.
Future<void> signInWithPhone(WidgetTester tester, String phone) async {
  await tapTab(tester, 'Profile');
  await tapText(tester, 'Sign in');
  await tester.enterText(
    find.byType(TextField).first,
    '0${phone.substring(3)}',
  );
  await tapText(tester, 'Send code');
  await tester.enterText(find.byType(TextField).last, DemoAuthRepository.code);
  await tester.pumpAndSettle();
  // The code submits itself at 6 digits on some builds; tap if still here.
  if (find.text('Enter the code').evaluate().isNotEmpty &&
      find.widgetWithText(FilledButton, 'Continue').evaluate().isNotEmpty) {
    await tester.tap(find.widgetWithText(FilledButton, 'Continue').first);
    await tester.pumpAndSettle();
  }
}

/// Signs in with the demo Google account (the same id every time).
Future<void> signInWithGoogle(WidgetTester tester) async {
  await tapTab(tester, 'Profile');
  await tapText(tester, 'Sign in');
  await tapText(tester, 'Continue with Google');
}

Future<void> signOutFromProfile(WidgetTester tester) async {
  await tapTab(tester, 'Profile');
  await tapText(tester, 'Sign out');
}
