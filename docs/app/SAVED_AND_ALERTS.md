# Saved and the alerts inbox (sub-phase 4.8)

## Saved (screen S17, the Saved tab)
- **Active (n)** and **Ended (n)** split the saved deals, newest saved first. "Ended" is relative to the app clock.
- Each card has its own bookmark: unsave shows "Removed from saved" with **Undo**. The Ended view also has **Remove ended deals**.
- **Gone deals** (removed, or hidden by moderation) are summed up once: "2 saved deals are no longer available." with **Remove them**.
- **Data:** `savedViewProvider` reads the saved ids through `DealRepository.byIds` (`deal_cards`, 100 ids a request). Ended deals are still readable there; gone ones are simply missing.
- **Offline:** the last copy (`JsonCache` `saved.deals`, up to 7 days) with the offline banner and its age. Nothing is called gone offline. With no copy, the error view with Try again.
- Pull to refresh reloads. The list itself is `savedDealsProvider` (see DEAL_PAGE.md).

## Alerts (screen S15, the Alerts tab)
- **Following** sits at the top ("1 brand · 2 categories") and opens the Following list (S16, `/following`): followed brands and categories, each opening its page, each with its Follow button to stop. Empty: a nudge to Explore.
- **Guests** see "Sign in to get alerts here…" with Sign in. Alerts are written per account by the dispatcher (2.5), so a guest has no inbox; follows still work.
- **Signed in:** the inbox, newest first, grouped **Today** and **Earlier**, 30 at a time (the next page loads at the end, with a retry row on failure).
  - Unread alerts are bold, tinted, have a dot, and say "Unread" to screen readers (not colour alone).
  - Tapping marks the alert read (at once, then on the server) and opens its deal.
  - **Mark all as read** shows while any is unread.
  - Times read "Just now", "5 min ago", "3 h ago", "Yesterday", then the date.
- **The badge** on the Alerts tab counts unread alerts that came after the tab was last opened (`alerts.seen_at.v1` on the phone; `unread_alert_count(since)`), shown as "99+" past 99. Opening the tab clears it; the unread marks stay until read. Screen readers hear it with the tab ("Alerts, 2 new alerts").

## Changed after the 4.8 QA gate (FAIL: BUG-1)
- **BUG-1 (S2), a shared phone:** the phone notes which account its saved deals, cards and follows belong to (`account.on_phone.v1`, the last account that signed in).
  - When the same account, or a first account, signs in, the phone's lists go into it, as before.
  - When another account signs in, the phone's lists are dropped, never sent, and that account's own come in. An unreadable note counts as another account's.
  - So nothing one person saved, or which bank cards they hold, ever goes into someone else's account.
  - **Signing out (round 2, BUG-9):** Sign out first sends the phone's saved deals, cards and follows into the account (one call each), then removes them and the note from the phone. The next person sees none of them, and what they save as a guest goes into their own account when they sign in.
    - If the lists can't be sent (offline), they stay on the phone rather than be lost. The note still keeps them out of any other account, and the same account sends them at its next sign-in.
    - A session that ends on its own (not through Sign out) leaves the lists in the same way.
- **BUG-3 (S3):** guest saves and cards go up in one call, `sync_guest_items(deal_ids, card_product_ids)` (`20261029270000_guest_items.sql`), instead of one request each. At most 500 and 20. Only deals the caller can see and active card products are added; ones already in the account are skipped.
- **BUG-2 (S3):** "Remove ended deals" and "Remove them" delete from the account too (`SavedDeals.removeAll`).
- **BUG-4 (S4):** an alert read while the next page loads stays read.
- **BUG-5 (S4):** entering the Alerts tab clears its badge every time, by a tap or a link (the shell does it, since it keeps the tab's state).
  - The seen time is the later of the phone's clock and the newest alert's server time, so a phone clock running behind doesn't keep the badge.
- **BUG-6 (S4):** Undo puts the deal back where it was.
- **BUG-8 (S4):** screen readers hear the badge with the tab ("Alerts, 2 new alerts"; past 99, "More than 99 new alerts").
- **BUG-10 (S4):** the generated Urdu strings are regenerated.
- **Open:** BUG-7 (S4). A followed brand or category that was switched off is counted, but not listed, so it can't be unfollowed.

## Backend (`20261029240000_inbox.sql`)
- `mark_alerts_read(ids)` and `unread_alert_count(since)`, security invoker, signed-in only. Marking touches only `read_at` of the caller's rows, as the column grant and policy already require.

## Code
- `lib/features/saved/application/saved_view.dart`; `presentation/saved_screen.dart`.
- `lib/features/alerts/`: `AppAlert` and `AlertKind`; `inboxProvider` (`Inbox`: load, page, mark read); `alertsBadgeProvider`, `markAlertsSeen`; `AlertsScreen`.
- `lib/features/follows/`: `followedBrandsProvider`, `FollowingScreen`.
- `CatalogRepository.brandsByIds`, `DealRepository.byIds`, `DealTimeLabels.received`; `dealCardFor(onSaveToggle:)`.
- Demo backend: three demo alerts (two unread) and both RPCs.

## Tests
- `test/features/inbox/saved_and_alerts_test.dart`:
  - the Saved view (on, ended, gone, in order; offline copy; no copy);
  - the inbox (guest; signed in: order, read one, read all, the badge); alert rows;
  - the pull at sign-in; the time labels;
  - the screens: Saved (Undo, gone deals, empty), Alerts as a guest and signed in (badge, unread, open, mark all), Following;
  - guidelines and 200% text in en and ur for Saved, Alerts and Following.
- `supabase/tests/database/850_inbox.test.sql`: counts, since, marking one or all, others' rows untouched, guests refused.
