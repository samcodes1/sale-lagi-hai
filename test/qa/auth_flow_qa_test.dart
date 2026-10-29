// QA (sub-phase 4.2 gate): auth flows the developer's tests don't cover.
// The real app on the demo backend (onboarding harness), with a spy around
// the demo sign-in to count calls and hold requests in flight.
//
// "QA BUG" tests fail until the bug in docs/qa/4.2.md is fixed; S4
// findings are skipped with their bug id.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/device/notification_permission.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/presentation/delete_account_screen.dart';
import 'package:sale_lagi_hai/features/auth/presentation/sign_in_screen.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/domain/shopper_preferences.dart';
import 'package:sale_lagi_hai/features/profile/presentation/profile_screen.dart';

import '../features/onboarding/onboarding_harness.dart';
import '../helpers/fakes.dart';

final _brand = brandBySlug('demo-karahi-house')['id']! as String;

/// Wraps the demo sign-in: counts calls, records who each deletion was
/// for, and can hold a code check in flight.
final class SpyAuth implements AuthRepository {
  new(this.inner);

  final DemoAuthRepository inner;
  int codesSent = 0;
  int codeChecks = 0;
  final deletedIds = <String>[];
  Completer<void>? holdVerify;

  /// When set, deletion fails with it (the server said no).
  AppFailure? deleteFailure;

  @override
  AppUser? get currentUser => inner.currentUser;

  @override
  Stream<AppUser?> userChanges() => inner.userChanges();

  @override
  bool get canUseGoogle => inner.canUseGoogle;

  @override
  Future<Result<void>> sendPhoneCode(String e164) {
    codesSent++;
    return inner.sendPhoneCode(e164);
  }

  @override
  Future<Result<AppUser>> verifyPhoneCode(String e164, String code) async {
    codeChecks++;
    final result = await inner.verifyPhoneCode(e164, code);
    await holdVerify?.future;
    return result;
  }

  @override
  Future<Result<AppUser?>> signInWithGoogle() => inner.signInWithGoogle();

  @override
  Future<Result<void>> signOut() => inner.signOut();

  @override
  Future<Result<DeletionOutcome>> deleteAccount() async {
    if (deleteFailure case final failure?) return Failure(failure);
    final who = inner.currentUser?.id;
    final result = await inner.deleteAccount();
    if (result case Success(value: DeletionOutcome.deleted)) {
      deletedIds.add(who!);
    }
    return result;
  }
}

/// A backend whose guest-sync call fails; counts calls to it.
final class SyncCountingGateway implements BackendGateway {
  new({this.failSync = false});

  final bool failSync;
  final _demo = DemoGateway();
  int syncCalls = 0;

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) =>
      _demo.select(query);

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) async {
    if (function == 'sync_guest_preferences') {
      syncCalls++;
      if (failSync) throw const OfflineFailure();
    }
    return await _demo.rpc(function, params);
  }

  @override
  Future<void> insert(String table, Map<String, Object?> row) =>
      _demo.insert(table, row);

  @override
  Future<void> delete(String table, Map<String, Object?> match) =>
      _demo.delete(table, match);
}

/// The onboarding harness's app, with the spy as the auth repository.
final class QaHarness {
  new({required this.auth, required this.backend, required this.saved});

  final SpyAuth auth;
  final BackendGateway backend;
  final ShopperPreferences saved;
  final store = InMemoryKeyValueStore();
  late ProviderContainer container;

  GoRouter get router => container.read(routerProvider);
  ShopperPreferences get preferences => container.read(preferencesProvider);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 915) * 2;
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
        deviceLocaleProvider.overrideWithValue(AppLocales.english),
        keyValueStoreProvider.overrideWithValue(store),
        loggerProvider.overrideWithValue(AppLogger(sinks: [])),
        savedPreferencesProvider.overrideWithValue(saved),
        locationServiceProvider.overrideWithValue(
          FakeLocation(const Located(24.8138, 67.03)),
        ),
        notificationPermissionProvider.overrideWithValue(
          FakeAlerts(AlertPermission.granted),
        ),
        authRepositoryProvider.overrideWithValue(auth),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
  }
}

({QaHarness h, SpyAuth auth, SyncCountingGateway backend}) _setUp({
  DateTime Function()? clock,
  bool failSync = false,
}) {
  final auth = SpyAuth(DemoAuthRepository(clock: clock));
  final backend = SyncCountingGateway(failSync: failSync);
  return (
    h: QaHarness(
      auth: auth,
      backend: backend,
      saved: ShopperPreferences(
        onboarded: true,
        cityId: karachiId,
        brandIds: [_brand],
      ),
    ),
    auth: auth,
    backend: backend,
  );
}

Future<void> _pump(WidgetTester tester, QaHarness h, SpyAuth spy) =>
    h.pump(tester);

Future<void> _tap(WidgetTester tester, String text) => tapText(tester, text);

Future<void> _toCodeStep(WidgetTester tester, QaHarness h, String phone) async {
  h.router.go('/profile');
  await tester.pumpAndSettle();
  await _tap(tester, 'Sign in');
  await tester.enterText(find.byType(TextField), phone);
  await _tap(tester, 'Send code');
  expect(find.text('Enter the code'), findsOneWidget);
}

Future<void> _confirmDelete(WidgetTester tester) async {
  await _tap(tester, 'Delete account');
  await _tap(tester, 'Delete my account');
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete my account'),
    ),
  );
  await tester.pumpAndSettle();
}

/// Confirms deletion from the delete page itself.
Future<void> _confirmDelete2(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(FilledButton));
  await tester.tap(find.byType(FilledButton));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete my account'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('auto-submit at six digits plus Enter checks the code once', (
    tester,
  ) async {
    final s = _setUp();
    await _pump(tester, s.h, s.auth);
    await _toCodeStep(tester, s.h, '03001234567');
    s.auth.holdVerify = Completer<void>();
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    s.auth.holdVerify!.complete();
    await tester.pumpAndSettle();
    expect(s.auth.codeChecks, 1);
    expect(s.auth.currentUser, isNotNull);
    expect(s.backend.syncCalls, 1, reason: 'guest sync runs once');
  });

  testWidgets('a guest-sync failure still signs in, and keeps the choices', (
    tester,
  ) async {
    final s = _setUp(failSync: true);
    await _pump(tester, s.h, s.auth);
    await _toCodeStep(tester, s.h, '03001234567');
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();
    expect(s.backend.syncCalls, 1);
    expect(s.auth.currentUser, isNotNull);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(s.h.preferences.brandIds, [_brand]);
  });

  testWidgets('an expired code is refused; a new code then works', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 29, 12);
    final s = _setUp(clock: () => now);
    await _pump(tester, s.h, s.auth);
    await _toCodeStep(tester, s.h, '03001234567');
    now = now.add(const Duration(minutes: 11));
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'That code is wrong or has expired. Check it, or send a new one.',
      ),
      findsOneWidget,
    );
    expect(s.auth.currentUser, isNull);
    await tester.pump(resendWait);
    await tester.pumpAndSettle();
    await _tap(tester, 'Send a new code');
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();
    expect(s.auth.currentUser, isNotNull);
  });

  testWidgets('too many codes shows the rate-limit message, not a crash', (
    tester,
  ) async {
    final s = _setUp();
    for (var i = 0; i < 5; i++) {
      await s.auth.inner.sendPhoneCode('+923001234567');
    }
    await _pump(tester, s.h, s.auth);
    s.h.router.go('/profile');
    await tester.pumpAndSettle();
    await _tap(tester, 'Sign in');
    await tester.enterText(find.byType(TextField), '0300 1234567');
    await _tap(tester, 'Send code');
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Enter the code'), findsNothing);
    expect(tester.takeException(), isNull);
    // Some message is shown in the live region under the form.
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.liveRegion ?? false),
      ),
      findsOneWidget,
    );
  });

  testWidgets('declining the fresh sign-in keeps the account, and the delete '
      'button works again', (tester) async {
    var now = DateTime.utc(2026, 10, 29, 12);
    final s = _setUp(clock: () => now);
    await _pump(tester, s.h, s.auth);
    await _toCodeStep(tester, s.h, '03001234567');
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();
    now = now.add(const Duration(minutes: 10));
    await _confirmDelete(tester);
    expect(find.text("Confirm it's you"), findsOneWidget);
    // Back out of the re-sign-in.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(s.auth.currentUser, isNotNull);
    expect(s.auth.deletedIds, isEmpty);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('the fresh sign-in before deletion does not run guest sync', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 29, 12);
    final s = _setUp(clock: () => now);
    await _pump(tester, s.h, s.auth);
    await _toCodeStep(tester, s.h, '03001234567');
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();
    expect(s.backend.syncCalls, 1);
    now = now.add(const Duration(minutes: 10));
    await _confirmDelete(tester);
    await _tap(tester, 'Send code');
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();
    expect(s.backend.syncCalls, 1);
    expect(s.auth.deletedIds, hasLength(1));
  });

  testWidgets('a server failure while deleting says so, keeps the account '
      "and this phone's data, and allows a retry", (tester) async {
    final s = _setUp();
    await _pump(tester, s.h, s.auth);
    await _toCodeStep(tester, s.h, '03001234567');
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();
    s.auth.deleteFailure = const ServerFailure(statusCode: 500);
    await _confirmDelete(tester);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(
      find.text('Something went wrong on our side. Try again in a minute.'),
      findsOneWidget,
    );
    expect(s.auth.currentUser, isNotNull);
    expect(s.h.preferences.onboarded, isTrue);
    expect(s.h.preferences.brandIds, [_brand]);
    // Retry once the server is back.
    s.auth.deleteFailure = null;
    await _confirmDelete2(tester);
    expect(s.auth.deletedIds, hasLength(1));
    expect(s.h.preferences, const ShopperPreferences());
  });

  // QA BUG 4.2-A2 (S2): the fresh sign-in before deletion accepts ANY
  // account. The number is prefilled but editable (and Google is offered
  // to phone users); whoever signs in, the retry deletes *them*. The
  // shopper who asked keeps their account and data, while the app clears
  // this phone and says "Your account was deleted."
  // delete_account_screen.dart:65-71, sign_in_screen.dart:156-165.
  testWidgets('QA BUG 4.2-A2: re-signing in as someone else must not delete '
      'that other account', (tester) async {
    var now = DateTime.utc(2026, 10, 29, 12);
    final s = _setUp(clock: () => now);
    await _pump(tester, s.h, s.auth);
    await _toCodeStep(tester, s.h, '03001234567');
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();
    final original = s.auth.currentUser!.id;
    now = now.add(const Duration(minutes: 10));
    await _confirmDelete(tester);
    expect(find.text("Confirm it's you"), findsOneWidget);
    // A different number in the prefilled field.
    await tester.enterText(find.byType(TextField), '0333 7654321');
    await _tap(tester, 'Send code');
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pumpAndSettle();
    expect(
      s.auth.deletedIds.every((id) => id == original),
      isTrue,
      reason: 'deleted ${s.auth.deletedIds} but the request was for $original',
    );
  });

  // QA BUG 4.2-A3 (S3): leaving the sign-in page while the code is being
  // checked still signs in (the server accepted the code), but the guest
  // choices are never synced and nothing says so
  // (sign_in_screen.dart:119, `if (!mounted) return;` before _signedIn).
  testWidgets('QA BUG 4.2-A3: backing out while the code is checked still '
      'syncs the guest choices', (tester) async {
    final s = _setUp();
    await _pump(tester, s.h, s.auth);
    await _toCodeStep(tester, s.h, '03001234567');
    s.auth.holdVerify = Completer<void>();
    await tester.enterText(find.byType(TextField), DemoAuthRepository.code);
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    s.auth.holdVerify!.complete();
    await tester.pumpAndSettle();
    expect(s.auth.currentUser, isNotNull, reason: 'signed in on the server');
    expect(s.backend.syncCalls, 1, reason: 'guest choices synced');
  });

  // QA BUG 4.2-A5 (S4): two taps on "Send code" in one frame send two
  // SMS codes (`_sendCode` has no `_busy` guard, sign_in_screen.dart:76).
  testWidgets('QA BUG 4.2-A5: a double tap on Send code sends one code', (
    tester,
  ) async {
    final s = _setUp();
    await _pump(tester, s.h, s.auth);
    s.h.router.go('/profile');
    await tester.pumpAndSettle();
    await _tap(tester, 'Sign in');
    await tester.enterText(find.byType(TextField), '03001234567');
    final send = find.text('Send code');
    await tester.tap(send);
    await tester.tap(send, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(s.auth.codesSent, 1);
  });

  // QA BUG 4.2-A6 (S4): "Change number" then "Send code" skips the 60 s
  // wait for the same number (the server's own limit still applies).
  testWidgets('QA BUG 4.2-A6: Change number does not reset the resend wait', (
    tester,
  ) async {
    final s = _setUp();
    await _pump(tester, s.h, s.auth);
    await _toCodeStep(tester, s.h, '03001234567');
    await _tap(tester, 'Change number');
    await _tap(tester, 'Send code');
    expect(s.auth.codesSent, 1);
  });

  // QA BUG 4.2-A7 (S4): system Back on the code step leaves sign-in
  // instead of going back to the number.
  testWidgets('QA BUG 4.2-A7: Back on the code step returns to the number', (
    tester,
  ) async {
    final s = _setUp();
    await _pump(tester, s.h, s.auth);
    await _toCodeStep(tester, s.h, '03001234567');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('Sign in to sync'), findsOneWidget);
  });

  // QA BUG 4.2-A8 (S4): the code field says it "never learns" but keeps
  // the keyboard's personalised learning on (sign_in_screen.dart:285).
  testWidgets('QA BUG 4.2-A8: the code field turns off keyboard learning', (
    tester,
  ) async {
    final s = _setUp();
    await _pump(tester, s.h, s.auth);
    await _toCodeStep(tester, s.h, '03001234567');
    final code = tester.widget<TextField>(find.byType(TextField));
    expect(code.enableIMEPersonalizedLearning, isFalse);
  });
}
