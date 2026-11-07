import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/sponsors/data/backend_sponsor_repository.dart';
import 'package:sale_lagi_hai/features/sponsors/domain/sponsor_banner.dart';

/// The banners for Home's city. A failure only means no banners: they must
/// never get in the way of the deals.
final sponsorBannersProvider = FutureProvider<List<SponsorBanner>>(
  (ref) async {
    final city = ref.watch(homeCityProvider);
    try {
      final repository = BackendSponsorRepository(
        ref.watch(backendGatewayProvider),
      );
      return [
        for (final banner in await repository.live())
          if (banner.cityId == null || banner.cityId == city) banner,
      ];
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning('Sponsor banners could not load', error: error);
      return const [];
    }
  },
  // Pull to refresh tries again; nothing else should.
  retry: (_, _) => null,
);
