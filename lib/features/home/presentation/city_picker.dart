import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_bottom_sheet.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/locate_city.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

/// The city sheet (Home's city button, Settings): "Use my location", "All
/// Pakistan" and every city, the current one checked. Picking one changes
/// the shopper's city; "Use my location" finds the nearest one (its
/// subtitle says what location is for before Android asks).
Future<void> pickCity(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final urdu = AppLocales.isRtl(ref.read(localeControllerProvider));
  final cities = await ref
      .read(citiesProvider.future)
      .then((c) => c, onError: (_) => const <City>[]);
  if (!context.mounted) return;
  final current = ref.read(homeCityProvider);
  final picked = await showAppBottomSheet<({String? id, bool locate})>(
    context: context,
    title: l10n.actionChangeCity,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const ExcludeSemantics(child: Icon(Icons.my_location)),
          title: Text(l10n.actionUseLocation),
          subtitle: Text(l10n.cityPickerLocationHint),
          onTap: () => Navigator.of(context).pop((id: null, locate: true)),
        ),
        const Divider(height: 1),
        for (final (id, name, live) in [
          (null, l10n.allPakistan, true),
          for (final c in cities) (c.id, c.name(urdu: urdu), c.isLive),
        ])
          Semantics(
            selected: id == current,
            inMutuallyExclusiveGroup: true,
            child: ListTile(
              selected: id == current,
              title: Text(name),
              subtitle: live ? null : Text(l10n.cityLocalSoon),
              trailing: id == current
                  ? const ExcludeSemantics(child: Icon(Icons.check))
                  : null,
              onTap: () => Navigator.of(context).pop((id: id, locate: false)),
            ),
          ),
      ],
    ),
  );
  if (picked == null) return;
  if (!picked.locate) {
    await ref.read(preferencesProvider.notifier).setCity(picked.id);
    return;
  }
  final (:outcome, :city) = await locateCity(ref);
  if (!context.mounted) return;
  final message = switch (outcome) {
    Located() when city != null => l10n.cityDetected(city.name(urdu: urdu)),
    Located() => l10n.locationStepNotCovered,
    LocationDenied(permanently: true) => l10n.locationStepBlocked,
    LocationDenied() => l10n.locationStepDenied,
    LocationServiceOff() => l10n.locationStepOff,
    LocationUnavailable() => l10n.locationStepUnavailable,
  };
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
