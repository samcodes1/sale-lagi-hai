import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/deal_time_labels.dart';
import 'package:sale_lagi_hai/core/l10n/failure_messages.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/links/open_link.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_bottom_sheet.dart';
import 'package:sale_lagi_hai/design_system/widgets/content_text.dart';
import 'package:sale_lagi_hai/design_system/widgets/deal_labels.dart';
import 'package:sale_lagi_hai/design_system/widgets/network_picture.dart';
import 'package:sale_lagi_hai/design_system/widgets/price_text.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/deals/application/deal_providers.dart';
import 'package:sale_lagi_hai/features/deals/application/report_providers.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal.dart';
import 'package:sale_lagi_hai/features/deals/domain/deal_detail.dart';
import 'package:sale_lagi_hai/features/deals/presentation/deal_card_mapper.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';

/// The deal page (screen S05, UX flow F2): image, offer, price, validity,
/// verified time, promo code, description and terms, where to use it
/// (outlets with directions and call), the cards it needs, the source, and
/// Save, Share on WhatsApp and Report. An ended deal still opens, marked
/// as ended. [dealId] was validated by the route.
class DealDetailScreen extends ConsumerWidget {
  const new({required this.dealId, super.key});

  final String dealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final detail = ref.watch(dealDetailProvider(dealId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dealTitle)),
      body: switch (detail) {
        AsyncData(:final value) => _Body(value),
        AsyncError(:final error) => ErrorView(
          failure: error is AppFailure ? error : const UnexpectedFailure(),
          onRetry: () => ref.invalidate(dealDetailProvider(dealId)),
        ),
        _ => const Padding(
          padding: EdgeInsetsDirectional.all(BrandSpacing.s5),
          child: DealCardSkeleton(),
        ),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const new(this.detail);

  final DealDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final deal = detail.deal;
    final now = ref.watch(clockProvider)();
    final ended =
        deal.status == DealStatus.expired ||
        (deal.endsAt != null && !deal.endsAt!.isAfter(now));
    final offer = deal.offer(urdu: urdu);
    final image = ref.watch(dealImageUrlProvider)(deal.imagePath);
    final description = detail.description(urdu: urdu);
    final terms = detail.terms(urdu: urdu);
    final offerUrl = deal.url ?? detail.sourceUrl;

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsetsDirectional.only(top: BrandSpacing.s7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: BrandSpacing.s3),
          ...children,
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsetsDirectional.only(bottom: BrandSpacing.s10),
      children: [
        if (detail.cachedAt case final at?)
          OfflineBanner(
            updatedLabel: DealTimeLabels(
              l10n,
              AppFormatters.of(context),
            ).updated(at, now: now),
            // The phone may say online while the server can't be reached:
            // a way to ask again (QA P4-R2-2).
            onRetry: () => ref.invalidate(dealDetailProvider(deal.id)),
          ),
        if (ended)
          Semantics(
            liveRegion: true,
            child: Material(
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(Icons.history, color: scheme.onSurface),
                    ),
                    const SizedBox(width: BrandSpacing.s4),
                    Expanded(child: Text(l10n.dealEndedBanner)),
                  ],
                ),
              ),
            ),
          ),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: image == null
              ? ColoredBox(
                  color: scheme.surfaceContainerHigh,
                  child: Center(
                    child: ExcludeSemantics(
                      child: Text(
                        deal.brand(urdu: urdu).characters.first,
                        style: theme.textTheme.displayMedium,
                      ),
                    ),
                  ),
                )
              : NetworkPicture(
                  image,
                  fallback: ColoredBox(color: scheme.surfaceContainerHigh),
                ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BrandSpacing.s5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: BrandSpacing.s5),
              Wrap(
                spacing: BrandSpacing.s3,
                runSpacing: BrandSpacing.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (offer != null) DiscountBadge(offer: offer),
                  if (deal.isFeatured) const FeaturedLabel(),
                ],
              ),
              const SizedBox(height: BrandSpacing.s3),
              ContentText(
                deal.brand(urdu: urdu),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Semantics(
                header: true,
                child: ContentText(
                  deal.title(urdu: urdu),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              if (deal.pricePkr case final price?) ...[
                const SizedBox(height: BrandSpacing.s3),
                PriceText(
                  price: price,
                  oldPrice: deal.originalPricePkr,
                  large: true,
                ),
              ],
              const SizedBox(height: BrandSpacing.s4),
              Wrap(
                spacing: BrandSpacing.s5,
                runSpacing: BrandSpacing.s2,
                children: [
                  if (!ended && deal.startsAt.isAfter(now))
                    Text(
                      l10n.dealStartsOn(
                        AppFormatters.of(context)
                            .shortDate(deal.startsAt.toLocal()),
                      ),
                    )
                  else
                    ExpiryTag(endsAt: deal.endsAt),
                  if (deal.verifiedAt case final verified?)
                    VerifiedTag(verifiedAt: verified),
                ],
              ),
              const SizedBox(height: BrandSpacing.s5),
              _Actions(deal: deal, offerUrl: offerUrl),
              if (deal.promoCode case final code? when !ended)
                section(l10n.dealPromoCode, [_PromoCode(code)]),
              if (deal.cardBanks.isNotEmpty)
                section(l10n.dealCards, [
                  Wrap(
                    spacing: BrandSpacing.s3,
                    runSpacing: BrandSpacing.s3,
                    children: [
                      for (final bank in deal.cardBanks)
                        CardNameChip(name: bank),
                    ],
                  ),
                ]),
              if (description != null)
                section(l10n.dealAbout, [
                  ContentText(description, style: theme.textTheme.bodyLarge),
                ]),
              if (terms != null)
                section(l10n.dealTerms, [
                  ContentText(terms, style: theme.textTheme.bodyMedium),
                ]),
              section(l10n.dealWhere, [_Where(detail)]),
              if (offerUrl != null) ...[
                const SizedBox(height: BrandSpacing.s5),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => openLink(
                      context,
                      ref.read(linkServiceProvider).openWeb(offerUrl),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.actionSeeSource),
                  ),
                ),
              ],
              const Divider(height: BrandSpacing.s9),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _report(context, ref, deal.id),
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(l10n.actionReportProblem),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const new({required this.deal, required this.offerUrl});

  final Deal deal;
  final String? offerUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final saved = ref.watch(
      savedDealsProvider.select((ids) => ids.contains(deal.id)),
    );
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final offerUrl = this.offerUrl;
    return Wrap(
      spacing: BrandSpacing.s3,
      runSpacing: BrandSpacing.s3,
      children: [
        if (offerUrl != null)
          FilledButton.icon(
            onPressed: () => openLink(
              context,
              ref.read(linkServiceProvider).openWeb(offerUrl),
            ),
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(l10n.actionOpenOffer),
          ),
        Builder(
          builder: (context) {
            Future<void> toggle() async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              final message = saved ? l10n.unsavedToast : l10n.savedToast;
              await ref.read(savedDealsProvider.notifier).toggle(deal.id);
              messenger
                ?..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            }

            // One node that screen readers announce as a toggle, with the
            // label on screen (QA 4.4 BUG-6), like the Follow button.
            return Semantics(
              // Its own node: with the button's excluded, it would merge
              // into whatever is around it.
              container: true,
              toggled: saved,
              label: saved ? l10n.actionUnsave : l10n.actionSave,
              button: true,
              excludeSemantics: true,
              onTap: toggle,
              child: OutlinedButton.icon(
                onPressed: toggle,
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
                label: Text(saved ? l10n.actionUnsave : l10n.actionSave),
              ),
            );
          },
        ),
        OutlinedButton.icon(
          onPressed: () {
            final offer = deal.offer(urdu: urdu);
            final text = l10n.shareDealText(
              deal.brand(urdu: urdu),
              offer == null ? '' : dealOfferText(context, offer),
              deal.title(urdu: urdu),
            );
            final link = this.offerUrl;
            unawaited(
              openLink(
                context,
                ref
                    .read(linkServiceProvider)
                    .shareOnWhatsApp(link == null ? text : '$text $link'),
              ),
            );
          },
          icon: const Icon(Icons.share_outlined),
          label: Text(l10n.actionShareWhatsApp),
        ),
      ],
    );
  }
}

class _PromoCode extends StatelessWidget {
  const new(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BrandRadii.button,
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: BrandSpacing.s4,
                vertical: BrandSpacing.s3,
              ),
              // Codes read left to right in both languages.
              child: SelectableText(
                code,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: BrandSpacing.s3),
        IconButton(
          tooltip: l10n.actionCopyCode,
          icon: const Icon(Icons.copy),
          onPressed: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            var copied = true;
            try {
              await Clipboard.setData(ClipboardData(text: code));
            } on PlatformException {
              copied = false;
            }
            messenger
              ?..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    copied ? l10n.codeCopiedToast : l10n.linkFailed,
                  ),
                ),
              );
          },
        ),
      ],
    );
  }
}

/// Online only, or the outlets (with directions and call), or a note.
class _Where extends ConsumerWidget {
  const new(this.detail);

  final DealDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final links = ref.read(linkServiceProvider);
    if (detail.deal.scope == DealScope.online) {
      return Text(l10n.dealOnlineOnly, style: theme.textTheme.bodyLarge);
    }
    if (detail.cachedAt != null) {
      return Text(l10n.dealOfflineDetails, style: theme.textTheme.bodyLarge);
    }
    if (detail.outlets.isEmpty) {
      return Text(
        detail.deal.scope == DealScope.nationwide
            ? l10n.dealEverywhere
            : l10n.dealNoOutlets,
        style: theme.textTheme.bodyLarge,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (detail.deal.scope == DealScope.nationwide)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: BrandSpacing.s3),
            child: Text(l10n.dealEverywhere, style: theme.textTheme.bodyMedium),
          ),
        for (final outlet in detail.outlets)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: BrandSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ContentText(outlet.name, style: theme.textTheme.titleSmall),
                ContentText(
                  outlet.address,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Wrap(
                  spacing: BrandSpacing.s3,
                  children: [
                    TextButton.icon(
                      onPressed: () => openLink(
                        context,
                        links.openMap(
                          outlet.latitude,
                          outlet.longitude,
                          outlet.name,
                        ),
                      ),
                      icon: const Icon(Icons.directions_outlined),
                      label: Text(l10n.actionDirections),
                    ),
                    if (outlet.phone case final phone?)
                      TextButton.icon(
                        onPressed: () => openLink(context, links.call(phone)),
                        icon: const Icon(Icons.call_outlined),
                        label: Text(l10n.actionCall),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// UX flow F5: a reason, an optional note, then thanks. Guests sign in
/// first (reports need an account, so they can't be faked in bulk).
Future<void> _report(BuildContext context, WidgetRef ref, String dealId) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (ref.read(authRepositoryProvider).currentUser == null) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.reportSignIn)));
    final signedIn = await const SignInRoute().push<bool>(context);
    if (signedIn != true || !context.mounted) return;
  }
  final sent = await showAppBottomSheet<ReportOutcome>(
    context: context,
    title: l10n.reportTitle,
    builder: (context) => _ReportSheet(dealId: dealId),
  );
  if (sent == null) return;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          sent == ReportOutcome.alreadyReported
              ? l10n.reportAlready
              : l10n.reportThanks,
        ),
      ),
    );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const new({required this.dealId});

  final String dealId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref.read(reportDealProvider)(
      widget.dealId,
      reason,
      note: _note.text,
    );
    if (!mounted) return;
    final l10n = context.l10n;
    switch (result) {
      case Success(:final value):
        Navigator.of(context).pop(value);
      case Failure(failure: ValidationFailure(:final fieldErrors)):
        setState(() {
          _sending = false;
          _error = fieldErrors['note'] == 'card_number'
              ? l10n.reportNoteCardNumber
              : l10n.reportNoteRequired;
        });
      case Failure(:final failure):
        setState(() {
          _sending = false;
          _error = failure.message(l10n);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      ReportReason.expired: l10n.reportExpired,
      ReportReason.wrongPrice: l10n.reportWrongPrice,
      ReportReason.wrongPlace: l10n.reportWrongPlace,
      ReportReason.closed: l10n.reportClosed,
      ReportReason.spam: l10n.reportSpam,
      ReportReason.offensive: l10n.reportOffensive,
      ReportReason.other: l10n.reportOther,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<ReportReason>(
          groupValue: _reason,
          onChanged: (value) => setState(() => _reason = value),
          child: Column(
            children: [
              for (final MapEntry(key: reason, value: label) in labels.entries)
                RadioListTile<ReportReason>(value: reason, title: Text(label)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: BrandSpacing.s5,
          ),
          child: TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              labelText: l10n.reportNoteLabel,
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
          child: FilledButton(
            onPressed: _reason == null || _sending ? null : _send,
            child: Text(l10n.actionSend),
          ),
        ),
      ],
    );
  }
}
