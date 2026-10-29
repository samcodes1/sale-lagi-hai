import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/features/deals/data/backend_deal_repository.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_repository.dart';

final dealRepositoryProvider = Provider<DealRepository>(
  (ref) => BackendDealRepository(
    ref.watch(backendGatewayProvider),
    ref.watch(loggerProvider),
  ),
);
