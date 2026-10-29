# Sale Lagi Hai! — project rules

A Pakistan-wide deals app (Flutter, Android first) with a Supabase backend. The full plan, phases and quality gates are in `docs/DEVELOPMENT_PLAN.md`. Read it before starting any work.

## Workflow (mandatory)
1. Work one **sub-phase** at a time, in plan order.
2. When a sub-phase is built: run analyze, format and tests yourself, then run the **QA engineer** (`.claude/agents/qa-engineer.md`) for the sub-phase gate.
3. Fix every S1/S2 bug and re-run QA until the verdict is PASS. Then commit.
4. After the last sub-phase of a phase, run the QA **full-phase gate**.
5. Never weaken lints, delete tests or lower coverage thresholds to pass a gate.

## Skills to follow
- `.claude/skills/flutter-architecture`: structure, state, testing
- `.claude/skills/flutter-ui-ux`: every screen and widget
- `.claude/skills/flutter-secure-dev`: every feature, especially data, auth and network
- `.claude/skills/qa-testing`: the QA gates
- `.claude/skills/brand-identity`: anything visual or brand-related; brand assets live in `design/`

## Commands
Flutter is at `/opt/flutter/bin` in the cloud container.
```
flutter pub get
dart format lib test
flutter analyze                      # must report: No issues found
flutter test --coverage
flutter run --flavor dev --dart-define-from-file=env/dev.json
flutter build web --release --dart-define-from-file=env/dev.json
```
Copy `env/<flavor>.example.json` to `env/<flavor>.json` before the first run. The real env files are gitignored.

## Code conventions
- Feature-first layout: `lib/features/<feature>/{data,domain,application,presentation}`. Shared code goes in `lib/core` and `lib/design_system`.
- Riverpod for state, go_router for navigation, freezed for models.
- Lints are `very_good_analysis`. Dart 3.13 uses the short constructor syntax: `const new(...)` and `factory fromMap(...)` instead of repeating the class name.
- Every user-facing string goes in the ARB files (`en` + `ur`). No hard-coded text in widgets.
- Every UI must work in light/dark, LTR/RTL (Urdu) and at 200% text size.

## Stack notes (verified October 2026; see `docs/research/packages.md`)
- Flutter 3.47 ships Material as the `material_ui` package; the in-SDK `package:flutter/material.dart` is being deprecated. We migrate in sub-phase 1.3, and new code uses `material_ui` from then on.
- Pin `build_runner: ^2.16.2`. Version 2.17 needs `build` 5, which riverpod_generator and go_router_builder don't support yet.
- go_router_builder's typed-route mixin is `$RouteName` (go_router's docs wrongly show `_$RouteName`).
- Supabase is replacing the anon key with the **publishable** key: use `publishableKey:` in `Supabase.initialize`. The env field gets renamed to `SUPABASE_PUBLISHABLE_KEY` in Phase 2.
- Golden tests use alchemist; widgets from `material_ui` need the wrapper documented in the `qa-testing` skill.
- Discontinued, so don't add them: golden_toolkit, uni_links, firebase_dynamic_links, intl_utils, hive, isar.
- Play requires target API 36.
- The `ur` locale formats numbers with Western digits; Urdu numerals need a manual digit mapping.

## Security rules
- The client only ever holds **public** config: the Supabase URL and the publishable/anon key. `AppConfig` rejects secret keys at startup.
- Never commit `env/*.json`, keystores or `android/key.properties`.
- Every database table has RLS enabled with explicit policies.
- Never log personal data (phone numbers, locations, tokens).
