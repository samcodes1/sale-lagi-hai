import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/l10n/deal_time_labels.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_refresh_indicator.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_card_mapper.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/home/presentation/city_picker.dart';

/// How close to the end of "For you" the next page starts loading.
const _prefetchFromEnd = 5;

/// Home (screen S03): Featured, Trending today, Near you, Ending soon and
/// the endless "For you" list. Pull to refresh reloads everything; offline,
/// the last copy shows with how old it is.
class HomeScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(featuredProvider)
      ..invalidate(trendingProvider)
      ..invalidate(endingSoonProvider)
      ..invalidate(forYouProvider);
    await ref.read(forYouProvider.future).then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final offline =
        ref.watch(networkStatusProvider).value == NetworkStatus.offline;
    return Scaffold(
      // The city is the title: it's what this screen is about, and it has
      // the room to grow with large text.
      appBar: AppBar(title: const _CityButton()),
      body: AppRefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          // Pull to refresh works even when everything fits.
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (offline) const SliverToBoxAdapter(child: OfflineBanner()),
            _Carousel(
              title: l10n.homeFeaturedTitle,
              provider: featuredProvider,
              size: DealCardSize.large,
            ),
            _Carousel(
              title: l10n.homeTrendingTitle,
              provider: trendingProvider,
            ),
            const _NearMe(),
            _Carousel(
              title: l10n.homeEndingTitle,
              provider: endingSoonProvider,
            ),
            const _ForYou(),
          ],
        ),
      ),
    );
  }
}

/// The current city, as a button that opens the city picker.
class _CityButton extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final name = _cityName(ref, urdu: urdu) ?? l10n.allPakistan;
    return Semantics(
      label: l10n.homeCityLabel(name),
      hint: l10n.actionChangeCity,
      button: true,
      excludeSemantics: true,
      // The excluded button's own tap action goes with it.
      onTap: () => pickCity(context, ref),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => pickCity(context, ref),
          icon: const Icon(Icons.location_on_outlined),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

String? _cityName(WidgetRef ref, {required bool urdu}) {
  final id = ref.watch(homeCityProvider);
  if (id == null) return null;
  final cities = ref.watch(citiesProvider).value ?? const <City>[];
  for (final c in cities) {
    if (c.id == id) return c.name(urdu: urdu);
  }
  return null;
}

/// A row title: a heading for screen readers, with the age of an offline
/// copy under it.
class _SectionTitle extends ConsumerWidget {
  const new(this.title, {this.cachedAt});

  final String title;
  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cachedAt = this.cachedAt;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s5,
        BrandSpacing.s6,
        BrandSpacing.s5,
        BrandSpacing.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          if (cachedAt != null)
            Text(
              DealTimeLabels(
                context.l10n,
                AppFormatters.of(context),
              ).updated(cachedAt, now: ref.watch(clockProvider)()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Builds the cards for [deals] in the UI language.
List<Widget> _cards(
  BuildContext context,
  WidgetRef ref,
  List<Deal> deals, {
  required DealCardSize size,
}) {
  final l10n = context.l10n;
  final format = AppFormatters.of(context);
  final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
  final imageUrl = ref.watch(dealImageUrlProvider);
  final city = _cityName(ref, urdu: urdu);
  return [
    for (final deal in deals)
      DealCard(
        key: ValueKey(deal.id),
        size: size,
        deal: dealCardData(
          deal,
          urdu: urdu,
          l10n: l10n,
          format: format,
          imageUrl: imageUrl,
          cityName: city,
        ),
        onTap: () => DealRoute(dealId: deal.id).push<void>(context),
      ),
  ];
}

/// A horizontal row of cards. Cards keep their natural height (they grow
/// with Urdu and large text), so the row is a scrolling [Row], not a
/// fixed-height list. Rows hold at most 20 cards.
class _Carousel extends ConsumerWidget {
  const new({
    required this.title,
    required this.provider,
    this.size = DealCardSize.standard,
  });

  final String title;
  final FutureProvider<HomeSection> provider;
  final DealCardSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(provider);
    final width = size == DealCardSize.large ? 320.0 : 260.0;
    return switch (section) {
      // An empty row is left out, not shown as a gap.
      AsyncData(:final value) when value.deals.isEmpty =>
        const SliverToBoxAdapter(child: SizedBox.shrink()),
      AsyncData(:final value) => SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(title, cachedAt: value.cachedAt),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BrandSpacing.s5,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final card in _cards(
                    context,
                    ref,
                    value.deals,
                    size: size,
                  ))
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: BrandSpacing.s4,
                      ),
                      child: SizedBox(width: width, child: card),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      AsyncError(:final error) => SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(title),
            InlineErrorBanner(
              failure: error is AppFailure ? error : const UnexpectedFailure(),
              onRetry: () => ref.invalidate(provider),
            ),
          ],
        ),
      ),
      _ => SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionTitle(title),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BrandSpacing.s5,
              ),
              child: SizedBox(width: width, child: const DealCardSkeleton()),
            ),
          ],
        ),
      ),
    };
  }
}

/// "Near you": a button until the shopper asks, then nearby deals with
/// their distance. Location is asked only on that tap.
class _NearMe extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(nearMeProvider);
    void locate() => unawaited(ref.read(nearMeProvider.notifier).locate());

    Widget prompt(String message, {bool settings = false}) => Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: BrandSpacing.s5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(message, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: BrandSpacing.s3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: settings
                ? TextButton(
                    onPressed: ref
                        .read(locationServiceProvider)
                        .openAppSettings,
                    child: Text(l10n.actionOpenSettings),
                  )
                : OutlinedButton.icon(
                    onPressed: locate,
                    icon: const Icon(Icons.near_me_outlined),
                    label: Text(l10n.actionShowNearby),
                  ),
          ),
        ],
      ),
    );

    final body = switch (state) {
      NearMeIdle() => prompt(l10n.homeNearBody),
      NearMeLocating() => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BrandSpacing.s5,
        ),
        child: Semantics(liveRegion: true, child: Text(l10n.homeNearLocating)),
      ),
      NearMeFound(:final deals) when deals.isEmpty => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BrandSpacing.s5,
        ),
        child: Text(l10n.emptyNearby, style: theme.textTheme.bodyMedium),
      ),
      NearMeFound(:final deals) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: BrandSpacing.s5,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final card in _cards(
              context,
              ref,
              deals,
              size: DealCardSize.standard,
            ))
              Padding(
                padding: const EdgeInsetsDirectional.only(end: BrandSpacing.s4),
                child: SizedBox(width: 260, child: card),
              ),
          ],
        ),
      ),
      NearMeNoLocation(outcome: LocationDenied(permanently: true)) => prompt(
        l10n.homeNearBlocked,
        settings: true,
      ),
      NearMeNoLocation() => prompt(l10n.homeNearNoLocation),
      NearMeFailed(:final failure) => InlineErrorBanner(
        failure: failure,
        onRetry: locate,
      ),
    };
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [_SectionTitle(l10n.homeNearTitle), body],
      ),
    );
  }
}

/// "For you": newest deals in the shopper's interests, loading the next
/// page about five cards before the end.
class _ForYou extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final feed = ref.watch(forYouProvider);
    final title = SliverToBoxAdapter(
      child: _SectionTitle(
        l10n.homeForYouTitle,
        cachedAt: feed.value?.cachedAt,
      ),
    );
    switch (feed) {
      case AsyncData(:final value) when value.deals.isEmpty:
        return SliverMainAxisGroup(
          slivers: [
            title,
            SliverToBoxAdapter(
              child: MessageView(
                icon: Icons.local_offer_outlined,
                message: l10n.homeFeedEmpty,
              ),
            ),
          ],
        );
      case AsyncData(:final value):
        final cards = _cards(
          context,
          ref,
          value.deals,
          size: DealCardSize.standard,
        );
        return SliverMainAxisGroup(
          slivers: [
            title,
            SliverPadding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BrandSpacing.s5,
              ),
              sliver: SliverList.builder(
                itemCount: cards.length,
                itemBuilder: (context, i) {
                  // Never after a failure: the retry row asks instead, or
                  // every rebuild would retry at once, in a loop.
                  if (i >= cards.length - _prefetchFromEnd &&
                      !value.atEnd &&
                      !value.loadingMore &&
                      value.moreFailure == null) {
                    // After this frame: never change state while building.
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => ref.read(forYouProvider.notifier).loadMore(),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: BrandSpacing.s4,
                    ),
                    child: cards[i],
                  );
                },
              ),
            ),
            SliverToBoxAdapter(child: _FeedFooter(value)),
          ],
        );
      case AsyncError(:final error):
        return SliverMainAxisGroup(
          slivers: [
            title,
            SliverToBoxAdapter(
              child: ErrorView(
                failure: error is AppFailure
                    ? error
                    : const UnexpectedFailure(),
                onRetry: () => ref.invalidate(forYouProvider),
              ),
            ),
          ],
        );
      default:
        return SliverMainAxisGroup(
          slivers: [
            title,
            SliverList.list(
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
            ),
          ],
        );
    }
  }
}

/// The end of "For you": loading the next page, a retry row when it
/// failed, or the end-of-list note.
class _FeedFooter extends ConsumerWidget {
  const new(this.state);

  final FeedState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final failure = state.moreFailure;
    final Widget child;
    if (state.loadingMore) {
      child = const Center(child: CircularProgressIndicator());
    } else if (failure != null) {
      child = InlineErrorBanner(
        failure: failure,
        onRetry: () => ref.read(forYouProvider.notifier).loadMore(),
      );
    } else if (state.atEnd && state.cachedAt == null) {
      // An offline copy is only the first page: more exist.
      child = Text(
        l10n.homeFeedEnd,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s5,
        BrandSpacing.s3,
        BrandSpacing.s5,
        BrandSpacing.s8,
      ),
      child: child,
    );
  }
}
