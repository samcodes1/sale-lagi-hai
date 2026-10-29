import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/models/deal_card_data.dart';
import 'package:sale_lagi_hai/design_system/models/deal_offer.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_bottom_sheet.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_stepper.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_tab_bar.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_card.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_labels.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';
import 'package:sale_lagi_hai/design_system/widgets/price_text.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';

/// Sample deals for the gallery and golden tests, relative to [now].
/// Illustrative only: not real offers.
List<DealCardData> galleryDeals(DateTime now) => [
  DealCardData(
    id: 'd1',
    brandName: 'Sapphire',
    title: 'Winter collection, in store and online',
    offer: DealOffer.fromPrices(was: 4999, now: 2999),
    price: 2999,
    oldPrice: 4999,
    endsAt: now.add(const Duration(days: 2, hours: 4)),
    verifiedAt: now.subtract(const Duration(hours: 3)),
    place: 'Dolmen Mall Clifton',
    featured: true,
  ),
  DealCardData(
    id: 'd2',
    brandName: 'Kolachi',
    title: '25% off dinner for HBL and Meezan cardholders',
    offer: const PercentOff(25),
    endsAt: now.add(const Duration(hours: 5)),
    verifiedAt: now.subtract(const Duration(minutes: 40)),
    place: 'Do Darya',
    cardNames: const ['HBL', 'Meezan'],
    saved: true,
  ),
  DealCardData(
    id: 'd3',
    brandName: 'Outfitters',
    title: 'Season end sale',
    offer: const UpToPercentOff(50),
    endsAt: now.add(const Duration(days: 9)),
    verifiedAt: now.subtract(const Duration(days: 4)),
    place: 'Online',
  ),
  DealCardData(
    id: 'd4',
    brandName: 'Burger Lab',
    title: 'Two smash burgers for Rs 999',
    offer: const TextOffer('2 for Rs 999'),
    endsAt: now.subtract(const Duration(hours: 1)),
    place: 'Gulshan',
  ),
];

/// Every design-system widget in its states. A developer tool, reachable
/// only outside production; its section titles are not localized.
class WidgetGalleryPage extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deals = galleryDeals(ref.watch(clockProvider)());
    void noop() {}
    return Scaffold(
      appBar: AppBar(title: const Text('Widget gallery')),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(BrandSpacing.screenGutter),
        children: [
          const _Heading('Deal cards'),
          DealCard(
            deal: deals[0],
            onTap: noop,
            onSaveToggle: noop,
            size: DealCardSize.large,
          ),
          const SizedBox(height: BrandSpacing.s4),
          DealCard(deal: deals[1], onTap: noop, onSaveToggle: noop),
          const SizedBox(height: BrandSpacing.s4),
          for (final deal in deals.skip(2)) ...[
            DealCard(
              deal: deal,
              onTap: noop,
              onSaveToggle: noop,
              size: DealCardSize.compact,
            ),
            const SizedBox(height: BrandSpacing.s3),
          ],
          const _Heading('Badges, labels and prices'),
          Wrap(
            spacing: BrandSpacing.s3,
            runSpacing: BrandSpacing.s3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const DiscountBadge(offer: PercentOff(40)),
              const DiscountBadge(offer: UpToPercentOff(70)),
              const DiscountBadge(offer: FlatPercentOff(30)),
              const DiscountBadge(offer: TextOffer('Buy 1 Get 1')),
              const FeaturedLabel(),
              const CardNameChip(name: 'HBL'),
              const PriceText(price: 1799, oldPrice: 2999),
              ExpiryTag(endsAt: deals[0].endsAt),
              VerifiedTag(verifiedAt: deals[2].verifiedAt!),
            ],
          ),
          const _Heading('Loading'),
          const DealCardSkeleton(),
          const _Heading('States'),
          const OfflineBanner(updatedLabel: 'Updated 2 hours ago'),
          const SizedBox(height: BrandSpacing.s3),
          InlineErrorBanner(failure: const ServerFailure(), onRetry: noop),
          SizedBox(
            height: 240,
            child: ErrorView(failure: const OfflineFailure(), onRetry: noop),
          ),
          const SizedBox(
            height: 200,
            child: MessageView(
              icon: Icons.bookmark_border,
              message: 'Nothing saved yet.',
            ),
          ),
          const _Heading('Tabs and sheets'),
          const DefaultTabController(
            length: 3,
            child: AppTabBar(labels: ['Near me', 'Online', 'All city']),
          ),
          const SizedBox(height: BrandSpacing.s4),
          Builder(
            builder: (context) => OutlinedButton(
              onPressed: () => showAppBottomSheet<void>(
                context: context,
                title: 'Filters',
                builder: (_) => const Text('Filter options go here.'),
              ),
              child: const Text('Open bottom sheet'),
            ),
          ),
          const _Heading('Steps'),
          AppStepper(
            currentStep: 1,
            onStepContinue: noop,
            onStepCancel: noop,
            steps: const [
              Step(
                title: Text('City'),
                content: SizedBox.shrink(),
                isActive: true,
                state: StepState.complete,
              ),
              Step(
                title: Text('Interests'),
                content: Text('Pick three or more.'),
                isActive: true,
              ),
              Step(title: Text('Alerts'), content: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: BrandSpacing.s8),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(
      top: BrandSpacing.s7,
      bottom: BrandSpacing.s4,
    ),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}
