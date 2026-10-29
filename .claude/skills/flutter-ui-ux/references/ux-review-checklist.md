# UX review checklist (per screen or widget)

Copy it into the PR description or the QA report and tick each item. "N/A" needs a reason.

## Layout and responsiveness
- [ ] Works at 360×800 (small Android), 412×915 (common) and 600dp+ (tablet or portal). No horizontal scroll except intentional carousels.
- [ ] Respects safe areas and edge-to-edge: content is not under the status bar or gesture bar, and the FAB and bottom nav are clear of the gesture area.
- [ ] Uses spacing tokens (4/8dp grid) and no magic numbers. Gutters are 16dp (compact) and 24dp (medium).
- [ ] Uses directional geometry only (`EdgeInsetsDirectional`, `AlignmentDirectional`, `start`/`end`).
- [ ] Lists are slivers or builders; nothing builds 100+ children eagerly.

## Text
- [ ] 200% text: nothing overflows or clips, and the layout reflows (wrap, scroll, stack).
- [ ] Every string comes from the ARB files (`en` + `ur`), and there are no concatenated sentences.
- [ ] Urdu Nastaliq isn't clipped (chips, buttons, badges, tabs, app bar titles) and has enough line height.
- [ ] Prices, dates and counts are formatted per locale. Codes, phones and URLs are forced LTR.

## RTL
- [ ] Directional icons flip; logos, the checkmark, clocks, media controls and digit order don't.
- [ ] Sliders, progress and carousels run from the start edge. Swipe actions are mirrored.
- [ ] Mixed-direction strings are isolated (FSI/PDI) where they contain brand names, numbers or %.

## Accessibility
- [ ] Every tappable is ≥48dp, ≥8dp from its neighbours, and labelled (tooltip or semantics label, in both languages).
- [ ] Composite widgets are merged; decorative images are excluded; headings are marked.
- [ ] TalkBack reading order and focus order are logical in LTR *and* RTL. Focus is never hidden behind sticky bars (web).
- [ ] Contrast: text 4.5:1, large text 3:1, UI and focus 3:1, in light, dark and high-contrast.
- [ ] Colour is never the only signal (expired, ending soon, errors, selected).
- [ ] Reduce motion: no parallax, auto-advance, shimmer sweep or pulsing. State changes are still clear.
- [ ] Status messages (saved, offline, errors) use live regions.
- [ ] No drag-only interaction; every swipe has a button alternative.
- [ ] Forms: labels are visible (not placeholder-only), errors show text plus an icon and are announced, autofill hints are set, and OTP paste works.

## States
- [ ] Loading: a skeleton matching the final layout (for 1–10s), and no flash for fast loads.
- [ ] Empty: one sentence + one action, with distinct copy for "no data" and "no results for filters".
- [ ] Error: plain language + [Retry], with cached content kept visible where possible.
- [ ] Offline: banner + cached data + "Updated X ago". Network-only actions are disabled with a reason.
- [ ] Pull to refresh on feeds. Infinite scroll has footer loading, error and end states.
- [ ] Optimistic actions (save, follow) roll back with a message on failure.

## Permissions and notifications
- [ ] No system permission dialog without an in-context priming screen first.
- [ ] The feature works, or degrades gracefully, when permission is denied. A permanent denial links to settings.
- [ ] Location asks for approximate first, never background; manual city selection exists.
- [ ] Notification topics, frequency (Low/Normal/High) and quiet hours are user-controllable; each topic has an Android channel.
- [ ] Notification taps deep-link to the exact content with a sane back stack; expired targets are handled.

## Deals and trust
- [ ] The discount number is computed from data; "Up to" is shown when it's a range; one badge per card.
- [ ] Expiry is correct in Asia/Karachi; the live countdown runs only when visible and has a coarse semantics label.
- [ ] Freshness ("Verified X ago") and its source are visible; stale deals are flagged.
- [ ] Sponsored items carry a visible "Featured" text label in the UI, semantics, search and push, with at most 1 per 5 feed items.
- [ ] No fake urgency, scarcity or resetting timers.

## Theme
- [ ] Light and dark both look intentional; logos sit on plates in dark mode; images are dimmed slightly.
- [ ] Only theme roles and extensions are used (no hex in widgets); component themes are respected.
- [ ] Material 3 Expressive isn't enabled (still under development in material_ui 1.8).

## Performance feel
- [ ] First meaningful content in under 1s from cache, with feedback within ~100–400ms of every tap.
- [ ] No jank when scrolling the feed (profile mode, DevTools frame chart).
- [ ] Images are sized (`memCacheWidth`/`cacheWidth`) and cached; no layout shift when they load.
