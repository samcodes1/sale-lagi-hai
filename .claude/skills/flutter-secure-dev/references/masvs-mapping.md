# OWASP MASVS v2.1 → Sale Lagi Hai! controls → verification

MASVS v2.1.0 is the latest tag on OWASP/masvs. It has 24 controls in 8 groups. MAS Testing Profiles replaced the old L1/L2/R levels:
- **L1**: baseline.
- **L2**: defence in depth.
- **R**: resilience.
- **P**: privacy.

Our target is **L1 for everything, plus P**, with selected **R** controls for abuse-prone writes.

| Control | Requirement (MASVS wording) | Our implementation | How QA verifies |
|---|---|---|---|
| STORAGE-1 | The app securely stores sensitive data | Session, refresh token and any per-user secrets go in `flutter_secure_storage` (Keystore AES-GCM). The cache DB holds public data only | Grep for `SharedPreferences` writes of tokens. Inspect `/data/data/<pkg>/shared_prefs` on an emulator after login |
| STORAGE-2 | The app prevents leakage of sensitive data | Backup rules exclude secure prefs and DBs (cloud + device-transfer). No PII in logs or notifications. OTP fields disable suggestions | `adb logcat` during the flows. `adb shell bmgr backupnow` + inspect. Review the notification payloads |
| CRYPTO-1 | Strong cryptography per best practice | Only the platform: TLS 1.2+/1.3, Keystore. No custom crypto, MD5, SHA-1 or ECB | Grep `crypto`/`encrypt` packages. Review any new crypto in a PR |
| CRYPTO-2 | Key management per best practice | No hard-coded keys. Supabase JWT signing keys are managed by Supabase (asymmetric), and secrets live in Edge Function secrets | `strings` on the release `libapp.so` for `sb_secret`, `service_role`, `-----BEGIN` |
| AUTH-1 | Secure authentication and authorization protocols | Supabase Auth (PKCE). All authorization is in RLS and Edge Functions. Access tokens are short-lived with refresh rotation | The RLS role-matrix tests. Expired or forged JWTs are rejected by functions (`verify_jwt`) |
| AUTH-2 | Local authentication per platform best practice | Not used in v1. If added (for example, to protect the business wallet), use `local_auth` with `BIOMETRIC_STRONG` and bind it to a Keystore key (crypto-object binding). A boolean callback alone is not enough | Review the code if introduced |
| AUTH-3 | Additional auth for sensitive operations | Fresh OTP re-auth before account deletion, phone change, payout or bank details, and role grants. Staff need `aal2` | Try the sensitive RPC with a stale session or `aal1`, and expect a denial |
| NETWORK-1 | Secure all network traffic | HTTPS only; NSC `cleartextTrafficPermitted=false`; no user CAs in release; HSTS on our web domains | Point `http://` at the app and expect a failure. Check the NSC in the merged manifest |
| NETWORK-2 | Identity pinning for endpoints under the developer's control | **Risk accepted for v1** (no pinning): the provider-managed certificates rotate, and pinning would cause outages. We rely on platform CT (Android 16+). Revisit if in-app payments ship | Documented decision in the threat model |
| PLATFORM-1 | Use IPC mechanisms securely | Every component has an explicit `exported`; only the launcher and deep-link activity are exported. `PendingIntent`s are immutable and explicit (plugins). Deep links are allowlisted and type-checked | `aapt dump xmltree` / the merged manifest review. Fuzz deep links with `adb shell am start -d …` |
| PLATFORM-2 | Use WebViews securely | Prefer Custom Tabs. Any WebView has JS off by default, an origin allowlist, no JS bridges and no file access | Grep for `webview_flutter` usage and review its settings |
| PLATFORM-3 | Use the UI securely | No sensitive data in notifications or recents. Promo-code copy only. Overlay-sensitive actions (payments) can use `FLAG_SECURE` and the tapjacking filter | Manual review of the business payment screens |
| CODE-1 | Requires an up-to-date platform version | minSdk 24 (the Flutter 3.47 default), targetSdk 36 (Play requirement since 31 Aug 2026) | `build.gradle.kts` check |
| CODE-2 | Mechanism for enforcing app updates | A `min_supported_version` row in a public config table. Below it, a blocking screen and `in_app_update` (immediate). For recommended updates, a flexible update | Set the min version above the current one in staging and expect the block |
| CODE-3 | Only components without known vulnerabilities | Pub advisories on `pub get`; OSV-Scanner on `pubspec.lock`; Dependabot (pub + actions); Flutter stable kept current | CI logs. `osv-scanner` exits 0 |
| CODE-4 | Validates and sanitizes untrusted inputs | Server: Postgres `check` constraints, RPC argument validation, Edge Function schema validation (zod or valibot). Client: form validation for UX only. Deep links and notification data are parsed strictly. Scraped HTML is never rendered | SQL tests for constraints. Fuzz the RPCs with oversized and odd inputs |
| RESILIENCE-1 | Validates the integrity of the platform | Play Integrity standard requests on abuse-prone writes, with server-side, tiered handling. No hard root block | Edge Function tests with mocked verdicts |
| RESILIENCE-2 | Anti-tampering mechanisms | Play App Signing. The integrity verdict's `appRecognitionVerdict` must be `PLAY_RECOGNIZED` for high-trust writes | Sideload a re-signed APK and expect submissions to drop to low trust |
| RESILIENCE-3 | Anti-static analysis | `--obfuscate --split-debug-info`, R8, no secrets to find | Inspect the release APK with jadx/blutter |
| RESILIENCE-4 | Anti-dynamic analysis | Out of scope for v1 (low value for a public-data app). Revisit if fraud appears | n/a |
| PRIVACY-1 | Minimizes access to sensitive data and resources | Approximate location; no contacts, SMS or phone-state reading; manifest permission audit (removes SDK extras) | Merged-manifest permission diff on every release |
| PRIVACY-2 | Prevents identification of the user | Opaque UUIDs in analytics and Sentry; no ad ID unless AdMob; IP addresses not stored in our tables beyond rate-limit windows | Inspect analytics and Sentry payloads in staging |
| PRIVACY-3 | Transparent about data collection | A privacy policy (en + ur), the Data safety form, in-context permission priming, and "Why am I seeing this?" for Featured content | Compare the Data safety answers with the SDK list each release |
| PRIVACY-4 | User control over their data | Topic-level notification controls, an analytics opt-out, data export on request, in-app and web account deletion | An end-to-end deletion test confirms the user's rows, storage objects and FCM tokens are gone |

## Mobile Top 10 (2024) cross-check
| Risk | Where it's covered |
|---|---|
| M1 Improper Credential Usage | Rules 1–2 (publishable key only, no secrets in the binary), CRYPTO-2 |
| M2 Inadequate Supply Chain Security | CODE-3, package vetting, SHA-pinned Actions |
| M3 Insecure Authentication/Authorization | AUTH-1/3 and RLS on every table |
| M4 Insufficient Input/Output Validation | CODE-4, deep-link validation, no rendering of scraped HTML |
| M5 Insecure Communication | NETWORK-1 |
| M6 Inadequate Privacy Controls | PRIVACY-1…4 |
| M7 Insufficient Binary Protections | RESILIENCE-2/3 |
| M8 Security Misconfiguration | Manifest hardening, Supabase default grants, storage bucket settings |
| M9 Insecure Data Storage | STORAGE-1/2 |
| M10 Insufficient Cryptography | CRYPTO-1 |

## Sources
- [OWASP/masvs controls](https://github.com/OWASP/masvs/tree/master/controls) and [Using the MASVS](https://github.com/OWASP/masvs/blob/master/Document/03-Using_the_MASVS.md) (MAS profiles; tags up to v2.1.0)
- [OWASP MASTG best practices](https://github.com/OWASP/mastg/tree/master/best-practices) (BEST-0004, 0010, 0012, 0022, 0029, 0030, 0052, 0063, 0070, 0071)
- [OWASP Mobile Top 10, 2024 final release](https://github.com/OWASP/www-project-mobile-top-10/blob/master/index.md)
- [Play Integrity API overview](https://developer.android.com/google/play/integrity/overview)
