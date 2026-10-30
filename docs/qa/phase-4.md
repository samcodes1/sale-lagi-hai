# QA Report — Phase 4 gate: Consumer app core (4.1–4.9)
Verdict, round 3 (`5e6b6bb`): **PASS**. P4-R2-1 (S2) and P4-R2-2 (S3) are verified fixed. One new S3 is open: P4-R3-1, the offline banner with Try again overflows in Urdu at 200%. See [Round 3](#round-3-5e6b6bb).

Round 2 (`381aaae`): **FAIL**. One S2 is open: P4-R2-1, the offline settings queue writes one account's change into another's account. One new S3 is open too: P4-R2-2. Every round-1 bug and the three carried items are verified fixed. See [Round 2](#round-2-381aaae).

Round 1 (`764d221`): **PASS**. No S1 or S2 bugs are open, and every gate step passes. New and open: **4 S3** (P4-J1, P4-F1, P4-R1, P4-P1) and **3 S4** (P4-D1, P4-P2, P4-T1). The carried-forward bugs keep their severity.

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

## Round 2 (`381aaae`)
### Run details
- Date: 2026-10-30. Commit: `381aaae` ("Phase 4 gate: PASS; its S3/S4 findings fixed"), detached in `/home/user/slh-qa49`, cleaned with `git clean -xfd -e env/`.
- What changed since `764d221`:
  - `220f3fc`: the 4.9-N6 offline settings queue;
  - `48b4f09`: the 4.9-V1 `TallTitleToolbar`;
  - `b81c78c`: the 4.8 BUG-7 fix;
  - `381aaae`: the fixes for this gate's 7 findings, and QA's files committed.
- Same toolchain and environment as round 1.

### Gate results
| # | Step | Command | Result | Evidence |
|---|---|---|---|---|
| 1 | Dependencies | `flutter pub get` | PASS | No advisories |
| 2 | Codegen is fresh | `dart run build_runner build -d && git status --porcelain` | PASS | "wrote 2 outputs"; no diff |
| 3 | Format | `dart format --output=none --set-exit-if-changed lib test` | PASS | "Formatted 256 files (0 changed)", and clean with QA's new file |
| 4 | Analyze | `flutter analyze` | PASS | "No issues found!", also with QA's new file |
| 5 | Flutter tests | `flutter test --coverage --concurrency=3` | PASS | `+1804 ~8: All tests passed!` (4m09s), the same count as the coordinator's run. QA's Phase 4 files plus the edited QA files (inbox, deal page, round2), re-run together: `+219 ~2: All tests passed!`. QA's round-2 file: `+17 ~2` (2 new open bugs, skipped). P4-T1 didn't recur |
| 6 | Coverage | `tool/check_coverage.dart --min 80` | PASS | **95.6%** (6970/7290). Phase 4 features 95.4%; application **95.4%**, domain **97.4%**. Changed files: `alert_prefs_providers` 84/93, `deal_providers` 28/30, `follow_providers` 45/45, `search_providers` 93/93, `network_picture` 10/10, `auth_providers` 112/118 |
| 7 | DB tests | `tool/db_test.sh` | PASS | Lint 6/6. **49 files, 859 tests, PASS** |
| 8 | Web build and journeys | `flutter build web --release …`; `drive_journeys.js` | PASS | 4 modes × 16 steps, 0 errors. Only host: `accounts.google.com` (4.2-A11). Urdu 200% app-bar titles now sit inside the taller bar (`screens/phase-4/round2/sheet_360x800_light_ur_ts2.png`). `main.dart.js` 4,328,088 B raw, 1,223,442 B gzip (+0.3% on round 1) |
| 9 | Journeys and a11y audit | `phase4_journeys_qa_test.dart`, `phase4_a11y_audit_qa_test.dart` | PASS | All 25 journeys now run, with no skips: the 4 that were skipped as open bugs pass. The audit passes in all 8 modes on 31 screens, with the taller app bars |
| 10 | Re-tests and regression hunt | `test/qa/phase4_r2_qa_test.dart` (new) | **FAIL** | P4-R2-1 (S2) and P4-R2-2 (S3) below |

### Re-tests of round 1's bugs
| Bug | Re-test | Result |
|---|---|---|
| P4-F1 (S3) | Sign in, then save, then sign out, with **0, 1, 200, 201 and 401** follows. A real brand is placed last, so it falls in the last chunk. Also an account holding 500 follows, pulled at sign-in then sent back at sign-out | **Fixed.** For each count, the calls are ⌈n/200⌉ (one call at 0), every call is ≤ 200, and every follow is sent once. The city and language go only in the first call and reach the profile. The last chunk's brand reaches the account. Sign-out leaves no follows, saves or account note, and nothing in the log. 500 follows go back in 3 calls |
| P4-J1 (S3) | A saved deal offline: its copy, with the banner, "Updated …" and the "Details, terms and outlets show when you are back online" note. Save and Share still work. Reconnect: the full page loads by itself. A deal seen only on Home: opens from the Home copy. No copy: the offline error, then Try again after reconnecting loads the page. A deal the server says is gone (online): no copy is shown. The journeys file's J4b and the split `deal_page_qa_test` cases also pass | **Fixed**, except a connected-but-unreachable network: P4-R2-2 |
| P4-R1 (S3) | J9 "P4-R1" (search, Dark, Clear everything) is unskipped. `search_providers_test`'s city test now waits a microtask; the area filter is still dropped on a city change | **Fixed** |
| P4-P1 (S3) | A new widget test: `NetworkPicture` in a 200-wide box at DPR 3 uses `ResizeImage` with width 600 | **Fixed** (no developer test covered it; QA's covers it now) |
| P4-D1 (S4) | J9b unskipped: the theme is `system` after deletion | **Fixed** |
| P4-P2 (S4) | Following is built with slivers; the audit and BUG-7 tests pass on it | **Fixed** |
| P4-T1 (S4) | Best of 3 runs, with the 400 ms budget unchanged. Passed in the full run | **Fixed** (the budget isn't weakened) |
| 4.8 BUG-7 (S4) | `inbox_qa_test` reproducer unskipped and passes. New: a follow made while the brands list is still loading is kept. A failed (offline) load drops nothing. A follow of a brand that is no longer offered is dropped | **Fixed** |
| 4.9-V1 (S4) | New: at 200% in Urdu, the app-bar title on Settings, Notifications and My cards ends inside the bar. Web screenshot. The phase-1 gallery walk now skips the contrast check only at stops where a button straddles a bar, the same false positive this report notes for onboarding; tap targets and labels are still checked there | **Fixed** |
| 4.9-N6 (S3) | Offline: "Saved on this phone…". The queue is stored with its user. It survives a restart (offline, then online), is sent, and is removed; the switch shows the sent value | **Fixed for one account.** Across accounts: **P4-R2-1 (S2)** |

### New bugs
| ID | Sev | Title | Status |
|---|---|---|---|
| P4-R2-1 | **S2** | A change queued offline by one account is sent into the next account that opens Notifications, and is lost for its own account | Open |
| P4-R2-2 | S3 | On a connection without internet, the offline copy of a deal sticks for the whole session, with "No internet" and no way to retry | Open |

#### P4-R2-1 (S2): A's queued alert settings go into B's account
- **Steps** (a shared phone; dev flavor; reproduced through the real screens):
  1. A, signed in, opens Settings → Notifications.
  2. The phone goes offline. A turns off "Brands you follow". The note reads "Saved on this phone…", and the queue is stored as `{user: A}`.
  3. A signs out (still offline).
  4. The network comes back. B signs in with a phone number and opens Notifications.
- **Expected:** B's preferences are B's own (followed brands still on). A's queued change waits for A, and is sent when A is next signed in.
- **Actual:**
  - Right after B's `my_alert_prefs`, the app calls `update_alert_prefs {followed_brands: false}` as **B**. A spy on the fake server shows `update_alert_prefs as=<B's id> {followed_brands: false}`.
  - B's account now has brand alerts turned off, which B never chose.
  - A's queue is then cleared, so A never gets the change.
  - This is the same class as 4.8 BUG-1 (S2): what one account did on a shared phone goes into another account.
- **Why:**
  - `AlertPrefsController._queued` is an instance field and isn't reset when `build()` runs for another user.
  - The `networkStatusProvider` listener is registered at the start of `build()`, before `_readQueue(B)` replaces `_queued`. When B's build resumes the paused network provider, the listener sees "online" while `queued` is still A's.
  - `_flush()` doesn't check whose queue it is sending: `_user` is set, but never compared with the signed-in user at send time.
  - On success it removes the stored queue, A's.
  - Also: one key holds one queue, so a change B queues offline would overwrite A's queue (the round-2 test "as it is today" pins today's behaviour).
- **Where:** `lib/features/settings/application/alert_prefs_providers.dart`:
  - `:44-73` (`build`: `_user = id`, the listener before `_queued = await _readQueue(id)`);
  - `:112-135` (`_flush`, no owner check);
  - `:90-104` (`_writeQueue`, a single key for every account).
- **Evidence:** `test/qa/phase4_r2_qa_test.dart`:
  - "P4-R2-1: another account never receives A's queued change…" (skipped as `P4-R2-1`; fails: B's `followed_brands` is `false`);
  - "P4-R2-1 (as it is today)" (passes and pins today's behaviour).
- **Suggested fix:**
  - At the top of `build()`, set `_queued = const {}`, and read the queue before registering the listener.
  - In `_flush()` and `change()`, send the queue only if its user is `authRepository.currentUser?.id`.
  - Key the queue per account (`settings.alert_prefs.queued.v1.<uid>`), or keep a map by user, so another account neither sends nor overwrites it.
  - Add the reproducer to the developer suite.

#### P4-R2-2 (S3): the offline copy sticks when the network status never changes
- **Steps:**
  1. Save deal 4 and open Saved, so its copy is stored.
  2. Restart with the phone "online" but the backend unreachable (Wi-Fi without internet, a captive portal, or a timeout).
  3. Open deal 4: the copy, with "No internet…" and "Updated …".
  4. The backend answers again. Leave the page and open it again, or pull down.
- **Expected:** the page tries again and shows the whole deal, or at least offers Try again.
- **Actual:** the copy stays for the whole session. There is no Try again and no pull to refresh.
- **Why:**
  - `dealDetailProvider` isn't `autoDispose`, so reopening the page reuses the copy.
  - Its only reload is a `networkStatusProvider` listener for a change to online, and on such a network the status is already online and never changes.
  - Before round 2, the same failure showed the error view with a working Try again.
- **Where:** `lib/features/deals/application/deal_providers.dart:25-43`.
- **Evidence:** `phase4_r2_qa_test.dart`:
  - "P4-R2-2: connected but the server unreachable…" (skipped; fails);
  - "P4-R2-2 (as it is today)" (passes: the copy is still shown, with no Try again).
- **Suggested fix:**
  - Make the provider `autoDispose`, or invalidate it when the page opens.
  - Give the offline banner on a copy a Try again (or a `RefreshIndicator`) that invalidates it.
  - Optionally, retry once with a short back-off when the status is already online.

### Notes (not filed)
- **A refused queued field blocks later changes:** suppose the flush on reconnect fails as offline (a flaky reconnect) and the server would refuse a queued field (for example, quiet hours changed on another phone). Each later online change then sends the queue with it, is refused and reverted, until the next load drops the queue. This is reasoned from the code (`alert_prefs_providers.dart:159-185`), not reproduced. Worth covering in the P4-R2-1 fix: on a refusal of the merged call, drop the queued fields, or send them separately.
- **`NetworkPicture` passes only `cacheWidth`:** an image much wider than its box is decoded to the box's width, then scaled up to the box's height by `BoxFit.cover`, so it is soft. Consider `ResizeImage(policy: ResizeImagePolicy.fit)` with both dimensions.

### Tests added by QA in round 2
`test/qa/phase4_r2_qa_test.dart` (19 tests, 2 skipped as open bugs):
- the F1 sync at 0, 1, 200, 201 and 401 follows, plus 500 from the account;
- the offline deal page: a saved copy then a reconnect, a Home copy, no copy then Try again, a deal that is gone (no copy), and P4-R2-2 (two tests);
- the N6 queue: a restart then online, and P4-R2-1 (two tests);
- BUG-7: a follow made during the load is kept, and a failed load drops nothing;
- the `NetworkPicture` decode size;
- the Urdu 200% app-bar title is inside the bar.

Screenshots: `docs/qa/screens/phase-4/round2/` (16 steps × 4 modes, `journeys-report.json`, and `sheet_360x800_light_ur_ts2.png`).

### Round 2 verdict
**FAIL.** P4-R2-1 (S2) is open. Every round-1 bug is fixed, and so are 4.8 BUG-7, 4.9-V1 and 4.9-N6 for a single account. After the P4-R2-1 fix, re-run `phase4_r2_qa_test.dart` with `--dart-define=QA_KNOWN_BUGS=true`, then remove both skips.

## Round 3 (`5e6b6bb`)
### Run details
- Date: 2026-10-30. Commit: `5e6b6bb` ("Phase 4 round 2: per-account settings queue; offline copy never sticks"), detached in `/home/user/slh-qa49`, cleaned with `git clean -xfd -e env/`.
- What changed since `381aaae`:
  - `alert_prefs_providers.dart`: one queue per account (`alertPrefsQueueKeyFor`). `build()` resets `_queued`/`_user` and reads the queue before the listener. `_flush()` checks the owner. An online `change()` flushes the queue on its own first.
  - `deal_providers.dart`: `autoDispose`.
  - `state_views.dart`: `OfflineBanner.onRetry`, used by the deal copy.
  - Test edits: `alert_prefs_test.dart` uses the per-account key. QA's round-2 reproducers are unskipped, and its two "as it is today" tests now assert the fixed behaviour.
- Same toolchain and environment as rounds 1 and 2.

### Gate results
| # | Step | Command | Result | Evidence |
|---|---|---|---|---|
| 1–4 | Dependencies, codegen, format, analyze | as in round 1 | PASS | No advisories. Codegen leaves no diff. "Formatted 257 files (0 changed)". "No issues found!", also with QA's new file |
| 5 | Flutter tests | `flutter test --coverage --concurrency=3` | PASS | `+1823 ~8: All tests passed!` (4m20s), as in the coordinator's run. All Phase 4 QA files, QA's new round-3 file and `alert_prefs_test.dart`, re-run together: `+85 ~2: All tests passed!`. The 2 skips are P4-R3-1 |
| 6 | Coverage | `tool/check_coverage.dart --min 80` | PASS | **95.7%** (6990/7307). Application **95.7%**, domain **97.4%**. `alert_prefs_providers` 95/104, `deal_providers` 29/30, `state_views` 75/75 |
| 7 | DB tests | `tool/db_test.sh` | PASS | **49 files, 859 tests, PASS** |
| 8 | Journeys and a11y audit | `phase4_journeys_qa_test.dart`, `phase4_a11y_audit_qa_test.dart` | PASS | 25 journeys, and 31 screens × 8 modes |
| 9 | Re-tests and regression hunt | `test/qa/phase4_r3_qa_test.dart` (new, 18 tests) | PASS, with one S3 | 16 pass. The 2 skipped (Urdu 200%, light and dark) are P4-R3-1 and fail when enabled |

The web build wasn't re-run for this round. The deal copy can't be reached on the web build, because the demo backend there is in memory and never goes offline; the widget tests cover it.

### Re-tests
| Bug | Re-test | Result |
|---|---|---|
| P4-R2-1 (S2) | QA's two round-2 tests (now asserting the fix), plus round 3's new tests:<ul><li>**two accounts, one phone:** A queues offline, signs out; B signs in online; B queues its own offline, signs out; A again, then B again;</li><li>**a flush in flight when the account changes:** A's `update_alert_prefs` is held at the server while A signs out and B signs in and queues offline, then released;</li><li>**a restart:** offline, then online;</li><li>**sign-out:** what is left on the phone</li></ul> | **Fixed.**<ul><li>B is never sent anything while signed in as B, and B's account and switches stay B's own.</li><li>Each queue is stored under its own account and waits for it. A's change reaches only A's account, and B's waits for B.</li><li>The in-flight call lands as A. B's queue is untouched, and nothing of B's is sent.</li><li>After a restart, the queue is sent online, removed, and the switch shows the sent value.</li><li>After sign-out, only `…queued.v1.<A>` is left, holding A's change; the guest view sends nothing</li></ul> |
| The blocked-changes note | Round 3: a flaky reconnect keeps the queue (the server can't be reached while the phone says online). The server then refuses the queued field, and the user changes another switch | **Fixed.** The other change saves with no failure toast. The refused field is dropped, the queue is removed, and both switches show what the server holds |
| P4-R2-2 (S3) | QA's round-2 test, now asserting the fix: on reopening, the full page loads. Round 3: Try again on the copy while still unreachable shows the copy again, with no error. Once reachable, Try again shows the full page without leaving it, and Saved state survives. Home's offline banner has no Try again | **Fixed** |
| Clear everything and account deletion | Round 3: a change is queued offline, then the phone is cleared, or the account is deleted | **Nothing is left behind:** no queue key and no non-cache key. No exception |

### New bug
| ID | Sev | Title | Status |
|---|---|---|---|
| P4-R3-1 | S3 | In Urdu at 200% text, the deal copy's offline banner overflows: Try again is about 525 dp wide on a 360 dp screen, and the banner grows thousands of dp tall | Open |

#### P4-R3-1 (S3): the banner with Try again overflows in Urdu at 200%
- **Steps:**
  1. Save deal 4.
  2. Restart offline, with the phone in Urdu at 200% text, 360×800.
  3. Open deal 4 from Saved.
- **Expected:** the banner's message, its age and Try again fit the width, with Try again fully on screen. English at 200% and Urdu at 100% fit.
- **Actual:**
  - "A RenderFlex overflowed by 234 pixels on the right".
  - "دوبارہ کوشش کریں", in Nastaliq at 200%, makes the `TextButton` about 525 dp wide (`Rect.fromLTRB(16, …, 541.7, …)`), so part of it is off screen.
  - The `Expanded` message beside it gets almost no width, so it wraps into a column thousands of dp tall, and the banner pushes the deal's content far down the page.
  - Release builds draw the same layout with the overflow clipped.
  - The flow still works: leaving and reopening the deal (now `autoDispose`) loads it again.
- **Where:** `lib/design_system/widgets/state_views.dart:119-157` (the `Row` in `OfflineBanner`, with the `TextButton` after the `Expanded`).
- **Evidence:** `test/qa/phase4_r3_qa_test.dart`:
  - "ur light 200% / ur dark 200%: the copy with its Try again meets the guidelines, with no overflow" (skipped as `P4-R3-1`; fails when enabled);
  - "P4-R3-1 (as it is today)" (passes and pins today's behaviour).
- **Suggested fix:**
  - Put Try again below the text when space is short. Use a `Wrap`, or an `OverflowBar`-style layout, or place it in the `Column` under the age when the text is scaled up (`MediaQuery.textScalerOf(context).scale(1) > 1.3`).
  - Alternatively, use a shorter Urdu label (for example "دوبارہ").
  - Add the Urdu 200% case to the developer's `state_views` tests.

### Notes (not filed)
- **Queues of accounts that never come back:** a queue (with its account's uuid) stays on the phone until that account signs in again, or the phone is cleared. Nothing else reads it. This is consistent with the account note, `account.on_phone.v1`.

### Tests added by QA in round 3
`test/qa/phase4_r3_qa_test.dart` (18 tests, 2 skipped as P4-R3-1). Its `_Prefs` fake applies an in-flight request as the account that sent it.
- **Queue:** two accounts on one phone in both directions, an in-flight flush across an account switch, a restart, clear and delete leaving nothing, and what sign-out leaves.
- **Blocked changes:** the refused-field case.
- **Try again on the copy:** still unreachable, then reachable. Home's banner has no Try again.
- **The copy page in 8 modes:** guidelines, a 48 dp Try again inside the screen, and no overflow.
- **P4-R3-1 "as it is today".**

### Round 3 verdict
**PASS.** No S1 or S2 bugs are open. P4-R2-1 (S2) and P4-R2-2 (S3) are fixed, along with all of round 1's bugs. Open and carried forward: P4-R3-1 (S3), 4.2-A11 (S4), and the S4s listed as open in earlier reports. Phase 4 can close.
