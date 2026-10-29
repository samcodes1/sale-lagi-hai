# Explore, category and brand pages (sub-phase 4.5)

| Screen | Route | Shows |
|---|---|---|
| Explore (S05) | `/explore` | Top-level categories as chips, then every brand with a Follow button. The rows stack (name above Follow) at large text sizes |
| Category (S06) | `/category/<slug>` | Follow in the app bar; subcategory chips ("All" + each child) in a sideways-scrolling row; the deals of the chosen categories in the shopper's city |
| Brand (S07) | `/brand/<slug>` | Logo initial, name, category, a "Verified" label when the brand is verified, Follow, "Visit website" (https only, through `LinkService`), then the brand's deals |

- **Deal lists** on both pages are `PagedDealSlivers`, backed by `dealListProvider(DealListQuery)`:
  - `CategoryDeals(categoryIds, cityId)` and `BrandDeals(brandSlug, cityId)` are value-equal, so the same page keeps one list.
  - Keyset-paged by 20 with the same rules as Home's "For you": prefetch about 5 cards before the end, a retry row for a failed page (no automatic retry), and an end-of-list line.
  - Empty lists say so ("No deals from this brand right now" / "No deals in this category yet").
- **Following** (`followsProvider`) works for guests:
  - Follows live on the phone in the shopper preferences (`brandIds`, `categoryFollowIds`).
  - Signed in, each change is mirrored to the `follows` table under the shopper's RLS. A failed mirror keeps the local change, and the guest sync copies it next time.
  - The button is a toggle in semantics ("Follow Threads (Demo)", checked when following) and confirms with a toast.

## Code
- `lib/features/deals/application/deal_list.dart`: `FeedState`, `DealListQuery`, `dealListProvider`.
- `lib/features/deals/presentation/paged_deal_list.dart`: `PagedDealSlivers`, `dealCardFor`.
- `lib/features/follows/`: `followsProvider`, `FollowButton`.
- `lib/features/explore/`, `lib/features/categories/`, `lib/features/brands/`: the three screens.
- Database: `sync_guest_preferences` gained `category_ids` (`20261029200000_accounts.sql`).

## Tests
- `test/features/explore/follows_and_lists_test.dart`: follow and unfollow as a guest and signed in, the mirror failing, paging category and brand lists to the end, query equality.
- `test/features/explore/explore_screens_test.dart`: the real app on demo data: categories and brands open their pages, Follow on a row, subcategory chips narrow the deals, a deal opens; 200% text in en and ur.
- `supabase/tests/database/800_accounts.test.sql`: category follows in the guest sync.
