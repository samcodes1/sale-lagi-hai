# Settings (sub-phase 4.9)

Settings (screen S18) opens from Profile, at `/settings`. Its pages open over the tabs, on the root navigator.

## The pages
- **Settings** (`/settings`):
  - language (English or اردو, the same control as on Profile);
  - city, through the same sheet as Home's city button;
  - appearance: as on this phone, light or dark;
  - links to Notifications, Privacy, the two legal texts and About.
- **Notifications** (`/settings/notifications`, S19):
  - **Guests** are asked to sign in. Alert choices are kept per account; follows work without one.
  - **Push notifications:** turning it on asks Android first (13+). Only a grant, or a phone with no permission to ask for, turns it on. Turning it off never asks.
    - If Android won't ask again (permanently denied), a note says so, with **Open settings**. Coming back re-checks.
  - **Topics:** followed brands, followed categories, offers for my cards, new deals in my city, price drops and ending soon on saved deals.
  - **Frequency:** at most 1, 3 or 6 a day.
  - **Quiet hours:** a start and an end, from the system time picker. The same start and end is refused with a note (the database refuses it too). The hint says deliveries in quiet hours wait for the morning.
  - **Every change saves at once.** Only the changed fields are sent. A failed save puts the old value back and shows "Couldn't save that. Try again." (UX S19).
- **Privacy** (`/settings/privacy`):
  - what stays on this phone, what the account keeps, and what we never collect;
  - **Clear recent searches**;
  - **Clear saved copies of deals** (the offline cache);
  - **Clear everything on this phone**, after a confirmation: signs out, clears local storage and the shopper's choices, and returns to onboarding. The account itself is untouched.
  - **Delete account** (signed in only) opens the deletion page from 4.2.
- **Legal** (`/settings/legal/terms`, `/settings/legal/privacy`): bundled text in the app's language, so it works offline. `# ` lines are headings and `- ` lines are list items. Any other document name goes to Settings. A text that can't be read shows the error view, not an endless spinner.
- **About** (`/settings/about`): the name, tagline, version ("1.0.0 (1)") and open-source licences. **Contact us** shows only when the build has a `SUPPORT_EMAIL`.

## Theme
- `themeModeProvider` holds `AppThemeMode {system, light, dark}`. It is saved under `settings.theme`.
- `bootstrap` reads it before the first frame (`StartupSettings.theme`), so the app never flashes the wrong theme.
- A failed save is logged with only the error type. The switch still applies for the session.

## Alert preferences
- `alertPrefsProvider` is `null` for guests. While the sign-in state is still loading it stays loading, so a signed-in shopper never sees the guest view first.
- `AlertPrefs.fromRow` keeps the defaults for missing or odd values. Times go to the database as `HH:MM` (`AlertPrefs.wireTime`).

## Config
- `SUPPORT_EMAIL` is optional and must be one plain address. Anything that could add a subject, body or more recipients is refused:
  - `?`, `&`, `#`, `/` or `:`;
  - `,`, `;` or `%`;
  - spaces or a second `@`.
- `AppConfig` refuses a bad address at startup, and `LinkService.email` checks it again (`mailtoUri`).

## Backend (`20261029250000_settings.sql`)
- `my_alert_prefs()` returns the caller's row. With no row, the client uses the defaults.
- `update_alert_prefs(...)` changes only the fields given. Both functions run as the caller, for `authenticated` only. RLS keeps each shopper to their own row.
- The `alert_prefs` table (`20261029120400_user_activity.sql`) checks that quiet hours have a different start and end.
- Tests: `supabase/tests/database/860_settings.test.sql`.

## Not built, and why
- **Per-topic Android notification channels** come with the push client in Phase 5. The topics here already map one to one.
- **Ramadan and Jumu'ah timing** is a campaign rule for the dispatcher, not a shopper setting.

## Tests
- `test/features/settings/alert_prefs_test.dart`: the model, loading, sending only the changed fields, reverting on failure, signing out.
- `test/features/settings/settings_screens_test.dart`: every page and flow above, plus tap targets, labels, contrast and 200% text, in English and Urdu.
- `test/core/theme/theme_mode_controller_test.dart`, `test/core/text/card_numbers_test.dart`, `test/core/links/link_service_test.dart`, and the `SUPPORT_EMAIL` cases in `test/app/config/app_config_test.dart`.
