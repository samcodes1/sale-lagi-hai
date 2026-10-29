# Onboarding (sub-phase 4.1)

UX flow F1 (`docs/ux/UX_ARCHITECTURE.md`): first launch takes under a minute, and every step except language can be skipped.

| Step | Route | What happens |
|---|---|---|
| Splash | (native) | Android 12+ system splash: the mark on Haldi (light) or Surma (dark), from `design/app-icon`. Older Androids get the same image as the launch background. It's removed at Flutter's first frame. |
| 1. Language | `/welcome` | English or اردو, defaulting to the phone's language. It applies at once (script and direction) and is saved. It can't be skipped. |
| 2. City | `/welcome/city` | Pick from the list, or tap **Detect my city**. |
| 3. Interests | `/welcome/interests` | Top-level categories as chips; 3 or more suggested, none required. |
| 4. Brands | `/welcome/brands` | Active brands in the picked interests (all brands if none), each a row that toggles Follow. |
| 5. Alerts | `/welcome/alerts` | Notification priming: an example alert, the promises (at most 3 a day, never at night, topics in Settings), then **Turn on alerts** or **Not now**. |

On the city step:
- **Detect my city** asks for approximate location (only when tapped) and matches it to the nearest city centre, within 60 km, on the phone.
- Every outcome has a message: denied, blocked (with a link to settings), location off, not near a covered city, or no location.

On the alerts step:
- The system dialog appears only after **Turn on alerts**, and onboarding never asks again.
- If Android has blocked the dialog for good, the step says so and offers settings.

## How it works
- **Routing.** `routerProvider` sends every location to `/welcome` until `onboarded`, and away from `/welcome` afterwards. A link that opened the app (a shared deal) is kept and opened once onboarding ends. Each step *pushes* the next, so system back returns to the previous step.
- **State.** `ShopperPreferences` holds `onboarded`, `cityId`, `interestIds`, `brandIds` and `alertsAskedAt`. It is saved as JSON in the key-value store (`preferences.v1`): public ids and flags only. `bootstrap()` reads it before the first frame, so a returning shopper never sees onboarding flash by. A damaged file reads as a first launch, field by field.
- **Guest-first.** Nothing needs an account. Followed brands are kept on the phone and become `follows` rows when the shopper signs in (4.2).
- **Reference data.** `CatalogRepository` (`lib/features/catalog`) reads `cities`, `categories` and `brands` through the backend gateway, and `DemoGateway` provides them in dev. Failures become `AppFailure`s, so each step shows `ErrorView` with **Try again**.
- **Device services.** `LocationService` (geolocator's Android and iOS implementations only; geolocator's Linux plugin conflicts with connectivity_plus over dbus) and `NotificationPermissionService` (permission_handler). Both turn every platform error, including "no plugin" on the web, into an outcome; neither ever throws.

## Privacy
- Location: `ACCESS_COARSE_LOCATION` only. Fine and background location are stripped from the merged manifest. Coordinates are used for one nearest-city lookup on the phone; they are never sent, stored or logged (`Located.toString()` hides them).
- Notifications: `POST_NOTIFICATIONS` is declared and requested only from the priming screen.

## Tests
| File | What it checks |
|---|---|
| `test/features/onboarding/onboarding_flow_test.dart` | The whole flow on the demo backend; skipping; back; a returning shopper; a deferred deep link; every location outcome; alerts blocked; offline and retry |
| `onboarding_a11y_test.dart` | Tap targets, labels and contrast on every step (en light, ur dark); 200% text at 360 × 800 in both languages; RTL mirroring; headings; selected and toggled semantics |
| `onboarding_golden_test.dart` | Every step in en, ur and ur dark (`goldens/ci`, `goldens/linux`) |
| `preferences_test.dart`, `test/features/catalog/catalog_test.dart`, `test/core/device/device_services_test.dart` | The model, store, controller, repository, nearest city and device services |
| `test/security/android_config_test.dart` | The permission allowlist, the adaptive and themed icon, and the splash in light and dark |
