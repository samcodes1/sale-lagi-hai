---
name: qa-testing
description: QA engineer's playbook for Sale Lagi Hai! It explains how to run and judge the sub-phase and full-phase gates. Covers static analysis, unit/widget/golden tests and coverage thresholds, visual QA of the Flutter web build in headless Chromium with Playwright (phone sizes, RTL/Urdu, dark mode, 200% text, semantics), accessibility matchers (meetsGuideline), security checks, Supabase migration and RLS testing (pgTAP or plain SQL on a local Postgres), exploratory charters, bug reports with S1–S4 severity, gate criteria, and report templates. Use it whenever you act as QA or run a gate.
---

# QA playbook: Sale Lagi Hai!

**Process owner:** `.claude/agents/qa-engineer.md`. **Gates:** `docs/DEVELOPMENT_PLAN.md` §3.

**Tools in this skill:**
- `scripts/web_visual_qa.js`: Playwright screenshots, console, network and semantics checks (verified against a Flutter 3.47.8 web build).
- `scripts/run_sql_rls_tests.sh` + `scripts/sql/`: migrations, schema lint and RLS tests on a throwaway Postgres 16. No Docker needed; it self-tests green.

**References:**
- [references/test-recipes.md](references/test-recipes.md): a11y tests, goldens with alchemist + material_ui, RTL and text scale, Riverpod overrides, flaky-test rules.
- [references/exploratory-charters.md](references/exploratory-charters.md).
- [references/templates.md](references/templates.md): bug report and QA report.

## 0. Principles
- **Be independent and skeptical.** Only trust what you ran: record the command, its exit code and the key output lines. "It looked fine" is not evidence.
- **You don't fix product code.** You add tests under `test/qa/`, plus screenshots and reports under `docs/qa/`. Bugs get file:line and a suggested fix.
- **Never weaken a gate:** no lowering lints or thresholds, no deleting or skipping tests, no `--update-goldens` to make a diff disappear without review.
- **Setup:** `export PATH=/opt/flutter/bin:$PATH`. Copy `env/<flavor>.example.json` to `env/<flavor>.json` if it's missing (example values only).

## 1. Sub-phase gate: steps and pass criteria
| # | Step | Command | Pass criterion |
|---|---|---|---|
| 1 | Deps resolve | `flutter pub get` | Exit 0. **Read the advisory output**: any security advisory is ≥S2 unless it's documented in `ignored_advisories` |
| 2 | Codegen fresh | `dart run build_runner build -d && git status --porcelain` | No diff in `*.g.dart`/`*.freezed.dart`/l10n |
| 3 | Format | `dart format --output=none --set-exit-if-changed lib test` | Exit 0 |
| 4 | Analyze | `flutter analyze` | `No issues found!`, with zero infos too. Any new `// ignore:` needs a reason comment |
| 5 | Tests | `flutter test --coverage` (plus `--tags golden` if they're separated) | 100% pass. A skipped test needs a written reason |
| 6 | Coverage | Parse `coverage/lcov.info` (excluding generated files) | Changed or new files ≥ **80%** lines; `features/*/domain/**` + `features/*/application/**` ≥ **90%** |
| 7 | Test quality | Read the tests | Every test asserts behaviour (not just "pumps without error"). Error, empty and edge paths are covered. Add `test/qa/` tests for gaps and run them |
| 8 | Visual QA (if there's UI) | §3 | No overflow, clipping, wrong mirroring, low contrast or console errors; no unexpected external hosts |
| 9 | Accessibility | §4 | Guideline tests on every new screen pass; 200% text has no overflow |
| 10 | Security | §5 | All applicable checklist items PASS |
| 11 | Backend (if DB) | §6 | Migrations apply from zero; RLS role matrix and schema lint pass |
| 12 | Exploratory | 2–3 charters (references/exploratory-charters.md) | Findings logged as bugs |
| 13 | Report | `docs/qa/<phase>.<sub>.md` (templates.md) | Written, with evidence |

**Verdict:** **FAIL** if any S1 or S2 bug is open, if any step 1–6 or 9–11 fails, or if coverage is below threshold. **PASS** otherwise. Open S3 and S4 bugs are listed and carried forward; they don't block.

## 2. Full-phase gate (adds to the above, for the whole phase)
- **Regression:** run *all* tests in the repo (unit, widget, golden, SQL, Edge Function) from a clean checkout: `git clean -xfd -e env/`, `flutter pub get`, codegen, then the tests.
- **Integration:** `flutter test integration_test` on an emulator if available. Otherwise run the web-build flows with Playwright, and note that the Android run is CI-only. Write the missing cross-sub-phase flows; at minimum:
  - onboarding → feed → deal → save;
  - deep link → deal;
  - offline → cached → reconnect;
  - language switch → RTL.
- **Performance sanity:**
  - `flutter build apk --analyze-size` / `flutter build web --release` sizes, compared with the previous phase (flag >10% growth).
  - Rebuild storms: use `debugPrintRebuildDirtyWidgets` or the DevTools rebuild counts on the feed.
  - Unbounded lists: no `ListView(children:)` for data.
  - Image cache bounds.
  - Feed query `EXPLAIN ANALYZE` for backend phases.
- **Bookkeeping:** every sub-phase report for the phase is PASS, its S1 and S2 bugs are verified fixed (retest them), and S3s are triaged.
- Write the report to `docs/qa/phase-<n>-final.md`, including the widget gallery screenshotted in all modes (Phase 1).

## 3. Visual QA with the web build (Playwright + headless Chromium)
Chromium is pre-installed. `require('playwright')` works from any directory, and `chromium.launch()` needs no options. **Never run `playwright install`.**

```bash
flutter build web --release --no-web-resources-cdn --dart-define-from-file=env/dev.json
node .claude/skills/qa-testing/scripts/web_visual_qa.js --dir build/web \
  --out docs/qa/screens/<phase>.<sub> --routes "/,/gallery" \
  --sizes 360x800,412x915 --themes light,dark --locales en-PK,ur-PK --text-scale 1,2 --semantics
```
- **Verified emulation:**
  - **Dark mode:** `colorScheme`, which `ThemeMode.system` follows.
  - **Urdu/RTL:** the `locale` context sets `navigator.language`; Flutter picks `ur` and mirrors the UI.
  - **200% text:** a root font-size of 32px; Flutter web derives `TextScaler` from it.
  - **Reduced motion.**
  - If the app persists a user-chosen locale or theme, ask engineering for a dev-flavor hook that reads `?qa_locale=&qa_theme=&qa_text_scale=`. The script already appends these parameters.
- **`--no-web-resources-cdn` bundles CanvasKit locally,** so the build works offline and reproducibly. The script reports every external host contacted.
  - **`fonts.gstatic.com` means the app fell back to downloading Noto fonts at runtime** (a glyph is missing from bundled fonts). That's an S3 bug against the "fonts bundled offline" rule (verified: a build without bundled Urdu fonts triggers it).
- **`--semantics`** activates Flutter's web semantics tree (`flt-semantics-placeholder`). It dumps role, name and size per node, and flags unlabeled buttons and targets under 48px. These are *hints*; confirm with the widget-test guidelines (§4).
- **Exit code:** 1 if any shot has console or page errors or failed to load.
- **Look at every screenshot with Read.** Check:
  - overflow stripes (yellow/black), and clipped Nastaliq (dots or descenders cut off);
  - truncated labels;
  - wrong mirroring: chevrons and back arrows must flip, while logos, digits, checkmarks and media controls must not;
  - contrast in dark mode, safe-area overlap, and inconsistent spacing;
  - FAB and bottom-nav placement in RTL.
- **Limits:** the web build isn't Android. Platform channels (FCM, secure storage, location) are stubbed or unavailable. Fonts render through CanvasKit, and text-scale behaviour on Android 14+ is non-linear while web scaling is linear. Treat web visual QA as layout evidence, and note anything that needs on-device confirmation.

## 4. Accessibility checks (authoritative: widget tests)
```dart
testWidgets('DealScreen meets a11y guidelines (en + ur, light + dark)', (tester) async {
  final handle = tester.ensureSemantics();
  for (final locale in [const Locale('en'), const Locale('ur')]) {
    await tester.pumpApp(const DealScreen(dealId: 'd1'), locale: locale, overrides: fakes);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));   // ≥48×48
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));       // ≥44×44
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));   // tappables have labels
    await expectLater(tester, meetsGuideline(textContrastGuideline));       // 4.5:1 / 3:1 large
  }
  handle.dispose();
});
```
- Also test **200% text**: `tester.platformDispatcher.textScaleFactorTestValue = 2.0` at 360×800 (`tester.view.physicalSize = const Size(720, 1600); tester.view.devicePixelRatio = 2;`). Assert `tester.takeException()` is null, so there's no overflow.
- **Semantics assertions:**
  - `expect(tester.getSemantics(find.byType(DealCard)), matchesSemantics(label: …, isButton: true, hasTapAction: true))`;
  - headings use `isHeader: true`;
  - live regions are set on banners.
- `textContrastGuideline` only checks text it can resolve. Also review non-text contrast (icons, borders, focus) against `design/tokens/contrast-report.md`.
- **Manual (full-phase gate):** run TalkBack through the five core flows on a device or emulator, and use Android Accessibility Scanner. Record the result or the reason it couldn't be done.

## 5. Security checks per sub-phase
Run the items of `flutter-secure-dev/references/security-review-checklist.md` that apply. Quick commands:
```bash
git grep -nE 'sb_secret_|service_role|BEGIN (RSA|EC|PRIVATE)' -- . ':!*.md'          # must be empty
git ls-files env/ ; git check-ignore -v --no-index env/dev.json env/dev.json.bak .env  # only examples tracked
grep -rnE "\bprint\(|debugPrint\(" lib --include=*.dart                                # logger only
grep -rn "http://" lib --include=*.dart                                                # https only
grep -nE 'exported|allowBackup|usesCleartextTraffic|networkSecurityConfig|dataExtractionRules' android/app/src/main/AndroidManifest.xml
flutter pub get 2>&1 | grep -i advisor                                                 # pub advisories
osv-scanner scan source --lockfile=pubspec.lock   # if installed; otherwise note "CI only"
```
- **Logging:** grep the log calls for phone, email, token and location variables, and run the redaction unit tests.
- **Deep links:** feed hostile URIs into the parser tests (`../`, `%2e%2e`, other hosts, `javascript:`, extremely long values).
- **Release-like build (where an SDK is available):** confirm `--obfuscate --split-debug-info` and grep `strings` of `libapp.so` for secrets.

## 6. Supabase migrations and RLS
**Option A, the full stack (Docker available):** `supabase start`, then `supabase db reset` (applies every migration from zero plus the seed; it must be clean twice in a row, so the seed is idempotent), then `supabase test db` (pgTAP in `supabase/tests/`) and `supabase db lint`.

**Option B, plain Postgres (this container: Postgres 16 binaries, no Docker):**
```bash
.claude/skills/qa-testing/scripts/run_sql_rls_tests.sh --self-test            # proves the harness works
.claude/skills/qa-testing/scripts/run_sql_rls_tests.sh \
  --migrations supabase/migrations --tests supabase/tests/sql                # real migrations + tests
```
- The harness creates a throwaway cluster and loads `00_supabase_stub.sql`, which provides the `anon`/`authenticated`/`service_role` roles, `auth.uid()`/`auth.jwt()`/`auth.role()` (same bodies as Supabase), `auth.users`, and the `qa.*` assertion helpers.
- It applies the migrations in order, runs `10_schema_lint.sql`, and then runs each `*.test.sql`.
- **The schema lint fails on:**
  - a table without RLS;
  - a `security definer` function without `search_path`;
  - an anon-executable definer function in `public`;
  - anon write grants;
  - views without `security_invoker`;
  - policies using `user_metadata`.
- **Write tests per table** (see `scripts/sql/example_rls.test.sql`):
  - `qa.as_anon()` / `qa.as_user(uid, '{"user_role":"moderator","aal":"aal2"}')`;
  - `qa.throws(sql, '42501', msg)` for missing grants and `with check` failures;
  - `qa.ok(qa.count(sql) = n, msg)` for filtered reads;
  - `qa.dml_count('update … returning 1') = 0` for silently filtered writes;
  - rate-limit cases.
  - Cover **allow and deny for anon, a plain user, an owner or member, a moderator and an admin**, for each of select, insert, update and delete.
- **Limits:** Supabase-only extensions (PostGIS from `extensions`, pg_cron, pg_net), storage policies and auth hooks need Option A. Mark those tests "CI only" in the report rather than skipping them silently.

## 7. Bugs and severity
| Sev | Definition | Examples here |
|---|---|---|
| **S1** | Crash, data loss or security hole | A secret key in the APK; a table without RLS; a user can edit another business's deal; PII in logs; crash on launch or in a core flow |
| **S2** | A core flow is broken (no workaround) | Can't save a deal; deep link opens the wrong deal; push tap does nothing; Urdu layout unusable; the Android build fails |
| **S3** | Wrong behaviour with a workaround | Wrong expiry formatting; filter count off; a runtime font fetch; a missing empty state; a 44dp target |
| **S4** | Cosmetic | 2dp misalignment; inconsistent icon weight; copy typo |

- **Escalate one level** when the bug affects accessibility for screen-reader users in a core flow (an S3 label bug on "Save" becomes S2), or affects all Urdu users.
- **Each bug records:** ID, severity, title, environment (flavor, commit, device or viewport, locale, theme, text scale), steps, expected, actual, evidence (screenshot path, log excerpt, failing test), file:line, and a suggested fix. Format: references/templates.md.

## 8. Report and reply
- Write `docs/qa/<phase>.<sub>.md` or `docs/qa/phase-<n>-final.md` using the template. Include the commit hash, toolchain versions, the gate table with evidence, coverage, bugs, tests added, screenshots and non-blocking recommendations.
- **Final reply:** the verdict, bug counts per severity, one line per top bug, and the report path.

## Sources
- Flutter (read through the flutter/website source): [Accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing) (meetsGuideline and the web semantics debug flag), [Assistive technologies](https://docs.flutter.dev/ui/accessibility/assistive-technologies) (web semantics enabling), [Web initialization config](https://docs.flutter.dev/platform-integration/web/initialization), [Web building](https://docs.flutter.dev/platform-integration/web/building), [Testing overview](https://docs.flutter.dev/testing/overview), [Integration tests](https://docs.flutter.dev/testing/integration-tests)
- Flutter SDK 3.47.8 (local): `flutter_test` guideline constants, and `flutter_tools` `--web-resources-cdn` (negatable flag)
- Supabase (read through supabase/supabase docs source): [Testing your database](https://supabase.com/docs/guides/database/testing), [RLS (policy test files, `request.jwt.claim.sub`)](https://supabase.com/docs/guides/database/postgres/row-level-security), [Advanced pgTAP](https://supabase.com/docs/guides/local-development/testing/pgtap-extended)
- WCAG 2.2 (w3c/wcag source): [1.4.3](https://www.w3.org/TR/WCAG22/#contrast-minimum), [1.4.4](https://www.w3.org/TR/WCAG22/#resize-text), [2.5.8](https://www.w3.org/TR/WCAG22/#target-size-minimum)
- `docs/DEVELOPMENT_PLAN.md` §3 and `.claude/agents/qa-engineer.md` (gates and severities); `docs/qa/1.1.md` (house style for reports)
- Local verification: `web_visual_qa.js` run against a Flutter 3.47.8 web build (dark mode, `ur-PK` RTL, text scale 2, semantics, and runtime font-fetch detection), and `run_sql_rls_tests.sh` self-test (all pass, plus a deliberately broken grant that fails).
