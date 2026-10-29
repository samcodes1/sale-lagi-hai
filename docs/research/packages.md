# Recommended pub.dev packages: Sale Lagi Hai!

**Verified on 29 Oct 2026, 08:12 UTC** against the pub.dev API (`/api/packages/<name>` for the latest version and pubspec, `/options` for the discontinued flag, `/score` for points, tags and licence). The changelogs and READMEs were read on pub.dev. "Published" is the date of the latest version. Points are pub points out of 160.

**Toolchain:** Flutter 3.47.8 stable / Dart 3.13.7 (`/opt/flutter`). Constraints below use caret ranges on the verified versions. Commit `pubspec.lock`.

## 1. Core: state, routing, models, codegen
| Package | Latest | Published | Publisher · License · Points | Purpose | Notes |
|---|---|---|---|---|---|
| flutter_riverpod | **3.4.3** | 2026-09-03 | dash-overflow.net · MIT · 140 | State management and DI | Riverpod 3: auto-retry, `Ref.mounted`, paused listeners, `ProviderContainer.test`. Mutations and offline persistence are under `…/experimental/` |
| riverpod_annotation | **4.0.7** | 2026-09-03 | dash-overflow.net · MIT · 130 | `@riverpod` annotations | Pairs exactly with riverpod 3.4.3 |
| riverpod_generator (dev) | **4.0.9** | 2026-09-03 | dash-overflow.net · MIT · 130 | Provider codegen | Recommended because we already run codegen. Requires `build` < 5 (see §7) |
| riverpod_lint (dev) | **3.1.9** | 2026-09-03 | (unverified publisher) · MIT · 130 | Riverpod lints and assists | Now an **analysis_server_plugin**: configure it under `plugins:` in `analysis_options.yaml`. `custom_lint` is no longer needed. Needs Dart ≥ 3.13 |
| go_router | **18.1.1** | 2026-10-20 | flutter.dev · BSD-3 · 150 · Flutter Favorite | Routing, redirects, deep links, shell routes | 18.0 **migrated to material_ui/cupertino_ui** and needs Flutter ≥ 3.44. Has `onEnter` (16.3+) and route `metadata` (17.5) |
| go_router_builder (dev) | **4.5.2** | 2026-10-19 | flutter.dev · BSD-3 · 160 | Typed routes | The generated mixin is `$RouteName` (`with $DealRoute`). Option `duplicate_route_paths: error`. Requires Flutter ≥ 3.47 and `build` < 5 |
| freezed (dev) | **4.0.3** | 2026-10-17 | dash-overflow.net · MIT · 160 · Flutter Favorite | Immutable models and unions | 4.0 supports Dart 3.13 primary constructors. Verified syntax: `const factory ({…}) = _X;` and `factory fromJson(…)` |
| freezed_annotation | **3.1.0** | 2025-07-02 | dash-overflow.net · MIT · 150 | Annotations | Still 3.1.0. freezed 4.0.3 pins exactly `freezed_annotation: 3.1.0` |
| json_serializable (dev) | **6.15.2** | 2026-10-20 | google.dev · BSD-3 · 160 · Flutter Favorite | JSON codegen | Configure `field_rename: snake` in `build.yaml` |
| json_annotation | **4.12.0** | 2026-05-15 | google.dev · BSD-3 · 150 | JSON annotations | |
| build_runner (dev) | latest **2.17.1** (2026-10-14) → **use 2.16.2** | | tools.dart.dev · BSD-3 · 160 | Runs the codegen | **Pin `^2.16.2`.** 2.17.x needs `build` 5, which conflicts with riverpod_generator 4.0.9, go_router_builder 4.5.2 and envied_generator 1.3.10 (verified by `pub get`) |
| material_ui | **1.8.0** | 2026-10-20 | flutter.dev · BSD-3 · 160 | The Material library, **now a package** | It replaces `package:flutter/material.dart` (frozen in 3.44, 1.0 in 3.47, deprecation planned for the November stable). Migrate with `dart fix --apply --code=migrate_design_widgets`. `MaterialUiCompatibilityBridge` exists for dependencies that haven't migrated, and is itself `@Deprecated` |
| cupertino_ui | **1.1.4** | 2026-10-20 | flutter.dev · BSD-3 · 160 | The Cupertino library as a package | Only if we use iOS-style widgets (iOS comes later) |

## 2. Backend, push, notifications
| Package | Latest | Published | Publisher · License · Points | Purpose | Notes |
|---|---|---|---|---|---|
| supabase_flutter | **2.18.3** | 2026-10-12 | supabase.io · MIT · 150 | Supabase client (Auth, PostgREST, Storage, Realtime, Functions) | Use `Supabase.initialize(publishableKey: …)`; `anonKey` is `@Deprecated`. PKCE is the default. Use `FlutterAuthClientOptions.localStorage` for secure session storage, and `detectSessionInUriPredicate` to filter deep links. **3.0.0-dev.14** is in progress with many breaking changes; stay on 2.x until 3.0 is stable |
| firebase_core | **5.1.0** | 2026-10-23 | firebase.google.com · BSD-3 · 160 · Flutter Favorite | Firebase bootstrap | Needed for FCM only. No Firebase Auth or Firestore |
| firebase_messaging | **17.0.1** | 2026-10-23 | firebase.google.com · BSD-3 · 160 · Flutter Favorite | FCM push | The background handler must be a top-level function with `@pragma('vm:entry-point')`. Send pushes from an Edge Function through the FCM HTTP v1 API |
| flutter_local_notifications | **22.3.3** | 2026-10-25 | dexterx.dev · BSD-3 · 150 · Flutter Favorite | Channels, foreground display, scheduled "remind me" | 22.3 added `openAppNotificationSettings()` and dismiss callbacks |
| timezone / flutter_timezone | **0.11.2** / **5.1.1** | 2026-10-12 / 2026-10-03 | labs.dart.dev · BSD-2 / wolverinebeach.net · Apache-2.0 | Zoned scheduling (Asia/Karachi) | Needed for scheduled local notifications |
| cronet_http | **1.10.1** | 2026-10-26 | dart.dev · BSD-3 · 160 | Platform HTTP stack on Android | Optional, only if platform-enforced TLS settings or pinning are ever needed. Dart's `HttpClient` ignores NSC pin-sets |

## 3. Device, platform, storage
| Package | Latest | Published | Publisher · License · Points | Purpose | Notes |
|---|---|---|---|---|---|
| flutter_secure_storage | **11.2.0** | 2026-09-16 | steenbakker.dev · BSD-3 · 160 | Keystore/Keychain secrets (the session) | v11 **removed `encryptedSharedPreferences`** and the old ciphers. minSdk 24. Upgrade through v10 if you're coming from ≤9. Has `checkUpgradeStatus()` |
| shared_preferences | **2.5.6** | 2026-10-05 | flutter.dev · BSD-3 · 160 · Flutter Favorite | Non-sensitive preferences | Never put tokens here. Prefer the `SharedPreferencesAsync`/`WithCache` APIs |
| drift + drift_flutter | **2.35.3** + **0.3.1** | 2026-10-23 / 2026-07-11 | simonbinder.eu · MIT · 160 · Flutter Favorite | Offline cache and outbox (SQLite) | drift_flutter now uses `sqlite3` 3.x (native build hooks). **`sqlite3_flutter_libs` is `0.6.0+eol`: remove it** |
| cached_network_image | **4.0.5** | 2026-10-21 | baseflow.com · MIT · 150 | Image caching | 4.0 line is active again; depends on material_ui |
| geolocator | **14.1.2** | 2026-10-19 | baseflow.com · MIT · 160 · Flutter Favorite | Approximate or precise location | Request coarse first; no background location |
| permission_handler | **13.0.2** | 2026-09-04 | baseflow.com · MIT · 160 | Permission status, rationale, settings deep link | Use it for status checks and the settings link. The notification permission itself can go through firebase_messaging or flutter_local_notifications |
| url_launcher | **6.3.3** | 2026-10-02 | flutter.dev · BSD-3 · 160 · Flutter Favorite | Custom Tabs, tel:, geo:, mailto: | `LaunchMode.inAppBrowserView` for web content. Allowlist schemes |
| share_plus | **13.3.1** | 2026-10-01 | fluttercommunity.dev · BSD-3 · 140 · Flutter Favorite | Share a deal | 13.x needs Flutter ≥ 3.38.1 and built-in Kotlin support (AGP 9) |
| app_links | **7.2.2** | 2026-10-06 | cow-level.ovh · Apache-2.0 · 160 | App Links and custom-scheme handling | Disable Flutter's own handler (`flutter_deeplinking_enabled=false`) so there's one entry point. supabase_flutter already depends on app_links (`>=6.4.1 <8.0.0`) |
| connectivity_plus | **7.3.2** | 2026-10-01 | fluttercommunity.dev · BSD-3 · 160 · Flutter Favorite | Network-interface hint | Reports interfaces, not internet. 7.3 adds `hasConnectivity()`. Treat request failure as the truth |
| package_info_plus / device_info_plus | **10.2.2** / **13.3.0** | 2026-10-01 | fluttercommunity.dev · BSD-3 · 150 | Version for the force-update check and Sentry | |
| in_app_update | **5.0.0** | 2026-07-04 | jonasbark.de · MIT · 160 | Play in-app updates (MASVS CODE-2) | Android only |
| in_app_review | **2.0.12** | 2026-05-15 | britannio.dev · MIT · 160 | Rating prompt after a success moment | |

## 4. UI helpers, l10n, assets
| Package | Latest | Published | Publisher · License · Points | Purpose | Notes |
|---|---|---|---|---|---|
| intl | **0.20.3** | 2026-06-25 | dart.dev · BSD-3 · 160 · Flutter Favorite | Number and date formatting, ICU messages | The `ur` locale uses Western digits by default; Urdu digits need mapping. Pin with `any` or match `flutter_localizations` |
| flutter_localizations | SDK | (Flutter 3.47.8) | flutter.dev | `gen-l10n` | Not on pub.dev. With material_ui, `GlobalMaterialLocalizations.delegates` comes from material_ui. Keep `flutter_localizations` until generated l10n no longer imports it |
| skeletonizer | **3.0.0** | 2026-09-11 | codeness.ly · MIT · 160 | Skeleton loading from real widgets | **Preferred over shimmer** for skeletons. 3.0 broke the API: `SkeletonizerConfigData` is no longer a `ThemeExtension`; use `SkeletonizerConfig(data:)`, `effectResolver` and `boneResolver` |
| shimmer | **4.0.0** | 2026-08-21 | hunghd.dev · BSD-3 · 160 | Shimmer effect | Revived; 4.0 migrated to material_ui. Use it only if a bespoke shimmer is needed. Turn it off under reduce motion |
| flutter_native_splash (dev) | **2.4.8** | 2026-05-29 | jonhanson.net · MIT · 150 · Flutter Favorite | Native splash, including the Android 12+ splash API | Configure `android_12:`. The brand icon and background come from `design/` |
| flutter_launcher_icons (dev) | **0.14.4** | 2025-06-10 | fluttercommunity.dev · MIT · 150 | Launcher icons (adaptive and monochrome) | No release in 16 months but stable. You can also hand-author the adaptive and themed icons from `design/app-icon` (brand-identity skill) |
| google_fonts | **9.0.0** | 2026-09-28 | flutter.dev · BSD-3 · 160 · Flutter Favorite | Font helper | **We bundle fonts offline instead.** If it's used at all, set `GoogleFonts.config.allowRuntimeFetching = false` and ship the files. 9.0 migrated to material_ui and added the tree-shakable `GoogleFontsLite` |
| flutter_svg | **2.3.2** | 2026-10-28 | flutter.dev · Flutter Favorite | SVG icons and illustrations | Published the day before this check, so pub points weren't computed yet (0/0) |
| infinite_scroll_pagination | **5.1.1** | 2025-08-28 | edsonbueno.com · MIT · 150 · Flutter Favorite | Optional paged-list controller | A plain `SliverList` + Riverpod cursor notifier is enough; only adopt it if it saves code |

## 5. Logging, monitoring
| Package | Latest | Published | Publisher · License · Points | Purpose | Notes |
|---|---|---|---|---|---|
| logging | **1.3.0** | 2024-10-17 | dart.dev · BSD-3 · 160 | **Chosen logger facade** | First party and stable (no release needed). supabase_flutter already logs through it |
| sentry_flutter | **10.2.0** | 2026-10-22 | sentry.io · MIT · 150 · Flutter Favorite | Crash and error reporting, performance | Use `sendDefaultPii: false` and scrub in `beforeSend`. Session Replay off or masked. Upload `--split-debug-info` symbols (sentry_dart_plugin). 10.2's network-type feature asks for `READ_PHONE_STATE` on Android ≤11; strip it with `tools:node="remove"` |
| sentry_logging | **10.2.0** | 2026-10-22 | sentry.io · MIT · 160 | Forwards `package:logging` records to Sentry | |
| talker / talker_flutter | **5.2.0** | 2026-10-24 | frezycode.com · MIT · 160 | Optional in-app log console for the dev flavor | Has `talker_riverpod_logger` 5.2.0. Never in prod builds |
| logger | **2.8.0** | 2026-09-05 | sourcehorizon.org · MIT · 150 | Pretty console logger | Not needed if we use `logging` |

## 6. Lints and testing
| Package | Latest | Published | Publisher · License · Points | Purpose | Notes |
|---|---|---|---|---|---|
| very_good_analysis (dev) | **11.0.0** | 2026-09-03 | verygood.ventures · MIT · 160 | **Chosen lint set** | Dart 3.13 rules: `use_declaring_parameters`, `unnecessary_type_name_in_constructor`, `empty_container_bodies`, automatic trailing commas. Needs Dart ^3.13 |
| flutter_lints (dev) | 6.0.0 | 2025-05-27 | flutter.dev · BSD-3 · 160 | The Flutter team's baseline | Not used, because VGA is stricter |
| mocktail (dev) | **1.0.5** | 2026-04-10 | felangel.dev · MIT · 160 | Mocks without codegen | |
| mocktail_image_network (dev) | **1.3.0** | 2026-04-12 | felangel.dev · MIT · 160 | `Image.network` in widget tests | Replaces the stale `network_image_mock` (2022) |
| alchemist (dev) | **0.14.1** | 2026-10-08 | betterment.dev · MIT · 150 | Golden tests (CI and platform variants) | Maintained (0.14 added `diffThreshold`). **It hasn't migrated to material_ui**: its internal `MaterialApp` is the old library. Host material_ui widgets in `Localizations(GlobalMaterialLocalizations.delegates) + Theme + Material` (verified fix) |
| patrol (dev) | **4.10.0** | 2026-09-15 | leancode.co · Apache-2.0 · 140 | Integration tests with native UI (permission dialogs, notifications) | Optional, on top of SDK `integration_test` |
| integration_test | SDK | | flutter.dev | End-to-end tests | Use the **SDK** package (`sdk: flutter`). The pub.dev `integration_test` 1.0.2+3 is an old, discontinued stub |
| build_verify (dev) | **3.1.1** | 2025-06-13 | kevmoo.com · MIT · 160 | Asserts committed codegen is fresh | Or use `git diff --exit-code` in CI |
| very_good_cli | **1.5.0** | 2026-09-08 | verygood.ventures · MIT · 150 | `very_good test --min-coverage` and the template | Optional |

## 7. Config ("secrets") and why none of these are secret
| Package | Latest | Published | Publisher · License · Points | Notes |
|---|---|---|---|---|
| envied / envied_generator | **1.3.10** / **1.3.10** | 2026-09-28 | cinibulk.dev · MIT · 160 | It compiles `.env` values into Dart constants. `@EnviedField(obfuscate: true)` only XOR-obfuscates; the README says it "does NOT make them completely secure". **Not needed:** `--dart-define-from-file` already gives typed compile-time config. Either way, only public values (Supabase URL, publishable key, Sentry DSN) may go in. envied_generator also requires `build` < 5 |
| flutter_dotenv | 6.0.1 | 2026-04-21 | (unverified) · MIT · 160 | It ships `.env` as a plain **asset** inside the APK, which is even more exposed. Don't use it |

## 8. Discontinued, abandoned or replaced (avoid) → 2026 replacements
| Package | Status (pub.dev, 2026-10-29) | Use instead |
|---|---|---|
| golden_toolkit 0.15.0 | **Discontinued** (last release Feb 2023, Dart < 3 constraint) | **alchemist** 0.14.1, or plain `matchesGoldenFile` |
| uni_links 0.5.1 | **Discontinued**, replaced by app_links | **app_links** 7.2.2 |
| firebase_dynamic_links 6.1.10 | **Discontinued**; the service shut down on 25 Aug 2025 | Verified **App Links** + our own `https://salelagihai.pk/d/<id>` pages |
| intl_utils 2.8.17 | **Discontinued** | Flutter's built-in `gen-l10n` (`l10n.yaml`, `generate: true`) |
| sqlite3_flutter_libs | `0.6.0+eol` (no-op) | `sqlite3` 3.x (bundled through build hooks) via drift_flutter |
| hive 2.2.3 | Unmaintained since 2022 (Dart < 3) | **drift** for structured data, or **hive_ce** 2.22.0 if key-value is enough |
| isar 3.1.0+1 | Abandoned (2023; ~4k downloads/30 days) | **drift** |
| dartz 0.10.1 | Unmaintained (2021, Dart < 3) | Dart 3 sealed classes (our `Result`), or fpdart 1.2.0 if FP is wanted |
| custom_lint 0.8.1 | No longer needed for riverpod_lint 3 (analysis_server_plugin) | `plugins:` in `analysis_options.yaml` |
| flutter_inappwebview 6.1.5 | No release since Oct 2024, 130 points | `url_launcher` Custom Tabs, or `webview_flutter` 4.14.1 (flutter.dev) if a WebView is unavoidable |
| `package:flutter/material.dart` (SDK) | Frozen since 3.44; deprecation planned for the November 2026 stable | **material_ui** 1.8.0 |

## 9. Suggested `pubspec.yaml` block (for the lib/ owner to adopt)
```yaml
environment:
  sdk: ^3.13.7

dependencies:
  flutter: { sdk: flutter }
  flutter_localizations: { sdk: flutter }
  material_ui: ^1.8.0
  flutter_riverpod: ^3.4.3
  riverpod_annotation: ^4.0.7
  go_router: ^18.1.1
  freezed_annotation: ^3.1.0
  json_annotation: ^4.12.0
  supabase_flutter: ^2.18.3
  firebase_core: ^5.1.0
  firebase_messaging: ^17.0.1
  flutter_local_notifications: ^22.3.3
  flutter_secure_storage: ^11.2.0
  shared_preferences: ^2.5.6
  drift: ^2.35.3
  drift_flutter: ^0.3.1
  cached_network_image: ^4.0.5
  intl: ^0.20.3
  geolocator: ^14.1.2
  permission_handler: ^13.0.2
  url_launcher: ^6.3.3
  share_plus: ^13.3.1
  app_links: ^7.2.2
  connectivity_plus: ^7.3.2
  package_info_plus: ^10.2.2
  logging: ^1.3.0
  sentry_flutter: ^10.2.0
  sentry_logging: ^10.2.0
  skeletonizer: ^3.0.0
  flutter_svg: ^2.3.2
  timezone: ^0.11.2
  in_app_update: ^5.0.0
  in_app_review: ^2.0.12

dev_dependencies:
  flutter_test: { sdk: flutter }
  integration_test: { sdk: flutter }
  build_runner: ^2.16.2          # NOT 2.17 until generators allow build 5
  freezed: ^4.0.3
  json_serializable: ^6.15.2
  riverpod_generator: ^4.0.9
  go_router_builder: ^4.5.2
  drift_dev: ^2.35.2              # allows build >=3 <6 and drift <2.36
  riverpod_lint: ^3.1.9           # configured under `plugins:` in analysis_options.yaml
  very_good_analysis: ^11.0.0
  mocktail: ^1.0.5
  mocktail_image_network: ^1.3.0
  alchemist: ^0.14.1
  flutter_native_splash: ^2.4.8
  flutter_launcher_icons: ^0.14.4
```
The codegen stack (freezed 4.0.3, json_serializable 6.15.2, riverpod_generator 4.0.9, go_router_builder 4.5.2, envied_generator 1.3.10 and build_runner 2.16.2) resolves together and was verified with `pub get` + `build_runner build` on Dart 3.13. `drift_dev` 2.35.2 (published 2026-10-23, 110 pub points) allows `build` 3–5, so it fits the 2.16.2 runner. It wasn't part of the codegen run, so confirm it when you add it.

## 10. How to re-verify (repeatable)
```bash
for p in go_router freezed supabase_flutter; do
  curl -s https://pub.dev/api/packages/$p | jq -r '"\(.name) \(.latest.version) \(.latest.published)"'
  curl -s https://pub.dev/api/packages/$p/options   # {"isDiscontinued":…, "replacedBy":…}
done
```
Before adding a new package, check: verified publisher, `isDiscontinued: false`, a release within 12 months (or a documented reason it's stable), an acceptable licence (no GPL), its native permissions, and whether it imports material_ui or the old library.

## Sources
- pub.dev package pages, changelogs and READMEs read for: [material_ui](https://pub.dev/packages/material_ui), [go_router changelog](https://pub.dev/packages/go_router/changelog), [go_router_builder changelog](https://pub.dev/packages/go_router_builder/changelog), [freezed](https://pub.dev/packages/freezed/changelog), [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage/changelog), [cached_network_image](https://pub.dev/packages/cached_network_image/changelog), [shimmer](https://pub.dev/packages/shimmer/changelog), [skeletonizer](https://pub.dev/packages/skeletonizer/changelog), [google_fonts](https://pub.dev/packages/google_fonts/changelog), [very_good_analysis](https://pub.dev/packages/very_good_analysis/changelog), [alchemist](https://pub.dev/packages/alchemist/changelog), [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications/changelog), [share_plus](https://pub.dev/packages/share_plus/changelog), [connectivity_plus](https://pub.dev/packages/connectivity_plus/changelog), [sentry_flutter](https://pub.dev/packages/sentry_flutter/changelog), [envied](https://pub.dev/packages/envied), [app_links](https://pub.dev/packages/app_links), [sqlite3_flutter_libs](https://pub.dev/packages/sqlite3_flutter_libs), [firebase_dynamic_links](https://pub.dev/packages/firebase_dynamic_links), [supabase_flutter API](https://pub.dev/documentation/supabase_flutter/latest/)
- pub.dev JSON API: `https://pub.dev/api/packages/<pkg>`, `/options`, `/score` (queried 2026-10-29 08:12 UTC)
- [Flutter: migrate to material_ui and cupertino_ui](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui) and [What's new in Flutter 3.47](https://flutter.dev/blog/whats-new-in-flutter-3-47) (read through the flutter/website source)
- [riverpod_lint README](https://github.com/rrousselGit/riverpod/blob/master/packages/riverpod_lint/README.md), [supabase_flutter CHANGELOG (3.0.0-dev)](https://github.com/supabase/supabase-flutter/blob/main/packages/supabase_flutter/CHANGELOG.md)
