# Security review checklist

Use it for every PR that touches data, auth, network, storage, permissions, the manifest or the backend, and for every phase gate. For each item, record PASS, FAIL or N/A with evidence (a command and its output, or file:line).

## A. Secrets and config
- [ ] `git grep -nE 'sb_secret_|service_role|BEGIN (RSA|EC|OPENSSH|PRIVATE)|AIza[0-9A-Za-z_-]{35}'` finds nothing outside documentation. (A Firebase `AIza` key in `google-services.json` is public, but it must be API-restricted in the Cloud console.)
- [ ] `env/*.json` is gitignored, and only `*.example.json` files are tracked. Variants (`.bak`, nested files, `.env`) are ignored too.
- [ ] `AppConfig` **allowlists** the publishable key format, and CI fails the build if an env file contains a secret-key pattern.
- [ ] `strings` on the release `libapp.so` finds no secret keys, internal hostnames or staging URLs (in the prod flavor).
- [ ] gitleaks runs in CI on every push, with the custom Supabase rules.

## B. Storage and privacy on device
- [ ] Tokens and the session are in `flutter_secure_storage` (a custom `LocalStorage` for supabase_flutter). No tokens are in `shared_preferences`.
- [ ] Backup rules exclude secure storage and DBs (both `cloud-backup` and `device-transfer`). The restore test signs the user out cleanly.
- [ ] Sign-out and account deletion wipe secure storage, the cache DB, the image cache entries for private images, and the FCM token mapping.
- [ ] No PII in logs (`adb logcat` capture during login, search, save and report), Sentry events, analytics events or notifications.
- [ ] OTP and phone fields: `autocorrect: false`, `enableSuggestions: false`, `AutofillHints.oneTimeCode` and `telephoneNumber`.

## C. Network
- [ ] NSC `cleartextTrafficPermitted="false"`; no `usesCleartextTraffic="true"` in the merged manifest.
- [ ] Release builds trust system CAs only. User CAs appear in `debug-overrides` only.
- [ ] `rg -n "http://" lib/` finds nothing (except tests and localhost in dev).
- [ ] The pinning decision is documented. If pinning is implemented: backup pin, expiry and kill switch.
- [ ] Timeouts are set; the retry policy skips 4xx and auth errors.

## D. Platform
- [ ] Every component in the merged manifest has an explicit `exported`; only `MainActivity` is exported.
- [ ] Permissions match the expected list exactly; SDK extras are removed with `tools:node="remove"`.
- [ ] App Links verify (`pm get-app-links` shows `verified`), and custom schemes are in a separate filter.
- [ ] Deep links and notification payloads go through `parseLink()`, with unit tests for hostile inputs.
- [ ] No `webview_flutter` without a review. External links open in Custom Tabs, and `url_launcher` schemes are allowlisted.
- [ ] `android:taskAffinity=""` is on the launcher activity, and predictive back is enabled.

## E. Code and build
- [ ] Release is built with `--obfuscate --split-debug-info`, R8 minify and shrink, and not debuggable. Symbols are uploaded and archived.
- [ ] `flutter pub get` shows no unhandled advisories. `osv-scanner scan source --lockfile=pubspec.lock` is clean. Dependabot is enabled.
- [ ] New packages are vetted: verified publisher or justification, not discontinued, an acceptable license, and a reviewed native permission footprint.
- [ ] No `print`/`debugPrint` in `lib/` (lint `avoid_print` + grep), and the logger redaction is unit-tested.
- [ ] Forced-update path: `min_supported_version` is respected (tested in staging).

## F. Supabase
- [ ] Every new table: RLS on, default grants revoked, explicit grants, one policy per operation, indexes on the policy columns.
- [ ] New functions: `security invoker` by default. Definer functions are in `private` with `search_path = ''`, `execute` revoked from `public`/`anon`, and justified in a comment.
- [ ] New views use `security_invoker = true`.
- [ ] No policy uses `user_metadata`; role checks use `user_roles` or the hook claim.
- [ ] Staff-only writes have restrictive `aal2` policies.
- [ ] Edge Functions use the right `withSupabase` auth mode; `verify_jwt` is set in `config.toml`; inputs are schema-validated; errors are generic; `supabaseAdmin` queries filter by the caller.
- [ ] Rate limits exist for every new write endpoint (a quota trigger, the pre-request function, or a function-level limit).
- [ ] Storage buckets have a size limit, a MIME allowlist and per-folder policies; private data is never in public buckets.
- [ ] pgTAP or SQL RLS tests are added and pass: allow and deny per role per operation, plus the schema lint (`10_schema_lint.sql`).
- [ ] The Security Advisor in the dashboard shows no new findings.

## G. Abuse and integrity
- [ ] Abuse-prone writes go through a moderation status and are not published directly.
- [ ] If Play Integrity is used: standard requests, `requestHash` bound to the payload, server-side decode, and tiered responses (telemetry first).

## H. Privacy and policy
- [ ] The Data safety form matches the current SDK list and data flows (Supabase, Firebase Messaging, Sentry, plus AdMob or Analytics if added).
- [ ] The privacy policy (en + ur) is updated, and the web deletion URL works without the app.
- [ ] Account deletion end-to-end test: rows are gone through the cascades, storage objects and FCM tokens are removed, and the auth user is deleted.
- [ ] Featured or sponsored disclosure is present (consumer protection) and moderation logs are kept (PECA takedown readiness).
