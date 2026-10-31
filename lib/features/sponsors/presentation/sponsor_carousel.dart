import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
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

/// Banner height at normal text size. It grows with large text.
const _height = 168.0;

/// The sponsors' banners at the top of Home. Nothing shows without any.
class SponsorCarousel extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(sponsorBannersProvider).value ?? const [];
    if (banners.isEmpty) return const SizedBox.shrink();
    return _Pager(banners);
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
      height: MediaQuery.textScalerOf(context).scale(_height),
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
            Flexible(
              child: Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
