# Code patterns (compiled and tested on Flutter 3.47.8, Dart 3.13, VGA 11)

Every snippet in §1–§4 and §8 was compiled with `flutter analyze` (VGA 11 + riverpod_lint, 0 errors) and the tests pass. Adapt the names, but keep the shapes.

## 1. Result
```dart
/// Outcome of an operation that can fail with a typed Failure.
sealed class Result<T> {
  const new();
  const factory ok(T value) = Ok<T>;
  const factory err(Object failure, [StackTrace? stackTrace]) = Err<T>;
}

final class Ok<T> extends Result<T> {
  const new(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const new(this.failure, [this.stackTrace]);
  final Object failure;
  final StackTrace? stackTrace;
}

extension ResultX<T> on Result<T> {
  /// For use inside Riverpod providers: Err becomes AsyncError with the typed failure.
  T unwrap() => switch (this) {
    Ok(:final value) => value,
    Err(:final failure, :final stackTrace) =>
      Error.throwWithStackTrace(failure, stackTrace ?? StackTrace.current),
  };
}
```

## 2. Failure (freezed union)
```dart
@freezed
sealed class Failure with _$Failure implements Exception {
  const factory network() = NetworkFailure;
  const factory unauthorized() = UnauthorizedFailure;
  const factory notFound() = NotFoundFailure;
  const factory rateLimited({Duration? retryAfter}) = RateLimitedFailure;
  const factory unexpected(Object error) = UnexpectedFailure;
}

// presentation/failure_l10n.dart
extension FailureMessage on Failure {
  String message(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorOffline,
    UnauthorizedFailure() => l10n.errorSignInAgain,
    NotFoundFailure() => l10n.errorNotFound,
    RateLimitedFailure() => l10n.errorTooManyRequests,
    UnexpectedFailure() => l10n.errorGeneric,
  };
}
```

## 3. Gateway → repository → provider
```dart
/// Thin wrapper over the Supabase client so repositories are testable (don't mock the query builder).
abstract interface class FeedGateway {
  Future<List<Map<String, Object?>>> rpc(String fn, Map<String, Object?> args);
}

abstract interface class FeedRepository {
  Future<Result<List<Deal>>> fetch({required String city, String? cursor});
}

final class SupabaseFeedRepository implements FeedRepository {
  const new(this._gateway);
  final FeedGateway _gateway;
  static final _log = Logger('SupabaseFeedRepository');

  @override
  Future<Result<List<Deal>>> fetch({
    required String city,
    String? cursor,
  }) async {
    try {
      final rows = await _gateway
          .rpc('feed', {'p_city': city, 'p_cursor': cursor})
          .timeout(const Duration(seconds: 10));
      return Result.ok(rows.map(Deal.fromJson).toList());
    } on SocketException {
      return const Result.err(Failure.network());
    } on TimeoutException {
      return const Result.err(Failure.network());
    } on Object catch (e, st) {
      _log.warning('feed failed', e, st); // message has no PII
      return Result.err(Failure.unexpected(e), st);
    }
  }
}

@Riverpod(keepAlive: true)
FeedGateway feedGateway(Ref ref) =>
    throw UnimplementedError('overridden in bootstrap');

@Riverpod(keepAlive: true)
FeedRepository feedRepository(Ref ref) =>
    SupabaseFeedRepository(ref.watch(feedGatewayProvider));

@riverpod
class Feed extends _$Feed {
  @override
  Future<List<Deal>> build({required String city}) async =>
      (await ref.watch(feedRepositoryProvider).fetch(city: city)).unwrap();

  Future<void> refresh() async {
    final result = await ref.read(feedRepositoryProvider).fetch(city: city);
    if (!ref.mounted) return; // Riverpod 3: never touch a disposed notifier
    state = switch (result) {
      Ok(:final value) => AsyncData(value),
      Err(:final failure, :final stackTrace) =>
        AsyncError(failure, stackTrace ?? StackTrace.current),
    };
  }
}
```
In the real data layer, add the Supabase exception mapping in the `catch` chain: `PostgrestException` (`code`), `AuthException`, `StorageException` and `FunctionException` → `Failure`.

## 4. Unit test with ProviderContainer.test + mocktail
```dart
import 'package:flutter_riverpod/misc.dart' show ProviderException;

class _MockGateway extends Mock implements FeedGateway; // Dart 3.13 empty body

void main() {
  late _MockGateway gateway;
  setUp(() => gateway = _MockGateway());

  ProviderContainer makeContainer() => ProviderContainer.test(
    overrides: [feedGatewayProvider.overrideWithValue(gateway)],
    retry: (_, _) => null, // disable Riverpod 3 auto-retry in tests
  );

  test('socket errors become Failure.network', () async {
    when(() => gateway.rpc('feed', any())).thenThrow(const SocketException('x'));
    final c = makeContainer();
    final sub = c.listen(feedProvider(city: 'lahore'), (_, _) {}); // keep auto-dispose alive
    await expectLater(
      c.read(feedProvider(city: 'lahore').future),
      throwsA(isA<NetworkFailure>()), // .future rethrows the raw error
    );
    expect(sub.read().error, isA<NetworkFailure>());
    expect(() => sub.read().requireValue, throwsA(isA<ProviderException>()));
  });
}
```

## 5. Widget test helper (sketch)
For text-scale tests, set `tester.platformDispatcher.textScaleFactorTestValue = 2.0` (and reset it with `addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue)`) so the real `TextScaler` path is exercised.
```dart
extension PumpApp on WidgetTester {
  Future<void> pumpApp(
    Widget child, {
    List<Override> overrides = const [],
    Locale locale = const Locale('en'),
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: overrides,
        retry: (_, _) => null,
        child: MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: themeMode,
          home: child,
        ),
      ),
    );
  }
}
```

## 6. Router provider (sketch)
```dart
@Riverpod(keepAlive: true)
GoRouter router(Ref ref) {
  final auth = ValueNotifier<AuthSnapshot>(ref.read(authSnapshotProvider));
  ref
    ..listen(authSnapshotProvider, (_, next) => auth.value = next)
    ..onDispose(auth.dispose);
  final router = GoRouter(
    routes: $appRoutes,
    refreshListenable: auth,
    redirect: (context, state) {
      final s = auth.value;
      if (!s.onboarded && !state.matchedLocation.startsWith('/onboarding')) {
        return const OnboardingRoute().location;
      }
      if (s.signedOut && state.topRoute?.name == 'requiresAuth') {
        return SignInRoute(from: state.uri.toString()).location;
      }
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
  );
  ref.onDispose(router.dispose);
  return router;
}
```
Typed route classes use `with $XRoute` (the generated mixin), with a `const new({required this.id})` constructor and `build(context, state)`. Run `dart run build_runner build -d`.

## 7. AppConfig validation (allowlist, not denylist)
```dart
static String validatePublishableKey(String key) {
  if (key.startsWith('sb_publishable_')) return key;
  final parts = key.split('.');
  if (parts.length == 3) {
    final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map;
    if (payload['role'] == 'anon') return key;      // legacy anon JWT (deprecated end of 2026)
  }
  throw const ConfigException('SUPABASE_PUBLISHABLE_KEY must be a publishable/anon key');
}
```
Pair this with a CI step that fails the build if any `env/*.json` matches `sb_secret_|service_role`. The runtime check alone runs after the secret is already compiled in.

## 8. Logging with redaction (verified with `dart run`)
```dart
final _rules = <(RegExp, String Function(Match))>[
  (RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+'), (_) => '<jwt>'),
  (RegExp(r'sb_(publishable|secret)_[\w-]+'), (_) => '<key>'),
  (RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), (_) => '<email>'),
  (RegExp(r'(?:\+92|0092|\b0)3\d{2}[\s-]?\d{7}\b'), (_) => '<phone>'),
  (RegExp(r'(-?\d{1,3}\.\d{2})\d+'), (m) => m.group(1)!), // coordinates → 2 decimals (~1 km)
];

String redact(String input) =>
    _rules.fold(input, (acc, rule) => acc.replaceAllMapped(rule.$1, rule.$2));
// 'call 0300 1234567 or +923001234567' → 'call <phone> or <phone>'
// 'at 31.520370, 74.358749'            → 'at 31.52, 74.35'

void setupLogging({required bool release}) {
  Logger.root.level = release ? Level.INFO : Level.ALL;
  Logger.root.onRecord.listen((r) {
    if (!release) debugPrintSynchronously('[${r.loggerName}] ${redact(r.message)}');
  });
  // In release, sentry_logging's LoggingIntegration forwards records. Redact in Sentry's
  // beforeSend/beforeBreadcrumb with the same redact() so both paths are covered.
}
```
Unit-test `redact` with real-looking Pakistani numbers (`0300 1234567`, `+923001234567`), emails, JWTs and coordinates.
