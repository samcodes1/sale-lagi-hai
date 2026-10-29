# Android and Google Play icon reference

Sources: developer.android.com adaptive icons, Google Play icon specification, splash screen, notifications
(URLs in SKILL.md). Re-check them before a release: Google revises these pages.

## Google Play store icon
- 512 × 512 px, 32-bit PNG, sRGB, max 1024 KB.
- Upload a **full square**. Play applies the rounded mask (corner radius = 30% of icon size) and a dynamic shadow.
- Do not add a drop shadow or round the corners yourself. Lighting inside the artwork is allowed.
- Opaque background preferred; transparent areas show Play's UI color.
- Full-bleed background when the logo has no defining outer shape. If the shape matters, keep it on the keyline
  grid (legacy-mode keyline = 75% of canvas = 384 px).
- Policy: no text or graphics for ranking ("#1"), deals or install incentives ("50% off", "free"),
  Play program badges, or anything misleading. **For a deals app this matters: never put a % or "SALE" in the icon.**

## Adaptive launcher icon (API 26+)
| Item | Value |
|---|---|
| Layer canvas | 108 × 108 dp (foreground and background, both required) |
| Reserved margin | 18 dp per side (masking, parallax, pulse) |
| Visible window | up to 72 × 72 dp |
| Safe zone | 66 × 66 dp centred, never clipped by any OEM mask; masks may come as close as 33 dp from centre |
| Logo size | min 48 × 48 dp, max 66 × 66 dp |
| Format | Vector drawable preferred; bitmaps OK |
| Don't | bake masks, outlines or background shadows into layers |

Pixel sizes of the 108 dp canvas: mdpi 108, hdpi 162, xhdpi 216, xxhdpi 324, xxxhdpi 432.

```xml
<!-- res/mipmap-anydpi-v26/ic_launcher.xml -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
```
Manifest: `android:icon="@mipmap/ic_launcher"`, optional `android:roundIcon`.

Numeric safe-zone check: compute the maximum distance of every outline point (and curve control point, which bounds
the curve) from the canvas centre. It must be ≤ 33 dp, aim for ≤ 30 dp.

## Themed (monochrome) icon
- Android 13 (API 33)+, user must enable themed icons, launcher must support it.
- Single-color layer, same 108 dp canvas and 66 dp safe zone. System chooses the tint from wallpaper; only alpha counts.
- Android 16 QPR 2 auto-themes apps without a monochrome layer: ship your own so it looks intended.
- It may share the foreground drawable, but a slightly smaller (≈ 90–92%) dedicated version usually balances better,
  because themed icons sit on a pale or dark disc with less contrast than the brand color.

## Legacy launcher icons (pre-26 fallback)
48 dp: mdpi 48, hdpi 72, xhdpi 96, xxhdpi 144, xxxhdpi 192 px. Provide `ic_launcher` (rounded square) and
`ic_launcher_round` (circle). Keep a ~1 dp transparent margin.

## Notification small icon
- 24 × 24 dp; mdpi 24, hdpi 36, xhdpi 48, xxhdpi 72, xxxhdpi 96 px.
- **White on transparent**. Android draws only the alpha channel and tints it; a colored or opaque icon renders as a
  white square/blob.
- Older Google guidance: 22 dp optical square inside 24 dp. Keep the silhouette within ~20–22 dp.
- No thin details: strokes ≥ 2 dp. Consider an "optical-size" variant of the mark (heavier, simpler).
- `NotificationCompat.Builder.setSmallIcon(R.drawable.ic_stat_x)` (required) + `setColor(accent)`.
- Large icon is for contact photos/images, not the app icon.

## Splash screen (Android 12+ `SplashScreen` API)
| Variant | Canvas | Content must fit |
|---|---|---|
| Icon without icon background | 288 × 288 dp | circle of 192 dp diameter |
| Icon with icon background | 240 × 240 dp | circle of 160 dp diameter |
| Branded image (discouraged) | 200 × 80 dp | |

- Animated icon: AnimatedVectorDrawable, 432 dp area with 288 dp visible; ≤ 1000 ms recommended; start delay ≤ 166 ms.
- `windowSplashScreenBackground` must be one opaque color. Use `values-night-v31` for the dark variant.
- Flutter: the `flutter_native_splash` package or a manual `LaunchTheme` in `values-v31/styles.xml`.

## Review sheet (always produce one)
Home screen with real-looking neighbours on light and dark wallpaper, themed light/dark, the 4 common masks
(circle, squircle, rounded square, teardrop), sizes 96/72/48/36/24/16, and a notification shade with the small icon.
