# Templates

## Bug report
```markdown
### BUG-<n> (S<1-4>): <short imperative title: what is wrong, where>
- **Area / file:** `lib/features/deal/presentation/deal_card.dart:87` (and related lines)
- **Environment:** commit `<sha>`, flavor `dev`, web build 412×915 | Android API 35 emulator, locale `ur`, theme dark, text scale 2.0
- **Steps to reproduce:**
  1. …
  2. …
- **Expected:** … (cite the rule: flutter-ui-ux §5.2, WCAG 1.4.4, secure-dev rule 3…)
- **Actual:** …
- **Evidence:** `docs/qa/screens/1.6/deal_412x915_dark_ur-PK_ts2.png`, log excerpt or failing test `test/qa/deal_card_qa_test.dart:42`
- **Severity rationale:** why S<n> (and whether it was escalated for a11y/Urdu impact)
- **Suggested fix:** …
- **Regression test:** the test that will guard it (written by QA under `test/qa/` or requested from the developer)
```

## Sub-phase QA report (`docs/qa/<phase>.<sub>.md`)
```markdown
# QA Report — <phase>.<sub> <name>
Verdict: **PASS** | **FAIL** (<n> open S1/S2)

- Date: YYYY-MM-DD
- Commit: `<git rev-parse --short HEAD>` (<commit subject>)
- Toolchain: Flutter <x> stable, Dart <y>; Postgres <v> / Supabase CLI <v> (if used)
- Scope (from docs/DEVELOPMENT_PLAN.md): <deliverables and gate column, quoted>
- Not reviewed / environment limits: <e.g. no Android SDK → Android build verified in CI only>

## Gate results
| # | Step | Command | Result | Evidence |
|---|---|---|---|---|
| 1 | Deps + advisories | `flutter pub get` | PASS | no advisories |
| 2 | Codegen fresh | `dart run build_runner build -d` + `git status` | PASS | clean |
| 3 | Format | `dart format --output=none --set-exit-if-changed lib test` | PASS | `0 changed` |
| 4 | Analyze | `flutter analyze` | PASS | `No issues found!` |
| 5 | Tests | `flutter test --coverage` | PASS | 142 passed, 0 skipped |
| 6 | Coverage | changed files / domain+application | PASS | 87.4% / 93.1% |
| 7 | Test quality | review + `test/qa/` | PASS with gaps | see "Tests added by QA" |
| 8 | Visual QA | `web_visual_qa.js …` | PASS | 32 shots, 0 errors, no unexpected hosts |
| 9 | Accessibility | guideline tests, 200% text | PASS | `test/qa/a11y_qa_test.dart` |
| 10 | Security | checklist items A1, B1, C3 … | PASS | greps + manifest review |
| 11 | Backend | `run_sql_rls_tests.sh` / `supabase test db` | PASS | 48 ok |
| 12 | Exploratory | charters 2, 5, 7 | Findings | BUG-3 |

## Coverage
| File / layer | Lines | Hit | % |
|---|---|---|---|

## Bugs
| ID | Sev | Title | Status |
|---|---|---|---|
<then one "### BUG-n" section per bug using the bug template>

## Tests added by QA
- `test/qa/<file>_qa_test.dart`: what it covers, and whether it passes or fails (fails = a bug reproducer)

## Screenshots
`docs/qa/screens/<phase>.<sub>/` (report.md lists every shot). Notable shots: …

## Exploratory sessions
<session notes, using the charter note template>

## Recommendations (non-blocking)
- …
```

## Full-phase report (`docs/qa/phase-<n>-final.md`): extra sections
```markdown
## Sub-phase reports
| Sub-phase | Report | Verdict | Open S1/S2 | Retested |
|---|---|---|---|---|

## Regression
Clean checkout → pub get → codegen → all tests: <counts by suite: unit/widget/golden/sql/functions>

## Integration flows
| Flow | Where run (emulator / web / CI-only) | Result |
|---|---|---|

## Performance sanity
| Metric | Previous phase | Now | Δ | Verdict |
|---|---|---|---|---|
| APK/AAB size (arm64) | | | | |
| Web main.dart.js (gzip) | | | | |
| Feed scroll (profile, frame build p90) | | | | |
| Feed RPC EXPLAIN ANALYZE (ms) | | | | |

## Accessibility (manual)
TalkBack pass over the core flows: <result or "not possible in this environment; scheduled on device">
```

## One-line final reply (to the caller)
`<phase>.<sub> QA: FAIL — S1:0 S2:1 S3:4 S4:2. Top: BUG-1 (S2) Android flavor build fails on AGP 9 resValues; BUG-2 (S3) … Report: docs/qa/<phase>.<sub>.md`
