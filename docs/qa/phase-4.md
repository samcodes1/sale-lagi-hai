# QA Report — Phase 4 gate: Consumer app core (4.1–4.9)
Verdict: **PASS**. No S1 or S2 bugs are open, and every gate step passes. New and open: **4 S3** (P4-J1, P4-F1, P4-R1, P4-P1) and **3 S4** (P4-D1, P4-P2, P4-T1). The carried-forward bugs keep their severity.

- Date: 2026-10-30
- Commit: `764d221` ("QA 4.8 round 2 and 4.9: PASS; sign-out leaves the phone as a guest's"), detached in `/home/user/slh-qa49`, cleaned with `git clean -xfd -e env/`
- Toolchain: Flutter 3.47.8 stable, Dart 3.13.7; PostgreSQL 16.15 with PostGIS, pgTAP and pg_cron via `tool/db_test.sh`; Node 22.22.0; Playwright 1.63.0 with its preinstalled Chromium
- Flavor and data: dev, on the in-memory demo backend. Widget journeys use a server-faithful fake, `ServerGateway` in `test/qa/phase4_harness.dart`. It honours filters, offsets and per-user RLS on `saves`, `user_cards`, `follows`, `notifications` and `alert_prefs`, refuses writes the policies refuse, and has an offline switch.
- Not possible here, so they are **CI or manual items**:
  - An Android emulator or device: `flutter test integration_test`, TalkBack through the core flows, the Android Accessibility Scanner, and `flutter build apk --analyze-size`.
  - gitleaks and osv-scanner (downloading binaries isn't allowed).

## Gate results
| # | Step | Command | Result | Evidence |
|---|---|---|---|---|
| 1 | Clean checkout and dependencies | `git clean -xfd -e env/`; `flutter pub get` | PASS | Exit 0. No advisories (`grep -i advisor` finds nothing). 12 packages have newer versions held back by constraints, including build_runner 2.17, which is pinned on purpose |
| 2 | Codegen is fresh | `dart run build_runner build -d && git status --porcelain` | PASS | "wrote 2 outputs"; `git status` is empty, so nothing generated differs from the commit |
| 3 | Format | `dart format --output=none --set-exit-if-changed lib test` | PASS | "Formatted 251 files (0 changed)". QA's new files are formatted too |
| 4 | Analyze | `flutter analyze` | PASS | "No issues found!" (also with QA's new files) |
| 5 | Flutter tests | `flutter test --coverage --concurrency=3` | PASS | **Run 1** (developer and earlier QA tests): `+1754 ~9 -1`. The one failure is a timing budget, `round2_qa_test.dart` "the worst 8 kB inputs … under 400 ms", at 553 ms under load. It passes alone, so it is flaky: P4-T1. **Run 2** (with QA's Phase 4 files): `+1788 ~13: All tests passed!` in 4m03s. The 13 skips: 8 documented open bugs (4 from earlier phases, 4 new from this gate) and the conditional `bootstrap_qa_test` cases |
| 6 | Coverage | `dart run tool/check_coverage.dart coverage/lcov.info --min 80` | PASS | **95.6%** (6812/7123). Phase 4 code (`lib/features`) **95.4%**; application **96.2%**, domain **97.4%** (table below) |
| 7a | Edge Function tests | `node --test 'supabase/functions/**/*.test.ts'` | PASS | 94 tests: 93 pass, 0 fail, 1 skipped (the existing no-PGHOST case), the same as at 4.2 and 4.6 |
| 7 | DB tests | `tool/db_test.sh` | PASS | Migrations from zero, then the schema lint 6/6 ok. pgTAP: **49 files, 859 tests, PASS**, with QA's new `qa_phase4_app_surface.test.sql` (54). The `todo` failures in `qa_rls`, `qa_seed` and `qa_storage` are Phase 2's documented open bugs |
| 8 | Dependency audit | `dart run tool/audit_deps.dart` | PASS | "Dependency audit passed: 158 packages." osv-scanner: CI only |
| 9 | Web release build | `flutter build web --release --no-web-resources-cdn --dart-define-from-file=env/dev.json` | PASS | "✓ Built build/web" in 55 s. Sizes are under Performance |
| 10 | Cross-sub-phase journeys | `test/qa/phase4_journeys_qa_test.dart` | PASS, with findings | 21 pass and 4 are skipped as open bugs (P4-J1, P4-R1, P4-D1, P4-F1). They fail as expected with `--dart-define=QA_KNOWN_BUGS=true` |
| 11 | Web journeys | `node docs/qa/screens/phase-4/drive_journeys.js build/web …` | PASS | 4 modes × 16 steps. 0 console or page errors. The only outside host is `accounts.google.com` (the known 4.2-A11, S4) |
| 12 | Accessibility audit | `test/qa/phase4_a11y_audit_qa_test.dart` | PASS | 31 screens × 8 modes (en/ur × light/dark × 100/200%, at 360×800). Checked: tap targets, labels, contrast, no layout exception, a heading on every content screen, and the reading order. TalkBack and Accessibility Scanner are manual |
| 13 | Performance sanity | `test/qa/phase4_perf_qa_test.dart`, review, bundle sizes | PASS, with findings | No rebuild storm and no request storm, and the lists are lazy. Findings: P4-P1 (image decode size, S3) and P4-P2 (Following is eager, S4). `main.dart.js` grew more than 10% over the phase (a note, not a defect) |
| 14 | Security review | the flutter-secure-dev checklist | PASS | Details below. No S1 or S2 |
| 15 | Bookkeeping | `docs/qa/4.1.md` … `4.9.md` | PASS | Every sub-phase's latest round is PASS. Every S1 and S2 from those reports has a reproducer that passes in this run. 4.9's fixes in `764d221` are re-tested (below) |

## Coverage
From `coverage/lcov.info` after run 2. Generated files (`*.g.dart`, `*.freezed.dart`, `l10n/gen`) are excluded.

| Area | Lines | % |
|---|---|---|
| Whole repo (`lib/`) | 6812/7123 | **95.6%** |
| `lib/features` (Phase 4) | 4333/4540 | **95.4%** |
| `features/*/domain` | 302/310 | **97.4%** (≥ 90%) |
| `features/*/application` | 819/851 | **96.2%** (≥ 90%) |
| `features/*/data` | 477/501 | 95.2% |
| `features/*/presentation` | 2735/2878 | 95.0% |
| `lib/core` | 1155/1218 | 94.8% |
| `lib/app` | 337/365 | 92.3% |
| `lib/design_system` | 986/999 | 98.7% |

- **Per-file exceptions:**
  - `auth/data/google_id_token.dart` is at 2/12. It is the native plugin wrapper, which needs a device (accepted in 4.2).
  - `auth/domain/auth_repository.dart` (lines 26–27) and `deals/domain/deal_page.dart` (lines 16–17) are each 2 lines short. They are equality and hashCode members.
  - The 4.2 gate judged domain and application as a group, as this report does. Both groups are above 90%.

## Bugs
| ID | Sev | Title | Status |
|---|---|---|---|
| P4-J1 | S3 | Offline, a saved deal opens to "No internet connection", not its saved copy, although the Saved tab says "Your saved deals still work" | Open |
| P4-F1 | S3 | With more than 200 follows, Sign out leaves every list on the phone, and sign-in syncs no city, language or follows | Open |
| P4-R1 | S3 | After a search, a city change made during a build ("Clear everything" in dark mode) trips Riverpod's "modify a provider while building" assertion | Open |
| P4-P1 | S3 | Deal images are decoded at full resolution in cards and on the deal page | Open (latent: the demo has no images) |
| P4-D1 | S4 | Deleting the account leaves the theme choice in memory (4.9-P1 was fixed only for "Clear everything") | Open |
| P4-P2 | S4 | Following builds every followed brand and category at once (`ListView(children:)`) | Open |
| P4-T1 | S4 | The redactor timing test is flaky under `--concurrency=3` | Open (test only) |

Environment for all: dev flavor, commit `764d221`, widget tests at 412×915 unless a size is given, en, light, 100%.

### P4-J1 (S3): offline, a saved deal can't be opened
- **Steps:**
  1. Online, save "Winter collection sale" (deal 4) and open the Saved tab, so its copy is stored.
  2. Restart offline.
  3. On Saved, the card shows with the offline banner: "No internet. Your saved deals still work; new ones will load when you're back."
  4. Tap the card.
- **Expected:** the deal page from its saved copy, with the offline banner and its age. UX S08 lists Deal detail's offline state as "Cached copy", and S17 as "Local copy".
- **Actual:** the deal page shows only "No internet connection. Check your connection and try again." and Try again. There is no title, offer or terms.
- **Evidence:** `phase4_journeys_qa_test.dart` "a saved deal opened from the Saved tab offline shows its saved copy" (skipped as `P4-J1`; fails when enabled).
- **Where:** `lib/features/deals/application/deal_providers.dart:19-26`. `dealDetailProvider` has no cache fallback, unlike `home_providers.dart:44-80` and `saved_view.dart:39-100`.
- **Suggested fix:** on an offline failure, build a reduced deal page from the cached card row (`saved.deals` or `home.*`, through `dealFromRow`): the offer, validity, brand and promo code, with "Updated X ago". Or cache `deals`/`outlets` rows for saved deals when they are viewed.

### P4-F1 (S3): more than 200 follows break Sign out and the sign-in sync
- **Steps:**
  1. Signed in, follow 201 brands or categories. Nothing on the phone caps follows; the account pull alone can bring up to 500.
  2. Save a deal.
  3. Profile, then Sign out.
- **Expected:** the phone is a guest's: no saves, cards or follows (the 4.8 BUG-9 fix).
- **Actual:**
  - `sync_guest_preferences` refuses the whole call ("at most 200 follows at once", 22023). `_sendLists` then returns false, so nothing is removed. The next person sees the saves, the bank cards and the follows, and the toast still says "Signed out".
  - At sign-in, the same refusal drops the city and language sync too, because they share that call.
  - The log has "Could not send the lists before signing out" and nothing else. The account note still keeps the lists out of another account.
- **Evidence:** `phase4_journeys_qa_test.dart`, group "exploratory": "P4-F1: … Sign out still leaves the phone as a guest's" (skipped as `P4-F1`; fails when enabled: the saved list is `[deal 4]`) and "P4-F1 (as it is today)" (passes and pins today's behaviour).
- **Where:**
  - `lib/features/auth/application/auth_providers.dart:63-70` (sign-out) and `:160-170` (sign-in);
  - the cap is in `supabase/migrations/20261029200000_accounts.sql:30-31`;
  - there is no follow cap in `lib/features/onboarding/application/preferences_controller.dart`.
- **Suggested fix:** send follows in chunks of at most 200, and send the city and language in their own call. Alternatively, cap follows in the app at 200 with a note, and cap the pull at 200.

### P4-R1 (S3): a provider is changed during a build after a search
- **Steps:**
  1. Search for "burger" (Explore, then search).
  2. Settings: pick Dark.
  3. Privacy: "Clear everything on this phone", then Clear.
- **Expected:** onboarding, and no framework error.
- **Actual:**
  - "Tried to modify a provider while the widget tree was building" is thrown inside `SettingsScreen.build`, which watches `homeCityProvider`.
  - The theme reset rebuilds every route. The dirty city provider is flushed inside that build, and `SearchController`'s listener then sets `state` synchronously.
  - Debug and dev builds report the error. Release builds skip the assertion, and Riverpod warns that the UI can end up inconsistent. The flow still reaches onboarding.
  - Without the earlier search, or without the theme change, nothing is thrown.
- **Evidence:** `phase4_journeys_qa_test.dart` "P4-R1: … changes no provider during a build" (skipped; fails when enabled). Stack: `SearchController.build.<closure>` at `search_providers.dart:59`, called from `SettingsScreen.build`.
- **Where:** `lib/features/search/application/search_providers.dart:56-61`.
- **Suggested fix:** don't write `state` from a listener on a provider that other widgets watch during build. Either keep the area filter keyed by city (drop it when it is read if its city isn't the current one), or defer the write with `Future.microtask`.

### P4-P1 (S3): deal images decode at full size
- **Where:** `lib/design_system/widgets/deal_card.dart:327` and `lib/features/deals/presentation/deal_detail_screen.dart:134`. Both use `Image.network(url)` with no `cacheWidth` or `cacheHeight` and no `ResizeImage`. URLs are `/storage/v1/object/public/deal-images/…` (`deal_card_mapper.dart:14`), with no image transform.
- **Why it matters:**
  - `deal-images` accepts files up to 2 MB (`20261029150000_storage.sql:23`). A 2 MB JPEG or WebP can be 12 MP, about 48 MB decoded.
  - A feed card is about 330×165 dp. The default `ImageCache` (100 MB) then holds about 2 such images, so a scroll keeps decoding again on low-RAM Android phones.
  - The demo data has no images, so nothing shows today.
- **Suggested fix:** pass `cacheWidth` from `LayoutBuilder` width × `devicePixelRatio` (or wrap in `ResizeImage`), or request Supabase's `render/image` transform at the card's size. Add a widget test asserting the `ImageProvider` is a `ResizeImage`.

### P4-D1 (S4): account deletion keeps the theme in memory
- **Steps:** signed in, choose Dark in Settings. Profile, Delete account, Delete my account, then confirm.
- **Expected:** a fresh start, as "Clear everything" now does (4.9-P1): the theme follows the phone.
- **Actual:** onboarding shows in Dark. After the next launch it is "As on this phone", because the stored key is gone.
- **Evidence:** `phase4_journeys_qa_test.dart` "deleting the account starts the phone fresh …" (skipped as `P4-D1`; `themeModeProvider` is `dark`).
- **Where:** `lib/features/auth/presentation/delete_account_screen.dart:91-104`, compared with `lib/features/settings/presentation/privacy_screen.dart:60-61`.
- **Suggested fix:** use one shared "fresh start" routine for both paths: clear the store, reset preferences and reset the theme.

### P4-P2 (S4): Following is not lazy
`lib/features/follows/presentation/following_screen.dart:80-100` uses `ListView(children: [... Column(children: [for (final b in value) row(...)])])`. Follows are uncapped (see P4-F1), and the pull brings up to 500. Every row and its `FollowButton` is built at once. Fix: `CustomScrollView` with `SliverList.builder` per section.

### P4-T1 (S4): a flaky timing test
`test/qa/round2_qa_test.dart:78-88` asserts each 8 kB redaction takes under 400 ms of wall-clock time. In run 1 it took 553 ms under `--concurrency=3`, with 3 test isolates on this container. It passes alone and in run 2. Fix: warm up first, and compare with a linear baseline measured in the same test, not a fixed number of milliseconds. Or tag it `perf` and run it on its own.

### Carried forward (not re-filed; the whole-phase view keeps their severity)
- **4.8 BUG-7 (S4)** (a switched-off follow is counted but not listed) and **4.9 N6 (S3)** (offline settings changes are reverted with a note, not queued): unchanged.
- **4.9 V1 (S4):** at 200%, the audit found no overflow or exception on any Urdu screen. The clipping is visual only.
- **4.2-A11 (S4):** the web build still contacts `accounts.google.com` (`journeys-report.json`).
- The S4s listed as open in earlier reports.

## Integration: cross-sub-phase journeys
Every journey runs the real `App`, `routerProvider` and providers, and drives the real screens by tapping and typing. Only the device services (location, notification permission, links, network status) and the backend are faked.

| # | Journey | Sub-phases | Result | What is asserted |
|---|---|---|---|---|
| J1 | First launch → onboarding (detect city, interest, brand, alerts) → Home feed → deal from the feed → Save → Saved tab | 4.1, 4.3, 4.4, 4.8 | PASS | Home in Karachi with cards. The deal opens from its card. "Saved." shows, and as a guest nothing is sent to the server. Saved lists it under "Active (1)", and it is stored on the phone |
| J2 | A guest saves, adds a card (Profile → My cards) and follows a brand → signs in as A → A's rows on the server → signs out → Saved is empty → B saves as a guest and signs in → B's rows only → A again | 4.2, 4.4, 4.5, 4.7, 4.8 | PASS | Per-user rows on the server. The phone is a guest's after Sign out. B never gets A's lists, and A never gets B's. A's lists come back to the phone. No write is refused by RLS. No phone number appears in any log line |
| J2b | A session that ends on its own (a raw repository sign-out) keeps the lists; the next account still doesn't get them | 4.2, 4.8 | PASS | As designed |
| J3 | A link to `/deal/<id>` → the deal page, then Share on WhatsApp | 4.4 | PASS | The shared text holds the deal's title |
| J3b | A link that opens the app on first launch → onboarding → the deal | 4.1, 4.4 | PASS | |
| J3c | 6 hostile links (`..%2F`, `%2e%2e`, `javascript:`, 5,000 characters, an unknown uuid, a malformed id) | 4.4 | PASS | No crash, and the input is never shown (Home, Not found, or the deal's not-found view) |
| J3d | `https://evil.example.com/deal/<id>` | — | Note | go_router matches on the path only. Android has `flutter_deeplinking_enabled=false` until 5.3, so no outside link reaches the router today. The 5.3 `DeepLinkService` must check the host (Recommendations) |
| J4 | Online Home → restart offline → banner, cached rows with "Updated …" → back online: banner gone → pull to refresh: fresh rows | 4.3 | PASS | |
| J4b | A saved deal opened offline | 4.4, 4.8 | **P4-J1** | |
| J5 | Profile → اردو → all 5 tabs are RTL, with Urdu nav labels and no exception → a deal shows its Urdu title → English → LTR. Stored as `settings.locale = ur` | 4.2, 4.3, 4.5, 4.8 | PASS | |
| J6 | Explore → search "burger" → Filters → "Meezan" → Show deals → deal 9 → back keeps "Filters (1)" and the results | 4.5, 4.6, 4.4 | PASS | At most 4 `search_deals` calls. The words are kept in recent searches on the phone only |
| J7 | Explore → "My cards" → add Meezan Visa Debit → its offer (deal 9, not HBL's deal 7) → the deal → sign in → the card is in the account → the list still shows deal 9 only | 4.5, 4.7, 4.4, 4.2 | PASS | The list comes from `deals_for_cards` over the phone's cards (as designed, `docs/app/MY_CARDS.md`). No 12–19 digit number in any write |
| J8 | Settings → Dark, City Lahore, اردو → every tab is dark and RTL with no exception → Home is Lahore's (no Karachi local deals) → `loadStartupSettings` reads all three back (a restart) | 4.9, 4.3, 4.1 | PASS | |
| J9 | Signed in with a save, Dark → Settings → Privacy → "Clear everything" → onboarding, signed out, no lists, theme reset, store empty. The account's save is untouched; onboard again, sign in, and the save is back | 4.9, 4.2, 4.1, 4.8 | PASS | Also **P4-R1** when a search came first |
| J9b | Signed in → Delete account → confirm → onboarding, "Your account was deleted.", no lists, store empty | 4.2, 4.1 | PASS except the theme | **P4-D1** |
| X1 | A double tap on Sign out | 4.2 | PASS | One sign-out, no error |
| X2 | Sign out offline → the lists stay (by design) → B signs in online → B gets none of A's | 4.8 | PASS | |

**Web build (Playwright, `docs/qa/screens/phase-4/drive_journeys.js`):**
- **Modes:** 360×800 light en, 360×800 dark ur, 360×800 light ur at 200%, 412×915 dark en.
- **Flows:**
  - J1: language → city (Karachi) → Skip, Skip, Not now → Home → deal → Save → Saved;
  - J4: browser offline → banner on Home → Saved and a deal → online → banner gone;
  - J5: Profile language switch → 4 tabs;
  - J6: `/search?q=burger`.
- **Result:** 0 console or page errors in all modes, and every check is true (`journeys-report.json`). The demo backend is in memory on the web, so web "offline" only tests the banner; the data path is J4 above.
- **Contact sheets:** `sheet_<mode>.png`. Mirroring is correct: the back arrow and the bookmark flip in Urdu, and the digits and logo don't. There is no overflow.
- **Web-only artifact:** after a tap, the nav-bar tooltip ("Alerts", "تلاش") hovers over content.

## Accessibility audit
**Automated** (`phase4_a11y_audit_qa_test.dart`, 9 tests, all pass):
- **Screens (31):**
  - onboarding (5 steps);
  - as a guest: Alerts, Saved, Profile, My cards, Following, Notifications, Sign in;
  - signed in with data (saves, a card, a follow, 2 alerts): Home, Explore, Alerts, Saved, Profile, 2 deals (a local one and a card offer), brand, category, search (empty and with results), My cards, Following, Settings, Notifications, Privacy, Terms, About, Delete account.
- **Modes (8):** English and Urdu, light and dark, 100% and 200% text, at 360×800.
- **Per screen and mode:**
  - `androidTapTargetGuideline`, `labeledTapTargetGuideline` and `textContrastGuideline`;
  - no exception or overflow;
  - a heading for screen readers (`isHeader`) on every content screen (sign-in, search and About are forms or short pages);
  - 248 screen-mode checks in all.
- **Reading order:** on Home, Explore, Saved and Profile, in English and Urdu, the screen's content comes before the bottom navigation in traversal order.
- **Contrast false positive (not filed):**
  - On the Urdu onboarding steps at 360dp and 200% text, `textContrastGuideline` reported 1.5:1 for the body text.
  - The body text there runs on below the pinned yellow Continue bar, and the guideline samples the node's whole rect, so it measured the text against the button.
  - Scrolled into view, the same text passes. The audit scrolls and measures again before it records a contrast failure.
- **Test artifact (not filed):** the Terms page "never settles" in tests that load it after an earlier test. `rootBundle` caches the `loadString` future from the earlier test's fake-async zone. `setUp(rootBundle.clear)` fixes it in the test; the app is unaffected.

**Manual (could not run here):** TalkBack through the five core flows (onboarding, feed → deal → save, search, sign in, settings) and the Android Accessibility Scanner. They need a device or emulator; record them on the release candidate. Earlier gates judged TalkBack labels from the semantics tree, which is what TalkBack reads.

## Performance sanity
- **Feed paging** (`phase4_perf_qa_test.dart`): 200 deals scroll to "You've seen all the new deals" in **11** `feed` calls: 10 pages, then one empty page that confirms the end. No cursor is asked twice. Fewer than 90 `DealCard`s are built at any time: the 4 carousels of up to 20 each, plus a screenful of the feed.
- **Rebuild storm:**
  - With `debugOnRebuildDirtyWidget`, an idle Home rebuilds **nothing** over 10 s. The minute timers in `deal_labels.dart` didn't fire in that window.
  - A scroll doesn't rebuild `HomeScreen`, and sends at most 1 request (the next page).
- **Saved at its cap of 500:** at most 5 `deal_cards` reads (chunks of 100). "Active (500)" shows with fewer than 20 cards built.
- **Unbounded lists:**
  - Every data list is `SliverList.builder`: feed, Saved, Alerts, Explore brands, brand and category deals, search results, the onboarding brands and cities.
  - These are bounded and eager: the carousels (at most 20), My cards (at most 20), suggestions (at most 10) and the legal text (static).
  - One exception: Following (P4-P2).
- **Image cache:** Flutter's default `ImageCache` (1000 images / 100 MB) applies, but images are decoded at full size (P4-P1).

**Bundle sizes:**

| Measure | Phase 1 final | 4.3 | Phase 4 (this run) | Change over the phase |
|---|---|---|---|---|
| `main.dart.js` raw | 3,278,784 B | 3,829,320 B | **4,315,603 B** | +31.6% (+12.7% since 4.3) |
| `main.dart.js` gzip -9 | 940,671 B | 1,102,021 B | **1,220,621 B** | +29.8% (+10.8% since 4.3) |
| Web `assets/` | 3,412,927 B | — | **3,690,070 B** | +8.1% (+0.3% since 4.1) |

The growth is nine sub-phases of features: search, cards, inbox, settings and the legal texts. It is flagged as more than 10%, but it isn't a defect. APK size (`--analyze-size`) needs the Android SDK, so it is CI only.

## Security review (flutter-secure-dev checklist, whole phase)
| Item | Result | Evidence |
|---|---|---|
| Secrets in the repo | PASS | `git grep -nE 'sb_secret_\|service_role\|BEGIN (RSA\|EC\|PRIVATE)'` outside docs and tests matches only the QA SQL stub and `.gitleaks.toml`. There are no JWTs in `lib`, `android`, `ios`, `web` or `env`. Only `env/*.example.json` is tracked, and `env/dev.json`, `.env` and `android/key.properties` are ignored. gitleaks: CI only |
| Personal data in logs | PASS | No `print(`/`debugPrint(` in `lib`. No log call passes a phone number, email, location, token or search words; context values are codes, counts and error types. J2 ran two phone sign-ins and found neither number in any log record |
| Cleartext | PASS | No `http://` in `lib`. `usesCleartextTraffic="false"` and `network_security_config.xml` trusts system CAs only (user CAs only in debug overrides) |
| Manifest | PASS | Only `MainActivity` is exported (the launcher). The geolocator service is removed. Permissions are coarse location and POST_NOTIFICATIONS; fine and background location and AD_ID are stripped. `allowBackup="true"` with rules that exclude `FlutterSecureStorage*.xml` (the session) |
| Deep links | PASS (note) | `flutter_deeplinking_enabled=false`: no outside link reaches the router until 5.3. Route parameters are checked (`route_params.dart`): an invalid id or slug goes Home and is never shown. 6 hostile links in J3c. Host checking is a 5.3 requirement (J3d) |
| On-phone data | PASS | SharedPreferences hold the language, city, interests, follows, saved deal ids, card product ids (never numbers), recent searches, public deal copies, and the account note (a user uuid). The session is in secure storage, which backup excludes. Clear everything and account deletion empty the store (J9 and J9b assert no non-cache key remains) |
| RLS on every table and RPC the app uses | PASS | QA's `qa_phase4_app_surface.test.sql` (54 tests) — see the list below this table |
| Card numbers | PASS | J7: no 12–19 digit run in any write. 4.9-C1/C2 (Urdu and Arabic-Indic digits, separators) are re-tested by QA's `settings_units_qa_test.dart` and `qa_card_numbers_urdu.test.sql`, which pass |

What `qa_phase4_app_surface.test.sql` checks:
- **Tables:** RLS is on for all 16 tables the app touches, and `deal_cards` is `security_invoker`.
- **Grants:**
  - anon can call the 9 read RPCs and none of the 7 account RPCs;
  - no app RPC is executable by PUBLIC;
  - every definer function pins `search_path`.
- **Isolation between two shoppers:** B sees, deletes and marks read none of A's saves, follows, cards, alerts or alert preferences. Inserts in A's name are refused (42501). `unread_alert_count`, `mark_alerts_read`, `deals_for_my_cards` and `my_alert_prefs` are scoped to the caller, and the sync RPCs write as B only. A is untouched afterwards.
- **anon:** no reads of user tables, no saves, reports or sync. No draft or review appears through `deal_cards`, `deals`, `feed`, `search_deals` or `brand_deals`, while the live deal does.

## Bookkeeping: sub-phase reports
| Report | Latest verdict | S1/S2 in it | Re-test here |
|---|---|---|---|
| 4.1 | PASS (round 2) | BUG-1 (S2) fixed | The reproducer in `onboarding_r2_qa_test.dart` passes. J1 and J3b cover the flow |
| 4.2 | PASS (round 2) | A1, A2 (S2) fixed | The A1 reproducers (`supabase/functions/delete-account/qa_account.test.ts`) and the A2 reproducers (`auth_flow_qa_test.dart`) pass. J2 and J9b |
| 4.3 | PASS (round 2) | BUG-7 (S2) fixed | The city button reproducer in `home_qa_test.dart` passes. The audit passes on Home in every mode |
| 4.4 | PASS (round 2) | BUG-1, BUG-2 (S2) fixed | The reproducers pass. In J2 and J7, `RulesGateway` refused no write |
| 4.5 | PASS (round 2) | BUG-1 (S2) fixed | J2 follows reach the account as the user |
| 4.6 | PASS | none | 4.6-S3 is fixed (`c771bf5`): QA's `qa_search` reproducer passes in the DB run |
| 4.7 | PASS | none | A1, A6 and P1 are fixed (`199c59e`), and their reproducers pass |
| 4.8 | PASS (round 2) | BUG-1 (S2) fixed | The round-2 shared-phone tests pass. J2 repeats them through the screens. BUG-9 (S3) is fixed except with more than 200 follows (P4-F1) |
| 4.9 | PASS | none | The fixes in `764d221` are re-tested: QA's N1, N2, N4, N5, P1, S1 (widget), M1, C1, C2, T1 (unit), C1/C2 (SQL) and L1 (the privacy text now points to the Play listing) reproducers run unskipped and pass. N6 (S3) and V1 (S4) are carried |

## Exploratory charters
1. **A shared phone, three ways to leave** (sign out, a session that ends, Clear everything, delete). Driven by J2, J2b, J9, J9b, X1 and X2.
   - Findings: P4-D1, P4-R1, and P4-F1 (the over-200 path).
   - Offline and double-tap sign-out behave as designed.
2. **Offline across the tabs** (Home, Saved, a deal, Settings).
   - Home and Saved keep their copies.
   - A deal doesn't (P4-J1).
   - A Settings change offline reverts with a note (N6, carried).
3. **Big inputs:**
   - 200 feed deals and 500 saves behave (Performance).
   - 201 follows break the sync (P4-F1).
   - A 5,000-character link and hostile ids are handled (J3c).
   - Full-size images aren't (P4-P1).

## Tests added by QA
- `test/qa/phase4_harness.dart`:
  - `ServerGateway`: `RulesGateway` plus per-user RLS on reads, deletes and the per-user RPCs, an offline switch, and a request log;
  - `Journey`: the real `App` with scripted device services, a network that can drop and return, a memory log sink for privacy checks, and a pluggable backend;
  - helpers to sign in by phone or Google through the real pages.
- `test/qa/phase4_journeys_qa_test.dart` (25): J1–J9 and the exploratory group. 4 are skipped as open bugs: P4-J1, P4-R1, P4-D1, P4-F1.
- `test/qa/phase4_a11y_audit_qa_test.dart` (9): the 8-mode audit over 31 screens, plus the reading order.
- `test/qa/phase4_perf_qa_test.dart` (3): feed paging at 200, no rebuild or request storm, Saved at 500.
- `supabase/tests/database/qa_phase4_app_surface.test.sql` (54): the app's database surface per role.
- `docs/qa/screens/phase-4/drive_journeys.js`: the Playwright web journeys.

Run the open-bug tests with `flutter test test/qa/phase4_journeys_qa_test.dart --dart-define=QA_KNOWN_BUGS=true`. When a bug is fixed, delete its `skip:`.

## Screenshots
All in `docs/qa/screens/phase-4/`. They were taken at deviceScaleFactor 2 and saved at half size, with a 128-colour palette.
- **Per step:** `<step>_<mode>.png`. The steps are `j1-language`, `j1-city`, `j1-home`, `j1-deal`, `j1-deal-saved`, `j1-saved`, `j4-home-offline`, `j4-saved-offline`, `j4-saved-deal-offline`, `j4-home-online`, `j5-profile-switched`, `j5-tab-*` and `j6-search`. The modes are `360x800_light_en`, `360x800_dark_ur`, `360x800_light_ur_ts2` and `412x915_dark_en`.
- **Contact sheets:** `sheet_360x800_light_en.png`, `sheet_360x800_dark_ur.png`, `sheet_360x800_light_ur_ts2.png`, `sheet_412x915_dark_en.png`.
- **Report:** `journeys-report.json` (steps, checks, issues and outside hosts per mode).

## Recommendations (non-blocking)
- **5.3 deep links:** the `DeepLinkService` must accept only the app's own host and scheme before handing a path to go_router, because go_router ignores the host (J3d). Add the hostile URIs from J3c and J3d to its tests.
- **Bundle:**
  - Add a CI size budget for `main.dart.js` (gzip). It grew about 30% over Phase 4.
  - Keep the developer pages (theme preview, gallery) out of prod builds (1.5 S4-2, still open).
- **One "fresh start" routine** for Clear everything and account deletion (P4-D1), so the next reset item isn't missed in one of them.
- **Offline promise:** either deliver a cached deal page (P4-J1) or soften the banner copy ("Your saved deals still work").
- **Release candidate:** run TalkBack, Accessibility Scanner, `integration_test` on an emulator, `flutter build apk --analyze-size`, gitleaks and osv-scanner in CI.
