# Self-hosted Supabase on Railway

The backend runs as Railway project **sale-lagi-hai** (environment `production`, used by dev builds for now). It started from Railway's `supabase` template, plus an `edge-functions` service of our own.

## Services
| Service | What it does |
|---|---|
| Envoy | The gateway: the one public URL (`https://<envoy domain>`). Routes `/rest/v1`, `/auth/v1`, `/storage/v1`, `/functions/v1` and Studio |
| Postgres | Supabase Postgres 17, with pg_cron, pg_net, Vault, PostGIS and pg_trgm |
| Postgrest, Gotrue Auth, Supabase Storage (S3 bucket), Imgproxy, Supabase Realtime, Supavisor, Postgres Meta | The standard Supabase services |
| Supabase Studio | The admin UI, behind the gateway's basic auth (`DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD` on Envoy) |
| edge-functions | `supabase/edge-runtime` running our functions (`deploy/edge-runtime`) |

Railway's private network is IPv6: services must listen on `::`. PostgREST has `PGRST_SERVER_HOST=*6`, and the edge runtime starts with `--ip ::`.

## Keys
- **All derived from `ROOT_SECRET`.** Every key derives from `ROOT_SECRET` (a variable on every service, set once by the template): the JWT secret, the anon key, the service-role key and the `sb_` keys. The template's `supabase-secrets` tool does the derivation; see its source in `6ixfalls/supabase/secrets`.
  - Never change `ROOT_SECRET`: that would sign out every user and invalidate every key.
- **The app:** uses the anon key. It's public, and stored as the GitHub variable `DEV_SUPABASE_PUBLISHABLE_KEY`, next to `DEV_SUPABASE_URL`.
- **The `edge-functions` service variables:**
  - `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY`;
  - `SUPABASE_DB_URL`, which references Postgres;
  - `DISPATCHER_SECRET`, used by pg_cron;
  - `INGEST_BATCH_SECRET`, used by the daily Claude run;
  - `FCM_SERVICE_ACCOUNT`, once Firebase is set up.
- **Vault** holds `project_url` and `dispatcher_secret`, for the cron jobs that call functions.

## Migrations
The Supabase CLI isn't needed. Apply new files in `supabase/migrations` in order, as the `postgres` user, over the Postgres TCP proxy (`RAILWAY_TCP_PROXY_DOMAIN:RAILWAY_TCP_PROXY_PORT`). Each file runs in its own transaction and is recorded in `supabase_migrations.schema_migrations`, as the CLI would. So `supabase db push --db-url …` also works once the CLI is installed.

Never apply the seed (`supabase/seed.sql`): it has demo brands and deals.

## Edge Functions
```bash
tool/deploy_functions.sh
```
It uploads `supabase/functions` and `deploy/edge-runtime` to the `edge-functions` service. A new function must also be added to `FUNCTIONS` in `deploy/edge-runtime/main/index.ts`.

## Cron jobs
These come from the migrations:
- `expire-deals`, `refresh-freshness`, `plan-alerts`, `cleanup-old-rows`, `notify-staleness`;
- `push-dispatcher`, every minute.

`ingest` (every 15 minutes) was added by hand, as `docs/backend/JOBS.md` describes. It runs the coded adapters' sources and the daily link checks.

## Ingestion
- **Agent sources:** the daily Claude run (`docs/scraping/DAILY_RUN.md`) posts to `/functions/v1/ingest-batch`.
- **Paused sources:** each has the reason in its `notes`. Shopify stores currently answer our bot with 429 through Cloudflare, so they have no coded adapter sources yet.

## Still to set up (needs the owner's accounts)
- **Phone sign-in:** an SMS provider on Gotrue (`GOTRUE_SMS_*`, for example Twilio).
- **Google sign-in:** `GOTRUE_EXTERNAL_GOOGLE_*`, plus `GOOGLE_SERVER_CLIENT_ID` in the env.
- **Push:** `FCM_SERVICE_ACCOUNT` on `edge-functions`, and Firebase in the app.
- **Domains:** a custom domain for the gateway (for example `api.salelagihai.pk`). Then update `DEV_SUPABASE_URL`, Vault `project_url` and `SUPABASE_PUBLIC_URL`.
- **Backups:** turn on Railway volume backups for Postgres (service → Settings → Backups).
- **Studio access:** the basic-auth password is in Envoy's variables. Change it from the template's generated one if it was ever shared.
