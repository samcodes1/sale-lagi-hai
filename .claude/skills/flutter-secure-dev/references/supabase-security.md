# Supabase security reference

A runnable version of the core patterns (roles, business membership, moderation, report rate limit) and the tests that prove them is in `.claude/skills/qa-testing/scripts/sql/example_migration.sql` and `example_rls.test.sql`. They are verified on Postgres 16 with the bundled stub.

## 1. Keys and roles
| Key | Postgres role | Where it may live |
|---|---|---|
| Publishable `sb_publishable_…` (legacy `anon` JWT) | `anon` when signed out, `authenticated` with a user JWT | The app, the web portals, CI |
| Secret `sb_secret_…` (legacy `service_role` JWT) | `service_role` (**BYPASSRLS**) | Edge Function secrets and deploy-time CI secrets only |

- Supabase is deprecating the legacy `anon` and `service_role` keys **by the end of 2026**. Create the publishable and secret keys now and use one secret key **per backend component** (for example `ingestion` or `push`) so leaks can be rotated individually.
- The new keys go in the `apikey` header, **not** `Authorization: Bearer`. A secret key in `Authorization` fails JWT parsing.
- A request that carries a *user* JWT runs under that user's RLS even if the client was created with a secret key.
- The **Security Advisor** in the dashboard must show zero unresolved findings before each phase gate.

## 2. Table recipe (do this for every table)
```sql
create table public.saves (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  deal_id uuid not null references public.deals on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, deal_id)
);
alter table public.saves enable row level security;
revoke all on table public.saves from anon, authenticated;              -- grants are opt-in
grant select, insert, delete on table public.saves to authenticated;

create policy "own saves: read"   on public.saves for select to authenticated using ((select auth.uid()) = user_id);
create policy "own saves: add"    on public.saves for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "own saves: remove" on public.saves for delete to authenticated using ((select auth.uid()) = user_id);
create index on public.saves (user_id);                                  -- index every policy column
```
Rules:
- **One policy per operation.** No `for all`. `update` needs `using` (which rows) **and** `with check` (what the new row may look like), plus a `select` policy.
- **Always add `to <role>`.** Write `(select auth.uid())`, not a bare `auth.uid()`, so it's evaluated once per statement. Use `auth.uid() is not null` when intent matters.
- **Revoke the project defaults once.** On existing projects new `public` objects auto-grant everything to `anon`, `authenticated` and `service_role`. Run these once per project in a migration:
  ```sql
  alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated, service_role;
  alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated, service_role;
  alter default privileges for role postgres in schema public revoke all on functions from anon, authenticated, service_role;
  alter default privileges for role postgres revoke execute on functions from public;
  ```
  Then grant `execute` explicitly on every function a policy or client needs. Alternatively, turn off **"Automatically expose new tables"** in the Data API settings.
- **Views** use `create view … with (security_invoker = true)`. Otherwise they run as `postgres` and bypass RLS.
- **Column-level secrets** (for example a moderator note) don't belong in a client-readable table. Put them in a separate table, use column grants, or expose them through an RPC.
- **Use `check` constraints** for lengths, enums and ranges. The database is the validator of last resort.

## 3. Policy patterns for our roles
| Pattern | Expression |
|---|---|
| Public read of live content | `for select to anon, authenticated using (status = 'published' and (ends_at is null or ends_at > now()))` |
| Owner-only | `using ((select auth.uid()) = user_id)` + the same `with check` |
| Business member | `using (business_id in (select private.my_business_ids()))` |
| Staff role (table-based, always fresh) | `using ((select private.has_role('moderator')))` |
| Staff role (JWT claim, fast but stale until refresh) | `using ((auth.jwt() ->> 'user_role') = 'admin')`, only for low-risk reads |
| MFA for staff writes | `create policy … as restrictive for update to authenticated using ((select auth.jwt() ->> 'aal') = 'aal2')` |
| Insert-only audit and reports | grant `insert` only; `with check (reporter_id = (select auth.uid()))`; no update or delete policies |

**Roles via a Custom Access Token Hook.** A `public.user_roles` table plus `public.custom_access_token_hook(event jsonb)` adds a `user_role` claim.
- Grant the hook `execute` to `supabase_auth_admin`, revoke it from `authenticated`, `anon` and `public`.
- Give `supabase_auth_admin` a `select` policy on `user_roles`.
- Clients may read the claim for UI only, by decoding the access token. Authorization is always re-checked in SQL.
- **Never** use `raw_user_meta_data`/`user_metadata` for authorization, because the user can edit it with `auth.updateUser`.

## 4. `security definer` functions: pitfalls
```sql
create function private.has_role(r public.app_role) returns boolean
language sql stable security definer
set search_path = ''                                 -- 1. pin search_path, qualify every name
as $$ select exists (select 1 from public.user_roles ur
                     where ur.user_id = (select auth.uid()) and ur.role = r) $$;
revoke execute on function private.has_role(public.app_role) from public, anon;   -- 2. least privilege
grant usage on schema private to authenticated;
grant execute on function private.has_role(public.app_role) to authenticated;
```
1. **Without `search_path = ''`**, a caller can shadow an unqualified name (for example by creating `public.user_roles` in a schema earlier in their path) and run code with the owner's privileges.
2. **A definer function in an exposed schema** (`public`) is callable over `/rpc` with owner privileges. Keep helpers in `private`, which is not in "Exposed schemas".
3. **Definer functions bypass RLS** (owner `postgres` has BYPASSRLS). Every query inside must filter by `auth.uid()` itself.
4. **Use them to break recursive policies** (`42P17`), as with `lists` ↔ `list_members` and our `businesses` ↔ `business_members`.
5. **Mark them `stable`** when they're read-only, so the planner can cache them, and call them as `(select private.fn())` in policies.
6. **Public RPCs** (`api.feed(...)`) should normally be `security invoker` so RLS applies. Use definer only with a written justification and tests.

## 5. Edge Functions
```ts
import { withSupabase } from 'npm:@supabase/server@1'   // @supabase/server 1.9.x on npm

// User-facing (verify_jwt = true, the default): RLS-scoped client
export default {
  fetch: withSupabase({ auth: 'user' }, async (req, ctx) => {
    const body = SubmitDeal.parse(await req.json())      // schema-validate every input (zod/valibot)
    const { data, error } = await ctx.supabase.rpc('submit_deal', body)   // RLS applies
    if (error) return Response.json({ error: 'submit_failed' }, { status: 400 }) // no internals leaked
    return Response.json(data)
  }),
}
```
- **Function auth modes:**
  - `auth: 'user'` for app calls.
  - `auth: 'secret'` (with `verify_jwt = false` in `config.toml`) for pg_cron, `pg_net` and function-to-function calls.
  - `auth: 'none'` only for signed webhooks (verify the provider's signature) and health checks.
- **`ctx.supabaseAdmin` bypasses RLS.** Filter by `ctx.userClaims.id` on every query that uses it.
- **Read secrets** from `Deno.env`, never from request input. New-style keys come from `SUPABASE_SECRET_KEYS` as a JSON map by name. Never log headers or keys; log at most 6 characters after the prefix, or a SHA-256.
- **CORS:** allow only our web portal origins for browser-called functions. Mobile calls don't need CORS.
- **Return generic errors** and log details server-side without PII.
- **Push dispatcher:**
  - Holds the FCM HTTP v1 service account in function secrets. The legacy FCM API is gone.
  - Reads `alert_prefs` and quiet hours and enforces the frequency caps (see the flutter-ui-ux skill).
  - Deletes tokens on `UNREGISTERED` or `INVALID_ARGUMENT`.

## 6. Rate limiting and abuse prevention
| Surface | Control |
|---|---|
| Phone OTP and sign-in | The built-in Auth rate limits (token bucket, about 30 bursts per IP). Tune them in the dashboard and Management API. Enable CAPTCHA (Turnstile, invisible) if SMS pumping appears. Enable IP forwarding if a proxy sits in front |
| Data API writes | A `pgrst.db_pre_request` function (`public.check_request`) that counts writes per IP in `private.rate_limits`, returns HTTP 420 over the limit, and is cleaned by pg_cron. GET/HEAD can't be limited this way because they're read-only |
| Submissions, reports, votes | A per-user quota in a `before insert` trigger or in the RPC, for example 10 reports per hour (see the example migration). Add a unique constraint so one user reports a deal once. Send new submissions to a moderation queue (`status = 'pending'`) and require Play Integrity for high trust |
| Search and feed scraping | Cursor pagination with a max page size of 50, RPCs only (no raw table select for heavy joins), and optional per-IP limits in Edge Functions using Upstash Redis (the Supabase example) |
| Storage uploads | `file_size_limit` and `allowed_mime_types` per bucket, a per-user upload quota, and server-side resizing |

## 7. Storage buckets
```sql
-- deal-images: public read, write only by members of the business that owns the folder.
-- Compare as text: casting a hostile folder name to uuid would raise 22P02 instead of denying.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('deal-images', 'deal-images', true, 2097152, array['image/jpeg','image/png','image/webp']);

create policy "members upload deal images" on storage.objects for insert to authenticated
with check (bucket_id = 'deal-images'
            and (storage.foldername(name))[1] in (select b::text from private.my_business_ids() b));
create policy "members replace deal images" on storage.objects for update to authenticated
using (bucket_id = 'deal-images' and (storage.foldername(name))[1] in (select b::text from private.my_business_ids() b));
-- avatars (private bucket): owner-only, folder = user id
create policy "own avatar read" on storage.objects for select to authenticated
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
```
- Upserts need `insert` + `select` + `update`. **Public buckets serve objects without policies**, so never put private files in them.
- For a non-public bucket that should still be readable, use `storage.allow_any_operation(...)` (see the Supabase docs) so users can't *list* the bucket.
- Deleting a user fails while they own storage objects. Delete their objects first, then the user.

## 8. Account deletion (Play requirement)
Edge Function `delete-account` (`auth: 'user'`):
1. Require recent re-auth. Check the OTP or that `iat` is within 5 minutes, and that `aal` matches the account type.
2. Remove storage objects owned by the user (`avatars/<uid>/…`) and hand any business's assets over to a co-owner or delete them.
3. Delete FCM tokens and `alert_prefs`, then call `supabaseAdmin.auth.admin.deleteUser(uid)`. Not a soft delete. The `on delete cascade` FKs remove saves, follows, user_cards and profiles.
4. Keep only what policy requires (for example an anonymised moderation audit with `reporter_id` set to null) and document the retention.
5. The client signs out locally and wipes secure storage and the cache. Outstanding access tokens remain valid until `exp`, so keep the JWT expiry short and have sensitive RPCs verify `session_id` exists in `auth.sessions`.

Also provide a web deletion page (works without the app) and link it in the Play Data safety form.

## 9. Testing (what the gates require)
- **Per table:** a `supabase/tests/<table>_rls.test.sql` (pgTAP), or the plain-SQL harness when Docker isn't available. Assert:
  - grants: `has_table_privilege`;
  - allow and deny per role (`anon`, user, member, moderator, admin) per operation;
  - `42501` for missing grants and `with check` failures;
  - **empty results** (not errors) for rows filtered by `using`;
  - that a denied update or delete left the row intact.
- **Schema-wide:** RLS is on everywhere (`tests.rls_enabled('public')` from basejump test helpers, or `10_schema_lint.sql`), no definer function without `search_path`, and no anon write grants.
- **Functions:** a JWT-verification test for each Edge Function (no token → 401, anon → 401 for `auth: 'user'`, other user → 403 or empty), rate-limit tests, and input-validation tests.

## Sources
Supabase docs, read through their source in supabase/supabase `apps/docs/content/guides`:
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security), [RLS performance](https://supabase.com/docs/guides/database/postgres/row-level-security-performance), [Securing your API](https://supabase.com/docs/guides/api/securing-your-api), [API keys](https://supabase.com/docs/guides/getting-started/api-keys), [Migrating to new API keys](https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys)
- [Securing Edge Functions](https://supabase.com/docs/guides/functions/auth), [Custom claims & RBAC](https://supabase.com/docs/guides/api/custom-claims-and-role-based-access-control-rbac), [Custom access token hook](https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook)
- [Storage access control](https://supabase.com/docs/guides/storage/security/access-control), [Managing user data](https://supabase.com/docs/guides/auth/managing-user-data), [Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits), [Rate-limiting Edge Functions](https://supabase.com/docs/guides/functions/examples/rate-limiting)
- [Testing your database](https://supabase.com/docs/guides/database/testing), [Advanced pgTAP testing](https://supabase.com/docs/guides/local-development/testing/pgtap-extended)
- [@supabase/server on npm](https://www.npmjs.com/package/@supabase/server) (latest 1.9.2, checked against the npm registry)
