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
