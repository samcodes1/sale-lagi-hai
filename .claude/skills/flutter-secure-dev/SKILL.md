---
name: flutter-secure-dev
description: Security playbook for the Sale Lagi Hai! Flutter app and its Supabase backend. Maps OWASP MASVS v2.1 and the Mobile Top 10 (2024) to concrete Flutter/Android practices (storage, keys, obfuscation, manifest hardening, TLS/pinning, deep links, WebViews, logging, dependency audit, Play Integrity, Data safety), and covers Supabase RLS, security-definer functions, keys, Edge Function auth, rate limiting, storage policies, pgTAP tests, account deletion and PECA. Use it for every feature that touches data, auth, network, storage, permissions or the backend.
---

# Secure development playbook: Sale Lagi Hai!

**Deep detail:**
- [references/masvs-mapping.md](references/masvs-mapping.md): every MASVS control → what we do → how QA verifies it.
- [references/android-hardening.md](references/android-hardening.md): manifest, network security config, backup rules, R8, App Links.
- [references/supabase-security.md](references/supabase-security.md): RLS patterns, functions, Edge Functions, rate limits, storage, account deletion.
- [references/security-review-checklist.md](references/security-review-checklist.md).

## 0. Threat model in one paragraph
**Assets:**
- User accounts (phone number, Google identity), saved deals, followed brands, "my cards", which are **bank and card *product* names only**. We never collect card numbers, CVV or OTPs for banks.
- Approximate location, FCM tokens, business-owner accounts (deal publishing, paid placements), and the admin and moderator consoles.

**Attackers:**
- Scrapers that clone our curated deal data.
- Spammers that submit fake deals or mass-report a competitor.
- Competitors gaming "Featured" or votes, and account takeover via phone-OTP abuse (SIM swap, SMS pumping).
- Anyone holding the APK: the publishable key, all of our Dart code and every endpoint are public.

**The core assumption:** *the client is fully public and hostile*. All authorization lives in Postgres RLS and in Edge Functions.

## 1. Ten non-negotiable rules
1. **The client holds only public config:** the Supabase URL and the **publishable key** (`sb_publishable_…`; the legacy `anon` JWT is deprecated by Supabase by the end of 2026).
   - Never ship a `sb_secret_…` or `service_role` key, a Firebase service account, FCM server credentials, or any third-party API secret.
2. **`--dart-define`, `--dart-define-from-file`, `.env` files and `envied` are *not* secret.** They compile into the binary as constants, so `strings libapp.so` recovers them. envied's `obfuscate: true` only slows an attacker down, as its README says.
   - `AppConfig` must **allowlist** the key format: accept only `sb_publishable_` keys or a JWT whose payload `role` is `anon`, and reject everything else.
   - CI must also fail the *build* if any env file contains `sb_secret_`, `service_role` or `"role":"service_role"`. A runtime check alone comes too late, because the secret is already in the APK.
3. **RLS is on for every table in every exposed schema**, with an explicit policy per operation and explicit grants. New tables get `revoke all … from anon, authenticated` first. CI runs the RLS test suite (pgTAP or plain SQL) on every migration.
4. **`security definer` functions** set `search_path = ''`, fully qualify every name, live in a **non-exposed schema** (`private`), and have `execute` revoked from `public`/`anon` unless they're intended. Views use `security_invoker = true`.
5. **Sensitive data at rest goes in `flutter_secure_storage`** (Keystore-backed AES-GCM in v11). That includes the Supabase session, via a custom `LocalStorage`. `shared_preferences` is for non-sensitive preferences only. Sensitive files are excluded from cloud backup and device transfer.
6. **HTTPS only.** Set `cleartextTrafficPermitted="false"` in the network security config. Our minSdk 24 devices (API 24–27) allow cleartext by default, so the explicit config matters. Release builds trust no user CAs.
7. **Every deep link, notification payload and web URL is untrusted input.** Parse it, allowlist the host and path, type-convert parameters (`int.tryParse`), bound-check them, and route only to known routes. Use verified App Links (`autoVerify`) for `https` links.
8. **Never log PII or secrets.** No phone numbers, emails, precise locations, tokens, JWTs, FCM tokens or request bodies, in any build. `print`/`debugPrint` are banned in `lib/`; use the logger, which redacts. Sentry has `sendDefaultPii: false`, and a `beforeSend` scrubs data.
9. **Release builds are obfuscated and minified:** `--obfuscate --split-debug-info=build/symbols/<flavor>/<version>`, R8 on, `debuggable=false`, symbols uploaded to Sentry and archived. Obfuscation is not protection; it just raises the cost.
10. **Abuse controls are server-side:** rate limits on OTP, submissions, reports, votes and search; Play Integrity for high-value write actions; and moderation queues. The client UI never decides trust.

## 2. MASVS v2.1 control groups → our practice (summary)
| Group | What it means here | Key practices |
|---|---|---|
| **STORAGE** (1: store securely, 2: prevent leakage) | Session tokens, cached user data, logs | `flutter_secure_storage` for tokens; drift/sqflite cache holds only public deal data; backup rules exclude secure prefs and DBs; no PII in logs or analytics; `FLAG_SECURE` isn't needed (no sensitive screens) except maybe the business payment screens; keyboard caching is off for OTP (`enableSuggestions: false`, `autocorrect: false`) |
| **CRYPTO** (1: strong crypto, 2: key management) | We don't roll our own crypto | Rely on TLS, Keystore (via secure storage) and Supabase-managed JWT signing keys (asymmetric signing keys). No custom encryption of local data beyond secure storage. No hard-coded keys |
| **AUTH** (1: secure protocols, 2: local auth, 3: step-up) | Supabase Auth: phone OTP + Google | PKCE flow (the supabase_flutter default); short access-token expiry; refresh tokens rotate; re-authentication (fresh OTP) before account deletion, phone change or business payout changes; MFA (`aal2`) required for moderator and admin by RLS `restrictive` policies |
| **NETWORK** (1: secure traffic, 2: identity pinning) | Supabase (REST, Realtime, Storage, Functions), FCM, CDN images | TLS everywhere; cleartext disabled; pinning is **not** enabled by default (see §5); certificate transparency comes from the platform on Android 16+ |
| **PLATFORM** (1: IPC, 2: WebViews, 3: UI) | Intents, deep links, share, notifications, WebViews | `exported="false"` everywhere except the launcher and the verified deep-link activity; immutable `PendingIntent`s; Custom Tabs instead of WebViews; no secrets in notifications; overlay/tapjacking awareness on payment screens |
| **CODE** (1: up-to-date platform, 2: forced updates, 3: no vulnerable components, 4: validate input) | SDKs, dependencies, inputs | minSdk 24, targetSdk 36; a server-driven minimum app version (`app_config` table) with a soft or hard update prompt; `in_app_update` on Android; `dart pub outdated`, OSV-Scanner on `pubspec.lock`, pub advisories, Dependabot; validation on the server (Postgres constraints, Edge Function schema validation) |
| **RESILIENCE** (1: platform integrity, 2: anti-tamper, 3: anti-static, 4: anti-dynamic) | Abuse of write endpoints, cloned apps | Play Integrity standard requests on submit, report and vote, verified in an Edge Function; obfuscation + R8; no hard block on rooted devices (proportional response) |
| **PRIVACY** (1: minimize, 2: prevent identification, 3: transparency, 4: user control) | Location, phone, analytics, FCM | Approximate location only; no advertising ID unless AdMob ships (then declare it); Data safety form plus a privacy policy; in-app *and* web account deletion; export of user data on request; analytics opt-out |

The Mobile Top 10 (2024) maps onto this. M1 Improper Credential Usage maps to rules 1–2. M2 Supply Chain is CODE-3. M3 AuthN/AuthZ is RLS and AUTH. M4 Input/Output Validation is CODE-4 and deep links. M5 Communication is NETWORK. M6 Privacy is PRIVACY. M7 Binary Protection is RESILIENCE. M8 Misconfiguration is the manifest and Supabase grants. M9 Data Storage is STORAGE. M10 Cryptography is CRYPTO.

## 3. Keys, config and secrets
- **Ship per flavor:** `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SENTRY_DSN` (a DSN is public by design), `FLAVOR` and `APP_NAME`. Load them through `--dart-define-from-file=env/<flavor>.json`.
- **Never ship anything else.** The secret key, the FCM v1 service account and scraper credentials live in **Supabase Edge Function secrets** (`supabase secrets set`) or in GitHub Actions encrypted secrets used only for deploys.
- **Separate Supabase projects for dev, staging and prod.** Prod keys never appear in dev machines' env files.
- **Initialize the client with the publishable key:** `Supabase.initialize(url: cfg.url, publishableKey: cfg.publishableKey, …)`. The `anonKey:` parameter is `@Deprecated` in supabase_flutter 2.18.
- **Secret scanning:** gitleaks in CI (the plan already has it), plus a custom rule for `sb_secret_` and `service_role`. Rotate a leaked key immediately; new-style secret keys can be deleted individually.

## 4. Storage (client)
```dart
/// Persists the Supabase session in the Android Keystore / iOS Keychain instead of SharedPreferences.
final class SecureSessionStorage extends LocalStorage {
  const new(this._storage);
  final FlutterSecureStorage _storage;
  static const _key = 'sb_session';
  @override Future<void> initialize() async {}
  @override Future<bool> hasAccessToken() async => (await _storage.read(key: _key)) != null;
  @override Future<String?> accessToken() => _storage.read(key: _key);
  @override Future<void> persistSession(String s) => _storage.write(key: _key, value: s);
  @override Future<void> removePersistedSession() => _storage.delete(key: _key);
}
// Supabase.initialize(..., authOptions: FlutterAuthClientOptions(
//   localStorage: SecureSessionStorage(const FlutterSecureStorage()),
//   detectSessionInUriPredicate: (uri) => uri.scheme == 'pk.salelagihai.app' && uri.host == 'login-callback'));
```
- **flutter_secure_storage 11** removed `encryptedSharedPreferences` and the old ciphers. Its minSdk is 24. A first install has no migration to worry about, but **never jump straight from v9 to v11**; go through v10 first.
  - Call `checkUpgradeStatus()` after upgrades.
  - The default `AndroidOptions` is fine. Use `storageNamespace` per flavor if flavors share a device.
- **Keystore data doesn't survive restore to a new device.** Treat "secure storage is empty" as signed-out, never as an error.
- **The local cache (drift/sqflite)** holds public deal data and the user's own non-sensitive lists (saved and followed). Clear it on sign-out and on account deletion.
- **Don't write user data** to external storage, the clipboard (except an explicit "Copy code"), or temp files that outlive the session.

## 5. Network and TLS
- **Network security config** sets `base-config cleartextTrafficPermitted="false"` with system trust anchors only. `debug-overrides` trusts a local proxy CA in dev builds only.
- Dart's `dart:io` `HttpClient`, used by supabase_flutter through `package:http`, **respects the Android cleartext policy**. It uses Dart's own TLS stack, though, so `<pin-set>` and custom trust anchors in the network security config are **not** applied to Dart traffic. Verify this on a device with a MITM proxy.
  - If you need platform-enforced pinning or user-CA rules, route traffic through `cronet_http` (dart.dev, 1.10.1), which uses the platform stack.
- **Pinning decision: no pinning in v1.** Supabase and CDN certificates are rotated by their providers, and pinning a leaf you don't control causes outages. If the threat model changes (payments in-app):
  - Pin the **SPKI of the issuing CA or intermediate**, with at least one **backup pin**, and an `expiration` date.
  - Ship a kill switch through remote config.
  - Pin only our own API domains, never third parties.
- **Timeouts and retries:** set connect, idle and total timeouts. Retry only idempotent reads, with backoff. Riverpod 3 retries failing providers by default (200ms doubling to 6.4s), so customize `retry:` to skip 4xx and auth errors.
- **Realtime:** subscribe only to the channels and topics RLS allows, and never broadcast PII.

## 6. Android platform hardening (summary; full XML in references/android-hardening.md)
- **Manifest:**
  - `android:allowBackup` is explicit, and `android:dataExtractionRules` (12+) + `android:fullBackupContent` (≤11) exclude secure-storage prefs, the session and DBs from both `cloud-backup` and `device-transfer`.
  - `android:usesCleartextTraffic="false"` and `android:networkSecurityConfig`.
  - Every `<activity>`, `<service>`, `<receiver>` and `<provider>` has an explicit `android:exported`. Only `MainActivity` is `true`, and it must check merged manifests from plugins (`build/app/intermediates/merged_manifests`).
  - `debuggable` is never set by hand.
- **Permissions:** declare only `INTERNET`, `POST_NOTIFICATIONS`, `ACCESS_COARSE_LOCATION` (and `ACCESS_FINE_LOCATION` only if "nearest outlet" needs it). Audit the permissions SDKs merge in (location, `READ_PHONE_STATE` from Sentry's network-type feature on Android ≤11, `AD_ID`). Remove unwanted ones with `tools:node="remove"`.
- **R8:** `isMinifyEnabled = true` and `isShrinkResources = true` for release. Keep rules only where plugins need them.
- **Signing:** Play App Signing. Keep the upload key in CI secrets, and register both the upload and app-signing SHA-256 fingerprints in `assetlinks.json`.

## 7. Deep links, App Links and WebViews
- **One entry point.** Use Flutter's built-in deep linking (`flutter_deeplinking_enabled`) *or* `app_links`, not both. Recommended: set `flutter_deeplinking_enabled=false` and run a single `DeepLinkService` on `app_links` that does three things:
  1. Hands `login-callback` URIs to Supabase (`detectSessionInUriPredicate`).
  2. Validates everything else against an allowlist (`https://salelagihai.pk/d/<uuid>`, `/b/<slug>`, `/c/<slug>`).
  3. Calls `router.go()` with a typed route. Anything unknown goes to Home, never to an error that echoes the input.
- **App Links:** add `autoVerify="true"` intent filters for `https` hosts. Put `assetlinks.json` on every host, served without redirects, and verify it with `adb shell pm get-app-links <pkg>`. On Android ≤11, one bad host breaks verification for all of them, so keep custom schemes in a *separate* intent filter.
- **Parameter validation:** IDs must be UUIDs or slugs matching `^[a-z0-9-]{1,64}$`. Reject `..`, `%2F` and encoded scripts. Never pass deep-link values into SQL strings, file paths or WebView URLs.
- **WebViews:** avoid them. Open external content with `url_launcher` `LaunchMode.inAppBrowserView` (Custom Tabs), which is also what Android recommends for sign-in flows.
  - If a WebView is unavoidable (for example, a bank T&C page): JavaScript off unless needed, allowlisted origins in `NavigationDelegate`, no `addJavaScriptChannel` to untrusted content, file access off, and `clearCache` on exit.
- **`url_launcher`:** only launch `https`, `tel`, `geo` and `mailto` schemes that we build ourselves. Never launch a raw URL from deal data without validating the scheme and host (deal links come from scrapers and businesses, so treat them as hostile).

## 8. Logging, analytics, crash reporting
- Use one logger facade (`package:logging` + `sentry_logging`, or talker in dev) with levels. Release builds log `info` and above, with no request or response bodies.
- **The redaction layer** masks `+92…` phone patterns, emails, JWTs (`eyJ…`), `sb_` keys and lat/lng with more than 2 decimals. Unit-test it.
- **Sentry:** `sendDefaultPii = false`. In `beforeSend`/`beforeBreadcrumb`, strip query strings and headers. Set the user context to an opaque UUID only, and leave Session Replay off (or masked) because it can capture screens.
- **Analytics events** carry IDs and categories, never free text typed by users (search queries can contain phone numbers, so hash or bucket them).

## 9. Dependencies and supply chain (CODE-3, M2)
- CI runs on every PR:
  - `dart pub outdated --json` (report it).
  - `osv-scanner scan source --lockfile=pubspec.lock` (OSV supports `pubspec.lock`).
  - `flutter pub get`, which prints pub.dev security advisories from the GitHub Advisory Database. Suppress one only with `ignored_advisories:` in pubspec, plus a written justification.
- Dependabot runs with `package-ecosystem: "pub"` weekly, along with `github-actions`. Pin Actions to commit SHAs.
- **Before adding a package,** check:
  - pub points, verified publisher, last release under 12 months ago, and that it's not `discontinued` (see `docs/research/packages.md`);
  - its license (no GPL in the app);
  - its native permissions, and whether it's migrated to material_ui.
- **Prefer first-party packages** (flutter.dev, dart.dev, firebase.google.com, supabase.io) for anything security-relevant.
- **Commit `pubspec.lock`.** Use exact-major constraints, and upgrade deliberately with tests.

## 10. Play Integrity: when it's worth it
- **Use it on the abuse-prone writes:** deal submissions, expired reports, votes, referral or rewards actions, business sign-up, and OTP requests if SMS pumping shows up.
  - **Don't** put it on reads or feed browsing (quota: 10,000 requests/day by default, and the latency).
- **Use standard requests** (a few hundred ms, automatic replay protection through `requestHash`). Bind the `requestHash` to a SHA-256 of the action payload.
- **Decrypt and verify server-side** in an Edge Function using Google's `decodeIntegrityToken`, with the credentials in function secrets. Respond in tiers: allow, allow with lower trust (moderation queue), or require extra verification. **Never hard-fail users** on `MEETS_BASIC_INTEGRITY` only, and run telemetry-only first.
- It doesn't replace RLS, rate limits or moderation. Don't add a RASP SDK (freeRASP and similar) in v1 unless abuse data justifies it.

## 11. Privacy, account deletion, Play policy, Pakistan law
- **Data safety form:** declare what *we and our SDKs* collect.
  - Phone number (account), approximate location (app functionality), app activity (saves, follows), device IDs (FCM token), and crash logs and diagnostics (Sentry).
  - Plus the ad ID *if* AdMob ships.
  - Encrypted in transit: yes. Deletion: yes, with the web URL. Re-check it whenever an SDK is added.
- **Account deletion is a Google Play requirement:**
  - An in-app path: Profile → Account → Delete account, with a re-auth OTP and a confirmation that lists what gets deleted.
  - A **web** deletion page linked in the Data safety form, which works without the app.
  - Delete the `auth.users` row (`auth.admin.deleteUser`, through an Edge Function using the secret key), let `on delete cascade` remove the user's rows, and delete their Storage objects *first* (Supabase blocks deleting users who own objects).
  - Delete their FCM tokens and analytics identity.
  - **"Deactivate" does not count.** Document what we retain and why (fraud logs, legal), with retention periods.
  - Access tokens stay valid until `exp`, so keep JWT expiry short and check `session_id` against `auth.sessions` for sensitive RPCs.
- **Pakistan (brief):**
  - **PECA 2016**, as amended in January 2025, creates offences for unauthorised access and data interference, and adds a §26A "false information" offence (up to 3 years and/or a PKR 2m fine).
  - It also creates a social-media regulator (reported as the Social Media Protection and Regulatory Authority) with registration and takedown powers over "social media platforms".
  - User-generated deal submissions and reports make us a moderation target, so keep an auditable takedown and moderation log and a complaints channel, and have counsel assess whether registration applies.
  - **No comprehensive data-protection law** has been enacted as of mid-2026; the Personal Data Protection Bill is still pending. Follow GDPR-grade minimization anyway, which also covers the expat Pakistani users we have.
- **Notifications:** no personal data in payloads. Marketing pushes require opt-in to that topic (see the flutter-ui-ux skill).

## 12. Supabase backend (summary; patterns in references/supabase-security.md)
- **Grants then policies.** Revoke the default privileges in `public` (or turn off "automatically expose new tables"), grant per role per operation, and enable RLS. Postgres checks grants before RLS: a missing grant gives a `42501` error, and a policy with no matching rows gives an empty result.
- **Write one policy per operation** (`select`/`insert`/`update`/`delete`). Avoid `for all`. `update` needs both `using` and `with check`, plus a `select` policy.
- **Wrap auth calls:** `(select auth.uid())` lets the planner cache the value per statement. Always add `to authenticated`/`to anon`. Index the policy columns, and avoid joins in policies.
- **Roles** (anon, user, business_owner, moderator, admin) come from a `user_roles` table, exposed in the JWT through a **Custom Access Token Hook** (`user_role` claim) and checked with `private.has_role()`. **Never** authorize on `user_metadata` (users can edit it); `app_metadata` or our own table is fine. JWT claims are stale until refresh, so re-check the table for critical actions.
- **Business ownership** goes through a `business_members(business_id, user_id, role)` table and a security-definer membership helper, which avoids recursive policies (`42P17`).
- **Edge Functions:** keep `verify_jwt = true` for user calls. Use the `withSupabase({ auth: 'user' })` wrapper from `@supabase/server` and `ctx.supabase` (RLS-scoped).
  - `ctx.supabaseAdmin` only when crossing RLS, and then always filtered by `ctx.userClaims.id`.
  - Cron and internal calls use `auth: 'secret'` with `verify_jwt = false`. Webhooks use `auth: 'none'` + signature verification.
- **Rate limits:**
  - Auth endpoints use the built-in limits; tune them, and enable CAPTCHA (Turnstile or hCaptcha) on OTP if pumping appears.
  - Data API writes go through a `db_pre_request` function (per-IP), plus per-user quotas in `private.rate_limits`, checked inside the submission and report RPCs.
  - pg_cron cleans up old rows.
- **Storage:**
  - Buckets are private by default. Policies on `storage.objects` scope paths to `(storage.foldername(name))[1] = auth.uid()::text` or a business ID the user is a member of.
  - Set `allowed_mime_types` and `file_size_limit` per bucket.
  - Public deal images go in a public bucket, written only by business members and moderators.
- **Testing:** run `supabase test db` (pgTAP) per table, with allow *and* deny cases per role per operation, plus a schema-wide "RLS is enabled everywhere" test. See the qa-testing skill for a plain-SQL harness that runs on bare Postgres.

## 13. Security review checklist (short; full list in references/security-review-checklist.md)
- [ ] No secret key, service-account file or private credential in the repo, the env files or the build output (`strings` check).
- [ ] New tables have RLS, explicit grants, a policy per operation, and pgTAP tests for allow and deny per role.
- [ ] New security-definer functions are in `private` with `search_path = ''` and execute grants restricted.
- [ ] New deep links, routes or notification payloads are validated against an allowlist.
- [ ] No PII in logs, analytics, crash reports or notifications; the redaction tests pass.
- [ ] The manifest diff is reviewed (exported, permissions, backup rules, cleartext).
- [ ] New dependencies are vetted (maintenance, license, permissions, advisories); OSV-Scanner is clean.
- [ ] Abuse-prone endpoints have rate limits (and Play Integrity where justified).
- [ ] The Data safety form and privacy policy are updated if data collection changed.
- [ ] The account-deletion path still removes all new user data.

## Sources
Pages marked † were read through their official GitHub sources because the docs host was blocked.
- OWASP†: [MASVS v2.1 controls](https://mas.owasp.org/MASVS/) ([OWASP/masvs](https://github.com/OWASP/masvs)); MASTG best practices: [BEST-0004 backups](https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0004/), [BEST-0010 minSdk](https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0010/), [BEST-0012 WebView JS](https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0012/), [BEST-0022 logging](https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0022/), [BEST-0030 root detection](https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0030/), [BEST-0052 components](https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0052/), [BEST-0063 PendingIntents](https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0063/), [BEST-0070 App Links](https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0070/), [BEST-0071 deep-link input](https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0071/); [Mobile Top 10 2024](https://owasp.org/www-project-mobile-top-10/)
- Flutter†: [Security](https://docs.flutter.dev/security), [Obfuscate Dart code](https://docs.flutter.dev/deployment/obfuscate), [Set up app links](https://docs.flutter.dev/cookbook/navigation/set-up-app-links), [Deep-link flag change](https://docs.flutter.dev/release/breaking-changes/deep-links-flag-change)
- Android: [Security checklist](https://developer.android.com/privacy-and-security/security-tips), [Network security config](https://developer.android.com/privacy-and-security/security-config), [Auto Backup](https://developer.android.com/identity/data/autobackup), [Verify App Links](https://developer.android.com/training/app-links/verify-android-applinks), [Play Integrity overview](https://developer.android.com/google/play/integrity/overview), [Target API requirement](https://developer.android.com/google/play/requirements/target-sdk), [Location permissions](https://developer.android.com/training/location/permissions)
- Supabase†: [API keys](https://supabase.com/docs/guides/getting-started/api-keys), [Migrating to new API keys](https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys), [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security), [RLS performance](https://supabase.com/docs/guides/database/postgres/row-level-security-performance), [Securing your API](https://supabase.com/docs/guides/api/securing-your-api), [Securing Edge Functions](https://supabase.com/docs/guides/functions/auth), [Storage access control](https://supabase.com/docs/guides/storage/security/access-control), [Custom claims & RBAC](https://supabase.com/docs/guides/api/custom-claims-and-role-based-access-control-rbac), [Custom access token hook](https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook), [Managing user data](https://supabase.com/docs/guides/auth/managing-user-data), [Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits), [Rate-limiting Edge Functions](https://supabase.com/docs/guides/functions/examples/rate-limiting), [Testing your database](https://supabase.com/docs/guides/database/testing)
- supabase_flutter 2.18.3 API: [Supabase.initialize](https://pub.dev/documentation/supabase_flutter/latest/supabase_flutter/Supabase/initialize.html), [FlutterAuthClientOptions](https://pub.dev/documentation/supabase_flutter/latest/supabase_flutter/FlutterAuthClientOptions-class.html), [LocalStorage](https://pub.dev/documentation/supabase_flutter/latest/supabase_flutter/LocalStorage-class.html)
- Packages: [envied README (obfuscation caveat)](https://pub.dev/packages/envied), [flutter_secure_storage CHANGELOG](https://pub.dev/packages/flutter_secure_storage/changelog), [app_links Android setup](https://github.com/llfbandit/app_links/blob/master/doc/README_android.md), [OSV-Scanner supported lockfiles](https://github.com/google/osv-scanner/blob/main/docs/supported_languages_and_lockfiles.md)
- Search-result summaries only (the hosts were blocked, so verify before relying on them): [Play account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111), [pub security advisories](https://dart.dev/go/pub-security-advisories), [Firebase Play data disclosure](https://firebase.google.com/docs/android/play-data-disclosure), PECA 2025 amendment coverage ([Dawn](https://www.dawn.com/news/1888590)), and the Pakistan PDP Bill status ([Chambers 2026](https://practiceguides.chambers.com/practice-guides/data-protection-privacy-2026/pakistan)).
