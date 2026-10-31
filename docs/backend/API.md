# Read APIs

The apps call these RPCs with `supabase.rpc(...)`. They are defined in `supabase/migrations/20261029140000_read_apis.sql` and tested in `supabase/tests/database/200_read_apis.test.sql` (results) and `210_query_plans.test.sql` (index use on 20,000 deals).

Every RPC returns `deal_card` rows: the deal-card fields (brand, category, offer, prices, dates, `card_banks`), plus `is_featured` and `distance_m`. A single deal (the detail page, including expired deals) is read from the `deal_cards` view: `.from('deal_cards').select().eq('id', id)`.

| RPC | For | Paging |
|---|---|---|
| `feed(city_id, category_ids, following_only, after_published_at, after_id, page_size)` | Home and category pages. Live nationwide and online deals, plus local deals targeting the city (once the city is live). Categories include their subcategories. `following_only` limits it to followed brands, categories (and their subcategories) and banks, and local deals targeting a followed city (the alert planner's rules). An empty `category_ids` means any | Keyset: pass the last row's `published_at` and `id` |
| `featured_deals(slot, city_id, category_id, page_size)` | "Featured" slots. Active placements in their window, highest priority first, at most 10 | — |
| `trending_deals(city_id, days, page_size)` | Trending. Saves in the last 1–30 days, weighted towards newer deals | Top 50 |
| `nearby_deals(lat, lng, radius_m, page_size)` | Near me. Deals with an active outlet within the radius (100 m–20 km), with the distance to the nearest outlet. Local deals only in live cities (as in the feed). The location is not stored | Nearest 50 |
| `ending_soon_deals(city_id, within_hours, page_size)` | Home's "Ending soon" (4.3). Live deals ending within the window (1–168 h, default 72), soonest first; shown in a city like the feed | One page (≤ 50) |
| `deals_for_my_cards(city_id, after_published_at, after_id, page_size)` | Deals for my cards: `deals_for_cards` over the signed-in user's own `user_cards`. Signed-in users only | Keyset |
| `deals_for_cards(card_product_ids, city_id, after_published_at, after_id, page_size)` | Card offers (4.7) that one of these card products gets: the same bank, and the offer's product, kind and network where set. At most 20 cards count; inactive products match nothing. Open to guests: the ids are products ("HBL Visa Credit"), never card numbers | Keyset |
| `mark_alerts_read(ids)` | Alerts inbox (4.8): marks the caller's notifications read, these ids (at most 200) or all when null; returns how many changed. Signed-in users only | — |
| `unread_alert_count(since)` | The Alerts badge: the caller's unread notifications, created after `since` when given; capped at 100. Signed-in users only | — |
| `search_deals(query, city_id, category_ids, area_id, bank_ids, min_percent, ending_within_hours, after_id, page_size)` | Search (4.6). With words (2–100 characters): full text on titles and descriptions (English, Roman Urdu, Urdu), plus fuzzy matching on titles and brand names that forgives a wrong letter or two, best first. With no words: the newest deals that pass the filters. Filters: area (local deals there or city-wide; online and nationwide stay), banks (card offers), at least a percentage off (1–99), ending within hours (1–336). Every filter applies before the 250-hit cap | Keyset on `after_id` (the rank is recomputed; a deal no longer in the results ends the list) |
| `brand_suggestions(query, page_size)` | Brands while typing (4.6): name starts with the words, then fuzzy matches, then Urdu-name prefixes. 1–60 characters, at most 10. LIKE wildcards in the words are plain characters | One list |
| `brand_deals(brand_slug, city_id, after_published_at, after_id, page_size)` | Brand pages | Keyset |

## Tables read directly

`sponsor_banners`: Home's sponsor banners. RLS returns those running now; the app filters by city.

## Rules
- **Pages hold at most 50 rows** (`page_size` is clamped to 1–50; the default is 20). PostgREST's `max_rows` is 100 as a backstop.
- **RLS decides visibility.** The RPCs are `security invoker`, and lists show live deals only: published, started, not ended, from an active brand.
- **Where RLS would block an index**, the lookup runs in a `private` security-definer helper (`search_hits`, `brand_hits`, `outlets_near`) that returns only public rows; the RPC then reads the cards under RLS. This applies to full-text, fuzzy and spatial matching, which Postgres won't push below RLS policies because their operators aren't leakproof.
- **Counts without identities:** trending reads save counts through `private.recent_save_counts`, never who saved.
- **Search indexes skip GIN's pending list** (`fastupdate = off`), so results stay index-backed right after an ingestion burst.

## Cursor example
```dart
final page = await supabase.rpc('feed', params: {
  'city_id': cityId,
  'after_published_at': last?.publishedAt.toIso8601String(),
  'after_id': last?.id,
  'page_size': 20,
});
```

## Accounts (4.2)
| RPC | Who | What |
|---|---|---|
| `sync_guest_preferences(city, lang, brand_ids)` | Signed-in users | Copies a guest's on-phone city, language and followed brands (at most 200, active only) into the account. Nulls keep what the account has. |
| `sync_guest_items(deal_ids, card_product_ids)` | Signed-in users | Adds a guest's on-phone saved deals (at most 500, visible ones only) and cards (at most 20, active products only) to the account in one call. Ones already there are skipped. |
| `prepare_account_deletion(target)` | Service role only (the `delete-account` Edge Function) | Hands business-bucket uploads to the business, and lists the private files to delete. See `docs/app/ACCOUNTS.md`. |
