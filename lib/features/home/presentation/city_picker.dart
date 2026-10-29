import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/widgets/app_bottom_sheet.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

/// The city sheet (Home's city button, Settings): "All Pakistan" and every
/// city, the current one checked. Picking one changes the shopper's city.
Future<void> pickCity(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final urdu = AppLocales.isRtl(ref.read(localeControllerProvider));
  final cities = await ref
      .read(citiesProvider.future)
      .then((c) => c, onError: (_) => const <City>[]);
  if (!context.mounted) return;
  final current = ref.read(homeCityProvider);
  final picked = await showAppBottomSheet<({String? id})>(
    context: context,
    title: l10n.actionChangeCity,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
              onTap: () => Navigator.of(context).pop((id: id)),
            ),
          ),
      ],
    ),
  );
  if (picked != null) {
    await ref.read(preferencesProvider.notifier).setCity(picked.id);
  }
}
