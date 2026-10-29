# Android hardening reference

## 1. `AndroidManifest.xml` (application and activity)
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          xmlns:tools="http://schemas.android.com/tools">
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <!-- Strip permissions that SDKs merge in and we don't use (check the merged manifest). -->
  <uses-permission android:name="android.permission.READ_PHONE_STATE" tools:node="remove"/>
  <uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/> <!-- until AdMob ships -->

  <application
      android:label="@string/app_name"
      android:allowBackup="true"
      android:fullBackupContent="@xml/backup_rules"
      android:dataExtractionRules="@xml/data_extraction_rules"
      android:usesCleartextTraffic="false"
      android:networkSecurityConfig="@xml/network_security_config"
      android:enableOnBackInvokedCallback="true">

    <activity android:name=".MainActivity" android:exported="true"
              android:launchMode="singleTop" android:taskAffinity="">
      <meta-data android:name="flutter_deeplinking_enabled" android:value="false"/> <!-- app_links handles links -->
      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
      <!-- Verified App Links: https only, in their own filter -->
      <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="https" android:host="salelagihai.pk" android:pathPrefix="/d/"/>
        <data android:scheme="https" android:host="salelagihai.pk" android:pathPrefix="/b/"/>
      </intent-filter>
      <!-- Auth callback custom scheme: SEPARATE filter (an unverifiable entry would break autoVerify on Android ≤ 11) -->
      <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="pk.salelagihai.app" android:host="login-callback"/>
      </intent-filter>
    </activity>
  </application>
</manifest>
```
Notes:
- `android:taskAffinity=""` mitigates task hijacking (StrandHogg-style).
- The app-name `resValue` approach needs `buildFeatures { resValues = true }` on AGP 9 (see QA report 1.1, BUG-1).
- **Review the merged manifest** (`android/app/build/intermediates/merged_manifests/<variant>/…/AndroidManifest.xml`) for components plugins add (firebase_messaging's service and receivers, flutter_local_notifications' receivers). Every one must have `exported` set; FCM's service is `exported=false` by design.
- `allowBackup="true"` + rules is the deliberate choice: preferences restore, secrets don't. With `allowBackup="false"`, some OEMs still do device-to-device transfer, so the rules are needed either way.
- Use a separate scheme and App Link host per flavor (`pk.salelagihai.app.dev`), so dev builds never receive prod links.

## 2. `res/xml/network_security_config.xml`
```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
  <base-config cleartextTrafficPermitted="false">
    <trust-anchors>
      <certificates src="system"/>
    </trust-anchors>
  </base-config>
  <!-- Debug builds only (android:debuggable=true): trust a local proxy CA for traffic inspection. -->
  <debug-overrides>
    <trust-anchors>
      <certificates src="user"/>
    </trust-anchors>
  </debug-overrides>
</network-security-config>
```
- The explicit `cleartextTrafficPermitted="false"` matters because API 24–27 default to cleartext **allowed**, and our minSdk is 24.
- Pinning (if it's ever adopted) is a `<domain-config><pin-set expiration="YYYY-MM-DD">` with **≥2 pins** (current plus backup), pinned to a CA or intermediate SPKI. Remember that Dart's `HttpClient` does not apply NSC pin-sets; pin in Dart (`SecurityContext(withTrustedRoots: false)` + the bundled CA) or use `cronet_http`.
- Android 16 added certificate transparency support. It's enabled by default for apps targeting API 37+.

## 3. Backup rules
`res/xml/data_extraction_rules.xml` (Android 12+):
```xml
<?xml version="1.0" encoding="utf-8"?>
<data-extraction-rules>
  <cloud-backup disableIfNoEncryptionCapabilities="true">
    <include domain="sharedpref" path="."/>
    <exclude domain="sharedpref" path="FlutterSecureStorage.xml"/>  <!-- verify the file name for flutter_secure_storage v11 -->
    <exclude domain="database" path="."/>                            <!-- cache DBs: rebuildable -->
    <exclude domain="file" path="."/>
  </cloud-backup>
  <device-transfer>
    <include domain="sharedpref" path="."/>
    <exclude domain="sharedpref" path="FlutterSecureStorage.xml"/>
    <exclude domain="database" path="."/>
  </device-transfer>
</data-extraction-rules>
```
`res/xml/backup_rules.xml` (Android ≤ 11) uses the same rules inside `<full-backup-content>`.

- Keystore keys never back up, so restored ciphertext would be useless and could crash naive code. Always exclude secure-storage files.
- Verify on an emulator: `adb shell bmgr backupnow <pkg>`, clear the data, `adb shell bmgr restore <pkg>`, then confirm the user is signed out and preferences are restored.

## 4. Gradle release config (`android/app/build.gradle.kts`)
```kotlin
android {
  defaultConfig { minSdk = flutter.minSdkVersion /* 24 */; targetSdk = flutter.targetSdkVersion /* 36 */ }
  buildTypes {
    release {
      isMinifyEnabled = true
      isShrinkResources = true
      proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
      signingConfig = signingConfigs.getByName("release")   // upload key from CI secrets, never committed
    }
  }
  buildFeatures { resValues = true }                         // AGP 9 default is false
}
```
The build command for each flavor:
```bash
flutter build appbundle --release --flavor prod \
  --dart-define-from-file=env/prod.json \
  --obfuscate --split-debug-info=build/symbols/prod/$(git describe --tags)
# Upload the symbols to Sentry (sentry_dart_plugin) and archive build/symbols as a CI artifact.
```
- Obfuscation caveat: `runtimeType.toString()` and class names in logic break, while enum names aren't obfuscated. Never switch on type-name strings.
- Web builds can't be obfuscated (they're only minified). The admin and business portals hold no secrets either; all authorization is in RLS.

## 5. App Links: `https://salelagihai.pk/.well-known/assetlinks.json`
```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "pk.salelagihai.app",
    "sha256_cert_fingerprints": ["<Play app-signing SHA-256>", "<upload key SHA-256 for internal testing>"]
  }
}]
```
- Serve it over HTTPS with **no redirects** (http→https and apex→www redirects break verification), `Content-Type: application/json`, on **every** host in the intent filters.
- Check it: `adb shell pm verify-app-links --re-verify pk.salelagihai.app`, then `adb shell pm get-app-links pk.salelagihai.app` should show `verified`. On Android 15+ the system re-verifies periodically, and `assetlinks.json` changes can take up to 7 days to reach devices.

## 6. Deep-link validation (Dart)
```dart
sealed class LinkTarget { const new(); }
final class DealLink extends LinkTarget { const new(this.id); final String id; }
final class BrandLink extends LinkTarget { const new(this.slug); final String slug; }

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
final _slug = RegExp(r'^[a-z0-9-]{1,64}$');
const _hosts = {'salelagihai.pk', 'www.salelagihai.pk'};

LinkTarget? parseLink(Uri uri) {
  if (uri.scheme != 'https' || !_hosts.contains(uri.host)) return null;
  final s = uri.pathSegments;
  if (s.length == 2 && s[0] == 'd' && _uuid.hasMatch(s[1])) return DealLink(s[1]);
  if (s.length == 2 && s[0] == 'b' && _slug.hasMatch(s[1])) return BrandLink(s[1]);
  return null; // unknown → Home, never echo input back
}
```
Unit-test this with hostile inputs: `../`, `%2e%2e`, mixed case, other hosts, `javascript:`, overly long segments, extra segments and query injection. Notification `data` payloads go through the same parser.

## 7. Release verification commands (QA)
```bash
apkanalyzer manifest print app-release.apk | grep -E 'exported|debuggable|allowBackup|cleartext|permission'
unzip -p app-release.apk lib/arm64-v8a/libapp.so | strings | grep -E 'sb_secret_|service_role|BEGIN (RSA|PRIVATE)' && echo FAIL
osv-scanner scan source --lockfile=pubspec.lock
```

## Sources
- [Network security configuration](https://developer.android.com/privacy-and-security/security-config), [Auto Backup](https://developer.android.com/identity/data/autobackup), [Security checklist](https://developer.android.com/privacy-and-security/security-tips), [Verify Android App Links](https://developer.android.com/training/app-links/verify-android-applinks)
- [MASTG-BEST-0004](https://github.com/OWASP/mastg/blob/master/best-practices/MASTG-BEST-0004.md), [-0052](https://github.com/OWASP/mastg/blob/master/best-practices/MASTG-BEST-0052.md), [-0063](https://github.com/OWASP/mastg/blob/master/best-practices/MASTG-BEST-0063.md), [-0070](https://github.com/OWASP/mastg/blob/master/best-practices/MASTG-BEST-0070.md), [-0071](https://github.com/OWASP/mastg/blob/master/best-practices/MASTG-BEST-0071.md)
- Flutter (read through the flutter/website source): [Obfuscate Dart code](https://docs.flutter.dev/deployment/obfuscate), [Set up app links](https://docs.flutter.dev/cookbook/navigation/set-up-app-links), [What's new in 3.47](https://flutter.dev/blog/whats-new-in-flutter-3-47) (AGP 9.1, minSdk 24, target 36)
- [app_links Android setup](https://github.com/llfbandit/app_links/blob/master/doc/README_android.md) (disable `flutter_deeplinking_enabled`)
- `docs/qa/1.1.md` BUG-1 (AGP 9 `resValues`)
