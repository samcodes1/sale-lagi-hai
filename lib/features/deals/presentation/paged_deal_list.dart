import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_card_mapper.dart';

/// How close to the end the next page starts loading.
const _prefetchFromEnd = 5;

/// A standard deal card that opens its deal page.
Widget dealCardFor(BuildContext context, WidgetRef ref, Deal deal) {
  final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
  return DealCard(
    key: ValueKey(deal.id),
    deal: dealCardData(
      deal,
      urdu: urdu,
      l10n: context.l10n,
      format: AppFormatters.of(context),
      imageUrl: ref.watch(dealImageUrlProvider),
    ),
    onTap: () => DealRoute(dealId: deal.id).push<void>(context),
  );
}

/// The deals of [query] as slivers: cards, then loading more, a retry row
/// or the end note. Empty shows [emptyMessage]; a failed first page, the
/// full error with Try again.
class PagedDealSlivers extends ConsumerWidget {
  const new({required this.query, required this.emptyMessage, super.key});

  final DealListQuery query;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final list = ref.watch(dealListProvider(query));
    switch (list) {
      case AsyncData(:final value) when value.deals.isEmpty:
        return SliverToBoxAdapter(
          child: MessageView(
            icon: Icons.local_offer_outlined,
            message: emptyMessage,
          ),
        );
      case AsyncData(:final value):
        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BrandSpacing.s5,
              ),
              sliver: SliverList.builder(
                itemCount: value.deals.length,
                itemBuilder: (context, i) {
                  // Never after a failure: the retry row asks instead.
                  if (i >= value.deals.length - _prefetchFromEnd &&
                      !value.atEnd &&
                      !value.loadingMore &&
                      value.moreFailure == null) {
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) =>
                          ref.read(dealListProvider(query).notifier).loadMore(),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: BrandSpacing.s4,
                    ),
                    child: dealCardFor(context, ref, value.deals[i]),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  BrandSpacing.s5,
                  BrandSpacing.s3,
                  BrandSpacing.s5,
                  BrandSpacing.s8,
                ),
                child: switch (value) {
                  FeedState(loadingMore: true) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  FeedState(moreFailure: final failure?) => InlineErrorBanner(
                    failure: failure,
                    onRetry: () =>
                        ref.read(dealListProvider(query).notifier).loadMore(),
                  ),
                  FeedState(atEnd: true) => Text(
                    l10n.listEnd,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ],
        );
      case AsyncError(:final error):
        return SliverToBoxAdapter(
          child: ErrorView(
            failure: error is AppFailure ? error : const UnexpectedFailure(),
            onRetry: () => ref.invalidate(dealListProvider(query)),
          ),
        );
      default:
        return SliverList.list(
          children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  BrandSpacing.s5,
                  0,
                  BrandSpacing.s5,
                  BrandSpacing.s4,
                ),
                child: DealCardSkeleton(),
              ),
          ],
        );
    }
  }
}
