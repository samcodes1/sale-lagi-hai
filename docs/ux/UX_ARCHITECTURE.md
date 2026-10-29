# UX Architecture — Phase 0.3

The consumer app's structure: navigation, screens, flows and notifications. Visual design follows `design/BRAND_GUIDELINES.md` and the `flutter-ui-ux` skill.

---

## 1. Navigation (information architecture)

Bottom navigation with five tabs. Labels are always visible, never icons alone.

| Tab | EN label | UR label | Purpose |
|---|---|---|---|
| 1 | Home | ہوم | Personal feed: Trending Today, For You, Near Me, Ending Soon |
| 2 | Explore | تلاش | Categories, brands, banks and cards, search |
| 3 | Alerts | الرٹس | Notification inbox and followed brands/stores |
| 4 | Saved | محفوظ | Saved deals, with expiry warnings |
| 5 | Profile | پروفائل | My Cards, city, language, settings, account |

```
Home ─┬─ Deal detail ─┬─ Outlet list / map
      │               ├─ Brand / business page
      │               └─ Share sheet (WhatsApp first)
      ├─ Section "See all" (Trending, Near me, Ending soon)
      └─ City switcher (sheet)
Explore ─┬─ Search (suggestions, recent, results + filters)
         ├─ Category page ── sub-filters ── Deal detail
         ├─ Brand directory ── Brand page ── Deal detail
         └─ Banks ── Bank page ── Card offers
Alerts ─┬─ Inbox (grouped by day) ── Deal detail
        └─ Following (brands, businesses, categories) ── manage
Saved ── Saved list (active / expired) ── Deal detail
Profile ─┬─ My Cards (pick bank + card type)
         ├─ City & areas
         ├─ Notification settings (per topic, quiet hours, daily cap)
         ├─ Language (English / اردو) · Theme
         ├─ Account (sign in to sync / delete account)
         ├─ For businesses → opens business portal
         └─ Help · Report a problem · Privacy · Terms · About
```

### Deep links (Phase 5.3)
`/deal/<id>` · `/brand/<slug>` · `/business/<slug>` · `/category/<slug>` · `/city/<slug>` · `/search?q=` · `/alerts`

---

## 2. Screen inventory

Every screen must define all of its states. "Offline" means the screen shows cached data with a banner; it is never a blank screen.

| # | Screen | Key content | Loading | Empty | Error | Offline |
|---|---|---|---|---|---|---|
| S01 | Splash | Logo (Android 12 splash API) | — | — | Config error screen | Continue with cache |
| S02 | Language | English / اردو cards, previewing the UI direction | — | — | — | Works |
| S03 | City | Auto-detect button + searchable list | Detecting… | No match → "Request your city" | Location denied → list | Bundled city list |
| S04 | Interests | Category chips (pick 3+) | Skeleton chips | — | Retry | Bundled categories |
| S05 | Favourite brands | Brand logo grid with search | Skeleton grid | — | Retry | Skip allowed |
| S06 | Notification priming | Shows the value ("Know the moment Khaadi's sale starts") → system prompt | — | — | Denied → explain how to enable later | — |
| S07 | Home | Featured carousel (labelled), Trending Today, For You, Near Me, Ending Soon | Skeleton sections | New city → "We're adding deals in X" + nationwide deals | Inline retry per section | Cached feed + banner |
| S08 | Deal detail | Images, title, discount, validity, terms, "Verified X ago", source, outlets, Save, Share, Report | Skeleton | — | Not found / expired state | Cached copy |
| S09 | Brand / business page | Logo, follow button, active deals, outlets, about | Skeleton | "No active deals. Follow to get alerted" | Retry | Cached |
| S10 | Category page | Filter chips, sort, deal list | Skeleton | "No deals right now", suggest related | Retry | Cached |
| S11 | Search | Recent, trending searches, suggestions, results tabs (Deals / Brands / Places) | Inline spinner | "No results for X" + suggestions | Retry | Recent only + banner |
| S12 | Filters sheet | City, area, category, bank/card, min discount, ending soon, open now | — | — | — | Works |
| S13 | Banks | Bank list → card offers | Skeleton | — | Retry | Cached |
| S14 | My Cards | Bank picker → card type picker (Visa Platinum, etc.). **No card numbers, ever** | — | "Add your cards to see your discounts" | — | Works (local + sync) |
| S15 | Alerts inbox | Grouped notifications, unread marker | Skeleton | "No alerts yet. Follow brands to get alerts" | Retry | Cached |
| S16 | Following | Followed brands, businesses and categories, with toggles | Skeleton | Suggest popular brands | Retry | Cached |
| S17 | Saved | Active / Expired tabs, "ends in 2 days" chips | Skeleton | "Save deals to find them here" | Retry | Local copy |
| S18 | Profile & settings | Sections as in the tree above | — | — | — | Works |
| S19 | Notification settings | Topic toggles, quiet hours, max per day | — | — | Save failed → revert + toast | Queued |
| S20 | Sign in | Phone OTP (+92 prefilled), Google | Button spinner | — | Wrong code, rate limited | Disabled with banner |
| S21 | Delete account | Explains what's deleted → confirm | Spinner | — | Retry | Disabled |
| S22 | Report deal | Reasons: expired, wrong price, spam, other | Spinner | — | Retry | Queued |
| S23 | Submit a deal | Photo or link + business + details | Upload progress | — | Retry | Saved as draft |
| S24 | Widget gallery (dev only) | Every design-system widget in every state | — | — | — | — |

---

## 3. Deal card: content priority

What the eye should read first, in order:
1. **Discount**: "40% OFF", "Rs 999 deal", "Buy 1 Get 1". It's the biggest element and uses the "hot" accent.
2. **Who**: brand or business logo and name.
3. **What**: a one-line title, e.g. "Winter collection".
4. **When**: "Ends in 2 days", "Ends today" (urgent styling) or "Ongoing".
5. **Trust**: "Verified 3h ago", plus a bank/card chip if relevant.
6. **Where**: "DHA · 1.2 km", "Online" or "All Pakistan".
7. **Actions**: Save (icon button with a label for screen readers). Share is on the detail page.

Variants: **Large** (feed hero), **Standard** (lists), **Compact** (horizontal carousels), **Card-offer** (bank discount, with the bank logo first).
Featured placements use the same card with a visible **"Featured"** label. Never disguise a paid placement as a normal deal.

---

## 4. Key user flows

### F1: First launch (target under 60 seconds, every step except language skippable)
Splash → Language → City (auto-detect or pick) → Interests → Favourite brands → Notification priming → Home.
- Location: ask only when the user taps "Detect my city". Never prompt on launch.
- Notifications: the system prompt appears only after the priming screen's "Turn on alerts" button.
- No sign-in required. The app is guest-first.

### F2: Find a deal → use it
Home/Explore → Deal card → Detail → (outlets / map / source link) → Save or Share to WhatsApp.

### F3: Follow a brand → get an alert
Brand page → Follow → (if notifications are off: priming sheet) → later, push "🔔 Sale Lagi Hai! Sapphire up to 40% off" → tap → deal detail via deep link.

### F4: My cards → card discounts
Profile → My Cards → pick bank → pick card type → Home shows "For your cards" section and a card chip on matching deals.

### F5: Report an expired deal
Deal detail → "Report" → reason → thanks toast. The deal is flagged for moderators; after N reports it is auto-hidden pending review.

### F6: Sign in to sync (optional)
Any sync-worthy action (saving the 5th deal, following, changing settings) → soft prompt "Sign in to keep your saves on any phone" → phone OTP or Google → local data merges into the account.

### F7: Delete account (Play requirement)
Profile → Account → Delete → explanation of what's deleted → confirm → signed out, local data cleared. A web URL for deletion requests is also published for the Play listing.

### F8: Business owner → portal
Profile → "For businesses" → opens the web business portal (Phase 6). The consumer app stays focused on shoppers.

---

## 5. Notification taxonomy

| Type | Trigger | Default | Android channel | Example (Roman Urdu style) |
|---|---|---|---|---|
| Brand sale live | A followed brand starts a sale | On | `brand_sales` (high) | 🔔 Sale Lagi Hai! Khaadi up to 50% off |
| New deal from a followed place | A followed business posts a deal | On | `followed_places` | Kolachi: new weekday deal Rs 1,499 |
| Saved deal ending | Saved deal ends in 24h | On | `reminders` | Your saved deal ends tomorrow ⏰ |
| Card deal | A new offer for one of the user's cards | On | `card_deals` | HBL card: 20% off at Burger Lab |
| Daily digest | Once a day, at the user's chosen time | Off | `digest` (low) | Aaj ke top 5 deals 🔥 |
| Featured / campaign | A paid push campaign (admin-approved) | On, capped | `promotions` (default) | Labelled "Featured" |

Rules:
- A **daily cap** (default 5, user-adjustable). Featured pushes count toward the cap and are limited to at most 1 per day.
- **Quiet hours** default to 11pm–8am Pakistan time.
- **One channel per type**, so users can turn off types in Android settings too.
- Every push deep-links to the exact content, never just to Home.

---

## 6. Content rules
- **Language:** the UI follows the chosen language. Brand names stay as brands write them. Prices use "Rs 1,499", with Urdu numerals available as an option.
- **Tone:** friendly and direct, in the brand voice (`design/BRAND_STRATEGY.md`). Short sentences, no hype words like "AMAZING!!!".
- **Trust:** every deal shows its source and when it was last verified. Expired deals are removed automatically, never left showing as active.
- **Sponsored content** is always labelled "Featured" (EN) / "نمایاں" (UR).
