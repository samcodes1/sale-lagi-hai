import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sale_lagi_hai/app/config/app_config.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/device/notification_permission.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/links/link_service.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/theme/theme_mode_controller.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/presentation/delete_account_screen.dart';
import 'package:sale_lagi_hai/features/auth/presentation/sign_in_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/language_step.dart';
import 'package:sale_lagi_hai/features/search/application/search_providers.dart';
import 'package:sale_lagi_hai/features/settings/application/alert_prefs_providers.dart';
import 'package:sale_lagi_hai/features/settings/domain/alert_prefs.dart';
import 'package:sale_lagi_hai/features/settings/presentation/about_screen.dart';
import 'package:sale_lagi_hai/features/settings/presentation/legal_screen.dart';
import 'package:sale_lagi_hai/features/settings/presentation/notification_settings_screen.dart';
import 'package:sale_lagi_hai/features/settings/presentation/privacy_screen.dart';
import 'package:sale_lagi_hai/features/settings/presentation/settings_screen.dart';

import '../onboarding/onboarding_harness.dart';

final class _Links implements LinkService {
  final calls = <String>[];

  Future<bool> _record(String call) async {
    calls.add(call);
    return true;
  }

  @override
  Future<bool> openWeb(String url) => _record('web $url');

  @override
  Future<bool> openMap(double latitude, double longitude, String label) =>
      _record('map');

  @override
  Future<bool> shareOnWhatsApp(String text) => _record('whatsapp');

  @override
  Future<bool> call(String e164) => _record('call $e164');

  @override
  Future<bool> email(String address) => _record('email $address');
}

/// The demo backend; [failUpdates] makes alert-prefs saves fail.
final class _Backend implements BackendGateway {
  final _demo = DemoGateway();
  bool failUpdates = false;

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    if (failUpdates && function == 'update_alert_prefs') {
      throw const OfflineFailure();
    }
    return await _demo.rpc(function, params);
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

const _config = AppConfig(
  flavor: Flavor.dev,
  appName: 'SLH',
  supabaseUrl: '',
  supabasePublishableKey: '',
  supportEmail: 'help@salelagihai.pk',
);

Future<DemoAuthRepository> _signedIn() async {
  final auth = DemoAuthRepository();
  await auth.sendPhoneCode('+923001234567');
  await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
  return auth;
}

Future<Harness> _app(
  WidgetTester tester, {
  String at = '/settings',
  Locale locale = AppLocales.english,
  DemoAuthRepository? auth,
  BackendGateway? backend,
  AlertPermission alerts = AlertPermission.granted,
  AppConfig config = _config,
  _Links? links,
}) async {
  final h = Harness(
    saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
    auth: auth,
    backend: backend,
    alerts: alerts,
    config: config,
    overrides: [linkServiceProvider.overrideWithValue(links ?? _Links())],
  );
  await h.pump(tester, device: locale);
  h.router.go(at);
  await tester.pumpAndSettle();
  return h;
}

/// Scrolls [text] to the middle of the screen, then taps it.
Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

AlertPrefs? _prefs(Harness h) => h.container.read(alertPrefsProvider).value;

bool _switch(WidgetTester tester, String title) => tester
    .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
    .value;

/// Picks [hour]:[minute] in the open time picker, typed in.
Future<void> _typeTime(WidgetTester tester, int hour, int minute) async {
  await tester.tap(find.byTooltip('Switch to text input mode'));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  await tester.enterText(fields.at(0), '$h12');
  await tester.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
  await tester.tap(find.text(hour < 12 ? 'AM' : 'PM'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  // An asset read started in an earlier test's fake time never finishes;
  // the bundle would hand that read out again.
  setUp(rootBundle.clear);

  group('Settings', () {
    testWidgets('Profile opens Settings; each link opens its page', (
      tester,
    ) async {
      await _app(tester, at: '/profile');
      await _tap(tester, 'Settings');
      expect(find.byType(SettingsScreen), findsOneWidget);
      for (final (title, page) in [
        ('Notifications', NotificationSettingsScreen),
        ('Privacy', PrivacyScreen),
        ('Terms of use', LegalScreen),
        ('Privacy policy', LegalScreen),
        ('About', AboutScreen),
      ]) {
        await _tap(tester, title);
        expect(find.byType(page), findsOneWidget, reason: title);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the theme switches at once and is remembered', (tester) async {
      final h = await _app(tester);
      expect(find.text('As on this phone'), findsOneWidget);
      await _tap(tester, 'Dark');
      expect(h.container.read(themeModeProvider), AppThemeMode.dark);
      expect(h.store.values[themeModeStorageKey], 'dark');
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );
      await _tap(tester, 'As on this phone');
      expect(h.store.values[themeModeStorageKey], 'system');
    });

    testWidgets('the city: the sheet lists them; a pick is saved', (
      tester,
    ) async {
      final h = await _app(tester);
      expect(find.text('Karachi'), findsOneWidget);
      await _tap(tester, 'City');
      await _tap(tester, 'Lahore');
      expect(h.preferences.cityId, lahoreId);
      expect(find.text('Lahore'), findsOneWidget);
      await _tap(tester, 'City');
      await _tap(tester, 'All Pakistan');
      expect(h.preferences.cityId, isNull);
    });
  });

  group('Notifications', () {
    testWidgets('a guest is asked to sign in', (tester) async {
      await _app(tester, at: '/settings/notifications');
      expect(find.textContaining('Sign in to choose'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      await _tap(tester, 'Sign in');
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('signed in: topics and frequency save at once', (tester) async {
      final h = await _app(
        tester,
        at: '/settings/notifications',
        auth: await _signedIn(),
      );
      expect(_switch(tester, 'Brands you follow'), isTrue);
      await _tap(tester, 'Brands you follow');
      expect(_switch(tester, 'Brands you follow'), isFalse);
      expect(_prefs(h)?.followedBrands, isFalse);

      await _tap(tester, 'Offers for your cards');
      expect(_prefs(h)?.myCards, isFalse);

      await _tap(tester, 'At most 6 a day');
      expect(_prefs(h)?.frequency, AlertFrequency.high);

      // Saved on the server: a fresh load reads the same.
      h.container.invalidate(alertPrefsProvider);
      await tester.pumpAndSettle();
      expect(_prefs(h)?.followedBrands, isFalse);
      expect(_prefs(h)?.frequency, AlertFrequency.high);
    });

    testWidgets('push: on only once the phone allows it', (tester) async {
      final h = await _app(
        tester,
        at: '/settings/notifications',
        auth: await _signedIn(),
        alerts: AlertPermission.denied,
      );
      await _tap(tester, 'Push notifications');
      expect(h.alerts.requested, 1);
      expect(_prefs(h)?.pushEnabled, isFalse);
      expect(_switch(tester, 'Push notifications'), isFalse);

      h.alerts.answer = AlertPermission.granted;
      await _tap(tester, 'Push notifications');
      expect(_prefs(h)?.pushEnabled, isTrue);

      // Turning off never asks.
      await _tap(tester, 'Push notifications');
      expect(_prefs(h)?.pushEnabled, isFalse);
      expect(h.alerts.requested, 2);
    });

    testWidgets('blocked in the phone settings: a note, and a way there', (
      tester,
    ) async {
      final auth = await _signedIn();
      final h = Harness(
        saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
        auth: auth,
        config: _config,
      )..alerts.current = AlertPermission.permanentlyDenied;
      await h.pump(tester);
      h.router.go('/settings/notifications');
      await tester.pumpAndSettle();
      expect(find.textContaining('turned off for this app'), findsOneWidget);

      await _tap(tester, 'Push notifications');
      expect(h.alerts.requested, 0, reason: 'Android would not ask again');
      expect(_prefs(h)?.pushEnabled, isFalse);

      await _tap(tester, 'Open settings');
      expect(h.alerts.settingsOpened, 1);
      expect(find.textContaining('turned off for this app'), findsOneWidget);
      // Allowed there, then back in the app: re-checked.
      h.alerts.current = AlertPermission.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.textContaining('turned off for this app'), findsNothing);
    });

    testWidgets('quiet hours: a new time saves; the same start and end is '
        'refused', (tester) async {
      final h = await _app(
        tester,
        at: '/settings/notifications',
        auth: await _signedIn(),
      );
      expect(find.text('From 10:00 PM'), findsOneWidget);
      await _tap(tester, 'Until 8:00 AM');
      await _typeTime(tester, 9, 30);
      expect(_prefs(h)?.quietEnd, (hour: 9, minute: 30));
      expect(find.text('Until 9:30 AM'), findsOneWidget);

      await _tap(tester, 'From 10:00 PM');
      await _typeTime(tester, 9, 30);
      expect(
        find.text('Quiet hours need a different start and end.'),
        findsOneWidget,
      );
      expect(_prefs(h)?.quietStart, (hour: 22, minute: 0));

      // Cancel changes nothing.
      await _tap(tester, 'From 10:00 PM');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_prefs(h)?.quietStart, (hour: 22, minute: 0));
    });

    testWidgets('offline: a change stays, and says it will be sent', (
      tester,
    ) async {
      final h = Harness(
        saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
        auth: await _signedIn(),
        config: _config,
        network: NetworkStatus.offline,
      );
      await h.pump(tester);
      h.router.go('/settings/notifications');
      await tester.pumpAndSettle();
      await _tap(tester, 'New deals in your city');
      expect(
        find.text(
          'Saved on this phone. It will be sent when you are back online.',
        ),
        findsOneWidget,
      );
      expect(_prefs(h)?.myCity, isFalse);
      expect(_switch(tester, 'New deals in your city'), isFalse);
    });

    testWidgets('a failed save comes back as it was, with a note', (
      tester,
    ) async {
      final backend = _Backend()..failUpdates = true;
      final h = await _app(
        tester,
        at: '/settings/notifications',
        auth: await _signedIn(),
        backend: backend,
      );
      await _tap(tester, 'New deals in your city');
      expect(find.text("Couldn't save that. Try again."), findsOneWidget);
      expect(_prefs(h)?.myCity, isTrue);
      expect(_switch(tester, 'New deals in your city'), isTrue);
    });
  });

  group('Privacy', () {
    testWidgets('clear recent searches, then saved copies of deals', (
      tester,
    ) async {
      final h = await _app(tester, at: '/settings/privacy');
      await h.container.read(recentSearchesProvider.notifier).add('karahi');
      h.store.values['cache.home'] = '{}';
      expect(find.text('Delete account'), findsNothing, reason: 'a guest');

      await _tap(tester, 'Clear recent searches');
      expect(h.container.read(recentSearchesProvider), isEmpty);
      expect(jsonDecode(h.store.values[recentSearchesKey]!), isEmpty);
      expect(find.text('Cleared.'), findsOneWidget);

      await _tap(tester, 'Clear saved copies of deals');
      expect(h.store.values.containsKey('cache.home'), isFalse);
    });

    testWidgets('clear this phone: asks first, then signs out and starts '
        'fresh', (tester) async {
      final h = await _app(
        tester,
        at: '/settings/privacy',
        auth: await _signedIn(),
      );
      expect(find.text('Delete account'), findsOneWidget);
      h.store.values['anything'] = 'x';

      await _tap(tester, 'Clear everything on this phone');
      expect(find.text('Clear this phone?'), findsOneWidget);
      await _tap(tester, 'Cancel');
      expect(h.auth.currentUser, isNotNull);
      expect(h.store.values, isNotEmpty);

      await _tap(tester, 'Clear everything on this phone');
      await _tap(tester, 'Clear');
      expect(h.auth.currentUser, isNull);
      expect(h.store.values, isEmpty);
      expect(h.preferences, const ShopperPreferences());
      expect(find.byType(LanguageStep), findsOneWidget);
    });

    testWidgets('signed in, Delete account opens its page', (tester) async {
      await _app(tester, at: '/settings/privacy', auth: await _signedIn());
      await _tap(tester, 'Delete account');
      expect(find.byType(DeleteAccountScreen), findsOneWidget);
    });
  });

  group('Legal', () {
    testWidgets('the English terms', (tester) async {
      await _app(tester, at: '/settings/legal/terms');
      expect(find.text('Terms of use'), findsWidgets);
      expect(find.textContaining('Last updated'), findsOneWidget);
    });

    testWidgets('the Urdu privacy policy', (tester) async {
      await _app(
        tester,
        at: '/settings/legal/privacy',
        locale: AppLocales.urdu,
      );
      expect(find.byType(LegalScreen), findsOneWidget);
      expect(find.textContaining('آخری بار اپ ڈیٹ'), findsOneWidget);
    });

    testWidgets('a text that fails to load says so', (tester) async {
      final h = Harness(
        saved: const ShopperPreferences(onboarded: true, cityId: karachiId),
        overrides: [
          legalTextProvider.overrideWith(
            (ref, key) => Future<String>.error(StateError('missing')),
          ),
        ],
      );
      await h.pump(tester);
      h.router.go('/settings/legal/terms');
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('an unknown document goes to Settings', (tester) async {
      await _app(tester, at: '/settings/legal/cookies');
      expect(find.byType(LegalScreen), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('About', () {
    setUp(
      () => PackageInfo.setMockInitialValues(
        appName: 'Sale Lagi Hai!',
        packageName: 'pk.salelagihai.app',
        version: '1.2.3',
        buildNumber: '45',
        buildSignature: '',
      ),
    );

    testWidgets('the version, contact us, and the licences', (tester) async {
      final links = _Links();
      await _app(tester, at: '/settings/about', links: links);
      expect(find.text('Version 1.2.3 (45)'), findsOneWidget);
      await _tap(tester, 'Contact us');
      expect(links.calls, ['email help@salelagihai.pk']);
      await _tap(tester, 'Open-source licences');
      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('no support address: no Contact us', (tester) async {
      await _app(
        tester,
        at: '/settings/about',
        config: const AppConfig(
          flavor: Flavor.dev,
          appName: 'SLH',
          supabaseUrl: '',
          supabasePublishableKey: '',
        ),
      );
      expect(find.text('Contact us'), findsNothing);
    });
  });

  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'Sale Lagi Hai!',
      packageName: 'pk.salelagihai.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    ),
  );

  testWidgets('the app bar grows with a tall title; at 100% it is the usual '
      'height (QA 4.9-V1)', (tester) async {
    await _app(tester, at: '/settings/notifications');
    expect(tester.getSize(find.byType(AppBar)).height, kToolbarHeight);

    await _app(tester, at: '/settings/notifications', locale: AppLocales.urdu);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(AppBar));
    final title = tester.getRect(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Text)),
    );
    expect(bar.height, greaterThan(kToolbarHeight));
    expect(title.top, greaterThanOrEqualTo(bar.top));
    expect(title.bottom, lessThanOrEqualTo(bar.bottom));
  });

  for (final locale in AppLocales.supported) {
    for (final (name, at, signedIn) in [
      ('settings', '/settings', false),
      ('notifications', '/settings/notifications', true),
      ('notifications (guest)', '/settings/notifications', false),
      ('privacy', '/settings/privacy', true),
      ('terms', '/settings/legal/terms', false),
      ('about', '/settings/about', false),
    ]) {
      testWidgets('${locale.languageCode} $name: guidelines, and 200% text '
          'without overflow', (tester) async {
        final handle = tester.ensureSemantics();
        await _app(
          tester,
          at: at,
          locale: locale,
          auth: signedIn ? await _signedIn() : null,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        tester.view.physicalSize = const Size(360, 800) * 2;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
