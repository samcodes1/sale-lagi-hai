# Exploratory test charters

Format (session-based testing): **Explore** <target> **with** <resources/techniques> **to discover** <risk>. Time-box each to 20–45 minutes. Record your notes, the bugs and the coverage in the report. Pick 2–3 per sub-phase that touch what changed, and run more at the phase gate.

## Inputs and data
1. **Explore** search and filters **with** empty, 1-character, 500-character, emoji, Urdu, Roman Urdu, mixed `Khaadi سیل 50%` and SQL/HTML-looking input (`' OR 1=1 --`, `<script>`) **to discover** crashes, injection, broken highlighting and bad zero-result states.
2. **Explore** deal rendering **with** extreme data: a 0% discount, 100%, old price < new price, a null image, a 200-character title, `ends_at` in the past, now, 30 seconds away and 5 years away, and a missing city **to discover** wrong badges, negative countdowns, overflow and "Up to" misuse.
3. **Explore** price and number formatting **with** `en` and `ur`, Western and Urdu digits, values like 999, 1,000, 12,34,567 and 0 **to discover** bidi flips ("%50"), wrong separators and digit order.

## Network and state
4. **Explore** the feed and deal pages **with** airplane mode toggled mid-load, a slow network (DevTools throttling on the web build), and server 500s and 429s (fake gateway) **to discover** missing offline, error and retry states, infinite spinners and lost scroll position.
5. **Explore** save, follow and report **with** rapid repeated taps, double submission, going back mid-request, and killing the app mid-request **to discover** duplicate rows, optimistic UI not rolling back, and disposed-notifier crashes (`ref.mounted`).
6. **Explore** auth **with** an expired session, signing out in another tab (portal), a deleted account still holding a token, and switching user **to discover** stale data shown to the wrong user, redirect loops and cache leakage across accounts.

## Platform and navigation
7. **Explore** deep links and push taps **with** valid, expired, malformed and foreign-host links on a cold start, a warm start and while signed out **to discover** wrong routing, broken back stacks, crashes and error screens that echo input.
8. **Explore** permission flows **with** deny, "don't ask again", approximate-only location and notifications disabled in system settings **to discover** dead ends, re-prompt loops and features that break without permission.
9. **Explore** lifecycle **with** rotation (if not locked), split-screen, background/foreground with a running countdown, and system font or theme changes while the app is open **to discover** state loss, timers leaking in the background and theme glitches.

## Accessibility and locale
10. **Explore** the core flows **with** TalkBack (or the web semantics overlay `FLUTTER_WEB_DEBUG_SHOW_SEMANTICS=true`) in Urdu **to discover** unlabeled controls, English labels in Urdu UI, wrong reading order in RTL and chatty countdowns.
11. **Explore** every screen **with** 200% text + Urdu + dark mode + a 360dp width combined **to discover** Nastaliq clipping, overflow and contrast failures.

## Abuse and security (backend phases)
12. **Explore** submissions and reports **with** scripted bursts (the SQL harness, or a curl loop against local Supabase), forged `reporter_id` and `business_id` values, and oversized payloads **to discover** missing rate limits, RLS gaps and validation holes.
13. **Explore** storage uploads **with** wrong MIME types, oversized files, path traversal in file names (`../`), and uploads into another user's or business's folder **to discover** policy gaps.
14. **Explore** Featured placements **with** a feed of 30 items, search queries and pushes **to discover** unlabeled sponsored content or exceeded placement caps.

## Session note template
```
Charter: <#> <text>
Tester / date / commit / build (flavor, web|android, viewport, locale, theme, text scale)
Duration: 30 min   Coverage: <screens/paths touched>
Notes: <what was tried, what was observed>
Bugs: BUG-<n> (S?) …
Questions / follow-ups: …
```
