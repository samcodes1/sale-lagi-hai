# QA Report — Phase 1 (App foundation): full-phase gate
Verdict: **PASS**. 0 open S1/S2. Open: **1 S3** (1.4 BUG-2, deferred with an agreed reason) and **15 S4**.

**Conditions carried forward (they don't block this verdict):**
- **The Android build is verified in CI only.** This container's Android SDK has only `cmdline-tools` (no platforms or build-tools), so no APK could be built here. If the first CI `build-android` / `build-android-release` run fails, reopen 1.1 BUG-1 as S2.
- **Run `gitleaks git` once** wherever the binary is allowed, before the first push (from 1.7 round 3). It isn't installed here.
- **1.4 BUG-2 blocks any sub-phase that turns on the Urdu-digits option.** It's open as S3 until then.

## Run details
- Date: 2026-10-29
- Commit: `23d4c56` (detached, `/home/user/slh-qa`), plus QA's uncommitted test and report files listed below.
- Toolchain: Flutter 3.47.8 stable, Dart 3.13.7; Playwright with the pre-installed Chromium; fontTools 4.68 / uharfbuzz 0.57.
- Scope (docs/DEVELOPMENT_PLAN.md, Phase 1 gate): "Full regression, the gallery screenshotted in all modes", plus the full-phase rules in `.claude/agents/qa-engineer.md` (regression of all tests, cross-sub-phase integration tests, performance sanity, every sub-phase PASS with S1/S2 fixed).
- **Out of scope:** `supabase/` and `supabase/functions/` (Phase 2/3). Their tests were not run here.
- **Limits:**
  - No Android device, emulator or SDK platform, so the Android build, TalkBack and Accessibility Scanner couldn't be run (see "Accessibility (manual)").
  - Web is the layout stand-in. High contrast on web was emulated with Chromium `forced-colors: active`, which Flutter web maps to `highContrast`. QA confirmed it by checking the media query and seeing the HC palettes in the shots.

## Gate results
| # | Step | Command | Result | Evidence |
|---|---|---|---|---|
| 1 | Clean-checkout regression | `git clone` into scratch → `git checkout 23d4c56` → `flutter pub get` → `build_runner build -d` + `gen-l10n` → format → analyze → `flutter test --coverage` → coverage → `CI=true flutter test` | **PASS** | Committed tests only: **`+872 ~7`**, all passed. `CI=true`: `+869 ~7`. Codegen: no diff. Format: `124 files (0 changed)`. Analyze: `No issues found!`. Coverage: `97.4% (1687/1732)` |
| 2 | Working-tree regression (with QA's Phase-1 files) | `dart format …`, `flutter analyze`, `flutter test --coverage`, `tool/check_coverage.dart --min 80`, `CI=true flutter test` | **PASS** | Format `125 files (0 changed)`; analyze clean; **`+929 ~8`**, all passed; `CI=true` **`+926 ~8`**; coverage **97.5% (1689/1732)** |
| 3 | Known-bug mode | `flutter test test/qa --dart-define=QA_KNOWN_BUGS=true` | As expected | `524` pass, **6 fail**: exactly the open records (1.3 R2-5 ×4, resolved by policy and kept as a record; 1.4 BUG-2; the new 1.6 S4-5 reproducer). Every other reproducer from 1.1–1.7 runs un-skipped and passes |
| 4 | Bootstrap with real configs | `flutter test test/qa/bootstrap_qa_test.dart --dart-define-from-file=env/{dev,staging,prod}.example.json` | PASS | `+1 ~3` ×3. "SharedPreferencesAsyncPlatform instance must be set" is printed: there's no plugin in unit tests, and `loadStartupSettings` falls back to defaults as designed |
| 5 | Env templates | `dart run tool/check_env.dart env/<f>.example.json --flavor <f> --allow-placeholders` | PASS | Valid ×3. Fails closed as it should: staging/prod without `--allow-placeholders` → exit 1 ("template placeholder"); a flavor mismatch → exit 1; a lower-case placeholder file → exit 1; an unknown flag → usage, exit 1 |
| 6 | Dependency audit | `dart run tool/audit_deps.dart pubspec.lock` and `… --online` | PASS | `Dependency audit passed: 116 packages.` (both). `flutter pub get` shows no advisories |
| 7 | Integration (cross-sub-phase) | `test/qa/phase1_integration_qa_test.dart` (new) | **PASS** | 45 pass, 1 skipped reproducer (1.6 S4-5). See "Integration flows" |
| 8 | Visual QA, all modes | `p1_vqa.js` on `flutter build web --release --no-web-resources-cdn --dart-define-from-file=env/dev.json` | PASS with findings | Gallery + theme preview × en/ur × light/dark × HC on/off × 100%/200% = **32 modes, 232 pages**, 0 console/page errors, **no external hosts** (no runtime font fetch). Findings: none new beyond 1.6 S4-5 |
| 9 | Accessibility (automated) | guideline matchers in integration + sub-phase tests | PASS | Tap target, labelled tap target and text contrast at every scroll stop of both developer pages in all 32 modes, plus the opened bottom sheet. App screens in 8 modes (`shell_a11y_qa_test.dart`) |
| 10 | Performance sanity | release web build sizes; rebuild probes | PASS with notes | See "Performance sanity" |
| 11 | Security (phase) | greps + 1.7 lint tests | PASS | No `sb_secret_`, service_role or private keys outside fixtures. No `print(`/`debugPrint(` calls in `lib/`. No `http://` in `lib/`. Only `env/*.example.json` tracked. The 1.7 `test/security/*` lints pass. Deep linking is off on Android (in `<activity>`) and on iOS. Redaction e2e passes (below) |
| 12 | Bookkeeping | all sub-phase reports | PASS | Table below |

## Sub-phase reports
| Sub-phase | Report | Latest verdict | Open S1/S2 | S1/S2 bugs across rounds, retested now |
|---|---|---|---|---|
| 1.1 Project scaffold | `docs/qa/1.1.md` | PASS (round 2) | 0 | BUG-1 (S2, Android flavor build): code fix verified by reading only; **CI-only** (condition above). The round-2 S4s BUG-8/9/10 are **now fixed**: QA re-ran `check_env` with an unknown flag, a lower-case placeholder file and a reversed argument order, and `ConfigErrorApp` has a title |
| 1.2 Core layer | `docs/qa/1.2.md` | PASS (round 2) + developer fixes | 0 | No S1/S2. The round-2 S3/S4s BUG-18–24 were fixed after round 2. **Retested:** all their reproducers (`round2_qa_test.dart`) run un-skipped and pass, and redaction is verified end to end in the integration test. The condition "fix before Phase 2 auth/Sentry" is now **met** |
| 1.3 Theming | `docs/qa/1.3.md` | PASS (round 2); round-2 S3s resolved in 1.6 | 0 | BUG-1 (S2, Haldi text on light surfaces): **retested**, `theme_component_colors_qa_test.dart` passes. R2-1…R2-8 and BUG-10 were verified in 1.6 round 1. R2-5 is resolved by policy (guard test); its record stays skipped |
| 1.4 Localization & RTL | `docs/qa/1.4.md` | PASS (round 2) | 0 | No S1/S2. BUG-2 (S3) deferred, with QA's agreement |
| 1.5 Navigation shell | `docs/qa/1.5.md` | PASS (round 2) | 0 | No S1/S2 in 1.5. The deep-link flag placement (found as 1.7 BUG-1, S2) is retested here: in `<activity>`, and guarded by QA's tightened test |
| 1.6 Design-system widgets | `docs/qa/1.6.md` | PASS (round 2) + fixes for BUG-8/9 in `23d4c56` | 0 | BUG-1 (S2, card not activatable by screen readers): **retested** in en/ur × 3 sizes, and in the web DOM (`role=button` + `flt-tappable`). **BUG-8 (S3) fixed:** the reproducer runs un-skipped and passes; QA added 12 tests for 100–200% en/ur horizontal (no overflow; vertical above 115%). **BUG-9 (S4) fixed:** reproducer passes |
| 1.7 Security baseline | `docs/qa/1.7.md` | PASS (round 3) + developer fixes for R3-1…R3-5 | 0 | BUG-1 (S2, `flutter_deeplinking_enabled` ignored): **retested**, `router_qa_test.dart` plus the 1.7 manifest lint. The R3 reproducers run un-skipped and pass. The `gitleaks git` history check is still pending (condition) |

## Regression
| Suite | Where | Result |
|---|---|---|
| Unit + widget + golden (committed tests) | clean clone of `23d4c56` | `+872 ~7`. The 7 skips: 2 define-only bootstrap tests, 4 R2-5 records, 1.4 BUG-2 |
| Same, `CI=true` (Ahem goldens only) | clean clone | `+869 ~7` |
| Everything incl. QA's Phase-1 files | `/home/user/slh-qa` | `+929 ~8` (the 8th skip is the 1.6 S4-5 reproducer) |
| Goldens | both | `ci` and `linux` sets pass: theme preview en/ur, gallery en/ur × light/dark + en light HC + ur dark HC |
| SQL / Edge Functions | — | Not in Phase 1 (out of scope) |

## Integration flows
All in `test/qa/phase1_integration_qa_test.dart`. Each boots the real `App` with exactly the overrides `bootstrap()` builds: config, release-mode logger and crash reporter, `loadStartupSettings` store, saved locale, retry policy.

| Flow | Sub-phases | Where run | Result |
|---|---|---|---|
| Saved Urdu + English phone → first frame RTL Urdu → router to Profile → tap English → LTR, saved `en` → "restart" from the same store with an Urdu phone → English | 1.2, 1.4, 1.5 | widget test | PASS |
| Unreadable storage → error logged to the crash reporter → app still boots in the phone language (Urdu, RTL) | 1.2, 1.4 | widget test | PASS |
| prod config → `/profile/dev/gallery` and `/profile/dev/theme` redirect to Profile | 1.1, 1.5 | widget test | PASS |
| **Gallery and theme preview × en/ur × light/dark × HC × 100/200%** (32 tests): checks that each mode really applies (direction, brightness, `highContrastOf`, text scaler); scrolls the whole page; at **every stop**: no exception (overflow) plus tap-target / labelled / text-contrast guidelines; then opens the bottom sheet and re-checks | 1.3, 1.4, 1.5, 1.6 | widget test, 360×800 | **PASS** (contrast is skipped only at stops where the gallery's ErrorView box clips its own retry button: 1.6 S4-5, reproduced separately) |
| Config errors (secret key, service_role JWT, http URL + missing values) → `AppConfigException` → `ConfigErrorApp` lists every problem; neither the UI nor the crash log contains the key, JWT or host; `AppConfig.toString` hides them | 1.1, 1.2 | widget test | PASS |
| Logging redaction e2e (release mode): a widget that throws during build with email, phone, card, JWT and coordinates → `FlutterError.onError` → crash reporter gets only `[email]`-style tokens; `ReleaseErrorWidget` shown, no PII on screen. Uncaught error via `PlatformDispatcher.onError` → handled and redacted. Context maps redacted by key and value. Release logger writes nothing to the console | 1.2 | widget/unit test | PASS |
| Web: language choice persists across a reload (localStorage `slh.settings.locale`) | 1.2, 1.4 | Playwright, release build | PASS (1.4 round 1) |
| Onboarding → feed → deal → save; offline → cached → reconnect; deep link → deal via DeepLinkService | — | — | Not applicable yet (Phases 4–5). The router-level deep link → deal is covered in `router_qa_test.dart` |

Note: flutter_test's `TestPlatformDispatcher.onError` setter is a no-op (`flutter_test/lib/src/window.dart:915-916`), so the dispatcher test uses the real `PlatformDispatcher.instance`, as `error_handlers_test.dart` does.

## Performance sanity
| Metric | 1.1 gate (`24bfb4e`) | 1.3 gate (`01254a8`) | Now (`23d4c56`) | Δ vs 1.3 | Verdict |
|---|---|---|---|---|---|
| Web `main.dart.js` (raw) | 1,930,802 B | 2,603,497 B | **3,278,784 B** | +25.9% | Note (see below) |
| Web `main.dart.js` (gzip -9) | 571,485 B | 763,813 B | **940,671 B** | +23.2% | Note |
| Web `assets/` (fonts, NOTICES, shaders) | 1,498,218 B | 3,512,027 B | **3,412,927 B** | −2.8% | OK (the Latin-free Urdu subset saved about 120 KB) |
| Bundled fonts | — | — | 1.8 MB (Nastaliq 2 × 0.5 MB, Naskh 2 × 0.17 MB, Instrument Sans 4 × 69 KB, Bricolage 2 × 90 KB) | — | OK |
| First-load download (web, Chromium) | — | — | **10.8 MB, 18 files** (canvaskit.wasm 5.4 MB, main.dart.js 3.3 MB, all bundled fonts 1.8 MB, Flutter's local Roboto fallback 172 KB) | — | Note: every Urdu font loads even for English users (web only) |
| APK/AAB size | — | — | not measurable (no Android SDK) | — | CI-only |
| Idle rebuilds (gallery, 2 min) | — | — | only `ExpiryTag` subtrees rebuild (fewer than 12 tag rebuilds) | — | PASS (`phase1_integration_qa_test.dart`) |
| Language switch | — | — | 2,227 element rebuilds (one full-app rebuild); the router instance and current tab are kept | — | PASS, as expected |
| Unbounded lists | — | — | 4 `ListView(children:)` uses, all static pages (Profile, ConfigErrorApp, theme preview, gallery); no data lists yet | — | OK |

- **On the growth:** Phase 1 has no previous phase to compare with, so the sub-phase baselines are given above.
- **What grew:** `main.dart.js` grew 26% between the 1.3 and Phase-1 gates. go_router + typed routes, intl date symbols, the design-system widgets and the **developer pages** (theme preview and gallery, compiled into prod; 1.5 S4-2) account for it. Flagged as more than 10%; not a defect.
- **Recommendations:** tree-shake the dev pages (1.5 S4-2) and add a CI size budget.

## Visual QA: the gallery and theme preview in all modes
- **Where:** `docs/qa/screens/phase-1/<page>_<locale>_<theme>[_hc]_ts<1|2>.png`. 32 files; each is a horizontal strip of the page scrolled top to bottom at 360×800 (DPR 1), quantized to 256 colours, 3.2 MB in total.
- **Coverage:** 2 pages × en-PK/ur-PK × light/dark × HC off/on × 100%/200%; 232 pages in all. 0 console errors, 0 page errors, no external hosts.
- **High contrast** shows: HC light uses deeper Mirch and error reds; HC dark uses the inverse offline banner and a dark-red error banner.
- **What I checked:**
  - mirroring (save button at the end, badges at the start, stepper circles on the right, tabs starting at the right);
  - the isolates ("-40%", "30% فلیٹ رعایت" / "70% تک رعایت");
  - no clipped Nastaliq;
  - the stepper at 200% (circles fit, controls wrap);
  - tabs scrolling at 200%;
  - dark/HC contrast.
- **Only finding:** the known gallery-only S4-5 (the ErrorView sample in a fixed 240dp box clips "دوبارہ کوشش کریں۔" and its button at 200%, e.g. `gallery_ur-PK_light_hc_ts2.png` around page 8).
- Older per-sub-phase shots are in `docs/qa/screens/1.1`–`1.7` (and `1.4/round2`, `1.6/round2`).

## Accessibility (manual)
- **TalkBack and Android Accessibility Scanner:** not possible in this environment (no device or emulator; the SDK has no platforms). **Schedule on device** before Phase 4's core flows.
- **What stands in for them:**
  - the semantics-tree tests (one actionable node per deal card, save as its own node, labelled controls);
  - Flutter web's DOM semantics (`role=button` + `flt-tappable` on cards and save buttons, en and ur);
  - the guideline matchers in all modes.

## Bugs found in this gate
| ID | Sev | Title | file:line | Status |
|---|---|---|---|---|
| 1.6 S4-5 (new evidence) | S4 | The gallery's ErrorView sample sits in a fixed 240dp box. Its content overflows even at 100% (60dp in the test font), so the inner `SingleChildScrollView` becomes a **nested scroll trap**: a drag that starts on it doesn't scroll the page. At 200% Urdu the retry button is clipped, which fails the contrast sampler | `lib/design_system/gallery/widget_gallery_page.dart:118-121` (and `lib/design_system/widgets/message_view.dart:31-33`: any bounded placement scrolls internally) | Open. Reproducer: `phase1_integration_qa_test.dart` "gallery: the ErrorView sample keeps its retry button inside its box". **Fix:** drop the fixed height in the gallery. Recommendation: let `MessageView` take a `scrollable: false` for embedded use, or document "fill the area" |

No S1, S2 or S3 bugs were found in this gate.

## Open bugs after the Phase 1 gate
| ID | Sev | Title | file:line |
|---|---|---|---|
| 1.4 BUG-2 | **S3** (deferred, agreed) | The Urdu-digits option skips the discount badge and relative times | `lib/core/l10n/formatters.dart:38`, `lib/core/l10n/deal_time_labels.dart:29-62` |
| 1.4 S4-1 | S4 | Expiry thresholds and time zone differ between docs and code (72 h kept by decision) | `.claude/skills/flutter-ui-ux/references/deal-patterns.md:46-49` |
| 1.4 S4-2 | S4 | Theme preview's Latin samples are scrambled in RTL | `lib/design_system/gallery/theme_preview_page.dart:192,237` |
| 1.4 S4-4 | S4 | "yesterday" for anything 24–47 h old | `lib/core/l10n/deal_time_labels.dart:49-52,59-62` |
| 1.4 S4-5 | S4 | The phone language is read once (no live follow) | `lib/core/l10n/locale_controller.dart:25-27` |
| 1.4 S4-6 | S4 | Stale "gitignored" comment | `l10n.yaml:2` |
| 1.5 S4-2 | S4 | Developer pages compiled into prod (redirect-guarded) | `lib/app/router/routes.dart:57-58,191-225` |
| 1.5 S4-3 | S4 | No back from a cold-opened unknown link | `lib/app/router/app_router.dart:14` |
| 1.5 S4-4 | S4 | `go()` to a deal from another tab returns to Home | `lib/app/router/routes.dart:33-40` |
| 1.6 S4-1 | S4 | Guard-test patterns are easy to sidestep (`TabBar.secondary(`, code after `//` in a string) | `test/design_system/design_system_guard_test.dart:10-15` |
| 1.6 S4-2 | S4 | Latin content in the Urdu UI inherits Nastaliq line height | `lib/design_system/widgets/content_text.dart:28-39` |
| 1.6 S4-3 | S4 | Badge read as "minus forty percent" | `lib/design_system/widgets/deal_card.dart:106` |
| 1.6 S4-4 | S4 | `MessageView` copy in Naskh, banners in Nastaliq | `lib/design_system/widgets/message_view.dart:43-47` |
| 1.6 S4-5 | S4 | Gallery gaps, plus the ErrorView box scroll trap (above) | `lib/design_system/gallery/widget_gallery_page.dart:118-121` |
| 1.6 S4-6 | S4 | Stepper content and controls 16dp off the title at 200% | `lib/design_system/widgets/app_stepper.dart:44-60` |
| 1.6 BUG-6 residual | S4 | Day count not refreshed at midnight for deals more than 24 h out | `lib/design_system/widgets/deal_labels.dart:126-144` |

Accepted trade-offs (not counted): 1.2 BUG-15 and 1.3 R2-5 (policy, guard test).

## Tests added by QA in this gate
- `test/qa/phase1_integration_qa_test.dart` (new; 45 pass, 1 skipped reproducer):
  - boot → saved locale → router → shell (3);
  - developer pages in 32 modes with per-stop overflow and guideline checks, plus the bottom sheet (32);
  - the S4-5 reproducer (1);
  - config errors → ConfigErrorApp without leaks (4);
  - logging redaction end to end (4);
  - rebuild probes (2).
- `test/qa/round2_widgets_real_fonts_qa_test.dart` (extended): 12 tests for horizontal `AppStepper` at 100/110/115/120/150/200% × en/ur with real fonts, checking the BUG-8 fix around its 115% switch. All pass.

## Recommendations (non-blocking)
- **Before Phase 4:**
  - fix 1.6 S4-3 (the badge's spoken form) and S4-2 (Latin line height in Urdu); real feeds will show them on every card;
  - give `MessageView` a non-scrolling mode for embedded use.
- **Add a CI size budget** for `main.dart.js` (gzip) and tree-shake the developer pages (1.5 S4-2).
- **Web only:** consider deferred font loading for Urdu when the UI is English. Not relevant to the Android APK.
- **Run TalkBack** over Home → Profile → language → gallery deal card on a device, and record the result in the Phase 4 gate.
