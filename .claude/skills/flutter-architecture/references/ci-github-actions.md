# CI with GitHub Actions

`.github/workflows/ci.yml` already exists from sub-phase 1.1. It has a secret scan, format, analyze, tests with an 80% coverage gate, env-template validation, Android builds per flavor and a web build. Actions there are pinned to commit SHAs. **Keep that convention:** every `uses:` must be a full SHA with a `# vX.Y.Z` comment, and Dependabot (`github-actions` ecosystem) bumps them.

Below are the jobs and steps to add as the project grows. `<sha>` marks pins to resolve when adding them; never use bare tags.

## 1. Code-gen drift and layer rules (add to the `quality` job, before Analyze)
```yaml
      - name: Code generation is up to date
        run: |
          dart run build_runner build --delete-conflicting-outputs
          flutter gen-l10n
          git diff --exit-code -- '*.g.dart' '*.freezed.dart' 'lib/core/l10n/' \
            || { echo "::error::Generated code is stale. Run build_runner and commit."; exit 1; }
      - name: Layer dependency rule
        run: |
          # presentation must not import data; domain must stay pure Dart.
          ! grep -rnE "import 'package:sale_lagi_hai/features/[a-z_]+/data/" lib/features/*/presentation
          ! grep -rnE "import 'package:(flutter|material_ui|supabase_flutter|drift)" lib/features/*/domain
      - name: No print / no http:// / no hard-coded left-right
        run: |
          ! grep -rnE "\bprint\(|debugPrint\(" lib --include=*.dart | grep -v "lib/core/logging/"
          ! grep -rn "http://" lib --include=*.dart
```

## 2. Coverage per layer (domain/application ≥ 90%)
```yaml
      - name: Coverage thresholds
        run: |
          dart run tool/check_coverage.dart coverage/lcov.info --min 80 \
            --exclude '**/*.g.dart' --exclude '**/*.freezed.dart' --exclude 'lib/core/l10n/**'
          dart run tool/check_coverage.dart coverage/lcov.info --min 90 \
            --include 'lib/features/*/domain/**' --include 'lib/features/*/application/**'
```
(Extend `tool/check_coverage.dart` with `--include`/`--exclude` globs if it lacks them.)

## 3. Goldens
```yaml
  goldens:
    needs: quality
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: flutter pub get
      - run: flutter test --tags golden          # alchemist CI goldens (Ahem text, platform-independent)
      - if: failure()
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with: { name: golden-failures, path: test/**/failures/ }
```
Golden updates are a deliberate local step: `flutter test --update-goldens --tags golden`. Review the PNG diff in the PR. Add `dart_test.yaml` with `tags: { golden: {} }` so the tag is declared.

## 4. Dependency audit
```yaml
  deps-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - run: flutter pub get                     # prints pub.dev security advisories
      - run: dart pub outdated --no-dev-dependencies --json > outdated.json || true
      - uses: google/osv-scanner-action/osv-scanner-action@<sha> # vX
        with:
          scan-args: --lockfile=pubspec.lock
```
`.github/dependabot.yml`:
```yaml
version: 2
updates:
  - { package-ecosystem: pub, directory: "/", schedule: { interval: weekly }, open-pull-requests-limit: 5 }
  - { package-ecosystem: github-actions, directory: "/", schedule: { interval: weekly } }
```
**Hold `build_runner` at 2.16.x.** 2.17 needs `build` 5, which riverpod_generator, go_router_builder and envied_generator don't support yet. Add an `ignore` entry for it until they release.

## 5. Supabase migrations and RLS tests
```yaml
  supabase:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: supabase/setup-cli@<sha> # vX
      - run: supabase db start                    # local Postgres from migrations (Docker is available on GitHub runners)
      - run: supabase db lint --level warning     # plpgsql_check-based lint
      - run: supabase test db                     # pgTAP: supabase/tests/*.sql
      - run: .claude/skills/qa-testing/scripts/run_sql_rls_tests.sh   # plain-SQL harness + schema lint
```
Edge Functions: run `deno test` in `supabase/functions` (JWT, auth-mode and rate-limit tests) and `deno lint`.

## 6. Integration tests (nightly or pre-release)
```yaml
  integration:
    if: github.event_name == 'schedule' || startsWith(github.ref, 'refs/tags/')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - uses: actions/setup-java@b843ebf9b913146b38da2eaa7aeddf76074ae1ad # v6.1.0
        with: { distribution: temurin, java-version: "17" }
      - uses: subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0
        with:
          flutter-version: ${{ env.FLUTTER_VERSION }}
          channel: stable
          cache: true
      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm.rules
          sudo udevadm control --reload-rules && sudo udevadm trigger --name-match=kvm
      - uses: reactivecircus/android-emulator-runner@<sha> # vX
        with:
          api-level: 35
          script: flutter test integration_test --flavor dev --dart-define-from-file=env/dev.json
```

## 7. Release build (tags only, signed, obfuscated)
```yaml
      - run: |
          flutter build appbundle --release --flavor prod \
            --dart-define-from-file=env/prod.json \
            --obfuscate --split-debug-info=build/symbols
      - run: |   # fail if a secret slipped into the binary
          unzip -p build/app/outputs/bundle/prodRelease/*.aab 'base/lib/arm64-v8a/libapp.so' | strings \
            | grep -E 'sb_secret_|service_role' && exit 1 || true
      - uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: symbols-${{ github.ref_name }}
          path: build/symbols
          retention-days: 400
```
- `env/prod.json` is written from an encrypted secret (`echo "$PROD_ENV_JSON" > env/prod.json`). It contains only public values; the secret store is just there so it isn't committed.
- The upload keystore is decoded from a secret into the runner temp directory and never echoed. Use `environment: production` with required reviewers.
- Upload symbols to Sentry with `sentry_dart_plugin`, using `SENTRY_AUTH_TOKEN` as a secret.

## 8. Job hygiene
- Use `permissions: contents: read` by default, and add only what a job needs.
- Use `concurrency` with cancel-in-progress (already present). Cache Flutter with `cache: true` and pub with `actions/cache` on `~/.pub-cache`, keyed on `pubspec.lock`.
- Required checks on `main`: `secret-scan`, `quality`, `goldens`, `deps-audit`, `supabase`, `build-android (dev)` and `build-web`.
