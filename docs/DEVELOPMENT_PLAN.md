# Sale Lagi Hai! — Development Plan

> Working name: **Sale Lagi Hai!** (can be renamed; the name lives in one config place).
> A Pakistan-wide deals app: brand sales, restaurant deals, bank card discounts, telecom bundles and more, with instant alerts.
> This plan covers the **complete product**, not an MVP.

---

## 1. Product scope

| Surface | Who uses it | Built with |
|---|---|---|
| **Consumer app** (Android first, iOS later) | Shoppers across Pakistan | Flutter |
| **Business portal** (web) | Restaurants, brands, salons, shops that list and promote deals | Flutter Web |
| **Admin & moderation console** (web) | Our team | Flutter Web |
| **Backend** | Everything above | Supabase (Postgres + PostGIS, Auth, Storage, Edge Functions, pg_cron) |
| **Ingestion engine** | Automated deal collection | Supabase Edge Functions + scheduled jobs |
| **Push** | Alerts | Firebase Cloud Messaging (FCM) |

### Deal types
- **Nationwide:** brand sales, bank card discounts, telecom bundles, online promo codes, national chains.
- **City:** local restaurants, cafés, salons, gyms, boutiques and marts, rolled out city by city (Karachi → Lahore → Islamabad/Rawalpindi → others).

### Categories (data-driven, added from the admin panel without an app update)
Food & Restaurants · Fashion · Bank Cards · Groceries · Beauty & Salons · Mobiles & Electronics · Telecom Bundles · Online Promo Codes · Health & Fitness · Events & Cinema · Travel & Hotels · Education · Home & Furniture.

### How the app makes money
1. Featured and sponsored placements for businesses, targeted by city and category and clearly labelled "Featured".
2. Sponsored WhatsApp-channel posts and targeted push campaigns (with strict frequency caps).
3. Later: national brand and bank sponsorships, and affiliate commissions where programs exist.
4. Optional: low-frequency native ads (AdMob) in the feed.

---

## 2. Architecture

```
┌──────────────────────────┐   ┌──────────────────────┐   ┌──────────────────────┐
│ Consumer app (Flutter)   │   │ Business portal (Web)│   │ Admin console (Web)  │
└────────────┬─────────────┘   └──────────┬───────────┘   └──────────┬───────────┘
             │  supabase_flutter (anon key + user JWT, RLS-enforced) │
             └──────────────────────┬─────────────────────────────────┘
                                    ▼
                 ┌────────────────────────────────────────┐
                 │ Supabase                               │
                 │  Postgres + PostGIS + RLS              │
                 │  Auth (phone OTP, Google)              │
                 │  Storage (deal images, logos)          │
                 │  Edge Functions (push, ingestion,      │
                 │   moderation, payments webhooks)       │
                 │  pg_cron (expiry, digests, scrapers)   │
                 └───────────────┬────────────────────────┘
                                 ▼
                 FCM (push) · Shopify stores · bank sites · telecom sites
```

### Client code structure (feature-first, layered)
```
lib/
  app/              # App widget, router, bootstrap, flavors
  core/             # theme, l10n, errors, logging, networking, storage, utils
  design_system/    # tokens + reusable widgets (DealCard, Badge, Skeleton…)
  features/
    <feature>/
      data/         # DTOs, data sources, repository implementations
      domain/       # entities, repository interfaces, value objects
      application/  # Riverpod providers / notifiers (use-cases)
      presentation/ # screens, widgets
```

### Key technical decisions
| Decision | Choice | Why |
|---|---|---|
| State management | Riverpod | Testable, compile-safe, the standard for large Flutter apps |
| Routing | go_router | Deep links, redirects, web URLs for the portals |
| Models | freezed + json_serializable | Immutable models, unions for states and errors |
| Backend | Supabase | Relational data (deals ↔ brands ↔ outlets ↔ cities), RLS security, PostGIS for "near me", SQL full-text search |
| Push | FCM | Standard on Android, free |
| Languages | English + Urdu (RTL), Roman Urdu in copy | Matches how users text |
| Fonts | Bundled offline | No runtime font downloads, works on slow networks |
| Flavors | dev / staging / prod | Separate Supabase projects; never test on prod data |

---

## 3. How we work: quality gates

Each **phase** is split into **sub-phases**. Nothing moves forward until its gate passes.

```
Build sub-phase → Self-check → QA agent: sub-phase gate → fix → ✅
   … repeat for every sub-phase in the phase …
→ QA agent: FULL PHASE gate (regression + integration) → fix → ✅ → next phase
```

### Sub-phase gate (run by the QA agent)
1. `flutter analyze` with **zero** errors, warnings or infos.
2. `dart format` clean.
3. All unit, widget and golden tests pass; coverage for new code ≥ 80% (domain/application ≥ 90%).
4. Visual QA: the web build is screenshotted at phone sizes in light, dark and RTL/Urdu (where UI exists).
5. Accessibility: tap targets, contrast, labels and text scaling at 200%.
6. Security checklist items for that sub-phase (from the `flutter-secure-dev` skill).
7. QA report saved to `docs/qa/<phase>.<sub>.md` with a PASS or FAIL verdict. Any open S1 or S2 bug means FAIL.

### Full-phase gate
Everything above for the whole phase, plus a regression run of all earlier tests, integration tests across sub-phases, exploratory testing charters, and a performance check. The report goes to `docs/qa/phase-<n>-final.md`.

### Bug severity
- **S1:** crash, data loss or security hole
- **S2:** a core flow is broken
- **S3:** a feature works incorrectly but has a workaround
- **S4:** cosmetic

---

## 4. Phases

### Phase 0 — Brand & design foundations
| Sub-phase | Deliverables | Tests / gate |
|---|---|---|
| 0.1 Brand identity | Logo, app icon set, palette, typography, voice and tone, guidelines (brand agent) | Contrast script passes; icon legible at 16/48px; mono and themed icons work |
| 0.2 Skills | `flutter-ui-ux`, `flutter-secure-dev`, `flutter-architecture`, `qa-testing`, `brand-identity` skills | Reviewed for accuracy, with sources |
| 0.3 UX architecture | Information architecture, user flows, screen inventory, wireframes for key screens | Every flow covers its empty, loading, error and offline states |

### Phase 1 — App foundation
| Sub-phase | Deliverables | Tests / gate |
|---|---|---|
| 1.1 Project scaffold | Flutter project, feature-first folders, strict lints, dev/staging/prod flavors via `--dart-define-from-file`, environment config, CI workflow (analyze, format, test, build) | Analyze clean, the app boots in every flavor, env-config tests |
| 1.2 Core layer | Result and failure types, logger (no PII), error boundary, app bootstrap, connectivity, local cache, secure storage wrapper | Unit tests for every core class |
| 1.3 Theming & design tokens | Brand tokens → Material 3 `ThemeData` (light/dark), bundled fonts (Latin + Urdu), spacing, radii, motion | Golden tests for both themes, contrast tests |
| 1.4 Localization & RTL | `en` + `ur` ARB files, RTL layout, locale switching, number and date formatting (PKR, Urdu numerals as an option) | Golden tests in RTL, missing-key test |
| 1.5 Navigation shell | go_router with typed routes, bottom navigation shell (Home, Explore, Alerts, Saved, Profile), deep-link scaffolding, 404 route | Routing tests, deep-link tests |
| 1.6 Design-system widgets | Buttons, chips, `DealCard` variants, discount badge, "verified X ago" tag, skeletons, empty/error/offline views, bottom sheets, a Featured label, plus an in-app widget gallery | Golden tests for every widget × theme × direction; a11y guideline tests |
| 1.7 Security baseline | Android manifest hardening, network security config (no cleartext), backup rules, R8 + obfuscation settings, dependency audit script, secret scanning in CI | Security checklist; manifest lint |
| **Phase 1 gate** | | Full regression, the gallery screenshotted in all modes |

### Phase 2 — Backend (Supabase)
| Sub-phase | Deliverables | Tests / gate |
|---|---|---|
| 2.1 Schema | Migrations: `cities`, `areas`, `categories`, `businesses`, `brands`, `outlets` (PostGIS), `deals`, `deal_targets` (city/area), `banks`, `card_products`, `card_offers`, `profiles`, `follows`, `saves`, `user_cards`, `alert_prefs`, `notifications`, `reports`, `submissions`, `placements`, `payments`, `audit_log` | Migrations apply cleanly from zero; constraint tests |
| 2.2 Roles & RLS | Roles: anon, user, business_owner, moderator, admin. RLS on **every** table, safe `security definer` functions | pgTAP/SQL tests: each role can only do what it should |
| 2.3 Read APIs | RPCs and views: personalized feed, trending, nearby (PostGIS), deals for my cards, full-text + trigram search, brand and category pages | Query tests, `EXPLAIN` checks, index coverage |
| 2.4 Storage | Buckets and policies, image size and type limits, resized variants | Policy tests, upload abuse tests |
| 2.5 Jobs & functions | Auto-expiry (pg_cron), freshness scoring, push dispatcher Edge Function, rate limits on submissions and reports | Function unit tests, JWT verification tests |
| 2.6 Seed data | Pakistani cities and areas, categories, banks and card products, top brands | Seed is repeatable (idempotent) |
| **Phase 2 gate** | | A full role-matrix security test, load test on feed queries |

### Phase 3 — Deal ingestion engine
| Sub-phase | Deliverables | Tests / gate |
|---|---|---|
| 3.1 Ingestion framework | Source registry, per-source adapters, run logs, dedupe (fingerprints), polite fetching (rate limits, robots.txt, user agent) | Adapter contract tests with recorded fixtures |
| 3.2 Shopify sale detector | Watches Pakistani fashion brands' public product feeds, detects sale start and end, creates brand-sale deals with a % range | Fixture-based tests: sale start, sale end, price changes |
| 3.3 Bank card offers | Adapters for major banks' discount pages → `card_offers` | Parser tests per bank |
| 3.4 Telecom bundles | Jazz, Zong, Telenor and Ufone bundle adapters | Parser tests |
| 3.5 Submissions & moderation | Business and user submission pipeline, duplicate detection, moderation queue states | Workflow tests |
| 3.6 Freshness system | "Verified X ago" timestamps, dead-link checks, auto-expire, staleness alerts for admins | Job tests |
| **Phase 3 gate** | | An end-to-end ingest → moderate → publish → visible-in-feed test |

### Phase 4 — Consumer app core
| Sub-phase | Deliverables | Tests / gate |
|---|---|---|
| 4.1 Onboarding | Splash, language pick, city detection or picker, interests, favourite brands, notification permission priming | Widget + flow tests, RTL goldens |
| 4.2 Auth & profile | Guest-first; optional phone OTP or Google sign-in to sync; profile; **account deletion** (Play requirement) | Auth flow tests, session tests |
| 4.3 Home feed | Trending Today, For You, Near Me, Ending Soon, Featured slots, infinite scroll, pull to refresh, offline cache | Provider tests, pagination tests, goldens |
| 4.4 Deal detail | Images, terms, validity, verified time, source link, outlets map and list, share to WhatsApp, save, report expired | Widget tests, share and link tests |
| 4.5 Explore | Categories, brand and business pages, follow and unfollow | Tests |
| 4.6 Search & filters | Search with suggestions; filters for city, area, category, bank, discount %, ending soon; recent searches | Query-building tests, UX tests |
| 4.7 My Cards | Pick your bank and card type (**never** card numbers) → deals for your cards | Tests; a privacy check |
| 4.8 Saved & alerts inbox | Saved deals with expiry warnings, in-app notification inbox | Tests |
| 4.9 Settings | Language, city, theme, notification preferences (per topic, quiet hours), privacy, legal pages, about | Tests |
| **Phase 4 gate** | | Full user-journey integration tests, an accessibility audit |

### Phase 5 — Notifications & growth
| Sub-phase | Deliverables | Tests / gate |
|---|---|---|
| 5.1 FCM integration | Token lifecycle, topics (city/category/brand), foreground and background handling, notification channels | Tests |
| 5.2 Alert engine | Rules for brand sale live, new deal from a followed business, saved deal ending soon, daily digest; frequency caps, quiet hours | Rule-engine tests |
| 5.3 Deep links | Android App Links for `/deal/<id>`, `/brand/<slug>` and so on, plus verification | Link routing tests |
| 5.4 Share cards | A generated image card for WhatsApp/Instagram sharing with a deep link | Golden tests |
| 5.5 Engagement | In-app review prompt, invite-a-friend referral | Tests |
| **Phase 5 gate** | | End-to-end: a deal published → push received → tap → deal opens |

### Phase 6 — Business portal & monetization
| Sub-phase | Deliverables | Tests / gate |
|---|---|---|
| 6.1 Business onboarding | Sign up, claim or create a business, verification, outlets with map pins | Tests |
| 6.2 Deal management | Create, edit, schedule and end deals with image upload and a preview | Tests |
| 6.3 Featured placements | Packages, city and category targeting, scheduling, slot inventory | Tests |
| 6.4 Payments | JazzCash, Easypaisa, bank transfer (manual verification first), invoices, webhooks | Webhook signature tests |
| 6.5 Business analytics | Views, clicks, saves, follows, push reach | Aggregation tests |
| **Phase 6 gate** | | Full flow: business signs up → pays → featured deal appears in targeted feeds |

### Phase 7 — Admin & moderation console
| Sub-phase | Deliverables | Tests / gate |
|---|---|---|
| 7.1 Admin shell & auth | Admin-only login with 2FA, roles | Security tests |
| 7.2 Content management | Deals, businesses, brands, cities, areas, categories, banks, sources | Tests |
| 7.3 Moderation | Submission queue, reports, bulk actions, audit log | Tests |
| 7.4 Ingestion monitor | Source health, run logs, error alerts | Tests |
| 7.5 Campaigns | Push campaign composer with targeting, scheduling and caps; WhatsApp post drafts | Tests |
| 7.6 Revenue | Placements calendar, payments verification, invoices | Tests |
| **Phase 7 gate** | | A full admin-operations exercise |

### Phase 8 — Hardening
| Sub-phase | Deliverables | Tests / gate |
|---|---|---|
| 8.1 Performance | Startup time, image caching and sizes, list jank, app size (split APK/AAB) | Profiling report |
| 8.2 Accessibility & RTL audit | TalkBack pass, 200% text, full Urdu pass | Audit report |
| 8.3 Security audit | MASVS review, dependency and secret scans, RLS re-test, abuse and rate-limit tests | Audit report, zero open S1/S2 |
| 8.4 Observability | Crash reporting, privacy-safe analytics, consent, dashboards | Tests |
| **Phase 8 gate** | | Release-candidate sign-off |

### Phase 9 — Launch
| Sub-phase | Deliverables |
|---|---|
| 9.1 Store presence | Play listing in English and Urdu (ASO), screenshots, feature graphic, promo video script, Data safety form, privacy policy, terms |
| 9.2 Beta | Internal and closed testing tracks, feedback loop, fixes |
| 9.3 Release | Staged rollout (10% → 50% → 100%), monitoring, rollback plan |
| 9.4 Launch ops | WhatsApp channel and Instagram tie-in, business sales kit (pitch deck, rate card) |

### Phase 10 — Expansion (after launch)
Lahore city deals → Islamabad/Rawalpindi → more cities · iOS release · new categories · affiliate integrations · national sponsorships.

---

## 5. Definition of done (for every task)
- The code follows the project skills (`flutter-architecture`, `flutter-ui-ux`, `flutter-secure-dev`).
- Tests are written, and analyze and format are clean.
- Every UI works in light/dark, English/Urdu (RTL) and at large text sizes.
- No secrets in the repository; RLS covers every new table.
- The QA gate has passed and its report is saved in `docs/qa/`.
