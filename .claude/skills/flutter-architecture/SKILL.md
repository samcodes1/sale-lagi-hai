---
name: flutter-architecture
description: How to structure, build and test the Sale Lagi Hai! Flutter codebase. Covers the feature-first layers (presentation/application/domain/data), Riverpod 3 with codegen, go_router 18 typed routes, redirects and deep links, freezed 4 models on Dart 3.13, the repository pattern, sealed Result/Failure errors, logging, flavors with --dart-define-from-file, offline caching, very_good_analysis lints, the testing pyramid (mocktail, alchemist goldens, integration_test), the code-gen workflow, GitHub Actions CI and the definition of done. Use it when adding a feature, a provider, a route, a model or a test, or when changing build/CI.
---

# Flutter architecture playbook: Sale Lagi Hai!

**Deep detail:**
- [references/folder-layout.md](references/folder-layout.md): the full tree and naming.
- [references/code-patterns.md](references/code-patterns.md): Result, repository, notifier, router, config, logger and test snippets.
- [references/ci-github-actions.md](references/ci-github-actions.md): the workflow and code-gen checks.

Package versions are in `docs/research/packages.md`.

## 0. Versions and decisions (verified 29 Oct 2026)
| Concern | Choice | Why |
|---|---|---|
| SDK | Flutter 3.47.8 / Dart 3.13 | Primary constructors and short constructor syntax (`const new(...)`, `factory fromJson(...)`) are stable; very_good_analysis 11 enforces them |
| UI library | `material_ui` 1.8 (`package:material_ui/material_ui.dart`) | The in-SDK Material is frozen and will be deprecated (see flutter-ui-ux §0) |
| State / DI | `flutter_riverpod` 3.4.3 + `riverpod_annotation` 4.0.7 + `riverpod_generator` 4.0.9 | Riverpod's docs advise codegen "only if you already use code generation". We do (freezed), so use it: free family parameters and stateful hot reload |
| Lints | `very_good_analysis` 11.0.0 + `riverpod_lint` 3.1.9 | See §7 |
| Routing | `go_router` 18.1.1 + `go_router_builder` 4.5.2 | Typed routes, redirects, shell routes; the Flutter team recommends it for about 90% of apps |
| Models | `freezed` 4.0.3 + `freezed_annotation` 3.1.0 + `json_serializable` 6.15.2 | Unions, `copyWith`, deep equality. freezed 4 supports Dart 3.13 primary constructors |
| Codegen runner | **`build_runner: ^2.16.2` (2.16.x)** | **build_runner 2.17 requires `build` 5, but riverpod_generator 4.0.9, go_router_builder 4.5.2 and envied_generator 1.3.10 only allow `build` < 5. Don't bump until they do** (verified with `pub get`) |
| Backend client | `supabase_flutter` 2.18.3 (stable) | 3.0 is still `-dev`, with many breaking changes. Don't adopt it before its stable release |

## 1. Layers and the dependency rule
```
presentation  →  application  →  domain  ←  data
 (widgets,        (Riverpod        (entities,     (DTOs, data sources,
  screens,         notifiers =      value objects, repository impls,
  view state)      use-cases)       repo interfaces, Supabase/HTTP/DB)
                                    failures)
```
- **domain** is pure Dart: no Flutter, no Supabase, no JSON. It holds freezed entities, `abstract interface class XRepository`, value objects (`DealId`, `Money`, `CitySlug`) and the `Failure` union.
- **data** implements the domain interfaces. It maps DTOs to entities, maps exceptions to `Failure`, and returns `Result<T>`. It's the only layer that imports `supabase_flutter`, drift or `http`.
- **application** holds Riverpod providers and notifiers. They orchestrate repositories, hold screen state (`AsyncValue`), and run commands (save, report, follow). There are no widgets here.
- **presentation** holds widgets that `ref.watch` application providers. The only logic allowed is show/hide, layout by constraints, animation, and simple routing calls (Flutter architecture guidance).
- **Imports only point inward.** `presentation` never imports `data`. Enforce this with review plus a CI grep (references/ci-github-actions.md). Cross-feature use goes through the other feature's `application` or `domain` public API, never its `data`.
- The domain layer adds value here: our feed ranking, card-offer matching and expiry logic are real business rules. Keep use-case classes thin. A notifier method is a use-case unless the logic is reused, in which case extract a domain service.

## 2. Riverpod 3 rules
1. **Use codegen everywhere:** `@riverpod` functions for derived and read-only values, `@riverpod class X extends _$X` for state with methods. **Generated providers are auto-dispose by default**; use `@Riverpod(keepAlive: true)` only for app-wide singletons (Supabase client, config, router, repositories).
2. **Repositories are providers**, which gives us DI: `@Riverpod(keepAlive: true) DealRepository dealRepository(Ref ref) => SupabaseDealRepository(ref.watch(supabaseClientProvider));`. Tests override them.
3. **`ref.watch` in `build`, `ref.read` in callbacks, `ref.listen` for side effects** (snackbars, navigation). Never `ref.read` a provider inside `build`.
4. **After every `await`, check `if (!ref.mounted) return;`.** Riverpod 3 throws if you use a disposed `Ref` or notifier.
5. **Error wrapping (verified on 3.4.3):**
   - `AsyncValue.error` and `await provider.future` give you the **raw** error (our `Failure`).
   - `asyncValue.requireValue` throws a **`ProviderException`** that wraps it. Import it from `package:flutter_riverpod/misc.dart`.
   - Observers receive `ProviderException` when a provider failed only because one of its *dependencies* failed. Skip those in the `ProviderObserver` so you don't log the same error twice.
6. **Automatic retry is on by default** (200ms doubling to 6.4s). Configure `ProviderScope(retry: …)` to return `null` for `Failure.unauthorized`, validation and 4xx errors, and to cap the number of attempts.
7. **Listeners pause when hidden.** In widgets that aren't visible (`TickerMode` false), listeners are paused. Don't rely on a hidden screen keeping a stream alive.
8. **Families take named parameters.** Parameters must have stable `==`: primitives, records or freezed types. Never pass a `BuildContext` or a mutable object.
9. **Experimental APIs** (`package:riverpod/experimental/mutation.dart` and `persist.dart`, "API may change without a major bump") are allowed **only behind our own wrapper** in `core/`. Our offline cache is drift (§6), not Riverpod persistence.
10. Use `select` to cut rebuilds (`ref.watch(feedProvider.select((s) => s.value?.length))`). Use `AsyncValue` pattern matching with `switch`, and avoid the `when`/`maybeWhen` chains.
11. **Tests:** `ProviderContainer.test(overrides: [...])` disposes itself automatically. Use `overrideWithValue`/`overrideWith`, `NotifierProvider.overrideWithBuild`, and `tester.container()` in widget tests. **Mock repositories, not notifiers.**

## 3. Routing (go_router 18 + go_router_builder 4.5)
- **Use typed routes only.** Write `@TypedGoRoute` on `GoRouteData` classes and navigate with `DealRoute(dealId: id).go(context)`. Raw strings appear only in tests.
  - The generated mixin is **`$DealRoute`** (`with $DealRoute`). The go_router doc page shows `_$DealRoute`, but the builder rejects that (verified).
  - Use `StatefulShellRoute.indexedStack` for the bottom nav (Home, Explore, Alerts, Saved, Profile) so each tab keeps its stack.
  - Set `errorBuilder` (or `onException`) to a localized 404 page that offers Home.
- **The router is a keepAlive provider.** `refreshListenable` is a `ValueNotifier` fed by the auth-state stream. The top-level `redirect` handles: not onboarded → `/onboarding`; signed out on an auth-only route → `/sign-in?from=…`; signed-in staff role for admin routes (portal only).
  - Redirects must be **pure and fast**: read cached state only and never `await` network.
  - Keep `redirectLimit` at its default of 5, and test redirect loops.
- **Deep links:**
  - Platform links arrive through the `DeepLinkService` (flutter-secure-dev §7), which validates and then calls `router.go(typedRoute.location)`.
  - For pushes, use the same parser on the notification `data`.
  - `onEnter` (go_router 16.3+) can block or redirect navigations before they're processed. Use it to reject unknown external locations.
- **Pass IDs, not objects.** Fetch with providers using the ID, so deep links, restoration and the web portals work identically.
- On the web portals, use the path URL strategy (`usePathUrlStrategy()`), and note that Supabase auth redirects need it.

## 4. Models (freezed 4 on Dart 3.13; verified with VGA 11)
```dart
@freezed
abstract class Deal with _$Deal {
  const factory ({                         // unnamed factory: no repeated class name (VGA 11)
    required DealId id,
    required String title,
    @JsonKey(name: 'discount_pct') int? discountPct,
    @Default(false) bool isFeatured,
    DateTime? endsAt,
  }) = _Deal;
  factory fromJson(Map<String, Object?> json) => _$DealFromJson(json);
}

@freezed
sealed class Failure with _$Failure {      // sealed → exhaustive switch
  const factory network() = NetworkFailure;
  const factory unauthorized() = UnauthorizedFailure;
  const factory notFound() = NotFoundFailure;
  const factory rateLimited({Duration? retryAfter}) = RateLimitedFailure;
  const factory validation(Map<String, String> fields) = ValidationFailure;
  const factory unexpected(Object error, [StackTrace? stack]) = UnexpectedFailure;
}
```
- Put `json_serializable` options in `build.yaml` (`field_rename: snake`, `explicit_to_json: true`, `checked: true`) so models stay clean.
- **Keep the DTO and the entity separate** for aggregates that cross the API boundary (Deal, Brand, Outlet, CardOffer). Database column renames then stay in `data/`. Small leaf types can share one freezed class.
- DateTimes are stored and transferred as UTC; convert to Asia/Karachi only in presentation. Money is integer paisa or rupees plus a currency code, never `double`.

## 5. Errors, Result and logging
- **Repositories never throw.** They return `Result<T>` (a sealed `Ok`/`Err` from the Flutter architecture guide). The data layer maps:
  - `PostgrestException` code `42501` or `PGRST3xx` (JWT errors) → `unauthorized`;
  - `PGRST116` → `notFound`;
  - HTTP 420/429 or our `P0429` → `rateLimited`;
  - `SocketException`/`TimeoutException`/`ClientException` → `network`;
  - `AuthException` → `unauthorized`;
  - anything else → `unexpected`, which is logged.
- **Notifiers unwrap:** `Err(:final failure) => throw failure`, so `AsyncValue.error` carries a typed `Failure`. A presentation helper `failure.message(l10n)` maps it to localized copy with no codes.
- **Global error boundary:** `FlutterError.onError` and `PlatformDispatcher.instance.onError` go to Sentry, and an `ErrorWidget.builder` shows a friendly fallback in release.
- **Logging:**
  - `package:logging` loggers per class (`Logger('DealRepository')`).
  - A root handler writes to the console in debug and to Sentry breadcrumbs/events through `sentry_logging` in release, at `Level.INFO` and above.
  - Everything passes a **redactor** (phones, emails, JWTs, keys, precise coordinates; see flutter-secure-dev rule 8).
  - A `ProviderObserver` logs `providerDidFail` except `ProviderException`. `print` is banned by lint.

## 6. Flavors, config and offline caching
- **Flavors** are `dev`, `staging` and `prod`. Each has an Android `productFlavor` (application ID suffix, app name) and an `env/<flavor>.json` passed with `--dart-define-from-file`:
  - contents: `FLAVOR`, `APP_NAME`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SENTRY_DSN`, `DEEP_LINK_HOST`;
  - each flavor points at its own Supabase project.
  - `AppConfig.fromEnvironment()` reads `String.fromEnvironment` and validates (key-format allowlist, URL https, flavor enum).
  - **Cross-check `appFlavor`** (`package:flutter/services.dart`, set by `--flavor`) against the `FLAVOR` define, and fail fast on a mismatch.
  - Expose the config through `appConfigProvider` (keepAlive), overridden in tests.
- **Offline caching (stale-while-revalidate):**
  - The repository first `yield`s cached data from **drift** (SQLite, Flutter Favorite) and then refreshes from Supabase, upserting the cache.
  - The UI shows "Updated X ago". The cache holds public deal data and the user's saves and follows, with a TTL per table, and is cleared on sign-out.
  - Writes (save, follow, report) go into an **outbox table**, flushed on reconnect with idempotency keys. Conflicts resolve as server-wins except for the user's own toggles.
  - `connectivity_plus` is only a *hint* (it reports interfaces, not internet). Treat a failed request as the real signal.
- Images use `cached_network_image` with a size-bounded cache and `memCacheWidth`.

## 7. Lints and static analysis
- **Pick `very_good_analysis` 11** over the plain `flutter_lints` 6. It's a strict superset maintained by VGV, it's Dart 3.13-aware (`use_declaring_parameters`, `unnecessary_type_name_in_constructor`, trailing commas), and the team was asked for strict lints.
  - The only disabled rule is `public_member_api_docs` (this is an app), which the current `analysis_options.yaml` already does.
  - Keep `strict-casts`, `strict-inference` and `strict-raw-types`, and exclude `**/*.g.dart`, `**/*.freezed.dart` and generated l10n.
- **riverpod_lint 3.x is an `analysis_server_plugin`.** It's **no longer `custom_lint`**. Add it to `analysis_options.yaml` as `plugins: { riverpod_lint: ^3.1.9 }` (top level), and `dart analyze`/`flutter analyze` will run it in CI.
- **The gate is `flutter analyze` with zero issues** (including infos) plus `dart format --set-exit-if-changed`. Never add `// ignore:` without a reason comment. Known allowed one: `MaterialUiCompatibilityBridge` is `@Deprecated` by design.

## 8. Testing pyramid
| Level | Tool | What | Target |
|---|---|---|---|
| Unit | `test`/`flutter_test`, **mocktail** 1.0.5, `fake_async`, `clock` | Domain logic (expiry, discount maths, ranking), mappers, repositories (mock the Supabase client wrapper), notifiers through `ProviderContainer.test` | ≥90% lines in `domain/` + `application/` |
| Widget | `flutter_test` + `ProviderScope(overrides:)` | Every screen in loading, data, empty, error and offline states; interactions; a11y guidelines; 200% text; RTL | Every screen and design-system widget |
| Golden | **alchemist** 0.14.1 (`golden_toolkit` is **discontinued**) | The design system and key screens × light/dark × LTR/RTL × text scale | Run CI goldens (Ahem font, platform-independent) on every PR, and platform goldens locally for real-font review |
| Integration | SDK `integration_test` (+ optional **patrol** 4.10 for native permission dialogs and notifications) | Onboarding → feed → deal → save; deep link → deal; offline → reconnect | The critical flows, on the emulator in CI nightly |
| Backend | pgTAP / the SQL harness, Edge Function tests (Deno) | RLS role matrix, RPCs, rate limits | Every table and function |
| Visual and a11y | The web build + Playwright (qa-testing skill) | Phone-size screenshots, RTL, dark, semantics | Every UI sub-phase |

- **Prefer fakes over mocks** for repositories (Flutter's architecture recommendation). Use mocktail for edges (`SupabaseClient` wrappers, HTTP).
  - `registerFallbackValue` for custom types in `setUpAll`.
  - Use `mocktail_image_network` (1.3.0) for `Image.network` in widget tests.
- **Wrap the Supabase SDK** behind our own thin `SupabaseGateway` interface so repositories are testable. Don't mock the fluent query builder.
- **alchemist with material_ui:** alchemist's internal `MaterialApp` comes from the *old* SDK library. Host material_ui widgets in a `Localizations(delegates: GlobalMaterialLocalizations.delegates)` + `Theme` + `Material` wrapper inside each scenario, or they fail with "No MaterialLocalizations found" (verified). See qa-testing.
- Load the real fonts in goldens (Instrument Sans, Noto Nastaliq) for platform goldens, or Nastaliq clipping is invisible.

## 9. Code generation workflow
- Run `dart run build_runner build --delete-conflicting-outputs` once, or `dart run build_runner watch -d` while developing. Then `flutter gen-l10n` (or let `flutter pub get` do it, because `generate: true` is set).
- **Commit generated files** (`*.g.dart`, `*.freezed.dart`, l10n output). Agents and QA can then analyze without running codegen, and diffs are reviewable. CI regenerates and fails on `git diff --exit-code` (the `build_verify` idea).
- **`build.yaml`:**
  - Limit the builders to the folders that need them (`generate_for`), so builds stay fast.
  - `go_router_builder` option `duplicate_route_paths: error`.
  - `json_serializable` defaults (§4).
- Never edit generated files. Never import `*.g.dart` directly; use `part` files.

## 10. Definition of done (every PR or sub-phase)
- [ ] It follows the layer rule; there are no cross-feature `data/` imports; widgets have no business logic.
- [ ] Models are freezed and immutable; there are no `dynamic`s; JSON keys are mapped in `build.yaml`.
- [ ] Repositories return `Result`; every failure path maps to a typed `Failure` with localized copy.
- [ ] Providers: correct keepAlive/auto-dispose; `ref.mounted` after awaits; retry policy respected.
- [ ] Routes are typed; deep links are validated; the back stack is sane; 404 is handled.
- [ ] All strings are in ARB (`en` + `ur`); RTL, dark and 200% text are checked (flutter-ui-ux checklist).
- [ ] Security checklist items for the change are done (flutter-secure-dev §13).
- [ ] Tests: unit + widget (+ golden for UI). Coverage ≥80% on changed files and ≥90% for domain/application. a11y guideline tests are on new screens.
- [ ] `flutter analyze` reports zero issues; `dart format` is clean; codegen is up to date (no diff after build_runner).
- [ ] No new dependency without vetting (docs/research/packages.md updated).
- [ ] The QA sub-phase gate is PASS (qa-testing skill) before commit.

## Sources
- Flutter† (read through the flutter/website source): [Architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations) (the `architectureRecommendations.yml` data), [Result pattern](https://docs.flutter.dev/app-architecture/design-patterns/result), [Offline-first](https://docs.flutter.dev/app-architecture/design-patterns/offline-first), [Flavors](https://docs.flutter.dev/deployment/flavors), [Testing overview](https://docs.flutter.dev/testing/overview), [Accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing), [What's new in 3.47](https://flutter.dev/blog/whats-new-in-flutter-3-47)
- Riverpod† (rrousselGit/riverpod `website/docs`): [What's new in 3.0](https://riverpod.dev/docs/whats_new), [3.0 migration](https://riverpod.dev/docs/3.0_migration), [About code generation](https://riverpod.dev/docs/concepts/about_code_generation), [Testing](https://riverpod.dev/docs/how_to/testing), [riverpod_lint README](https://github.com/rrousselGit/riverpod/blob/master/packages/riverpod_lint/README.md)
- go_router: [CHANGELOG](https://github.com/flutter/packages/blob/main/packages/go_router/CHANGELOG.md), [Type-safe routes](https://github.com/flutter/packages/blob/main/packages/go_router/doc/type-safe-routes.md), [Redirection](https://github.com/flutter/packages/blob/main/packages/go_router/doc/redirection.md), [go_router_builder CHANGELOG](https://github.com/flutter/packages/blob/main/packages/go_router_builder/CHANGELOG.md)
- freezed: [README](https://pub.dev/packages/freezed) (primary constructors on Dart 3.13), [CHANGELOG](https://pub.dev/packages/freezed/changelog); [very_good_analysis CHANGELOG](https://pub.dev/packages/very_good_analysis/changelog); [alchemist CHANGELOG](https://pub.dev/packages/alchemist/changelog); [supabase_flutter CHANGELOG (3.0.0-dev)](https://github.com/supabase/supabase-flutter/blob/main/packages/supabase_flutter/CHANGELOG.md)
- Local verification on Flutter 3.47.8 in the scratchpad: freezed 4 short-syntax codegen with VGA 11 producing 0 issues, go_router_builder's `$Route` mixin, the alchemist + material_ui localization failure and its fix, and the `build_runner` 2.17 vs `build` < 5 conflict found by `pub get`.
