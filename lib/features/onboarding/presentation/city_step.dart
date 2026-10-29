import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/onboarding_scaffold.dart';

/// What "Detect my city" last found, as a message for the shopper.
enum _Detection {
  detecting,
  found,
  notCovered,
  denied,
  blocked,
  off,
  unavailable,
}

/// Step 2: the shopper's city. "Detect my city" asks for approximate
/// location only when tapped, and matches it to the nearest city on the
/// phone (the location is not sent anywhere or kept). Picking from the
/// list always works, with or without location.
class CityStep extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CityStep> createState() => _CityStepState();
}

class _CityStepState extends ConsumerState<CityStep> {
  _Detection? _detection;
  City? _found;

  Future<void> _detect(List<City> cities) async {
    if (_detection == _Detection.detecting) return;
    setState(() => _detection = _Detection.detecting);
    LocationOutcome outcome;
    try {
      outcome = await ref.read(locationServiceProvider).approximateLocation();
    } on Object {
      // Never leave the button spinning (QA 4.1 BUG-2).
      outcome = const LocationUnavailable();
    }
    if (!mounted) return;
    var detection = _Detection.unavailable;
    City? found;
    switch (outcome) {
      case Located(:final latitude, :final longitude):
        found = nearestCity(cities, latitude, longitude);
        detection = found == null ? _Detection.notCovered : _Detection.found;
      case LocationDenied(:final permanently):
        detection = permanently ? _Detection.blocked : _Detection.denied;
      case LocationServiceOff():
        detection = _Detection.off;
      case LocationUnavailable():
        detection = _Detection.unavailable;
    }
    if (found != null) {
      await ref.read(preferencesProvider.notifier).setCity(found.id);
    }
    if (!mounted) return;
    setState(() {
      _detection = detection;
      _found = found;
    });
  }

  String? _message(AppLocalizations l10n, {required bool urdu}) =>
      switch (_detection) {
        null => null,
        _Detection.detecting => l10n.cityDetecting,
        _Detection.found => l10n.cityDetected(_found!.name(urdu: urdu)),
        _Detection.notCovered => l10n.cityNotCovered,
        _Detection.denied => l10n.cityLocationDenied,
        _Detection.blocked => l10n.cityLocationBlocked,
        _Detection.off => l10n.cityLocationOff,
        _Detection.unavailable => l10n.cityLocationUnavailable,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final cities = ref.watch(citiesProvider);
    final selectedId = ref.watch(preferencesProvider.select((p) => p.cityId));
    final message = _message(l10n, urdu: urdu);
    void next() => const WelcomeInterestsRoute().push<void>(context);

    return OnboardingScaffold(
      step: 2,
      title: l10n.cityTitle,
      intro: l10n.cityBody,
      onSkip: next,
      slivers: [
        SliverPadding(
          padding: onboardingContentPadding,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      cities.hasValue && _detection != _Detection.detecting
                      ? () => _detect(cities.requireValue)
                      : null,
                  icon: _detection == _Detection.detecting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(l10n.actionDetectCity),
                ),
                // Announced without moving focus.
                Semantics(
                  liveRegion: true,
                  child: message == null
                      ? const SizedBox(height: BrandSpacing.s5)
                      : Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            vertical: BrandSpacing.s4,
                          ),
                          child: Text(
                            message,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                ),
                // Browsers have no app settings page (QA 4.1 BUG-7).
                if (_detection == _Detection.blocked && !kIsWeb)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: ref
                          .read(locationServiceProvider)
                          .openAppSettings,
                      child: Text(l10n.actionOpenSettings),
                    ),
                  ),
              ],
            ),
          ),
        ),
        switch (cities) {
          AsyncData(:final value) => SliverList.builder(
            itemCount: value.length,
            itemBuilder: (context, i) => _CityTile(
              city: value[i],
              urdu: urdu,
              selected: value[i].id == selectedId,
              onTap: () =>
                  ref.read(preferencesProvider.notifier).setCity(value[i].id),
            ),
          ),
          AsyncError(:final error) => SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(
              failure: error is AppFailure ? error : const UnexpectedFailure(),
              onRetry: () => ref.invalidate(citiesProvider),
            ),
          ),
          _ => SliverList.list(
            children: [
              for (var i = 0; i < 6; i++)
                const Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    horizontal: BrandSpacing.s5,
                    vertical: BrandSpacing.s3,
                  ),
                  child: SkeletonBox(height: 40),
                ),
            ],
          ),
        },
      ],
      primaryLabel: l10n.actionContinue,
      onPrimary: next,
    );
  }
}

class _CityTile extends StatelessWidget {
  const new({
    required this.city,
    required this.urdu,
    required this.selected,
    required this.onTap,
  });

  final City city;
  final bool urdu;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: BrandSpacing.s5,
        ),
        selected: selected,
        title: Text(city.name(urdu: urdu)),
        subtitle: city.isLive ? null : Text(context.l10n.cityLocalSoon),
        trailing: ExcludeSemantics(
          child: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? scheme.secondary : scheme.onSurfaceVariant,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
