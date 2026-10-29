import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/design_system/models/deal_card_data.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';

/// The public URL of a deal image in the `deal-images` bucket, or `null`
/// without a backend (demo builds show the brand plate).
final dealImageUrlProvider = Provider<String? Function(String? path)>((ref) {
  final base = ref.watch(appConfigProvider).supabaseUrl;
  return (path) => path == null || base.isEmpty
      ? null
      : '$base/storage/v1/object/public/deal-images/${Uri.encodeFull(path)}';
});

/// What a card shows for [deal], in the UI language. [cityName] labels
/// local deals; a distance (from "Near me") wins over every place label.
DealCardData dealCardData(
  Deal deal, {
  required bool urdu,
  required AppLocalizations l10n,
  required AppFormatters format,
  required String? Function(String? path) imageUrl,
  String? cityName,
}) {
  final hasPricePair =
      deal.pricePkr != null &&
      deal.originalPricePkr != null &&
      deal.originalPricePkr! > deal.pricePkr!;
  return DealCardData(
    id: deal.id,
    brandName: deal.brand(urdu: urdu),
    title: deal.title(urdu: urdu),
    offer: deal.offer(urdu: urdu),
    price: deal.pricePkr,
    oldPrice: hasPricePair ? deal.originalPricePkr : null,
    endsAt: deal.endsAt,
    verifiedAt: deal.verifiedAt,
    place: switch (deal) {
      Deal(distanceMeters: final meters?) => format.distance(meters),
      Deal(scope: DealScope.online) => l10n.online,
      Deal(scope: DealScope.nationwide) => l10n.allPakistan,
      Deal(scope: DealScope.local) => cityName,
    },
    imageUrl: imageUrl(deal.imagePath),
    featured: deal.isFeatured,
    cardNames: deal.cardBanks,
  );
}
