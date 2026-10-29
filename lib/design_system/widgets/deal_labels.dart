import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/deal_time_labels.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/models/deal_offer.dart';
import 'package:sale_lagi_hai/design_system/theme/deal_colors.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/content_text.dart';

/// The text of a [DealOffer] in the current language ("-40%", "Up to 50%
/// off", "Flat 30% off", "Buy 1 Get 1").
String dealOfferText(BuildContext context, DealOffer offer) {
  final l10n = context.l10n;
  return switch (offer) {
    PercentOff(:final percent) => AppFormatters.of(context).discount(percent),
    UpToPercentOff(:final percent) => l10n.upToPercentOff(percent),
    FlatPercentOff(:final percent) => l10n.flatPercentOff(percent),
    TextOffer(:final label) => label,
  };
}

/// The one discount badge a deal card carries: Mirch fill, bold label.
class DiscountBadge extends StatelessWidget {
  const new({required this.offer, super.key});

  final DealOffer offer;

  @override
  Widget build(BuildContext context) {
    final colors = DealColors.of(context);
    final text = dealOfferText(context, offer);
    // A bare percentage uses the brand's display figures; worded offers use
    // the UI type so Urdu renders in Urdu type.
    final style = offer is PercentOff
        ? BrandTypography.badge
        : Theme.of(context).textTheme.labelLarge!
              .copyWith(fontWeight: FontWeight.w700);
    return _Pill(
      color: colors.deal,
      // A worded offer is brand content and may be in either language.
      child: offer is TextOffer
          ? ContentText(text, style: style.copyWith(color: colors.onDeal))
          : Text(text, style: style.copyWith(color: colors.onDeal)),
    );
  }
}

/// Marks a paid placement. Every sponsored deal shows it.
class FeaturedLabel extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = DealColors.of(context);
    return _Pill(
      color: colors.featured,
      child: Text(
        context.l10n.featuredLabel,
        style: Theme.of(context).textTheme.labelMedium!
            .copyWith(color: colors.onFeatured),
      ),
    );
  }
}

/// A bank card the offer applies to, e.g. "HBL".
class CardNameChip extends StatelessWidget {
  const new({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BrandSpacing.s3,
        vertical: BrandSpacing.s1,
      ),
      decoration: BoxDecoration(
        borderRadius: BrandRadii.badge,
        border: Border.all(color: scheme.outline),
      ),
      child: Text(
        name,
        style: Theme.of(context).textTheme.labelMedium!
            .copyWith(color: scheme.onSurface),
      ),
    );
  }
}

/// "Ends in 2 days" with a clock icon: never colour alone. Under a day it
/// turns the warning colour and refreshes every minute; past the end it
/// reads "Expired".
class ExpiryTag extends ConsumerStatefulWidget {
  const new({required this.endsAt, super.key});

  final DateTime? endsAt;

  @override
  ConsumerState<ExpiryTag> createState() => _ExpiryTagState();
}

class _ExpiryTagState extends ConsumerState<ExpiryTag> {
  Timer? _timer;

  static const urgentWindow = Duration(hours: 24);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(ExpiryTag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final endsAt = widget.endsAt;
    if (endsAt == null) return;
    final remaining = endsAt.difference(ref.read(clockProvider)());
    if (remaining > Duration.zero && remaining <= urgentWindow) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider)();
    final endsAt = widget.endsAt;
    final labels = DealTimeLabels(context.l10n, AppFormatters.of(context));
    final text = labels.expiry(endsAt, now: now);
    final scheme = Theme.of(context).colorScheme;
    final remaining = endsAt?.difference(now);
    final expired = remaining != null && remaining <= Duration.zero;
    final urgent = !expired && remaining != null && remaining <= urgentWindow;
    final color = urgent
        ? DealColors.of(context).warning
        : scheme.onSurfaceVariant;
    return _IconLabel(
      icon: expired ? Icons.timer_off_outlined : Icons.schedule,
      text: text,
      color: color,
    );
  }
}

/// "Verified 3 hours ago" with a check icon; older than 3 days it turns the
/// warning colour, because the deal may have changed.
class VerifiedTag extends ConsumerWidget {
  const new({required this.verifiedAt, super.key});

  final DateTime verifiedAt;

  static const staleAfter = Duration(days: 3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final labels = DealTimeLabels(context.l10n, AppFormatters.of(context));
    final stale = now.difference(verifiedAt) > staleAfter;
    return _IconLabel(
      icon: stale ? Icons.history : Icons.verified_outlined,
      text: labels.verified(verifiedAt, now: now),
      color: stale
          ? DealColors.of(context).warning
          : Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}

class _IconLabel extends StatelessWidget {
  const new({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(color: color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: BrandSpacing.s2),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const new({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 24),
    padding: const EdgeInsetsDirectional.symmetric(
      horizontal: BrandSpacing.s3,
      vertical: BrandSpacing.s1,
    ),
    decoration: BoxDecoration(color: color, borderRadius: BrandRadii.button),
    child: child,
  );
}
