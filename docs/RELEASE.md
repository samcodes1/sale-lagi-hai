# Release builds

## Build
```
cp env/prod.example.json env/prod.json    # then fill in the real values
dart run tool/check_env.dart env/prod.json --flavor prod    # no --allow-placeholders
flutter build appbundle --release \
  --flavor prod \
  --dart-define-from-file=env/prod.json \
  --obfuscate --split-debug-info=build/symbols/prod/<version>
```
- `--obfuscate` renames Dart symbols, and `--split-debug-info` moves the symbol tables out of the app. Both are required for every release.
- Keep `build/symbols/prod/<version>` **for every version you ship**, and upload it to crash reporting (Sentry, Phase 9). Without it, crash stack traces can't be read.
  - Decode a trace by hand with `flutter symbolize -i trace.txt -d build/symbols/prod/<version>/app.android-arm64.symbols`.
- R8 (minify and resource shrinking) is on for the release build type in `android/app/build.gradle.kts`. Keep rules go in `android/app/proguard-rules.pro`, with a comment naming the plugin that needs them.
- Bump `version:` in `pubspec.yaml` (`name+code`). Play rejects a version code it has already seen.

## Signing
- **Play App Signing:** Google holds the app signing key. We hold only the **upload key**.
- The upload key lives outside the repository. `android/key.properties` points to it; that file and `*.jks` are gitignored:
  ```
  storePassword=…
  keyPassword=…
  keyAlias=upload
  storeFile=/absolute/path/to/upload-keystore.jks
  ```
- Release builds without `key.properties` fall back to the debug key, which Play rejects. In a CI release job, set `REQUIRE_RELEASE_SIGNING=true` so a missing key fails the build instead.
- In CI, write `key.properties` and the keystore from GitHub encrypted secrets at build time (base64 for the keystore). Never commit them, and never print them.
- If the upload key leaks, reset it in Play Console (Setup → App signing) and rotate the CI secrets.

## Before the first upload (owner)
1. Create the upload keystore (`keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`) and store it with its passwords in a password manager.
2. Enrol in Play App Signing when creating the app in Play Console.
3. Add the CI secrets (keystore, passwords, prod env values) and a release workflow with `REQUIRE_RELEASE_SIGNING=true`.
4. Check the merged manifest of the release build (`docs/security/CHECKLIST.md`, Notes).
5. Fill in the Data safety form from the current permissions and data flows (Phase 9 keeps it up to date). Declare ads and the advertising ID, and answer "yes" to "contains ads".
6. Create the app and its banner and interstitial units in AdMob. Put the unit IDs in `ADMOB_BANNER_ID` and `ADMOB_INTERSTITIAL_ID` in `env/prod.json`, and set the `ADMOB_APP_ID` environment variable for the release build. Prod refuses Google's test IDs, and with no unit IDs it shows no ads. Add `app-ads.txt` to the website and set up the consent message in AdMob, Privacy & messaging.

## Database migrations freeze at the first deploy
Before the first `supabase db push` to staging, record the last migration file in this section. From then on, never edit any migration up to and including it; add new ones (`docs/backend/SCHEMA.md`).
