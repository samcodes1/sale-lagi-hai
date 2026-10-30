// QA (sub-phase 4.9 gate): Settings. Alert preferences against a backend
// that answers as Postgres does (per-user rows, coalesce, the quiet-hours
// check, an empty result when there is no row, slow and failed calls), the
// push switch against permission_handler's real Android behaviour (through
// its method channel: `status` never says "permanently denied", a second
// request while the dialog is up is an error, `openAppSettings` returns at
// once), "Clear everything on this phone", hostile legal routes, dark-mode
// guidelines and 200% text scrolled to the end.
//
// "QA BUG" tests fail until the bug in docs/qa/4.9.md is fixed; S4 findings
// are skipped with their bug id (run with --dart-define=QA_KNOWN_BUGS=true).
import 'dart:async';
import 'dart:convert';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/notification_permission.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/theme/theme_mode_controller.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/cards/application/my_cards_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/language_step.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';
import 'package:sale_lagi_hai/features/search/application/search_providers.dart';
import 'package:sale_lagi_hai/features/settings/application/alert_prefs_providers.dart';
import 'package:sale_lagi_hai/features/settings/domain/alert_prefs.dart';
import 'package:sale_lagi_hai/features/settings/presentation/legal_screen.dart';
import 'package:sale_lagi_hai/features/settings/presentation/notification_settings_screen.dart';
import 'package:sale_lagi_hai/features/settings/presentation/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

// ------------------------------------------------------------ the server ---

/// `alert_prefs` and its RPCs as Postgres answers them
/// (20261029120400_user_activity.sql, 20261029250000_settings.sql): one row
/// per user, `coalesce` per field, the enum, `quiet_start <> quiet_end`
/// after the merge (23514), no rows for a user without one, 42501 for anon.
/// Times come back as "HH:MM:SS". Other calls go to the demo backend.
final class PrefsServer implements BackendGateway {
  new(this.auth);

  final DemoAuthRepository auth;
  final _demo = DemoGateway();
  final rows = <String, Map<String, Object?>>{};

  /// Users whose row is missing (deleted by an operator, or never made).
  final noRow = <String>{};
  final updates = <Map<String, Object?>>[];

  /// The next update calls wait on these, in order; completing one with an
  /// error makes that call fail (as a network failure would) unapplied.
  final gates = <Completer<void>>[];

  static const _defaults = <String, Object?>{
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

  Map<String, Object?>? rowOf(String uid) => noRow.contains(uid)
      ? null
      : rows.putIfAbsent(uid, () => {'user_id': uid, ..._defaults});

  static String _time(Object value) {
    final parts = (value as String).split(':');
    String two(String s) => s.padLeft(2, '0');
    return '${two(parts[0])}:${two(parts.length > 1 ? parts[1] : '0')}:'
        '${two(parts.length > 2 ? parts[2] : '0')}';
  }

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    if (function != 'my_alert_prefs' && function != 'update_alert_prefs') {
      return await _demo.rpc(function, params);
    }
    final uid = auth.currentUser?.id;
    if (uid == null) {
      throw const PostgrestException(
        message: 'permission denied',
        code: '42501',
      );
    }
    if (function == 'my_alert_prefs') {
      final row = rowOf(uid);
      return row == null ? const [] : [Map.of(row)];
    }
    updates.add(params);
    if (gates.isNotEmpty) await gates.removeAt(0).future;
    final row = rowOf(uid);
    if (row == null) return const [];
    final next = Map.of(row);
    for (final MapEntry(:key, :value) in params.entries) {
      if (value == null) continue;
      if (key == 'frequency' && !{'low', 'normal', 'high'}.contains(value)) {
        throw const PostgrestException(message: 'invalid enum', code: '22P02');
      }
      next[key] = key.startsWith('quiet_') ? _time(value) : value;
    }
    if (next['quiet_start'] == next['quiet_end']) {
      throw const PostgrestException(message: 'check', code: '23514');
    }
    row.addAll(next);
    return [Map.of(row)];
  }

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) =>
      _demo.select(query);

  @override
  Future<void> insert(String table, Map<String, Object?> row) =>
      _demo.insert(table, row);

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      _demo.delete(table, match);
}

Future<DemoAuthRepository> _signedIn() async {
  final auth = DemoAuthRepository();
  await auth.sendPhoneCode('+923001234567');
  await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
  return auth;
}

AlertPrefs _with(AlertPrefs p, {bool? followedBrands, bool? myCity}) =>
    AlertPrefs.fromRow({
      'push_enabled': p.pushEnabled,
      'frequency': p.frequency.name,
      'quiet_start': AlertPrefs.wireTime(p.quietStart),
      'quiet_end': AlertPrefs.wireTime(p.quietEnd),
      'time_zone': p.timeZone,
      'followed_brands': followedBrands ?? p.followedBrands,
      'followed_categories': p.followedCategories,
      'my_cards': p.myCards,
      'my_city': myCity ?? p.myCity,
      'saved_price_drops': p.savedPriceDrops,
      'saved_expiring': p.savedExpiring,
    });

// ------------------------------------------------ permission_handler ---

const _permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
const _notification = 17; // Permission.notification.value

/// permission_handler_android 14.1.1 as it behaves on a phone
/// (PermissionManager.java): a status check reports 0 (denied) for both
/// "never asked" and "permanently denied"; a request while one is running
/// is an error; openAppSettings returns true as soon as Settings opens.
final class AndroidPermissions {
  /// What a status check reports: 0 denied, 1 granted.
  int status = 0;

  /// What the dialog (or the lack of one) answers; `null`: the dialog
  /// stays up until [answer].
  int? immediate;
  Completer<int>? _dialog;
  int requests = 0;
  int settingsOpened = 0;

  void answer(int value) => _dialog?.complete(value);

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _permissions,
      (call) async {
        switch (call.method) {
          case 'checkPermissionStatus':
            return status;
          case 'requestPermissions':
            requests++;
            if (_dialog != null) {
              throw PlatformException(
                code: 'PermissionHandler.PermissionManager',
                message:
                    'A request for permissions is already running, '
                    'please wait for it to finish before doing another '
                    'request.',
              );
            }
            if (immediate case final value?) return {_notification: value};
            final dialog = _dialog = Completer<int>();
            final value = await dialog.future;
            _dialog = null;
            return {_notification: value};
          case 'openAppSettings':
            settingsOpened++;
            return true;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _permissions,
        null,
      ),
    );
  }
}

// ---------------------------------------------------------- the screen ---

const _config = AppConfig(
  flavor: Flavor.dev,
  appName: 'SLH',
  supabaseUrl: '',
  supabasePublishableKey: '',
  supportEmail: 'help@salelagihai.pk',
);

Future<Harness> _app(
  WidgetTester tester, {
  required String at,
  DemoAuthRepository? auth,
  BackendGateway? backend,
  Locale locale = AppLocales.english,
  InMemoryKeyValueStore? store,
  Size size = const Size(412, 915),
}) async {
  final h = Harness(
    saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
    auth: auth,
    backend: backend,
    config: _config,
    store: store,
  );
  await h.pump(tester, device: locale, size: size);
  h.router.go(at);
  await tester.pumpAndSettle();
  return h;
}

/// The Notifications page alone, with the real permission service (the
/// harness pins its own fake).
Future<ProviderContainer> _notificationsWithRealPermissions(
  WidgetTester tester,
  DemoAuthRepository auth,
  PrefsServer server,
) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testApp(
      const NotificationSettingsScreen(),
      overrides: [
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        loggerProvider.overrideWithValue(AppLogger(sinks: [])),
        backendGatewayProvider.overrideWithValue(server),
        authRepositoryProvider.overrideWithValue(auth),
        notificationPermissionProvider.overrideWithValue(
          const PlatformNotificationPermission(),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(NotificationSettingsScreen)),
  );
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

AlertPrefs? _prefs(Harness h) => h.container.read(alertPrefsProvider).value;

final Finder _blockedNote = find.textContaining('turned off for this app');

void main() {
  setUp(rootBundle.clear);
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'Sale Lagi Hai!',
      packageName: 'pk.salelagihai.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    ),
  );

  group('alert prefs against a Postgres-faithful server', () {
    late DemoAuthRepository auth;
    late PrefsServer server;

    Future<ProviderContainer> container() async {
      final c = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          loggerProvider.overrideWithValue(AppLogger(sinks: [])),
          backendGatewayProvider.overrideWithValue(server),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      final sub = c.listen(alertPrefsProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(alertPrefsProvider.future);
      return c;
    }

    setUp(() async {
      auth = await _signedIn();
      server = PrefsServer(auth);
    });

    test('a change is stored; a fresh load reads it back', () async {
      final c = await container();
      final notifier = c.read(alertPrefsProvider.notifier);
      final before = c.read(alertPrefsProvider).value!;
      expect(await notifier.change(_with(before, myCity: false)), isNull);
      expect(server.updates.single, {'my_city': false});
      c.invalidate(alertPrefsProvider);
      expect((await c.read(alertPrefsProvider.future))!.myCity, isFalse);
    });

    test('an end equal to the stored start: the server refuses, the app '
        'reverts and says so', () async {
      final c = await container();
      final before = c.read(alertPrefsProvider).value!;
      final next = AlertPrefs.fromRow({
        ...server.rows[auth.currentUser!.id]!,
        'quiet_end': '22:00',
      });
      expect(await c.read(alertPrefsProvider.notifier).change(next), isNotNull);
      expect(c.read(alertPrefsProvider).value, before);
    });

    test('QA BUG 4.9-N4: a failed save does not undo a later one that the '
        'server kept', () async {
      final c = await container();
      final notifier = c.read(alertPrefsProvider.notifier);
      final p0 = c.read(alertPrefsProvider).value!;

      // A: brands off, on a slow connection that then drops.
      final gate = Completer<void>();
      server.gates.add(gate);
      final a = notifier.change(_with(p0, followedBrands: false));
      await Future<void>.delayed(Duration.zero);
      // B: city off, while A is still on its way; it is saved.
      final p1 = c.read(alertPrefsProvider).value!;
      expect(await notifier.change(_with(p1, myCity: false)), isNull);
      expect(server.rows[auth.currentUser!.id]!['my_city'], isFalse);

      gate.completeError(const OfflineFailure());
      expect(await a, isA<OfflineFailure>());

      final shown = c.read(alertPrefsProvider).value!;
      expect(shown.followedBrands, isTrue, reason: 'A failed: reverted');
      expect(
        shown.myCity,
        isFalse,
        reason: 'B was saved on the server; the screen must not show it on',
      );
    });

    test('QA BUG 4.9-N5: with no row on the server, a change is not shown as '
        'saved', () async {
      server.noRow.add(auth.currentUser!.id);
      final c = await container();
      final before = c.read(alertPrefsProvider).value!;
      expect(before, const AlertPrefs(), reason: 'the documented defaults');
      final failure = await c
          .read(alertPrefsProvider.notifier)
          .change(_with(before, myCity: false));
      c.invalidate(alertPrefsProvider);
      final reread = await c.read(alertPrefsProvider.future);
      expect(
        failure != null || !reread!.myCity,
        isTrue,
        reason:
            'update_alert_prefs returned no row: nothing was saved, '
            'yet change() reported success',
      );
    });
  });

  group('push switch with permission_handler as on Android', () {
    AlertPrefs? prefsOf(ProviderContainer c) =>
        c.read(alertPrefsProvider).value;

    testWidgets(
      'QA BUG 4.9-N2: a second tap while the system dialog is up does not '
      'turn push on without a grant',
      (tester) async {
        final android = AndroidPermissions()..install(tester);
        final auth = await _signedIn();
        final server = PrefsServer(auth);
        final c = await _notificationsWithRealPermissions(tester, auth, server);
        final push = find.widgetWithText(SwitchListTile, 'Push notifications');
        await tester.tap(push);
        await tester.pump(const Duration(milliseconds: 50));
        // The dialog takes a moment to appear; the shopper taps again.
        await tester.tap(push);
        await tester.pump(const Duration(milliseconds: 50));
        // Since the fix the second tap doesn't ask again (and if it did,
        // the plugin's error would count as denied).
        expect(android.requests, 1);
        // Then denies in the dialog.
        android.answer(0);
        await tester.pumpAndSettle();

        expect(prefsOf(c)?.pushEnabled, isFalse);
        expect(server.rows[auth.currentUser!.id]!['push_enabled'], isFalse);
      },
    );

    testWidgets(
      'QA BUG 4.9-N1: blocked by Android, the note stays while Settings is '
      'open',
      (tester) async {
        final android = AndroidPermissions()
          // Permanently denied: the request answers at once, no dialog.
          ..immediate = 4
          ..install(tester);
        final auth = await _signedIn();
        await _notificationsWithRealPermissions(
          tester,
          auth,
          PrefsServer(auth),
        );
        await _tap(tester, 'Push notifications');
        expect(_blockedNote, findsOneWidget, reason: 'request said blocked');

        await _tap(tester, 'Open settings');
        expect(android.settingsOpened, 1);
        // Settings is now in front; nothing has changed yet.
        expect(
          _blockedNote,
          findsOneWidget,
          reason:
              'still blocked, but the page re-checked at once and the '
              'status check cannot say "permanently denied"',
        );
      },
    );

    testWidgets('QA BUG 4.9-N1: push on in the account while Android blocks '
        'notifications shows the note', (tester) async {
      AndroidPermissions().install(tester); // status: denied
      final auth = await _signedIn();
      final server = PrefsServer(auth);
      server.rowOf(auth.currentUser!.id)!['push_enabled'] = true;
      await _notificationsWithRealPermissions(tester, auth, server);
      final on = tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Push notifications'),
          )
          .value;
      expect(on, isTrue);
      expect(
        _blockedNote,
        findsOneWidget,
        reason: 'the switch says pushes are on, but none can be shown',
      );
    });

    testWidgets('granted: one tap turns push on and saves it', (tester) async {
      final android = AndroidPermissions()
        ..immediate = 1
        ..install(tester);
      final auth = await _signedIn();
      final server = PrefsServer(auth);
      final c = await _notificationsWithRealPermissions(tester, auth, server);
      await _tap(tester, 'Push notifications');
      expect(android.requests, 1);
      expect(prefsOf(c)?.pushEnabled, isTrue);
      expect(server.rows[auth.currentUser!.id]!['push_enabled'], isTrue);
    });

    testWidgets('denied in the dialog: stays off, nothing sent', (
      tester,
    ) async {
      AndroidPermissions()
        ..immediate = 0
        ..install(tester);
      final auth = await _signedIn();
      final server = PrefsServer(auth);
      final c = await _notificationsWithRealPermissions(tester, auth, server);
      await _tap(tester, 'Push notifications');
      expect(prefsOf(c)?.pushEnabled, isFalse);
      expect(server.updates, isEmpty);
    });
  });

  group('quiet hours', () {
    testWidgets('Urdu: the times read in the RTL label, and the picker opens '
        'and cancels cleanly', (tester) async {
      final auth = await _signedIn();
      final h = await _app(
        tester,
        at: '/settings/notifications',
        auth: auth,
        backend: PrefsServer(auth),
        locale: AppLocales.urdu,
      );
      final from = find.widgetWithIcon(ListTile, Icons.bedtime_outlined);
      await tester.scrollUntilVisible(
        find.byIcon(Icons.wb_sunny_outlined),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('10:00'), findsOneWidget);
      expect(find.textContaining('8:00'), findsOneWidget);
      await Scrollable.ensureVisible(tester.element(from.first));
      await tester.pumpAndSettle();
      await tester.tap(from.first);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(4, 4)); // outside: dismiss
      await tester.pumpAndSettle();
      expect(_prefs(h)?.quietStart, (hour: 22, minute: 0));
    });
  });

  group('Clear everything on this phone', () {
    Future<Harness> filled(WidgetTester tester) async {
      final store = InMemoryKeyValueStore();
      final auth = await _signedIn();
      final server = PrefsServer(auth);
      final h = await _app(
        tester,
        at: '/settings/privacy',
        auth: auth,
        backend: server,
        store: store,
      );
      final c = h.container;
      await c.read(recentSearchesProvider.notifier).add('karahi');
      await c.read(savedDealsProvider.notifier).toggle(demoDeals.first.id);
      await c.read(myCardsProvider.notifier).update((l) => [...l, 'card-x']);
      await c.read(themeModeProvider.notifier).select(AppThemeMode.dark);
      await c.read(localeControllerProvider.notifier).select(AppLocales.urdu);
      await tester.pumpAndSettle();
      expect(store.values, isNotEmpty);
      // Urdu now: tap by widget type.
      final clear = find.byIcon(Icons.phonelink_erase_outlined);
      await tester.scrollUntilVisible(
        clear,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(clear);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'صاف کریں'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('signed out, every list empty, storage empty, back to '
        'onboarding; the account and its alert prefs untouched', (
      tester,
    ) async {
      final h = await filled(tester);
      final c = h.container;
      expect(h.auth.currentUser, isNull);
      expect(h.auth.deletedIds, isEmpty, reason: 'the account stays');
      expect(find.byType(LanguageStep), findsOneWidget);
      expect(c.read(recentSearchesProvider), isEmpty);
      expect(c.read(savedDealsProvider), isEmpty);
      expect(c.read(myCardsProvider), isEmpty);
      expect(c.read(alertPrefsProvider).value, isNull);
      // Nothing written back after the clear.
      await tester.pumpAndSettle();
      expect(h.store.values, isEmpty, reason: jsonEncode(h.store.values));
      expect(tester.takeException(), isNull);
    });

    testWidgets('QA BUG 4.9-P1: the theme choice goes with everything else', (
      tester,
    ) async {
      final h = await filled(tester);
      expect(h.store.values.containsKey(themeModeStorageKey), isFalse);
      expect(
        h.container.read(themeModeProvider),
        AppThemeMode.system,
        reason:
            'storage says "as on this phone"; the app is still dark '
            'until the next launch',
      );
    });
  });

  group('legal routes', () {
    for (final doc in [
      'Terms',
      'terms%20',
      '..%2F..%2Fpubspec',
      '%2e%2e',
      'terms%00',
      'privacy_en',
      'cookies',
      List.filled(3000, 'a').join(),
    ]) {
      testWidgets(
        '/settings/legal/$doc goes to Settings'.substring(
          0,
          '/settings/legal/$doc goes to Settings'.length.clamp(0, 80),
        ),
        (tester) async {
          await _app(tester, at: '/settings/legal/$doc');
          expect(find.byType(LegalScreen), findsNothing);
          expect(find.byType(SettingsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('a deeper path is not a legal page', (tester) async {
      await _app(tester, at: '/settings/legal/terms/../../about');
      expect(find.byType(LegalScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Settings city', () {
    testWidgets(
      'QA BUG 4.9-S1: when the cities cannot load, the city row does not '
      'claim "All Pakistan"',
      (tester) async {
        final h = Harness(
          saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
          backend: FlakyGateway(),
          config: _config,
        );
        await h.pump(tester);
        h.router.go('/settings');
        await tester.pumpAndSettle();
        expect(h.preferences.cityId, karachiId);
        expect(find.text('All Pakistan'), findsNothing);
      },
    );
  });

  group('accessibility beyond the developer tests', () {
    for (final locale in AppLocales.supported) {
      for (final (name, at, signedIn) in [
        ('settings', '/settings', false),
        ('notifications', '/settings/notifications', true),
        ('privacy', '/settings/privacy', true),
        ('privacy policy', '/settings/legal/privacy', false),
        ('about', '/settings/about', false),
      ]) {
        testWidgets('dark ${locale.languageCode} $name: guidelines; 200% at '
            '360x800 scrolled to the end without overflow', (tester) async {
          final handle = tester.ensureSemantics();
          tester.platformDispatcher.platformBrightnessTestValue =
              Brightness.dark;
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final auth = signedIn ? await _signedIn() : null;
          await _app(
            tester,
            at: at,
            locale: locale,
            auth: auth,
            backend: auth == null ? null : PrefsServer(auth),
          );
          expect(
            Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
            Brightness.dark,
          );
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));

          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.view.physicalSize = const Size(360, 800) * 2;
          await tester.pumpAndSettle();
          final list = find.byType(Scrollable).last;
          for (var i = 0; i < 12; i++) {
            await tester.drag(list, const Offset(0, -500));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'scroll $i');
          }
          handle.dispose();
        });
      }
    }

    testWidgets('switches and quiet-hour rows have their names and roles', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final auth = await _signedIn();
      await _app(
        tester,
        at: '/settings/notifications',
        auth: auth,
        backend: PrefsServer(auth),
      );
      final brands = tester.getSemantics(
        find.widgetWithText(SwitchListTile, 'Brands you follow'),
      );
      expect(brands.label, 'Brands you follow');
      expect(brands.flagsCollection.isToggled, isNotNull);
      expect(brands.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      final from = find.widgetWithText(ListTile, 'From 10:00 PM');
      await Scrollable.ensureVisible(tester.element(from));
      await tester.pumpAndSettle();
      final node = tester.getSemantics(from);
      expect(node.label, contains('From 10:00 PM'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(find.byType(NotificationSettingsScreen), findsOneWidget);
      handle.dispose();
    });
  });
}
