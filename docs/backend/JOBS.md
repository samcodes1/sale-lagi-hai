# Jobs, alerts and push

Migrations: `supabase/migrations/20261029160000_jobs.sql`. Edge Function: `supabase/functions/push-dispatcher/`. Tests: `supabase/tests/database/400_jobs.test.sql` (SQL) and `supabase/functions/**/*.test.ts` (Node).

## Schedules (pg_cron)
| Job | When | What |
|---|---|---|
| `expire-deals` | every 5 min | Published deals past `ends_at` become `expired`. Placements start (`scheduled` → `active`) and end on time |
| `plan-alerts` | every 2 min | Plans alerts for newly live deals (below) |
| `push-dispatcher` | every minute | Calls the Edge Function through pg_net. Created only where pg_net and Vault exist, i.e. hosted Supabase |
| `refresh-freshness` | hourly | Scores live deals 0–100: verified today 100, then 80, 60, 30 and 10 as verification ages; never verified 40; minus 15 per open report |
| `cleanup-old-rows` | daily 03:43 | Removes pushes after 30 days, the processed queue after 7 days and notifications after 90 days |

## How an alert flows
1. A deal becomes `published`, and a trigger queues it once in `private.alert_queue`. Republishing doesn't alert again.
2. `plan_alerts()` finds followers of the deal's brand, its category (or parent category), a bank on its card offers, or the targeted city, plus users whose cards match a card offer.
   - Each user gets **one** alert, for the first of those topics they have switched on.
   - Everyone with the topic on gets an **in-app notification** in their language (`profiles.locale`).
3. A **push** is queued in `private.push_outbox` only if all of these hold:
   - push is on (`alert_prefs.push_enabled`) and the user has a registered device;
   - the daily cap isn't reached: 1 (low), 3 (normal) or 6 (high) per day, counted in the user's own time zone;
   - this brand hasn't already sent them a push today.
   - During the user's quiet hours (default 22:00–08:00, Asia/Karachi), the push is **deferred** until the quiet hours end, never dropped.
4. The dispatcher claims due pushes (one per device). It sends them through FCM HTTP v1, marks them sent, and deletes tokens FCM reports dead (`UNREGISTERED`, `INVALID_ARGUMENT`).
   - Rate limits and server errors are retried: a claim not marked sent within 10 minutes is handed out again, up to 5 attempts.
5. **Content rules:** the title is "Brand: offer" ("Khaadi: 40% off"), and the body is the deal title. No personal data, and taps open the deal (`data.deal_id`).

## Rate limits
| What | Limit | Response |
|---|---|---|
| Reports | 10 per user per hour | SQLSTATE `PT429`, returned by PostgREST as HTTP 429 |
| Submissions | 5 per hour and 20 per day per user | Same |
| Uploads | 60 per user per hour (storage policy) | 403 |

The service role (ingestion, staff tools) is not limited.

## Setting up a project (owner)
1. In **Vault** (Database → Vault), add `project_url` (`https://<ref>.supabase.co`) and `dispatcher_secret` (a random string of at least 32 characters, for example `openssl rand -hex 32`).
2. In **Edge Functions → Secrets**, add:
   - `DISPATCHER_SECRET` (the same value);
   - `FCM_SERVICE_ACCOUNT`: the Firebase service-account JSON key, with only the "Firebase Cloud Messaging API Admin" role.
3. Deploy the function: `supabase functions deploy push-dispatcher`. `config.toml` sets `verify_jwt = false` for it; it checks `x-dispatcher-secret` itself, in constant time, and fails closed if the secret is missing.
4. Enable the `pg_net` extension, then re-run the last block of the jobs migration (or `select cron.schedule('push-dispatcher', …)` as written there).

The function connects with `SUPABASE_DB_URL`, which the platform provides, so the `private` dispatcher functions are never exposed through the Data API.
