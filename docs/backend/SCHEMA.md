# Database schema

Supabase Postgres with PostGIS. The migrations in `supabase/migrations/` are the source of truth; this page explains them. Phase 2 sub-phases: 2.1 schema (this page), 2.2 roles and RLS, 2.3 read APIs, 2.4 storage, 2.5 jobs and functions, 2.6 seed data.

## Run the tests
```
tool/db_test.sh                      # every migration from zero + schema lint + pgTAP
tool/db_test.sh supabase/tests/database/000_setup.test.sql supabase/tests/database/040_deals.test.sql
tool/db_test.sh --keep               # leave the database running to poke at it
```
- It needs Postgres 16+ with PostGIS, pgTAP and pg_cron (`apt-get install postgresql-16-postgis-3 postgresql-16-pgtap postgresql-16-cron`).
- It loads `supabase/tests/support/supabase_stub.sql`, a minimal Supabase (API roles, `auth.uid()`, `auth.users`), so it runs without Docker.
- With Docker, the real stack runs the same tests: `supabase start && supabase db reset && supabase test db`.
- CI runs `tool/db_test.sh` in the `database` job.
- Hosted Supabase projects run Postgres 17; the local tests use 16. Don't use features newer than 16.

## Tables
| Area | Tables | Notes |
|---|---|---|
| Places | `cities`, `areas` | Bilingual names, PostGIS centres (also as generated `center_lat`/`center_lng`, so the app finds the nearest city on the phone). `cities.is_live` controls the city-by-city rollout; nationwide deals show everywhere |
| Catalogue | `categories` (two levels), `banks`, `card_products` | Data, not code: staff add them without an app update |
| People | `profiles`, `user_roles` | A profile and alert prefs are created by trigger on sign-up. Roles: `business_owner`, `moderator`, `admin`; plain shoppers have no row |
| Businesses | `businesses`, `business_members`, `brands`, `outlets` | A business is the portal account; brands are what shoppers see and follow. A brand can exist before a business claims it (ingested deals) |
| Deals | `deals`, `deal_targets`, `card_offers` | Targets (city, or area within a city) only for `local` deals; card offers only for `card_offer` deals |
| Shopper data | `follows`, `saves`, `user_cards`, `alert_prefs`, `notifications` | All deleted with the account |
| Moderation | `reports`, `submissions` | Reports survive account deletion without the reporter's id |
| Money | `placements`, `payments` | Written by staff and the payments webhook only |
| Audit | `audit_log` | Role grants, memberships, business and deal status, placements, payments, report status. Written by trigger only |

## Rules the database enforces
The database is the validator of last resort. The app and the portals validate too, but these hold whatever the client sends:
- **Real discounts only.** A `percent_off` shown with two prices must equal the computed percentage, rounded down, as `DealOffer.fromPrices` does. Rs 4,999 → Rs 2,999 is 40%, and "41%" is rejected. Each offer kind has exactly the fields it needs.
- **Deal status follows one graph:** draft → pending_review → published → expired/removed, plus a few returns. A deal that has already ended can't be published, and publishing stamps `published_at`. Who may make each change is decided by RLS (2.2).
- **Rules across tables are checked at commit** (deferred constraint triggers), so a deal and its targets or card offers can be written in one transaction. A published local deal needs a target, and a published card offer needs a card.
- **Places are consistent:** an outlet's or target's area must be in its city (composite foreign keys).
- **A placement promotes only the business's own deals.**
- **Formats:**
  - slugs match the app's route rule;
  - links are `https://` only;
  - phone numbers are `+92…`;
  - Storage paths are relative, with no `..`;
  - fingerprints are hex;
  - time zones are IANA-shaped.
- **Privacy:**
  - No card numbers anywhere; `user_cards` stores card products only.
  - Profiles never copy `user_metadata`.
  - Phone and email stay in `auth.users`, except a business's own contact details.

## Security model
- **Grants are opt-in.** Default privileges in `public` are revoked from `anon` and `authenticated`, and every table has RLS enabled. Sub-phase 2.2 grants access table by table, with a policy per operation and tests per role; the result is in [ACCESS.md](ACCESS.md).
- `service_role` (the server-only secret key) keeps its grants and bypasses RLS. It is for Edge Functions and ingestion only.
- `private` is not exposed through the Data API. Trigger and helper functions there are `security definer` with `search_path = ''` and fully qualified names, and nobody else can execute them.
- The schema lint (`supabase/tests/support/schema_lint.sql`) and `010_schema.test.sql` fail the build if any of these happens:
  - a table without RLS or a primary key;
  - an unindexed foreign key;
  - an `updated_at` column without its trigger;
  - a definer function without `search_path`, or one the API roles can execute;
  - an anon write grant;
  - a view without `security_invoker`;
  - a policy that reads `user_metadata`.

## Conventions
- **IDs:** `uuid` with `gen_random_uuid()`. Append-only internal tables (`deal_targets`, `follows`, `audit_log`) use identity bigints.
- **Text:** bilingual columns are `name_en` / `name_ur` (Roman Urdu goes in `_en`). Search uses the `simple` text configuration for both languages, plus trigram indexes on names and titles.
- **Types:** money is whole rupees (`pkr` domain), and times are `timestamptz` (stored in UTC, shown in Asia/Karachi). No `json`, `varchar` or `money` columns.
- **Every foreign key has an index**, and every `updated_at` has a trigger (both tested).
- **Enums** for stable vocabularies (`ALTER TYPE … ADD VALUE` to extend). Staff-managed lists such as categories are tables.
- **Migrations** are named `YYYYMMDDHHMMSS_name.sql`, run in order, and are never edited after they reach a shared environment; add a new migration instead.
  - **Until the first deploy** (no shared environment exists yet), QA fixes and small additions such as `cities.center_lat`/`center_lng` (4.1), `category_ids` in the guest sync (4.5) and `user_id default auth.uid()` on `follows`, `saves` and `user_cards` (QA 4.4 and 4.5) are made in place, so a fresh database gets one clean schema. The first `supabase db push` to staging freezes every file then in `supabase/migrations/`. From that point on, changes go in new migrations only (QA 4.1 BUG-4). Note it in `docs/RELEASE.md`.
