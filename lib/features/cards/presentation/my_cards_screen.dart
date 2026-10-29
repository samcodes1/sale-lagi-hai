import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/cards/application/my_cards_providers.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_list.dart';
import 'package:sale_lagi_hai/features/deals/presentation/paged_deal_list.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';

/// My Cards (screen S14): the shopper's bank cards, as bank and card type
/// only, and the offers they get. There is nowhere to type a card number.
class MyCardsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final mine = ref.watch(myCardsProvider);
    final products = ref.watch(cardProductsProvider);
    final banks = ref.watch(banksProvider);

    Widget heading(String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s5,
        BrandSpacing.s6,
        BrandSpacing.s5,
        BrandSpacing.s3,
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: BrandSpacing.s3,
        runSpacing: BrandSpacing.s2,
        children: [
          Semantics(
            header: true,
            child: Text(text, style: theme.textTheme.titleLarge),
          ),
          ?trailing,
        ],
      ),
    );

    final add = FilledButton.tonalIcon(
      onPressed: () => showAddCardSheet(context),
      icon: const Icon(Icons.add_card),
      label: Text(l10n.actionAddCard),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myCardsTitle)),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _PrivacyNote()),
          SliverToBoxAdapter(
            child: heading(
              l10n.myCardsYours,
              trailing: mine.isEmpty ? null : add,
            ),
          ),
          if (mine.isEmpty)
            SliverToBoxAdapter(
              child: MessageView(
                icon: Icons.credit_card,
                message: l10n.myCardsEmpty,
                actionLabel: l10n.actionAddCard,
                onAction: () => showAddCardSheet(context),
              ),
            )
          else
            switch ((products, banks)) {
              (AsyncData(value: final all), AsyncData(value: final bankList)) =>
                SliverList.list(
                  children: [
                    for (final id in mine)
                      if (all.where((p) => p.id == id).firstOrNull
                          case final product?)
                        _CardRow(
                          product: product,
                          bank: bankList
                              .where((b) => b.id == product.bankId)
                              .firstOrNull,
                        ),
                  ],
                ),
              (AsyncError(:final error), _) ||
              (_, AsyncError(:final error)) => SliverToBoxAdapter(
                child: InlineErrorBanner(
                  failure: error is AppFailure
                      ? error
                      : const UnexpectedFailure(),
                  onRetry: () => ref
                    ..invalidate(cardProductsProvider)
                    ..invalidate(banksProvider),
                ),
              ),
              _ => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsetsDirectional.all(BrandSpacing.s5),
                  child: SkeletonBox(height: 48),
                ),
              ),
            },
          if (mine.isNotEmpty) ...[
            SliverToBoxAdapter(child: heading(l10n.myCardsDeals)),
            PagedDealSlivers(
              query: CardDeals(mine, cityId: ref.watch(homeCityProvider)),
              emptyMessage: l10n.myCardsNoDeals,
            ),
          ],
        ],
      ),
    );
  }
}

/// What My Cards never asks for, said up front.
class _PrivacyNote extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s5,
        BrandSpacing.s4,
        BrandSpacing.s5,
        0,
      ),
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BrandRadii.card,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BrandSpacing.s4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: BrandSpacing.s4),
              Expanded(
                child: Text(
                  context.l10n.myCardsPrivacy,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _cardName(BuildContext context, CardProduct product, Bank? bank) {
  final l10n = context.l10n;
  final kind = switch (product.kind) {
    CardKind.credit => l10n.cardKindCredit,
    CardKind.debit => l10n.cardKindDebit,
    CardKind.prepaid => l10n.cardKindPrepaid,
  };
  return l10n.cardName(bank?.shortName ?? '', product.name, kind);
}

class _CardRow extends ConsumerWidget {
  const new({required this.product, required this.bank});

  final CardProduct product;
  final Bank? bank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = _cardName(context, product, bank);
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: BrandSpacing.s5,
        end: BrandSpacing.s2,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.credit_card,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: BrandSpacing.s4),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: BrandSpacing.s3,
              ),
              child: Text(name, style: theme.textTheme.bodyLarge),
            ),
          ),
          IconButton(
            tooltip: l10n.actionRemoveCard(name),
            icon: const Icon(Icons.close),
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              final toast = l10n.cardRemovedToast(name);
              await ref.read(myCardsProvider.notifier).remove(product.id);
              messenger
                ?..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(toast)));
            },
          ),
        ],
      ),
    );
  }
}

/// Adds a card in two steps: the bank, then the card type.
Future<void> showAddCardSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const AddCardSheet(),
    );

class AddCardSheet extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<AddCardSheet> {
  Bank? _bank;
  bool _full = false;

  Future<void> _pick(CardProduct product) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final toast = context.l10n.cardAddedToast(
      _cardName(context, product, _bank),
    );
    final added = await ref.read(myCardsProvider.notifier).add(product.id);
    if (!mounted) return;
    if (!added) {
      setState(() => _full = true);
      return;
    }
    navigator.pop();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(toast)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final bank = _bank;
    final mine = ref.watch(myCardsProvider);

    Widget choice({
      required String title,
      required VoidCallback? onTap,
      String? subtitle,
      Widget? trailing,
    }) => InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BrandSpacing.s5,
            vertical: BrandSpacing.s3,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );

    Widget body;
    if (bank == null) {
      body = switch (ref.watch(banksProvider)) {
        AsyncData(:final value) => Column(
          children: [
            for (final b in value)
              choice(
                title: b.shortName,
                subtitle: b.name(urdu: urdu) == b.shortName
                    ? null
                    : b.name(urdu: urdu),
                onTap: () => setState(() => _bank = b),
                trailing: const ExcludeSemantics(
                  child: Icon(Icons.chevron_right),
                ),
              ),
          ],
        ),
        AsyncError(:final error) => InlineErrorBanner(
          failure: error is AppFailure ? error : const UnexpectedFailure(),
          onRetry: () => ref.invalidate(banksProvider),
        ),
        _ => const SkeletonBox(height: 56),
      };
    } else {
      body = switch (ref.watch(cardProductsProvider)) {
        AsyncData(:final value) => Column(
          children: [
            for (final p in value.where((p) => p.bankId == bank.id))
              choice(
                title: p.name,
                subtitle:
                    '${p.network.label} · ${switch (p.kind) {
                      CardKind.credit => l10n.cardKindCredit,
                      CardKind.debit => l10n.cardKindDebit,
                      CardKind.prepaid => l10n.cardKindPrepaid,
                    }}',
                // Already added: shown, not offered again.
                onTap: mine.contains(p.id) ? null : () => _pick(p),
                trailing: mine.contains(p.id)
                    ? Semantics(
                        container: true,
                        label: l10n.cardAlreadyAdded,
                        child: const ExcludeSemantics(child: Icon(Icons.check)),
                      )
                    : null,
              ),
          ],
        ),
        AsyncError(:final error) => InlineErrorBanner(
          failure: error is AppFailure ? error : const UnexpectedFailure(),
          onRetry: () => ref.invalidate(cardProductsProvider),
        ),
        _ => const SkeletonBox(height: 56),
      };
    }

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.only(bottom: BrandSpacing.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BrandSpacing.s3,
            ),
            child: Row(
              children: [
                if (bank != null)
                  IconButton(
                    tooltip: l10n.actionBack,
                    icon: const BackButtonIcon(),
                    onPressed: () => setState(() => _bank = null),
                  )
                else
                  const SizedBox(width: BrandSpacing.s3),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      bank == null
                          ? l10n.addCardPickBank
                          : l10n.addCardPickType(bank.shortName),
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_full)
            Padding(
              padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.myCardsFull(MyCards.max),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
          const SizedBox(height: BrandSpacing.s3),
          body,
        ],
      ),
    );
  }
}
