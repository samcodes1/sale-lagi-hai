# Home feed (sub-phase 4.3)

Home (screen S03) is one scrolling list. From the top:

| Row | Source | Notes |
|---|---|---|
| City button (app bar) | `homeCityProvider` (the shopper's city) | Opens a city picker sheet; "All Pakistan" shows nationwide and online deals only |
| Featured | `featured_deals('home_featured', city)` | Paid placements; every card says "Featured" |
| Trending today | `trending_deals(city)` | |
| Near you | `nearby_deals(lat, lng)` | A button until tapped. Approximate location, used for this one query; never stored, logged or cached. Denied, blocked (with settings), unavailable and failed each show a message |
| Ending soon | `ending_soon_deals(city, 72 h)` | New RPC in `20261029210000_home.sql`, soonest first |
| For you | `feed(city, interests)` | Keyset-paged by 20. The next page loads about 5 cards before the end. A failed page shows a retry row, never a full-screen error, and never retries on its own. The end shows "You've seen all the new deals". |

- **Cards keep their natural height**, since they grow with Urdu and large text. The carousels are therefore a scrolling `Row` (at most 20 cards each), not fixed-height lists.
- **Pull to refresh** reloads every row.
- **An empty row is left out.**
- **Offline:**
  - The offline banner shows (a live region).
  - Each row shows its last saved copy (`JsonCache`, `cache.home.<row>.<city>`; "For you" keys also include the interests) with "Updated X ago". Copies older than 3 days aren't shown.
  - With no copy, the row shows a compact error with Try again; "For you" shows the full error view.
  - Deals that ended since they were saved are dropped when shown.
- **Privacy:** the cache holds public deal rows only (`dealToRow`, the inverse of `dealFromRow`). Nothing about where the shopper is gets cached.

## Code
- `lib/features/home/application/home_providers.dart`:
  - `featuredProvider`, `trendingProvider`, `endingSoonProvider` (each a `HomeSection`: deals, plus `cachedAt` and `failure` when stale);
  - `forYouProvider` (`ForYouController`: `FeedState`, `loadMore`);
  - `nearMeProvider` (`NearMeController`).
- `lib/features/home/presentation/home_screen.dart`.
- `lib/features/deals/presentation/deal_card_mapper.dart`: Deal → `DealCardData`. The place label is the distance, "Online", "All Pakistan" or the city. Image URLs point into the public `deal-images` bucket.
- `AppFormatters.distance`: `350 m`, `1.2 km`, `14 km` (Urdu: میٹر, کلومیٹر).

## Tests
- `test/features/home/home_providers_test.dart`: caching, stale fallback and expiry, corrupt copies, paging without repeats, single-flight loading, retry, city and interest changes, and Near me.
- `home_screen_test.dart`: the real app on demo data:
  - rows, a card opening its deal, changing city;
  - Near me (found, blocked);
  - endless scroll to the end, retry row, offline banner with saved rows, offline with nothing saved, pull to refresh.
- `home_a11y_test.dart`: guidelines in en and ur, light and dark, down the whole list; 200% text at 360 × 800 in both languages; headings; RTL.
- `home_golden_test.dart`: en, ur and ur dark.
- `supabase/tests/database/810_home.test.sql`: `ending_soon_deals`.
