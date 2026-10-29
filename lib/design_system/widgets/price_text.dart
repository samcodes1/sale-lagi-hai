import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// "Rs 1,799  ~~Rs 2,999~~": the new price first, the old one struck.
///
/// A strikethrough is invisible to screen readers, so the semantics label
/// says "was Rs 2,999, now Rs 1,799". The old price is only shown when it
/// is really higher.
class PriceText extends StatelessWidget {
  const new({
    required this.price,
    this.oldPrice,
    this.large = false,
    super.key,
  });

  final int price;
  final int? oldPrice;

  /// Hero cards use the display price size.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final format = AppFormatters.of(context);
    final theme = Theme.of(context);
    final was = oldPrice;
    final showOld = was != null && was > price;
    final priceStyle =
        (large ? BrandTypography.price : theme.textTheme.titleMedium!).copyWith(
          color: theme.colorScheme.onSurface,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: format.price(price), style: priceStyle),
          if (showOld) ...[
            const TextSpan(text: '  '),
            TextSpan(
              text: format.price(was),
              style: theme.textTheme.bodySmall!.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ],
      ),
      semanticsLabel: showOld
          ? format.priceChange(was: was, now: price)
          : format.price(price),
    );
  }
}
