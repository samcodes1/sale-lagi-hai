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

## Changed after the 4.9 QA gate (PASS)
- **N1 (S3):** Android's status check reports "denied" even when it won't ask again. So the page now:
  - remembers "blocked" from the request's answer, until a check says granted;
  - re-checks when the app comes back to the front, not straight after opening Settings;
  - shows the note whenever push is on in the account but the phone doesn't allow it.
- **N2 (S3):** a second tap while the system dialog is up doesn't ask again. A platform error from the permission plugin counts as denied, never as allowed. `unavailable` now means only that there is no plugin (web, tests).
- **N4 (S3):** a failed save puts back only the fields it changed. A later change that was saved stays.
- **N5 (S4):** if the server has no row and saves nothing, the change is reverted.
- **C1/C2 (S3/S4):** the card-number check, in the app and the database, also reads Urdu and Arabic-Indic digits, and dots, double spaces or " - " between the groups.
- **L1 (S3):** the privacy policy points to the Google Play listing's email, and to About only when the build shows a contact address.
- **P1:** "Clear everything" also resets the theme.
- **S1:** the city row shows no name, rather than "All Pakistan", while a chosen city's name can't load.
- **M1:** capitals in the support address's domain are accepted.
- **T1:** out-of-range times from the database (24:00) fall back to the default.
- **N6 (S3), fixed after the gate:** with the phone offline, a change stays on screen and waits on the phone (`settings.alert_prefs.queued.v1`, tied to the account), with "Saved on this phone. It will be sent when you are back online."
  - It goes out when the phone is back online, or at the next load (after a restart too), together with any later change.
  - A refusal from the server drops it and shows the saved values.
  - With the phone online, a failed save still reverts with a note (UX S19: "Save failed → revert + toast"; offline: "Queued").
- **V1 (S4), fixed after the gate:** the app bar grows by what large text adds to its title (`TallTitleToolbar` in `app.dart`), so a Nastaliq title at 200% stays inside it. At 100% it keeps Material's 56dp.
- **Open, carried forward:** the system time picker clips its AM/PM toggle at 200%. It's Material's own dialog, and the text is never shrunk to fit.

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
