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
