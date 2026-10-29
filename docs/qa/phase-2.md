# QA Report — Phase 2 full-phase gate (Backend, Supabase)
Verdict: **PASS** (no open S1 or S2; 1 open S3, 17 open S4)

- Date: 2026-10-29
- Commit: `9746349` (detached in `/home/user/slh-qa2`). Sub-phases 2.1–2.6 after three QA rounds: `126ed98` → `50a4ac6` → `9746349`.
- Toolchain:
  - PostgreSQL 16.15, PostGIS 3.4.2, pgTAP 1.3.2, pg_cron 1.6 via `tool/db_test.sh` (Supabase stub, no Docker);
  - pgbench 16;
  - Node 22.22.0 (`--experimental-strip-types`);
  - Flutter 3.47.8 at `/opt/flutter/bin`.
- Full stack only, not run here: the Storage API's size and MIME enforcement, `deno check` of the functions, the pg_net/Vault `push-dispatcher` cron job, the real Auth hook pipeline, and the hosted Security Advisor. Run them on `supabase start` or the dev project before Phase 4 ships.
- The Phase 3 files (ingestion and moderation migrations, tests 600–710, `functions/ingest`) are in the tree. They apply from zero and their tests pass. The flows below include the Phase 3 moderation RPC where a Phase 2 flow passes through it.

## Gate results
| # | Step | Command | Result | Evidence |
|---|---|---|---|---|
| 1 | Sub-phase reports | `docs/qa/2.1.md` … `2.6.md` (round 3) | PASS | All six PASS at `9746349`. Every S1 and S2 found in rounds 1–2 (C1, B1, B2, J1, J2, R8) is fixed and has a green reproducer |
| 2 | Migrations from zero | `tool/db_test.sh` (fresh cluster) | PASS | All 15 migrations apply with `ON_ERROR_STOP=1` |
| 3 | Schema lint | `supabase/tests/support/schema_lint.sql` | PASS | 6/6 `ok`: RLS on every table, definer `search_path`, no anon definer RPCs, no anon writes, `security_invoker` views, no `user_metadata` |
| 4 | Seed repeatable | fresh cluster: `seed.sql` ×2, then the reference migration again | PASS | Identical counts after each run: 16 cities, 22 areas, 22 categories, 14 banks, 36 products, 22 brands, 6 outlets, 7 deals (7 live). All 7 are in anon's Karachi feed. Cron: `cleanup-old-rows`, `expire-deals`, `notify-staleness`, `plan-alerts`, `refresh-freshness` |
| 5 | Database regression (all tests) | `tool/db_test.sh` | PASS | `Files=29, Tests=505 … Result: PASS`, developer and QA files together. Only S4 `todo`s fail (C2, C3, B7–B9, S1, S2, D1, D2) |
| 6 | Edge Function regression | `node --experimental-strip-types --no-warnings --test 'supabase/functions/**/*.test.ts'` | PASS except 1 QA reproducer | `tests 67, pass 66, fail 1` (with `PGHOST`). The 1 failure is the F6b reproducer (open S3). Without `PGHOST` the end-to-end test is skipped |
| 7 | App regression | `flutter analyze`; `dart format --output=none --set-exit-if-changed lib test`; `flutter test --coverage`; `dart run tool/check_coverage.dart` | PASS | `No issues found!`; `0 changed`; `+904 ~7: All tests passed!`; `Line coverage: 93.9% (2136/2275)` |
| 8 | End-to-end flow (integration) | `qa_phase2_flow.test.sql` (42 steps) | PASS | See "Flows" below |
| 9 | Dispatcher end to end | `supabase/functions/push-dispatcher/qa_e2e.test.ts` against the kept cluster | PASS | Outbox → `handle()` → `dispatch()` → `FcmClient` (fake FCM HTTP) → `mark_pushes_sent` / `drop_push_tokens`. One request per device; live device sent; UNREGISTERED token deleted; second run claims 0 |
| 10 | Role sweep: tables and views | `qa_rls.test.sql` test 1 | PASS | anon, shopper, editor, owner, moderator aal1/aal2, admin aal1/aal2, service_role × every public table and view: only clean `42501`, no `42P17` |
| 11 | Role sweep: RPCs and views | `qa_phase2_roles.test.sql` | PASS | 6 roles × 15 RPCs and views = 90 calls, each matching the expected answer. The public RPC surface is pinned to the 13 reviewed functions, so a new one fails the test until reviewed |
| 12 | Load test on feed queries | pgbench as `anon`, 8 clients, 4 cores, 20,000 deals / 5,000 outlets / 20,000 saves | PASS | Feed only: **1,995 TPS, 4.0 ms** average latency. Mixed load: 114 TPS, 70 ms average (feed 3.9 ms, deep feed 6.5 ms, city search 120 ms, nearby 3 km 105 ms, trending 228 ms), 0 failed |
| 13 | Security | greps over every change since `126ed98` | PASS | No keys or JWTs. Edge Functions log only error names, counts and a source slug. Dispatcher auth fails closed |
| 14 | Visual QA and accessibility | — | n/a | Phase 2 has no UI |

## Flows (qa_phase2_flow.test.sql, on the seeded reference data)
1. A shopper registers "Chai Corner" and becomes its owner.
2. The owner can't take a real-looking slug (`khaadi` → `42501`). They add the brand as `pending-chai-corner`, which stays hidden from anon.
3. A moderator without MFA changes nothing. With MFA they verify the business, then activate and verify the brand under its real slug `chai-corner`.
4. Two shoppers (English and Urdu) follow the brand, register devices and turn push on.
5. The owner adds a Clifton outlet. A fake 45% on Rs 1,000 → 590 is refused (`23514`). The real 41% is saved as a draft, targeted at Clifton, with an image uploaded to `deal-images/<business>/<deal>/hero.jpg`.
6. The owner sends the deal for review. They can't publish it or edit it while in review (`42501`), and anon can't see it.
7. A moderator publishes it. Anon then finds it in the Karachi cafés feed, in nearby (under 50 m), in search and on the brand page; the card shows the verified brand. A follower sees it in their following feed.
8. `plan_alerts()` queues 2 pushes: "Chai Corner: 41% off" and an Urdu title. `claim_due_pushes` gives 2 device rows, both are marked sent, and a second planner run alerts nobody.
9. A report lowers freshness to 25 (never verified 40, minus 15). A shopper's submission is approved through `approve_submission` (Phase 3), and the submitter is notified.
10. The deal ends. `expire_deals()` expires it; it leaves the feed, but its link still opens, marked expired.
11. The follower deletes their account: their follows, devices and alerts are gone.

## Open bugs
| ID | Sev | Title | Where | Report |
|---|---|---|---|---|
| 2.5-F6b | S3 | The dead-token breaker never trips below 10 sends per run. A wrong-project FCM key still drops every token it touches at launch volume | `supabase/functions/push-dispatcher/dispatch.ts:41, 77-78` | 2.5 |
| 2.1-C2 | S4 | The percentage check overflows int4 on very large prices | `deals.sql:115-117` | 2.1 |
| 2.1-C3 | S4 | Republishing keeps the first `published_at` | `deals.sql` (`check_deal_status`) | 2.1 |
| 2.1-C4 | S4 | Inserts can start in any status (staff and service only) | `deals.sql` (`check_deal_status`) | 2.1 |
| 2.2-B7 | S4 | `brands.is_active` defaults to true; member inserts must send `false` | `people_and_businesses.sql:93` | 2.2 |
| 2.2-B8 | S4 | A removed creator still reads the business | `rls_policies.sql` ("businesses: creator reads") | 2.2 |
| 2.2-B9 | S4 | Private files outlive the account (no delete-account flow yet) | ACCESS.md | 2.2 |
| 2.2-B10 | S4 | The audit log keeps deleted users' ids; retention undocumented | `moderation_and_commerce.sql` (`private.audit`) | 2.2 |
| 2.2-B11 | S4 | Save and report inserts scan every visible deal | `rls_policies.sql` ("saves: add own", "reports: send") | 2.2 |
| 2.3-R5b | S4 | `nearby_deals` at the 20 km maximum takes about 0.7 s on the worst-case dataset (local branch per outlet) | `read_apis.sql:323-340` | 2.3 |
| 2.3-R6 | S4 | Keyset cursors at millisecond precision skip ties (web and JS clients) | `read_apis.sql` (feed, my cards, brand page) | 2.3 |
| 2.3-R7 | S4 | Search negation is ignored by the fuzzy branches | `read_apis.sql` (`search_hits`) | 2.3 |
| 2.4-S1 | S4 | An update can move a file across buckets | `storage.sql` (update policies) | 2.4 |
| 2.4-S2 | S4 | The hourly quota counts files that still exist | `storage.sql` (`my_recent_uploads`) | 2.4 |
| 2.5-J5 | S4 | Followers of a city that isn't live get alerts the feed hides | `jobs.sql` (city candidates) | 2.5 |
| 2.6-D1 | S4 | The demo card offer is attributed to real HBL cards | `seed.sql:64-65, 80-83` | 2.6 |
| 2.6-D2 | S4 | Re-seeding a long-lived dev database doesn't revive expired demo deals | `seed.sql:69-71, 85-87` | 2.6 |
| 2.6-D3 | S4 | Re-running the reference migration overwrites staff edits | `20261029170000_reference_seed.sql` | 2.6 |

Fixed during the phase and verified, by round:
- **Round 1:** C1, B1–B6, R1–R5 (R5 partly), J1–J4, F1–F5, R3, R4.
- **Round 2:** R8, R9, R10, R5 (trending, following-only), F6 (partly), B12–B14, 2.4-S3.

## Tests added by QA (whole phase)
- **`supabase/tests/database/`:**
  - `qa_constraints.test.sql` (17), `qa_rls.test.sql` (24), `qa_read_apis.test.sql` (18), `qa_query_cost.test.sql` (5), `qa_storage.test.sql` (8), `qa_jobs.test.sql` (9), `qa_seed.test.sql` (7);
  - new for this gate: `qa_phase2_flow.test.sql` (42) and `qa_phase2_roles.test.sql` (4).
- **`supabase/functions/`:**
  - `_shared/qa_fcm.test.ts` (13; F6b fails until fixed);
  - new for this gate: `push-dispatcher/qa_e2e.test.ts` (database end to end, skipped without `PGHOST`).

## Recommendations (non-blocking)
- Run the full-stack checks listed at the top on `supabase start` or the dev project, and clear the Security Advisor, before Phase 4 relies on these APIs.
- Add the end-to-end dispatcher test to the CI `database` job, which has a running cluster: export `PGHOST` from `tool/db_test.sh --keep` and run `qa_e2e.test.ts`.
- `210_query_plans` now covers 5 of the 7 list RPCs. Add following-only, trending and nearby at 20 km, using plan-loop bounds as `qa_query_cost` does, not timings.
- The API surface pin in `qa_phase2_roles` is deliberate: when Phase 3 or 4 adds an RPC, add it there with its expected answers per role.
