import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/deal_time_labels.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_refresh_indicator.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/presentation/paged_deal_list.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_view.dart';

/// Saved tab (screen S17): saved deals still on, and those that ended,
/// newest saved first. Each card can be unsaved (with Undo). Saved deals
/// that no longer exist are summed up once, with a way to clear them.
class SavedScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

enum _Tab { active, ended }

class _SavedScreenState extends ConsumerState<SavedScreen> {
  _Tab _tab = _Tab.active;

  Future<void> _unsave(Deal deal) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final saved = ref.read(savedDealsProvider.notifier);
    final at = ref.read(savedDealsProvider).indexOf(deal.id);
    await saved.toggle(deal.id);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.unsavedToast),
          action: SnackBarAction(
            label: l10n.actionUndo,
            onPressed: () {
              if (!saved.isSaved(deal.id)) {
                unawaited(saved.toggle(deal.id, at: at));
              }
            },
          ),
        ),
      );
  }

  Future<void> _removeAll(List<String> ids) =>
      ref.read(savedDealsProvider.notifier).removeAll(ids);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final view = ref.watch(savedViewProvider);
    final hasSaves = ref.watch(savedDealsProvider).isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSaved)),
      body: !hasSaves
          ? MessageView(icon: Icons.bookmark_border, message: l10n.emptySaved)
          : switch (view) {
              AsyncValue(:final value?) => _list(context, value),
              AsyncError(:final error) => ErrorView(
                failure: error is AppFailure
                    ? error
                    : const UnexpectedFailure(),
                onRetry: () => ref.invalidate(savedViewProvider),
              ),
              _ => ListView(
                padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
                children: const [DealCardSkeleton(), DealCardSkeleton()],
              ),
            },
    );
  }

  Widget _list(BuildContext context, SavedView view) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final deals = _tab == _Tab.active ? view.active : view.ended;
    final cachedAt = view.cachedAt;
    return AppRefreshIndicator(
      onRefresh: () async {
        ref.invalidate(savedViewProvider);
        await ref.read(savedViewProvider.future).then((_) {}, onError: (_) {});
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (cachedAt != null)
            SliverToBoxAdapter(
              child: OfflineBanner(
                updatedLabel: DealTimeLabels(
                  l10n,
                  AppFormatters.of(context),
                ).updated(cachedAt, now: ref.watch(clockProvider)()),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BrandSpacing.s5,
                BrandSpacing.s4,
                BrandSpacing.s5,
                BrandSpacing.s2,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SegmentedButton<_Tab>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _Tab.active,
                      label: Text(l10n.savedActive(view.active.length)),
                    ),
                    ButtonSegment(
                      value: _Tab.ended,
                      label: Text(l10n.savedEnded(view.ended.length)),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (s) => setState(() => _tab = s.single),
                ),
              ),
            ),
          ),
          if (view.goneIds.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: BrandSpacing.s5,
                  vertical: BrandSpacing.s2,
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: BrandSpacing.s3,
                  children: [
                    Text(
                      l10n.savedGone(view.goneIds.length),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _removeAll(view.goneIds),
                      child: Text(l10n.actionRemoveThem),
                    ),
                  ],
                ),
              ),
            ),
          if (_tab == _Tab.ended && view.ended.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: BrandSpacing.s5,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () =>
                        _removeAll([for (final d in view.ended) d.id]),
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: Text(l10n.actionRemoveEnded),
                  ),
                ),
              ),
            ),
          if (deals.isEmpty)
            SliverToBoxAdapter(
              child: MessageView(
                icon: Icons.bookmark_border,
                message: _tab == _Tab.active
                    ? l10n.savedNoActive
                    : l10n.savedNoEnded,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BrandSpacing.s5,
                BrandSpacing.s3,
                BrandSpacing.s5,
                BrandSpacing.s8,
              ),
              sliver: SliverList.builder(
                itemCount: deals.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: BrandSpacing.s4,
                  ),
                  child: dealCardFor(
                    context,
                    ref,
                    deals[i],
                    saved: true,
                    onSaveToggle: () => _unsave(deals[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
