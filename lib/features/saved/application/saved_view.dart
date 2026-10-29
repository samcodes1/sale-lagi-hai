import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_providers.dart';
import 'package:sale_lagi_hai/features/deals/data/deal_row.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';

/// How long the offline copy of the Saved tab is shown.
const savedCacheMaxAge = Duration(days: 7);

/// The Saved tab: the saved deals, in the order saved (newest first),
/// split into those still on and those that ended. [goneIds] are saved
/// deals that no longer exist (removed, or hidden by moderation).
@immutable
final class SavedView {
  const new({
    this.active = const [],
    this.ended = const [],
    this.goneIds = const [],
    this.cachedAt,
    this.failure,
  });

  final List<Deal> active;
  final List<Deal> ended;
  final List<String> goneIds;

  /// Set when this is the offline copy, with why the fresh one failed.
  final DateTime? cachedAt;
  final AppFailure? failure;

  bool get isEmpty => active.isEmpty && ended.isEmpty;
}

const _cacheKey = 'saved.deals';

final savedViewProvider = FutureProvider<SavedView>((ref) async {
  final ids = ref.watch(savedDealsProvider);
  if (ids.isEmpty) return const SavedView();
  final now = ref.read(clockProvider)();
  final cache = ref.read(jsonCacheProvider);

  SavedView split(List<Deal> found, {DateTime? cachedAt, AppFailure? failure}) {
    final byId = {for (final d in found) d.id: d};
    final ordered = [for (final id in ids) ?byId[id]];
    bool ended(Deal d) => d.endsAt != null && !d.endsAt!.isAfter(now);
    return SavedView(
      active: [
        for (final d in ordered)
          if (!ended(d)) d,
      ],
      ended: [
        for (final d in ordered)
          if (ended(d)) d,
      ],
      // Unknown in an offline copy: it may just not have been saved yet.
      goneIds: cachedAt != null
          ? const []
          : [
              for (final id in ids)
                if (!byId.containsKey(id)) id,
            ],
      cachedAt: cachedAt,
      failure: failure,
    );
  }

  final result = await ref.read(dealRepositoryProvider).byIds(ids);
  switch (result) {
    case Success(:final value):
      try {
        await cache.put(_cacheKey, [for (final d in value) dealToRow(d)]);
      } on Object catch (error) {
        ref
            .read(loggerProvider)
            .warning(
              'Could not cache saved deals',
              context: {'error': error.runtimeType.toString()},
            );
      }
      return split(value);
    case Failure(:final failure):
      final entry = await cache.get(
        _cacheKey,
        maxAge: savedCacheMaxAge,
        dropExpired: true,
      );
      final rows = entry?.data;
      if (entry == null || rows is! List) throw failure;
      try {
        return split(
          [
            for (final row in rows)
              dealFromRow(Map<String, Object?>.from(row as Map)),
          ],
          cachedAt: entry.savedAt,
          failure: failure,
        );
      } on Object {
        throw failure;
      }
  }
});
