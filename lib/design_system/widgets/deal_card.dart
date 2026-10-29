import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/deal_time_labels.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/models/deal_card_data.dart';
import 'package:sale_lagi_hai/design_system/theme/accent_primary.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/content_text.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_labels.dart';
import 'package:sale_lagi_hai/design_system/widgets/price_text.dart';

enum DealCardSize {
  /// Home carousel hero: big image and price.
  large,

  /// Feed and list cards.
  standard,

  /// Search results and carousels: a thumbnail row.
  compact,
}

/// The deal card (UX_ARCHITECTURE §3, flutter-ui-ux deal patterns).
///
/// - The whole card is one tap target. Save is a separate 48dp button.
/// - Screen readers hear one sentence: brand, offer, price, expiry,
///   freshness, place, cards, and "Featured" for paid placements. Save is
///   also a custom action on that node.
/// - It grows with long Urdu text and large text sizes; nothing is clipped,
///   so feeds must not give cards a fixed height.
class DealCard extends ConsumerWidget {
  const new({
    required this.deal,
    required this.onTap,
    this.onSaveToggle,
    this.size = DealCardSize.standard,
    super.key,
  });

  final DealCardData deal;
  final VoidCallback onTap;

  /// Shows the save button when set.
  final VoidCallback? onSaveToggle;
  final DealCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = _summary(context, ref.watch(clockProvider)());
    final saveLabel = deal.saved ? l10n.actionUnsave : l10n.actionSave;

    final content = switch (size) {
      DealCardSize.compact => _CompactBody(deal: deal),
      DealCardSize.large || DealCardSize.standard => _FullBody(
        deal: deal,
        large: size == DealCardSize.large,
      ),
    };

    return Card(
      child: Stack(
        children: [
          Semantics(
            container: true,
            button: true,
            label: summary,
            // ExcludeSemantics below drops the InkWell's own tap action, so
            // the merged node needs it (screen readers open the deal).
            onTap: onTap,
            customSemanticsActions: {
              CustomSemanticsAction(label: saveLabel): ?onSaveToggle,
            },
            child: ExcludeSemantics(
              child: InkWell(onTap: onTap, child: content),
            ),
          ),
          if (onSaveToggle != null)
            PositionedDirectional(
              top: size == DealCardSize.compact ? 0 : BrandSpacing.s2,
              end: 0,
              child: _SaveButton(
                saved: deal.saved,
                label: saveLabel,
                onPressed: onSaveToggle!,
                onImage: size != DealCardSize.compact,
              ),
            ),
        ],
      ),
    );
  }

  String _summary(BuildContext context, DateTime now) {
    final l10n = context.l10n;
    final format = AppFormatters.of(context);
    final times = DealTimeLabels(l10n, format);
    final price = deal.price;
    final oldPrice = deal.oldPrice;
    return [
      deal.brandName,
      deal.title,
      if (deal.offer case final offer?) dealOfferText(context, offer),
      if (price != null && oldPrice != null && oldPrice > price)
        format.priceChange(was: oldPrice, now: price)
      else if (price != null)
        format.price(price),
      if (deal.endsAt != null) times.expiry(deal.endsAt, now: now),
      if (deal.verifiedAt case final verified?)
        times.verified(verified, now: now),
      ?deal.place,
      if (deal.cardNames.isNotEmpty) deal.cardNames.join(', '),
      if (deal.featured) l10n.featuredLabel,
    ].join('. ');
  }
}

class _FullBody extends StatelessWidget {
  const new({required this.deal, required this.large});

  final DealCardData deal;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _DealImage(deal: deal),
            ),
            PositionedDirectional(
              start: BrandSpacing.s3,
              top: BrandSpacing.s3,
              end: BrandSpacing.s10 + BrandSpacing.s3,
              child: Wrap(
                spacing: BrandSpacing.s2,
                runSpacing: BrandSpacing.s2,
                children: [
                  if (deal.offer case final offer?) DiscountBadge(offer: offer),
                  if (deal.featured) const FeaturedLabel(),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ContentText(
                deal.brandName,
                style: text.labelLarge!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: BrandSpacing.s1),
              ContentText(
                deal.title,
                style: large ? text.titleLarge : text.titleMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (deal.price case final price?) ...[
                const SizedBox(height: BrandSpacing.s3),
                PriceText(price: price, oldPrice: deal.oldPrice, large: large),
              ],
              const SizedBox(height: BrandSpacing.s3),
              _MetaRow(deal: deal),
              if (deal.cardNames.isNotEmpty) ...[
                const SizedBox(height: BrandSpacing.s3),
                _CardChips(names: deal.cardNames),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactBody extends StatelessWidget {
  const new({required this.deal});

  final DealCardData deal;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s3,
        BrandSpacing.s3,
        BrandSpacing.s10,
        BrandSpacing.s3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BrandRadii.button,
            child: SizedBox.square(
              dimension: 72,
              child: _DealImage(deal: deal),
            ),
          ),
          const SizedBox(width: BrandSpacing.s4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ContentText(
                  deal.brandName,
                  style: text.labelMedium!.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                ContentText(
                  deal.title,
                  style: text.titleSmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: BrandSpacing.s2),
                Wrap(
                  spacing: BrandSpacing.s3,
                  runSpacing: BrandSpacing.s2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (deal.offer case final offer?)
                      DiscountBadge(offer: offer),
                    if (deal.featured) const FeaturedLabel(),
                    if (deal.price case final price?)
                      PriceText(price: price, oldPrice: deal.oldPrice),
                    ExpiryTag(endsAt: deal.endsAt),
                  ],
                ),
                if (deal.cardNames.isNotEmpty) ...[
                  const SizedBox(height: BrandSpacing.s2),
                  _CardChips(names: deal.cardNames),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const new({required this.deal});

  final DealCardData deal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: BrandSpacing.s5,
      runSpacing: BrandSpacing.s2,
      children: [
        ExpiryTag(endsAt: deal.endsAt),
        if (deal.verifiedAt case final verified?)
          VerifiedTag(verifiedAt: verified),
        if (deal.place case final place?)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.place_outlined,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: BrandSpacing.s2),
              Flexible(
                child: ContentText(
                  place,
                  style: Theme.of(context).textTheme.bodySmall!
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _CardChips extends StatelessWidget {
  const new({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: BrandSpacing.s2,
    runSpacing: BrandSpacing.s2,
    children: [for (final name in names) CardNameChip(name: name)],
  );
}

/// The deal photo, or a brand plate with the brand's initial when there is
/// no image or it fails to load. Decorative: the card label carries the
/// meaning.
class _DealImage extends StatelessWidget {
  const new({required this.deal});

  final DealCardData deal;

  @override
  Widget build(BuildContext context) {
    final plate = _BrandPlate(name: deal.brandName);
    final url = deal.imageUrl;
    if (url == null) return plate;
    return Image.network(
      url,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => plate,
    );
  }
}

class _BrandPlate extends StatelessWidget {
  const new({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.isEmpty ? '' : name.characters.first.toUpperCase();
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          initial,
          style: BrandTypography.headline.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const new({
    required this.saved,
    required this.label,
    required this.onPressed,
    required this.onImage,
  });

  final bool saved;
  final String label;
  final VoidCallback onPressed;

  /// On a photo the icon sits on a solid disc so it stays visible.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = IconButton(
      tooltip: label,
      isSelected: saved,
      onPressed: onPressed,
      icon: const Icon(Icons.bookmark_border),
      selectedIcon: const Icon(Icons.bookmark),
      style: onImage
          ? IconButton.styleFrom(
              backgroundColor: scheme.surface,
              foregroundColor: scheme.onSurface,
            )
          : null,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: BrandSpacing.s1),
      // A toggle IconButton paints its selected icon in `primary` (yellow).
      child: AccentPrimary(child: button),
    );
  }
}
