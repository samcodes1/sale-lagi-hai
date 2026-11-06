import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/network_picture.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_card_mapper.dart';
import 'package:sale_lagi_hai/features/popups/application/popup_providers.dart';
import 'package:sale_lagi_hai/features/popups/domain/popup_banner.dart';

/// Shows the pop-up that is due over [child] (Home), once per app start,
/// after Home has drawn. It is recorded as seen when it shows, so a shopper
/// who closes it isn't asked again sooner than its frequency allows.
class PopupGate extends ConsumerWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popup = ref.watch(popupToShowProvider).value;
    if (popup != null && !ref.watch(popupShownThisRunProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        // Claimed once: rebuilds before the dialog opens add nothing.
        if (!ref.read(popupShownThisRunProvider.notifier).claim()) return;
        unawaited(_show(context, ref, popup));
      });
    }
    return child;
  }

  static Future<void> _show(
    BuildContext context,
    WidgetRef ref,
    PopupBanner popup,
  ) async {
    final now = ref.read(clockProvider)();
    unawaited(
      ref
          .read(popupSeenStoreProvider)
          .markSeen(popup.id, now)
          .then((_) {}, onError: (Object error) {
            ref
                .read(loggerProvider)
                .warning('Pop-up seen time not saved', error: error);
          }),
    );
    final target = await showDialog<PopupTarget>(
      context: context,
      builder: (_) => PopupBannerDialog(popup),
    );
    if (target == null || !context.mounted) return;
    switch (target) {
      case PopupLink(:final url):
        unawaited(ref.read(linkServiceProvider).openWeb(url));
      case PopupDeal(:final dealId):
        unawaited(DealRoute(dealId: dealId).push<void>(context));
      case PopupBrand(:final slug):
        unawaited(BrandRoute(slug: slug).push<void>(context));
    }
  }
}

/// The pop-up card: artwork, title, text and one button. Closes with the
/// close button, back, or a tap outside; the button closes it with its
/// target.
class PopupBannerDialog extends ConsumerWidget {
  const new(this.popup, {super.key});

  final PopupBanner popup;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final image = ref.watch(dealImageUrlProvider)(popup.imagePath);
    final body = popup.body(urdu: urdu);
    final label = popup.actionLabel(urdu: urdu);
    final target = popup.target;
    final sponsor = popup.sponsorName;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(borderRadius: BrandRadii.card),
      insetPadding: const EdgeInsets.all(BrandSpacing.s5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (image != null)
                    AspectRatio(
                      aspectRatio: 1,
                      child: NetworkPicture(
                        image,
                        fallback: ColoredBox(
                          color: theme.colorScheme.surfaceContainerHigh,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      BrandSpacing.s6,
                      BrandSpacing.s6,
                      BrandSpacing.s6,
                      BrandSpacing.s5,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (sponsor != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              bottom: BrandSpacing.s2,
                            ),
                            child: Text(
                              l10n.popupSponsoredBy(sponsor),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        Semantics(
                          header: true,
                          child: Text(
                            popup.title(urdu: urdu),
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),
                        if (body != null) ...[
                          const SizedBox(height: BrandSpacing.s3),
                          Text(body, style: theme.textTheme.bodyLarge),
                        ],
                        const SizedBox(height: BrandSpacing.s6),
                        if (target != null && label != null)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(target),
                              child: Text(label),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              top: BrandSpacing.s2,
              end: BrandSpacing.s2,
              child: IconButton.filledTonal(
                tooltip: l10n.actionClose,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
