# Search and filters (sub-phase 4.6)

Search (screens S11 and S12) opens from the search field at the top of Explore, or from `/search?q=<words>`. The words are cut to 100 characters.

## The page
- **Before searching:** recent searches (newest first, each with a remove button, plus "Clear all"), a note that they stay on this phone, and popular categories.
- **Typing:** results follow once typing settles (350 ms). Submitting with the keyboard's search key is immediate and adds the words to recent searches. One character shows nothing.
- **Suggestions** sit above the results:
  - brands, from `brand_suggestions` on the server;
  - categories and areas of the shopper's city, matched on the phone against names in both languages.

  A brand or category opens its page. An area becomes the area filter and clears the words.
- **Deals:** `PagedDealSlivers` over `SearchDeals(query, filters, cityId)`, keyset-paged like every other list. The empty state names the words, or for filters alone says "No deals match these filters" with **Clear filters**.
- **Filters:**
  - The bar under the field has **Filters (n)**, which opens the sheet, plus one-tap **Ending soon** and **50%+ off**, and **Clear filters** when any are on.
  - The sheet sets area (the shopper's city only), categories, card offers from banks, minimum discount (10, 25 or 50%), and ending within 3 days.
  - Choices apply on **Show deals**. Closing the sheet any other way changes nothing.
  - Changing city on Home drops the area filter and keeps the rest.
  - **Filters alone search:** with no words, the newest deals that pass them are shown.
- **Offline:** the offline banner shows. Recent searches still work. Results show the usual error with Try again.

## Changed after the 4.6 QA gate (PASS)
- **S3:** "N%+ off" counts "-40%" and "Flat 40% off" offers only. "Up to 50% off" is not at least 50% off.
- **S1:** with words, a page's last deal ending or being hidden before the next page loads no longer ends the list. `private.search_rank` recomputes its place.
- **S2:** with an area filter, the area's own local deals rank first (+10 on the rank), so the 250-hit cap can't push them out. Online, nationwide and city-wide deals follow.
- **A1 and A2:** a search saved while recent searches load is replayed onto them; logs hold only error types (`StoredStringList`).
- **A3:** suggestion and recent rows are buttons for screen readers.
- **A4:** `?q=` and the length checks count code points, never splitting an emoji.
- **A5:** with no filters on, the empty state doesn't mention filters.
- **A6:** deal lists and suggestions are kept only while shown (auto-dispose).

## Not built, and why
- **Trending searches** (in the S11 sketch) would need us to collect what people search for. We don't log searches; popular categories take that slot.
- **Open now** (in the S12 sketch) needs outlet opening hours, which the schema doesn't hold yet.

## Privacy
- Recent searches live only on this phone (`search.recent.v1`, at most 8). They are never sent anywhere or logged. They survive signing out, like the other on-phone choices, and go when the account is deleted, since that clears local data.
- Logs about recent searches carry only the error type. A `FormatException`'s text would quote the stored file.
- Searches reach the server only as RPC parameters and are not stored there.

## Backend (`20261029220000_search.sql`)
- `search_deals` is replaced (see docs/backend/API.md):
  - it filters by area, banks, minimum percent and ending window;
  - it also works without words;
  - it pages by `after_id`.
- `private.search_hits` applies every filter before its 250-hit cap, so a filtered search never loses matches.
- `private.matches_search_filters` is the filter rule, shared by both branches.
- `brand_suggestions` reads brand ids from the security-definer helper `private.brand_hits`. The helper uses literal patterns, so each condition uses its trigram index; RLS would otherwise keep the LIKE and trigram operators off the indexes. The RPC then reads the brands under RLS. A new trigram index covers `brands.name_ur`.

## Code
- `lib/features/deals/domain/search_filters.dart`: `SearchFilters`. It compares by value in any order, and `toString` holds no ids.
- `lib/features/deals/application/deal_list.dart`: `SearchDeals`.
- `lib/features/search/application/search_providers.dart`:
  - `searchProvider` (words, settled words, filters);
  - `searchResultsQueryProvider`;
  - `recentSearchesProvider`;
  - `searchSuggestionsProvider`.
- `lib/features/search/presentation/`: `SearchScreen` and the filters sheet.
- Catalog: `Area`, `Bank`, `areasProvider(cityId)`, `banksProvider`, `CatalogRepository.suggestBrands`.

## Tests
- `test/features/search/search_providers_test.dart`:
  - recent searches: order, dedupe, limit, persistence, corrupt files, and nothing searched in logs;
  - settling, submit, filters alone, city change, clearing words;
  - every filter and keyset paging on the demo backend;
  - suggestions.
- `test/features/search/search_screen_test.dart`, the real app on demo data:
  - Explore entry, suggestions, recent searches, popular categories;
  - the filters sheet (applies only on Show deals), quick chips, area suggestion, empty states, `?q=`;
  - guidelines and 200% text in en and ur on the start page, results and the sheet.
- `test/features/deals/deals_data_test.dart`: RPC parameters (only the filters that are on) and the skipped queries.
- `test/features/catalog/catalog_test.dart`: areas, banks, brand suggestions.
- `supabase/tests/database/830_search.test.sql`: each filter, filters alone, keyset paging with and without words, filters before the cap, the old signature gone, grants, brand suggestions (prefix, typo, Urdu, hidden brands, LIKE wildcards, length).
- `210_query_plans.test.sql`: filtered search, filters alone and suggestions (on 20,000 brands) use indexes.
