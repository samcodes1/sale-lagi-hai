import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/features/onboarding/application/locate_city.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/onboarding_scaffold.dart';

/// What "Use my location" last found, as a message for the shopper.
enum _Detection {
  detecting,
  found,
  notCovered,
  denied,
  blocked,
  off,
  unavailable,
}

/// Step 2: location instead of a city list. The screen says what location
/// is for before Android's own dialog appears (Play's prominent disclosure
/// for location), and the dialog only appears when the shopper taps "Use
/// my location". "Not now", a denial or a place far from every city all
/// carry on with deals from all over Pakistan; the city can be changed on
/// Home at any time.
class LocationStep extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends ConsumerState<LocationStep> {
  _Detection? _detection;
  String? _cityName;

  Future<void> _detect() async {
    if (_detection == _Detection.detecting) return;
    setState(() => _detection = _Detection.detecting);
    final urdu = AppLocales.isRtl(ref.read(localeControllerProvider));
    final (:outcome, :city) = await locateCity(ref);
    if (!mounted) return;
    setState(() {
      _cityName = city?.name(urdu: urdu);
      _detection = switch (outcome) {
        Located() =>
          city == null ? _Detection.notCovered : _Detection.found,
        LocationDenied(:final permanently) =>
          permanently ? _Detection.blocked : _Detection.denied,
        LocationServiceOff() => _Detection.off,
        LocationUnavailable() => _Detection.unavailable,
      };
    });
  }

  String? _message(AppLocalizations l10n) => switch (_detection) {
    null => null,
    _Detection.detecting => l10n.cityDetecting,
    _Detection.found => l10n.cityDetected(_cityName!),
    _Detection.notCovered => l10n.locationStepNotCovered,
    _Detection.denied => l10n.locationStepDenied,
    _Detection.blocked => l10n.locationStepBlocked,
    _Detection.off => l10n.locationStepOff,
    _Detection.unavailable => l10n.locationStepUnavailable,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final message = _message(l10n);
    final detecting = _detection == _Detection.detecting;
    final answered = _detection != null && !detecting;
    void next() => const WelcomeInterestsRoute().push<void>(context);

    return OnboardingScaffold(
      step: 2,
      title: l10n.locationStepTitle,
      intro: l10n.locationStepBody,
      onSkip: next,
      slivers: [
        SliverPadding(
          padding: onboardingContentPadding,
          sliver: SliverList.list(
            children: [
              for (final (icon, text) in [
                (Icons.near_me_outlined, l10n.locationStepApproximate),
                (Icons.phone_android_outlined, l10n.locationStepInUse),
                (Icons.tune, l10n.locationStepChange),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: BrandSpacing.s4,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Icon(icon, color: theme.colorScheme.secondary),
                      ),
                      const SizedBox(width: BrandSpacing.s4),
                      Expanded(
                        child: Text(text, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ),
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
                        child: Text(message, style: theme.textTheme.bodyMedium),
                      ),
              ),
              // Browsers have no app settings page (QA 4.1 BUG-7).
              if (_detection == _Detection.blocked && !kIsWeb)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: ref.read(locationServiceProvider).openAppSettings,
                    child: Text(l10n.actionOpenSettings),
                  ),
                ),
            ],
          ),
        ),
      ],
      primaryLabel: answered ? l10n.actionContinue : l10n.actionUseLocation,
      onPrimary: detecting ? null : (answered ? next : _detect),
      // Before asking: Not now. After a miss that may work next time
      // (denied, off, no fix): try again.
      secondaryLabel: switch (_detection) {
        null || _Detection.detecting => l10n.actionNotNow,
        _Detection.found || _Detection.blocked => null,
        _ => l10n.actionUseLocation,
      },
      onSecondary: switch (_detection) {
        null => next,
        _Detection.detecting || _Detection.found || _Detection.blocked => null,
        _ => _detect,
      },
    );
  }
}
