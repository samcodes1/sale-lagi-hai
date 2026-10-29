# Accounts (sub-phase 4.2)

The app is **guest-first**: everything works without an account, and signing in only syncs.

## Signing in (UX flow F6)
Profile → **Sign in** opens `/sign-in`, above the tabs.

| Method | How | Notes |
|---|---|---|
| Phone | A Pakistani mobile number, then a 6-digit code by SMS (Supabase Auth phone OTP) | Accepts `0300 1234567`, `+92…`, `0092…` and Urdu-keyboard digits (`PakistanPhone`). Landlines and foreign numbers are refused before any SMS is sent. The code field autofills from the SMS, accepts paste, and never suggests or learns. A new code can be requested after 60 s. |
| Google | Native Google sign-in; Supabase checks the ID token (`signInWithIdToken`) | Shown only when the build has `GOOGLE_SERVER_CLIENT_ID` (the **web** OAuth client ID that Supabase's Google provider uses) and the platform is native |

- **Errors.** A wrong or expired code, or a refused number, shows a message at the field. Rate limits (Supabase's own SMS limits) and network errors show their usual messages.
- **Guest sync.** Straight after sign-in, `sync_guest_preferences(city, lang, brand_ids, category_ids)` copies the on-phone city, language, followed brands and followed categories (from Explore, 4.5) into the account, together with saved deals. It runs once, under the shopper's own RLS, only follows active brands and categories, and takes at most 200 follows in all. If it fails, the choices stay on the phone and sync next time.
- **Sign out.** Signs out on this phone only. The on-phone choices stay.

## Deleting the account (UX flow F7, a Play requirement)
Profile → **Delete account** opens `/profile/account/delete` (signed-in shoppers only). The page lists what goes and what stays, and asks for one confirmation.

1. The app calls the `delete-account` Edge Function with the shopper's access token.
2. The function asks the Auth server who the token belongs to. If the last sign-in is more than 5 minutes old, it answers `403 reauth_required`. The app then opens `/sign-in?reauth=true` (with the number prefilled for phone users) and tries again once the shopper has signed in again.
3. `prepare_account_deletion(uid)` (service role only) hands the person's uploads in the public business buckets over to the business, and lists their private files. The function deletes those through the Storage API, in batches of 100 (Supabase refuses to delete a user who still owns files), then deletes the auth user. `on delete cascade` removes the profile, roles, follows, saves, cards, alert preferences, notifications, push tokens and queued pushes.
4. The app signs out, clears local storage (preferences and cached deals), and the phone returns to onboarding.

The function fails closed. Without `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`, or with any problem in the request (wrong method, missing or malformed token), nothing is deleted. Logs never hold ids or tokens.

**Still to do (Phase 9):** a web deletion page that works without the app, linked from the Play Data safety form.

## Configuration
| Setting | Where | Notes |
|---|---|---|
| Phone provider (SMS) | Supabase dashboard → Authentication → Providers → Phone | Owner decision: Twilio, MessageBird, Vonage or another provider. Pakistani senders may need PTA-registered sender IDs. |
| Google provider | Supabase dashboard → Authentication → Providers → Google | The web client ID (and its secret, server-side only). Android also needs an Android OAuth client with the app's SHA-1 per flavor. |
| `GOOGLE_SERVER_CLIENT_ID` | `env/<flavor>.json` | Public. Empty hides Google sign-in. `AppConfig` rejects anything that isn't `<number>-<id>.apps.googleusercontent.com`. |

## Code
- `lib/features/auth/domain`: `AuthRepository`, `AppUser` (its `toString()` holds no personal data), `PakistanPhone`.
- `lib/features/auth/data`:
  - `SupabaseAuthRepository`, which maps Auth errors to `AppFailure`s;
  - `DemoAuthRepository`, for builds without a backend: the code is always `123456`, 5 codes per hour per number, and the same 5-minute re-auth rule;
  - `PluginGoogleIdTokenSource`.
- `lib/features/auth/presentation`: `SignInScreen`, `DeleteAccountScreen`. Profile's account section is in `profile_screen.dart`.
- Server:
  - `supabase/migrations/20261029200000_accounts.sql`;
  - `supabase/functions/delete-account/` (`account.ts` holds the steps, `handler.ts` the HTTP layer).

## Tests
- `test/features/auth/`:
  - domain and demo rules;
  - the Supabase repository against mocked HTTP (request shapes, error mapping, deletion outcomes);
  - the flows in the real app (sign in, sync, wrong code, resend, Google, sign out, delete, re-auth, guests kept out);
  - accessibility (tap targets, labels and contrast in en and ur; 200% text; left-to-right number fields; the code field's privacy settings);
  - auth setup.
- `supabase/tests/database/800_accounts.test.sql`: sync rules and deletion preparation.
- `supabase/functions/delete-account/account.test.ts`: the steps, batching, re-auth, failure order and the HTTP API calls.
