# Access matrix

Who can do what, enforced by grants, RLS policies and guard triggers (`supabase/migrations/20261029130100_rls_policies.sql`). Each cell is tested allow and deny in `supabase/tests/database/1xx_rls_*.test.sql`.

- **Staff powers need MFA.** A moderator or admin without an `aal2` session is treated as a plain shopper.
- **The service role** (Edge Functions, ingestion, jobs) bypasses RLS and the guards. It never reaches the apps.

| Data | anon | Shopper | Business member (editor / owner) | Moderator | Admin |
|---|---|---|---|---|---|
| Cities, areas, categories, banks, card products | Read active | Read active | Read active | Read all | Read all, write |
| Profiles | — | Own: read, edit name, avatar, city, language | Own | Read all | Read all |
| User roles | — | Read own | Read own | Read own | Read all, grant, revoke (not their own admin) |
| Businesses | — | Register one (becomes owner) | Read own. Owners edit details; never verify | Read all, verify, suspend | Delete |
| Business members | — | — | Read team. Owners add, remove and change roles; anyone may leave; the last owner can't | Read all | Manage |
| Brands | Read active | Read active | Read own. Add (hidden until staff activate). Edit details, not slug, owner, bank, verified or active | Read all, add, edit, activate, verify | Delete |
| Outlets | Read active | Read active | Manage own brands' outlets | Manage | Manage |
| Deals | Read published and expired, once started | Same | Read all own. Write drafts, send for review, take back to draft, remove; edit content only as a draft; never publish, reject or verify | Read all, publish, reject, edit | Delete |
| Deal targets, card offers | With their deal | With their deal | Edit while the deal is a draft | Manage | Manage |
| Follows, saves, my cards | — | Own (saves: only deals they can see) | Own | Own | Own (no one reads others') |
| Alert preferences | — | Read and edit own | Own | Own | Own |
| Notifications | — | Read, mark read, delete own | Own | Own | Own (written by the push dispatcher) |
| Reports | — | Send (open, on visible deals); read own | Same | Read all, resolve as themselves | Same |
| Submissions | — | Send (pending); read own; withdraw while pending | Same | Read all, review as themselves | Same |
| Placements | Read live | Read live | Read own. Draft, edit and delete drafts, cancel; never activate or set priority | Read all | Manage |
| Payments | — | — | Owners read their business's | — | Read all (written by the payments webhook) |
| Audit log | — | — | — | — | Read (written by trigger) |

Notes:
- **Column grants limit what a client can send.** For example, a profile's id and timestamps, notification text, and a deal's `published_at`, `fingerprint`, `source` and `created_by` are not client-writable.
- `created_by`, `granted_by`, `reporter_id` and `submitter_id` default to the caller, and policies require them to equal the caller.
- The Custom Access Token Hook adds `user_roles` to the JWT **for the apps' UI only**; policies always read the table. Enable it in the dashboard (Authentication → Hooks).
- **Account deletion always succeeds.** If the user was a business's last owner, the business is left without an owner for staff to reassign.

## Storage
Defined in `supabase/migrations/20261029150000_storage.sql`, tested in `300_storage.test.sql`.

| Bucket | Public | Limit | Path | Write | Read |
|---|---|---|---|---|---|
| `deal-images` | Yes (by URL) | 2 MB | `<business_id>/<deal_id>/<file>`, or `staff/<deal_id>/<file>` | The business's members, for their own deals; staff with MFA | Anyone with the URL; nobody can list the bucket except members (their folder) and staff |
| `brand-logos` | Yes (by URL) | 1 MB | `<business_id>/<brand_id>/<file>`, or `staff/…` | Same as above, for their own brands | Same as above |
| `avatars` | No | 1 MB | `<user_id>/<file>` | The user | The user; moderators |
| `submission-photos` | No | 5 MB | `<user_id>/<file>` | The user | The user; moderators |

- **File types:** JPEG, PNG and WebP only, never SVG. The Storage API checks MIME type and size; policies also check the extension and the exact folder depth.
- **Path checks:** folder names are compared as text, never cast, so a hostile name is denied rather than raising an error. `..` and extra folders are refused.
- **Quota:** at most 60 uploads per user per hour, across all buckets.
- **Resized variants** come from image transformations at read time (`/storage/v1/render/image/public/deal-images/…?width=400`), so only originals are stored.
- **The size and MIME limits** are enforced by the Storage API itself, so they can only be tested on the full stack (`supabase start`). The plain-Postgres tests check the bucket settings that drive them.
