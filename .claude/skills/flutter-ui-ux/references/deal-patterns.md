# Deal, e-commerce, search and filter patterns

## 1. Deal card anatomy
Content priority (UX_ARCHITECTURE §3):

```
┌──────────────────────────────────────────┐
│ [image 16:9 or logo plate]  [-40%] badge │  ← badge at the top-end corner (mirrors in RTL)
│ [Featured] (only if sponsored)       [♡] │  ← save is a 48dp target
│ Brand name · Gulberg, Lahore             │
│ Flat 40% off on summer lawn              │  ← offer headline, 2 lines max
│ Rs 1,799  ~~Rs 2,999~~                   │  ← new price first, old price struck
│ ⏱ Ends in 2 days   ✓ Verified 3h ago     │  ← icon + text, never colour alone
│ [HBL] [Meezan] card chips (card offers)  │
└──────────────────────────────────────────┘
```

**Variants:**
- **Compact list row** for search results: thumbnail, title, badge, expiry.
- **Hero card** for the Home carousel.
- **Card-offer card:** bank logo, card product, "15% off at X", the cap ("max Rs 1,500"), valid days.
- **Promo-code card:** the code in a monospace LTR chip with a [Copy] button that confirms with "Copied".

**Rules:**
- **One primary tap target** (the whole card) opens the deal. Secondary actions (save, share) are separate 48dp `IconButton`s with tooltips.
- **Images:**
  - Use `cached_network_image` with a fixed aspect ratio, so the layout doesn't shift.
  - The placeholder is the brand colour or a blurhash, and the error widget is the brand logo plate.
  - Images are decorative (`excludeFromSemantics`) because the card label carries the meaning.
  - Pass a `memCacheWidth` matched to the display size.
- **Semantics:** one merged label, for example "Khaadi. Flat 40% off on summer lawn. Rs 1,799, was Rs 2,999. Ends in 2 days. Verified 3 hours ago. Featured." Add a custom semantics action for "Save".
- **Long Urdu and 200% text:** the card grows in height and is never clipped. Feeds must not use a fixed `itemExtent` for cards that contain text.

## 2. Discount badge
- **Computed from data, not typed by hand:** `((old - new) / old * 100).floor()`. Show "-40%" for a single item, "Up to 50%" when the range differs (the word "Up to" is **mandatory**), and "Flat 30%" for a store-wide flat discount.
  - For BOGO and bundles, show text ("Buy 1 Get 1", "2 for Rs 999") instead of a percentage.
- **Style:** Mirch 500 fill with a white **bold** label (4.71:1, so bold is required at small sizes), radius 8, min height 24dp (it isn't a target), and tabular figures.
- **One badge per card.** Don't stack "HOT", "NEW" and "-40%". Freshness and Featured are separate, quieter chips.
- **Never inflate.** If the old price isn't verifiable, show no struck price and no percentage, just the offer text.
  - Pakistan's Competition Act prohibits deceptive marketing (verify this with counsel), and fake discounts destroy trust faster than anything else in a deals app.

## 3. Expiry and countdowns

| Remaining | Display (en / ur) | Notes |
|---|---|---|
| > 7 days or no end | "Ends 15 Nov" / "15 نومبر تک" | Plain date in Asia/Karachi |
| 24h – 7d | "Ends in 3 days" | Plural ICU message |
| 1h – 24h | "Ends in 5h 12m" + clock icon in the warning colour | Updates every minute |
| < 1h | "Ends in 12:33" (mm:ss) | Updates every second **only while visible**. Stop the ticker with `TickerMode` or a visibility check |
| Expired | "Expired" chip; image desaturated | Removed from feeds; still reachable from saved items and deep links, with "similar live deals" |
| Not started | "Starts Fri 7 PM" | Lets people "Remind me" (local notification) |

- **The server is the clock.** Compute `endsAt` server-side, and correct device clock skew using the server time from the response header.
- **Semantics** for a live countdown: give a coarse label ("Ends in about 12 minutes") and exclude the per-second text from semantics, or TalkBack chatters.
- **Reduce motion:** no flip or pulse animations. The text just updates.
- **No fake urgency.** Don't show countdowns that reset, or "Only 2 left" without real stock data. Dark patterns are both a policy and a trust risk.

## 4. Trust signals
- **Freshness:** "Verified 3h ago". Tap it for a sheet: who verified it (our team, the brand, a user report, an automated check of the brand site), when, and the source link.
  - Turn the chip to the warning colour when it's older than 72h ("Last checked 4 days ago").
- **Official badge** for brand-claimed businesses ("Official", with a checkmark icon *and* text).
- **Community signals:** "Worked for 23 people", and "Reported not working 3× today", which shows a warning banner with [Report] and [Still works].
  - The report flow is 2 taps with optional reasons (expired, wrong price, location closed, other) and gives a "Thanks" confirmation. It's rate-limited server-side.
- **Terms are always visible** for bank offers (cap, days, min spend, card types) as a summary, with full T&Cs one tap away and a link to the bank source.
- **Location:** outlet address, distance (only when location is granted) and a [Directions] button (`url_launcher` geo URI).

## 5. Sponsored and Featured content (disclosure)
- Label every paid placement **"Featured"** (Urdu: "نمایاں") with a text chip. It's in Haldi with dark text (11:1) so it's visibly distinct from editorial content.
- The label appears on the card, in the deal detail header, in the semantics label, in search results, and in push notification text ("Featured · Khaadi …").
- **Placement rules:** at most 1 Featured item per 5 feed items, never in position 1 of search results unless it's also relevant to the query, and never disguised as a "Trending" or "Verified" signal.
- In Settings → "Why am I seeing this?", explain that Featured placements are paid and how ranking works.
- AdMob native ads (if used later) carry the ad-network label as their policy requires, plus our "Ad" chip. They must never imitate a deal card's discount badge.

## 6. Search UX
- **Entry:** a search field at the top of Home (it's a tap target, opening a dedicated search route), plus the Explore tab.
- **Before typing:** recent searches (removable), trending in your city, and category shortcuts.
- **While typing:**
  - Debounce by 300ms and cancel stale requests (Riverpod: `ref.onDispose` cancels the request; use `CancelToken` or drop late results).
  - Show suggestions in groups: brands, categories and deals.
  - Highlight matches with bold, not colour alone.
- **Tolerance:** search Roman Urdu and English synonyms ("joote" → shoes, "khana" → food) and typos (server-side `pg_trgm`). Never send the query to analytics with PII.
- **Results:**
  - Show the result count, active filters as chips, and the sort.
  - A zero-result page shows alternatives: the corrected spelling, broader categories, and "Follow this brand to get alerts" when the query matches a brand that has no live deals.
- **Keyboard:** `textInputAction: TextInputAction.search`. Clearing keeps focus. Back closes search before leaving the screen.

## 7. Filter UX
- **Facets:** city/area, category, bank or card (from "My cards"), discount ≥ (20/30/50%), ends within (today, this week), distance (needs location), online or in-store, and price range for shopping categories.
- Use a **bottom sheet** with sections, a sticky footer [Clear] + [Show 128 deals] with a live count, and a debounced count query.
- **Applied filters** show as removable `InputChip`s in a horizontally scrolling row. The row mirrors in RTL, and each chip has a 48dp target and a "Remove filter X" label.
- **Persistence:** filters persist per tab for the session. Preferred city and cards persist across sessions.
- **Sort:** Relevance (default for search), Newest (default for the feed), Ending soon, Biggest discount, and Nearest (hidden without location).

## 8. Feeds, pagination and refresh
- Home is a sliver feed in this order: personalized → "For your cards" → trending in city → categories → "Ending soon".
- **Pagination:**
  - Use cursor pagination ordered by (`score desc, id`), fetch page size 20, and prefetch when the user is 5 items from the end.
  - Footer states are: loading spinner, error with [Retry], and the end ("You're all caught up").
- **Pull to refresh** keeps the scroll position. New items arriving above show a "3 new deals ↑" pill, because the list never jumps under the user's thumb.
- **Offline:** show the cached feed with "Updated 2h ago" and an offline banner. Disable "Nearest" and the filter count, and say why.

## Sources
- `docs/ux/UX_ARCHITECTURE.md` §3 (deal card content priority) and §5 (notification taxonomy)
- [Apple HIG: Notifications](https://developer.apple.com/design/human-interface-guidelines/notifications) (no marketing disguised as alerts, avoid duplicates)
- [WCAG 2.2: 1.4.1 Use of Color](https://www.w3.org/TR/WCAG22/#use-of-color), [4.1.3 Status Messages](https://www.w3.org/TR/WCAG22/#status-messages), [2.2.2 Pause, Stop, Hide](https://www.w3.org/TR/WCAG22/#pause-stop-hide) (read through the w3c/wcag source)
- `design/tokens/contrast-report.md` (Mirch 4.71:1 and Haldi/Featured 11.04:1 ratios)
- Not fetched (hosts blocked): NN/g e-commerce and filter research, and the Baymard Institute. The rules above follow the primary platform guidance and should be re-checked against NN/g when it's reachable.
