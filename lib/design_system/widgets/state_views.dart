import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/failure_messages.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';

/// A full-area error: what happened, and [Try again] when retrying can help.
/// Never shows codes or technical details (the failure's `cause`).
///
/// Prefer [InlineErrorBanner] when there is cached content to keep showing.
class ErrorView extends StatelessWidget {
  const new({required this.failure, this.onRetry, super.key});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canRetry = onRetry != null && failure.isRetryable;
    return MessageView(
      icon: failure is OfflineFailure
          ? Icons.wifi_off_outlined
          : Icons.error_outline,
      message: failure.message(l10n),
      actionLabel: canRetry ? l10n.actionRetry : null,
      onAction: canRetry ? onRetry : null,
    );
  }
}

/// A slim, non-blocking error above content that is still usable (a cached
/// feed, a list whose next page failed).
class InlineErrorBanner extends StatelessWidget {
  const new({required this.failure, this.onRetry, super.key});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            BrandSpacing.s5,
            BrandSpacing.s2,
            BrandSpacing.s2,
            BrandSpacing.s2,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.error_outline, color: scheme.onSurface),
              ),
              const SizedBox(width: BrandSpacing.s4),
              // The action sits under the message, so at large text sizes
              // it never squeezes the message into a narrow column.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      failure.message(l10n),
                      style: Theme.of(context).textTheme.bodyMedium!
                          .copyWith(color: scheme.onSurface),
                    ),
                    if (onRetry != null && failure.isRetryable)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: onRetry,
                          child: Text(l10n.actionRetry),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The persistent "you're offline" strip. A live region, so screen readers
/// announce it without moving focus. [updatedLabel] says how old the shown
/// content is ("Updated 2 hours ago").
class OfflineBanner extends StatelessWidget {
  const new({this.updatedLabel, this.onRetry, super.key});

  final String? updatedLabel;

  /// Shows Try again (where a reload can help, e.g. a deal's offline copy).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.inverseSurface,
        child: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BrandSpacing.s5,
              vertical: BrandSpacing.s3,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.wifi_off_outlined,
                    color: scheme.onInverseSurface,
                  ),
                ),
                const SizedBox(width: BrandSpacing.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.offlineBanner,
                        style: text.bodyMedium!.copyWith(
                          color: scheme.onInverseSurface,
                        ),
                      ),
                      if (updatedLabel case final updated?)
                        Text(
                          updated,
                          style: text.bodySmall!.copyWith(
                            color: scheme.onInverseSurface,
                          ),
                        ),
                    ],
                  ),
                ),
                if (onRetry case final retry?)
                  TextButton(
                    onPressed: retry,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onInverseSurface,
                    ),
                    child: Text(context.l10n.actionRetry),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Static placeholder blocks in the shape of the real content, so nothing
/// jumps when it loads. No shimmer: it is motion for its own sake and must
/// be off for reduce-motion users anyway.
class SkeletonBox extends StatelessWidget {
  const new({this.width, this.height = 16, this.radius, super.key});

  final double? width;
  final double height;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: radius ?? BrandRadii.badge,
    ),
  );
}

/// A loading deal card. Screen readers hear "Loading deals" once.
class DealCardSkeleton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.loadingDeals,
    child: const ExcludeSemantics(
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonBox(radius: BorderRadius.zero),
            ),
            Padding(
              padding: EdgeInsetsDirectional.all(BrandSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 96, height: 12),
                  SizedBox(height: BrandSpacing.s3),
                  SkeletonBox(height: 18),
                  SizedBox(height: BrandSpacing.s2),
                  SkeletonBox(width: 200, height: 18),
                  SizedBox(height: BrandSpacing.s4),
                  SkeletonBox(width: 120, height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
