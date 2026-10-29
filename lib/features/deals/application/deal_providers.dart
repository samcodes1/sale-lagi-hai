import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/features/deals/data/backend_deal_repository.dart';
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
final FutureProviderFamily<DealDetail, String> dealDetailProvider =
    FutureProvider.family<DealDetail, String>((ref, id) async {
      final result = await ref.watch(dealRepositoryProvider).detail(id);
      return switch (result) {
        Success(:final value) => value,
        Failure(:final failure) => throw failure,
      };
    });
