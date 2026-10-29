# Security checklist

The security baseline from sub-phase 1.7, mapped to OWASP MASVS v2.1 and the Mobile Top 10 (2024). The rules are in `.claude/skills/flutter-secure-dev`. Update this file when a phase adds or changes a control.

**Status:** ✅ in place and checked by a test or CI · 🟡 in place, checked by hand · ⏳ planned (phase shown)

## Enforced automatically
| What | Where it's enforced |
|---|---|
| Manifest: no cleartext, network config used, only the launcher exported, no `VIEW` deep links, Flutter deep linking off, INTERNET only, unused SDK permissions stripped, never debuggable | `test/security/android_config_test.dart` |
| Network config: cleartext off in every config; release builds trust system CAs only; user CAs in `debug-overrides` only | same |
| Backups: secure storage excluded from cloud backup, device transfer and legacy full backup; only preferences and DataStore included | same |
| Release build: R8 minify and resource shrinking, keep rules, `REQUIRE_RELEASE_SIGNING`, target API ≥ 36, signing files gitignored | same |
| No `print`/`debugPrint`/`stdout` outside the console log sink | `test/security/source_hygiene_test.dart` |
| No `http://` URLs, TLS bypasses (`badCertificateCallback`, `HttpOverrides`) or runtime code loading | same |
| No secret keys, JWTs, private keys, keystore passwords or Google API keys in code, env templates, assets or Android resources | same, and gitleaks in CI (`.gitleaks.toml`) |
| Client config holds only public keys; secret and service_role keys rejected at startup and before builds | `AppConfig`, `tool/check_env.dart` (tests in `test/app/config`) |
| Logs redact phone numbers, cards, CNICs, JWTs, keyed secrets and coordinates | `LogRedactor` (tests in `test/core/logging`) |
| Dependencies: no known vulnerabilities (OSV), no pub.dev advisories, no retracted, discontinued or banned packages, pub.dev sources only | `dependency-audit` CI job: OSV-Scanner + `tool/audit_deps.dart --online` |
| Dependency updates | Dependabot (`.github/dependabot.yml`): pub, GitHub Actions, Gradle |
| CI actions pinned to commit SHAs; workflow token is read-only | `.github/workflows/ci.yml` |
| Release builds compile with R8 and Dart obfuscation, with symbols split out | `build-android-release` CI job |

## MASVS v2.1
| Group | Control | Status | Notes |
|---|---|---|---|
| STORAGE-1 | Sensitive data in secure storage | ✅ | `SecureStore` (Keystore-backed). Sessions move there in Phase 4 |
| STORAGE-2 | No leaks via backups and logs | ✅ | Backup rules and redacting logger (above) |
| CRYPTO-1/2 | No custom crypto, no hard-coded keys | ✅ | Platform TLS and Keystore only |
| AUTH-1–3 | OTP, PKCE, step-up | ⏳ Phase 4 | Supabase Auth |
| NETWORK-1 | TLS only | ✅ | See the note below on Dart networking |
| NETWORK-2 | Identity pinning | Not planned for v1 | Supabase rotates certificates; pinning risks outages. Revisit for payments (skill §5) |
| PLATFORM-1 | IPC: no exported components | ✅ | Launcher only. The verified App Links activity comes in Phase 5.3 |
| PLATFORM-2 | WebViews | ✅ | None. Custom Tabs for web pages |
| PLATFORM-3 | UI: no secrets on screen | ✅ | Nothing sensitive yet. `FLAG_SECURE` is to be considered for payment screens (Phase 8) |
| CODE-1 | Current platform | ✅ | targetSdk 36, minSdk 24 |
| CODE-2 | Forced updates | ⏳ Phase 4 | Server-driven minimum version |
| CODE-3 | No vulnerable components | ✅ | Dependency audit (above) |
| CODE-4 | Input validation | 🟡 | Route parameters are validated (`route_params.dart`, UUIDs). Server-side validation comes in Phase 2 |
| RESILIENCE-1–4 | Integrity, anti-tamper | 🟡 / ⏳ | R8 and Dart obfuscation now. Play Integrity on writes in Phase 5 |
| PRIVACY-1–4 | Minimisation, transparency, control | 🟡 / ⏳ | AD_ID and READ_PHONE_STATE stripped, no location yet. Data safety form, deletion and export in Phase 9 |

## Mobile Top 10 (2024)
| Risk | Covered by |
|---|---|
| M1 Improper credential usage | Public keys only; `AppConfig` and `check_env` reject secret keys; gitleaks |
| M2 Inadequate supply chain security | OSV-Scanner, `audit_deps.dart`, Dependabot, SHA-pinned actions, committed `pubspec.lock` |
| M3 Insecure authentication/authorization | RLS on every table (Phase 2), Supabase Auth (Phase 4) |
| M4 Insufficient input/output validation | Typed routes with validated parameters; deep links through one validating service (Phase 5.3) |
| M5 Insecure communication | HTTPS only (manifest, network config, `AppConfig`, hygiene test) |
| M6 Inadequate privacy controls | Redacting logger, stripped permissions, approximate location only (Phase 4) |
| M7 Insufficient binary protections | R8, `--obfuscate --split-debug-info` |
| M8 Security misconfiguration | Manifest and backup lint test |
| M9 Insecure data storage | `SecureStore`, backup exclusions |
| M10 Insufficient cryptography | No custom cryptography |

## Notes
- **Dart networking ignores Android's network security config.** `dart:io`'s `HttpClient` (and packages built on it, such as `http` and Supabase's client) uses Dart's own TLS stack. So the cleartext ban in `network_security_config.xml` covers only platform networking: plugins, Custom Tabs and image loaders on the platform stack. On the Dart side it is enforced by `AppConfig` (the Supabase URL must be `https://`) and by the hygiene test (no `http://` URLs). If we ever need the platform rules to apply to Dart traffic, use `cronet_http` (skill §5).
- **Re-check the merged manifest whenever a plugin is added:** `android/app/build/intermediates/merged_manifests/<variant>/AndroidManifest.xml`. Plugins can add permissions, exported components and backup settings. The lint test reads only our source manifest.
- **Owner to-dos before the first release** are in `docs/RELEASE.md`: upload key, Play App Signing, and the CI secrets.
