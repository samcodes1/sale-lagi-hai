import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/network/connectivity_service.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/deals/data/backend_deal_repository.dart';
import 'package:sale_lagi_hai/features/deals/data/deal_row.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_detail.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_repository.dart';

final dealRepositoryProvider = Provider<DealRepository>(
  (ref) => BackendDealRepository(
    ref.watch(backendGatewayProvider),
    ref.watch(loggerProvider),
  ),
);

/// The deal page's data. Fails with an `AppFailure` (a missing or hidden
/// deal is a `NotFoundFailure`).
///
/// Offline, a deal seen before (saved, or on Home) opens from its last
/// copy, marked with [DealDetail.cachedAt] (UX S08; QA P4-J1).
final FutureProviderFamily<DealDetail, String> dealDetailProvider =
    FutureProvider.family<DealDetail, String>((ref, id) async {
      final result = await ref.watch(dealRepositoryProvider).detail(id);
      switch (result) {
        case Success(:final value):
          return value;
        case Failure(:final failure):
          if (failure is OfflineFailure || failure is TimeoutFailure) {
            if (await _lastCopy(ref, id) case final copy?) {
              // Back online: the whole page.
              ref.listen(networkStatusProvider, (_, next) {
                if (next.value == NetworkStatus.online) ref.invalidateSelf();
              });
              return copy;
            }
          }
          throw failure;
      }
    });

/// The deal's card as last cached: the saved deals' copy first, then
/// Home's sections.
Future<DealDetail?> _lastCopy(Ref ref, String id) async {
  final cache = ref.read(jsonCacheProvider);
  final Set<String> keys;
  try {
    keys = await ref.read(keyValueStoreProvider).keys();
  } on Object {
    return null;
  }
  final home = [
    for (final k in keys)
      if (k.startsWith('cache.home.')) k.substring('cache.'.length),
  ]..sort();
  for (final key in ['saved.deals', ...home]) {
    final entry = await cache.get(key);
    final rows = entry?.data;
    if (entry == null || rows is! List) continue;
    for (final row in rows) {
      if (row is Map && row['id'] == id) {
        try {
          return DealDetail(
            deal: dealFromRow(Map<String, Object?>.from(row)),
            cachedAt: entry.savedAt,
          );
        } on FormatException {
          continue;
        }
      }
    }
  }
  return null;
}
