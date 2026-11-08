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
   - **Location.** Declare *Approximate location*: collected (Near me sends it to our server for that one query, which keeps nothing), not shared, processed ephemerally, optional, for *App functionality*. The app declares `ACCESS_COARSE_LOCATION` only; fine and background location are stripped from the merged manifest. Matching the phone to a city happens on the phone.
   - **Why this passes review** (User Data policy, prominent disclosure): Android's permission dialog only ever opens from a button under a screen that says what location is for (onboarding's "Deals near you" step, and the subtitle of "Use my location" in the city sheet). Nothing asks at launch, and every screen works without location (All Pakistan, or a city picked by hand). Keep it that way: never call the location service from anywhere else.
6. AdMob. The app is `ca-app-pub-8647701429172755~4595808320` (the prod default in `android/app/build.gradle.kts`; the `ADMOB_APP_ID` environment variable overrides it) and the banner unit is `ca-app-pub-8647701429172755/1550842584` (`ADMOB_BANNER_ID` in `env/prod.example.json`, so copy it into `env/prod.json`). Dev and staging keep Google's test IDs on purpose: never show your own real ads on a test phone, and never tap them, or AdMob can disable the account. To add more formats, create interstitial, app open and native advanced units in AdMob and put their IDs in `ADMOB_INTERSTITIAL_ID`, `ADMOB_APP_OPEN_ID` and `ADMOB_NATIVE_ID`; an empty ID means that format is off. Prod refuses Google's test IDs. Publish `app-ads.txt` at the root of the developer website listed in Play Console, containing `google.com, pub-8647701429172755, DIRECT, f08c47fec0942fa0`, and set up the consent message in AdMob, Privacy & messaging. After launch, tune ad frequency in the `ad_settings` row (Studio, Table editor), and add mediation networks in AdMob to raise fill and eCPM.

## Database migrations freeze at the first deploy
Before the first `supabase db push` to staging, record the last migration file in this section. From then on, never edit any migration up to and including it; add new ones (`docs/backend/SCHEMA.md`).
