import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/l10n/deal_time_labels.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_refresh_indicator.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/alerts/application/alerts_providers.dart';
import 'package:sale_lagi_hai/features/alerts/domain/app_alert.dart';
import 'package:sale_lagi_hai/features/follows/application/follow_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

/// Alerts tab (screen S15): the inbox, newest first, grouped Today and
/// Earlier, with unread ones marked; and what the shopper follows. Opening
/// the tab clears its badge; reading an alert marks it read.
class AlertsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  Future<void> _open(AppAlert alert) async {
    unawaited(ref.read(inboxProvider.notifier).markRead(alert));
    if (alert.dealId case final id?) {
      await DealRoute(dealId: id).push<void>(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inbox = ref.watch(inboxProvider);
    final unread = inbox.value?.hasUnread ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navAlerts),
        actions: [
          if (unread)
            IconButton(
              tooltip: l10n.actionMarkAllRead,
              icon: const Icon(Icons.done_all),
              onPressed: () => ref.read(inboxProvider.notifier).markAllRead(),
            ),
        ],
      ),
      body: AppRefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(inboxProvider)
            ..invalidate(alertsBadgeProvider);
          await ref.read(inboxProvider.future).then((_) {}, onError: (_) {});
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _FollowingEntry()),
            ...switch (inbox) {
              AsyncData(value: InboxState(signedIn: false)) => [
                SliverToBoxAdapter(
                  child: MessageView(
                    icon: Icons.notifications_none,
                    message: l10n.alertsGuest,
                    actionLabel: l10n.actionSignIn,
                    onAction: () => const SignInRoute().push<bool>(context),
                  ),
                ),
              ],
              AsyncData(:final value) when value.alerts.isEmpty => [
                SliverToBoxAdapter(
                  child: MessageView(
                    icon: Icons.notifications_none,
                    message: l10n.emptyAlerts,
                  ),
                ),
              ],
              AsyncData(:final value) => _alerts(context, value),
              AsyncError(:final error) => [
                SliverToBoxAdapter(
                  child: ErrorView(
                    failure: error is AppFailure
                        ? error
                        : const UnexpectedFailure(),
                    onRetry: () => ref.invalidate(inboxProvider),
                  ),
                ),
              ],
              _ => [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsetsDirectional.all(BrandSpacing.s5),
                    child: SkeletonBox(height: 64),
                  ),
                ),
              ],
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _alerts(BuildContext context, InboxState inbox) {
    final l10n = context.l10n;
    final now = ref.watch(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    bool isToday(AppAlert a) => !a.createdAt.toLocal().isBefore(today);
    final groups = [
      (
        l10n.alertsToday,
        [
          for (final a in inbox.alerts)
            if (isToday(a)) a,
        ],
      ),
      (
        l10n.alertsEarlier,
        [
          for (final a in inbox.alerts)
            if (!isToday(a)) a,
        ],
      ),
    ];
    final last = inbox.alerts.last;
    return [
      for (final (title, alerts) in groups)
        if (alerts.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BrandSpacing.s5,
                BrandSpacing.s5,
                BrandSpacing.s5,
                BrandSpacing.s2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: alerts.length,
            itemBuilder: (context, i) {
              final alert = alerts[i];
              // The next page loads at the last alert; never after a
              // failure (the retry row asks instead).
              if (identical(alert, last) &&
                  inbox.hasMore &&
                  !inbox.loadingMore &&
                  inbox.moreFailure == null) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => ref.read(inboxProvider.notifier).loadMore(),
                );
              }
              return _AlertRow(alert, now: now, onTap: () => _open(alert));
            },
          ),
        ],
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
          child: switch (inbox) {
            InboxState(loadingMore: true) => const Center(
              child: CircularProgressIndicator(),
            ),
            InboxState(moreFailure: final failure?) => InlineErrorBanner(
              failure: failure,
              onRetry: () => ref.read(inboxProvider.notifier).loadMore(),
            ),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    ];
  }
}

/// "Following: 3 brands · 1 category", opening the Following list.
class _FollowingEntry extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = ref.watch(preferencesProvider);
    // Loading them drops follows of what is no longer offered, so the
    // count matches the Following list (QA 4.8 BUG-7).
    ref
      ..watch(followedBrandsProvider)
      ..watch(followedCategoriesProvider);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () => const FollowingRoute().push<void>(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BrandSpacing.s5,
            vertical: BrandSpacing.s4,
          ),
          child: Row(
            children: [
              const ExcludeSemantics(child: Icon(Icons.favorite_border)),
              const SizedBox(width: BrandSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.followingTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      l10n.followingSummary(
                        p.brandIds.length,
                        p.categoryFollowIds.length,
                      ),
                    ),
                  ],
                ),
              ),
              const ExcludeSemantics(child: Icon(Icons.chevron_right)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const new(this.alert, {required this.now, required this.onTap});

  final AppAlert alert;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = alert.isUnread;
    final when = DealTimeLabels(
      l10n,
      AppFormatters.of(context),
    ).received(alert.createdAt, now: now);
    final icon = switch (alert.kind) {
      AlertKind.dealAlert => Icons.local_offer_outlined,
      AlertKind.priceDrop => Icons.trending_down,
      AlertKind.expiringSaved => Icons.timer_outlined,
      AlertKind.business => Icons.storefront_outlined,
      AlertKind.system => Icons.info_outline,
    };
    return MergeSemantics(
      child: Semantics(
        button: true,
        // Not colour alone: unread alerts say so, and are bold.
        label: unread ? l10n.alertUnread : null,
        child: Material(
          color: unread
              ? scheme.primaryContainer.withValues(alpha: 0.35)
              : null,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BrandSpacing.s5,
                vertical: BrandSpacing.s3,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(icon, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: BrandSpacing.s4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: unread ? FontWeight.w700 : null,
                          ),
                        ),
                        if (alert.body case final body?)
                          Text(body, style: theme.textTheme.bodyMedium),
                        Text(
                          when,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unread)
                    ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: BrandSpacing.s3,
                          top: BrandSpacing.s2,
                        ),
                        child: Icon(
                          Icons.circle,
                          size: 10,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
