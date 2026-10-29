# Deal page (sub-phase 4.4)

`/deal/<id>` (screen S05, UX flow F2) opens above the tabs, from any card, a shared link or (in Phase 5) a notification.

| Part | Source | Notes |
|---|---|---|
| Image, brand, title, badge, Featured, price | `deal_cards` | No image: a brand plate. The title is a heading. |
| Validity, verified | `ends_at`/`starts_at`, `verified_at` | `ExpiryTag`/`VerifiedTag`; "Starts …" before the start |
| Ended banner | status `expired`, or `ends_at` passed | The page still opens (old links work); the promo code is hidden |
| Open the offer, See the source | `url` (else `source_url`) | `LinkService.openWeb`: https only, in Custom Tabs |
| Save | `savedDealsProvider` | Kept on the phone (newest first, at most 500), mirrored to `saves` (with `user_id`) when signed in. Guest saves move into the account at sign-in. The Saved tab is 4.8. A save made while the saved file is being read is replayed onto it; a file that couldn't be read is never overwritten, and the next save reads it again (`StoredStringList`). A fresh start after account deletion forgets them. Screen readers get one toggle node ("Save" / "Remove from saved"). |
| Share on WhatsApp | `wa.me/?text=` | "Brand: offer. Title. Found on Sale Lagi Hai!" plus the offer link. An app link to the deal comes with Phase 5's deep links. |
| Promo code | `promo_code` | Left to right in both languages, selectable, with a Copy button |
| With these cards | `card_banks` | Chips |
| About, Terms | `deals.description_*`, `terms_*` | In the UI language, falling back to English |
| Where to use it | `outlets` (+ `deal_targets` for local deals) | Online: no outlets. Nationwide: all the brand's active outlets. Local: only outlets in the target cities and areas. Each has Directions (Google Maps link: the app if installed, else the web) and Call when there's a phone number. No embedded map, so no Maps API key or SDK. |
| Report a problem | `reports` insert | UX flow F5. Guests sign in first. Pick one of 7 reasons; "Something else" needs a note (capped at 500 chars). A second report on the same deal says "already reported". The server allows 10 reports an hour. |

- **Links.** `LinkService` is the only way the app opens anything outside itself: https pages, the maps link, `wa.me`, and `tel:` (only for a valid `+92` number). A failed launch shows "Couldn't open that".
- **Data.** `DealRepository.detail(id)` reads the card, the long text, the brand's outlets (at most 100) and the targets, in parallel. `outlets.latitude`/`longitude` are generated columns.

## Fixed in the 4.4 QA gate
- **BUG-1:** rows name their owner. The app sends `user_id`, and `saves`, `follows` and `user_cards` also default `user_id` to `auth.uid()`; the insert policies still check it.
- **BUG-2 and BUG-3:** the saved list (see Save above).
- **BUG-4:** a local deal's outlets are read in its target areas, or in its target cities when one is city-wide, before the 100-outlet cap.
- **BUG-5:** report notes are capped at 500 code points, never splitting an emoji.
- **BUG-6:** Save is a toggle for screen readers.
- Links that can't open say "Couldn't open that" (`openLink`), also on brand pages.

## Tests
- `test/features/deals/deal_detail_data_test.dart`:
  - outlet filtering per scope, the text, not found, malformed outlets;
  - saved deals (guest, restart, corrupt file, signed-in mirroring, guest sync);
  - reports (duplicates, notes, enum mapping).
- `deal_detail_screen_test.dart`, in the real app on demo data:
  - the page, Directions, promo copy, opening the offer, a failed link;
  - Save, WhatsApp text, the report flow as a guest (sign-in first, then duplicates), the note requirement;
  - an ended deal, an unknown deal;
  - guidelines and 200% text in en and ur.
- `test/core/links/link_service_test.dart`: the URL allowlist and the fixed endpoints.
- `supabase/tests/database/820_deal_detail.test.sql`: anon reads outlet coordinates and live deals' text, but not drafts.
