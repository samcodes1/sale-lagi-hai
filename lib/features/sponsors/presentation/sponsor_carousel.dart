import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/network_picture.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_card_mapper.dart';
import 'package:sale_lagi_hai/features/sponsors/application/sponsor_providers.dart';
import 'package:sale_lagi_hai/features/sponsors/domain/sponsor_banner.dart';

/// How long each banner stays before the next.
const _dwell = Duration(seconds: 5);

/// Room for two lines of title and two of subtitle in Urdu, the tallest
/// script. It grows with large text.
const _copyHeight = 160.0;

/// The sponsors' banners at the top of Home. With none booked, the slot
/// offers itself to advertisers instead (nothing while they load).
class SponsorCarousel extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(sponsorBannersProvider);
    return switch (banners.value) {
      null => const SizedBox.shrink(),
      [] => const _Slot(child: _AdvertiseHere()),
      final list => _Pager(list),
    };
  }
}

/// The banner frame: room for the copy at any text size.
class _Slot extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      BrandSpacing.s5,
      BrandSpacing.s4,
      BrandSpacing.s5,
      0,
    ),
    child: SizedBox(
      height:
          MediaQuery.textScalerOf(context).scale(_copyHeight) +
          2 * BrandSpacing.s5,
      child: child,
    ),
  );
}

/// Our own banner while no sponsor has the slot: "Your brand here". A tap
/// writes to us when the build has a support address.
class _AdvertiseHere extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final email = ref.watch(appConfigProvider).supportEmail;
    final open = email.isEmpty
        ? null
        : () => unawaited(ref.read(linkServiceProvider).email(email));
    return Semantics(
      label: '${l10n.advertiseTitle}. ${l10n.advertiseBody}',
      button: open != null,
      excludeSemantics: true,
      onTap: open,
      // Clean: the empty slot is the red hero card from the concept.
      child: Material(
        color: scheme.primary,
        borderRadius: BrandRadii.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.all(BrandSpacing.s3),
                    child: Icon(
                      Icons.campaign_outlined,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
                // Flexible: the text block gets the height left over, so
                // the title can shrink to fit at large text.
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          l10n.advertiseTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                      Text(
                        l10n.advertiseBody,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimary,
                        ),
                      ),
                      if (open != null) ...[
                        const SizedBox(height: BrandSpacing.s3),
                        Text(
                          l10n.advertiseAction,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimary,
                            decoration: TextDecoration.underline,
                            decorationColor: scheme.onPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Swipeable, and moves on by itself unless the phone asks for reduced
/// motion.
class _Pager extends StatefulWidget {
  const new(this.banners);

  final List<SponsorBanner> banners;

  @override
  State<_Pager> createState() => _PagerState();
}

class _PagerState extends State<_Pager> {
  final _pages = PageController(viewportFraction: 0.92);
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  @override
  void didUpdateWidget(_Pager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (widget.banners.length < 2 || MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _timer = Timer.periodic(_dwell, (_) => _next());
  }

  void _next() {
    if (!_pages.hasClients) return;
    final next = ((_pages.page ?? 0).round() + 1) % widget.banners.length;
    _pages.animateToPage(
      next,
      duration: BrandMotion.slow,
      curve: BrandMotion.standardCurve,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(top: BrandSpacing.s4),
    child: SizedBox(
      height:
          MediaQuery.textScalerOf(context).scale(_copyHeight) +
          2 * BrandSpacing.s5,
      child: PageView.builder(
        controller: _pages,
        itemCount: widget.banners.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BrandSpacing.s2,
          ),
          child: _BannerCard(widget.banners[i]),
        ),
      ),
    ),
  );
}

class _BannerCard extends ConsumerWidget {
  const new(this.banner);

  final SponsorBanner banner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final title = banner.title(urdu: urdu);
    final image = ref.watch(dealImageUrlProvider)(banner.imagePath);
    final link = banner.linkUrl;
    void open() => unawaited(ref.read(linkServiceProvider).openWeb(link!));
    final copy = _Copy(banner, urdu: urdu);

    return Semantics(
      label: l10n.sponsorBannerLabel(banner.sponsorName, title),
      button: link != null,
      excludeSemantics: true,
      onTap: link == null ? null : open,
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BrandRadii.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: link == null ? null : open,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image == null)
                copy
              else
                NetworkPicture(image, fallback: copy),
              const PositionedDirectional(
                top: BrandSpacing.s2,
                end: BrandSpacing.s2,
                child: _SponsoredTag(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The banner as text: for sponsors without artwork, and until it loads.
class _Copy extends StatelessWidget {
  const new(this.banner, {required this.urdu});

  final SponsorBanner banner;
  final bool urdu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = banner.subtitle(urdu: urdu);
    return Padding(
      padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              banner.title(urdu: urdu),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Sponsored is always labelled, on artwork as well as on text.
class _SponsoredTag extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BrandRadii.badge,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BrandSpacing.s2,
          vertical: BrandSpacing.s1,
        ),
        child: Text(
          context.l10n.sponsoredLabel,
          style: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}
