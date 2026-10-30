import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/theme/theme_mode_controller.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/home/application/home_providers.dart';
import 'package:sale_lagi_hai/features/home/presentation/city_picker.dart';
import 'package:sale_lagi_hai/features/profile/presentation/language_choice.dart';

/// Settings (screen S18): language, city, appearance, then notifications,
/// privacy, legal and about.
class SettingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final urdu = AppLocales.isRtl(ref.watch(localeControllerProvider));
    final cityId = ref.watch(homeCityProvider);
    final cities = ref.watch(citiesProvider).value ?? const [];
    final city = cities.where((c) => c.id == cityId).firstOrNull;
    final theme = ref.watch(themeModeProvider);

    Widget heading(String text) => ListTile(
      title: Semantics(
        header: true,
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );

    Widget link(IconData icon, String title, VoidCallback onTap) => ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          const LanguageChoice(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.location_city_outlined),
            title: Text(l10n.settingsCity),
            subtitle: Text(city?.name(urdu: urdu) ?? l10n.allPakistan),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => pickCity(context, ref),
          ),
          const Divider(),
          heading(l10n.settingsTheme),
          RadioGroup<AppThemeMode>(
            groupValue: theme,
            onChanged: (mode) {
              if (mode != null) {
                unawaited(ref.read(themeModeProvider.notifier).select(mode));
              }
            },
            child: Column(
              children: [
                for (final (mode, label) in [
                  (AppThemeMode.system, l10n.themeSystem),
                  (AppThemeMode.light, l10n.themeLight),
                  (AppThemeMode.dark, l10n.themeDark),
                ])
                  RadioListTile<AppThemeMode>(value: mode, title: Text(label)),
              ],
            ),
          ),
          const Divider(),
          link(
            Icons.notifications_outlined,
            l10n.settingsNotifications,
            () => const NotificationSettingsRoute().push<void>(context),
          ),
          link(
            Icons.shield_outlined,
            l10n.settingsPrivacy,
            () => const PrivacyRoute().push<void>(context),
          ),
          const Divider(),
          heading(l10n.settingsLegal),
          link(
            Icons.description_outlined,
            l10n.legalTerms,
            () => const LegalRoute(doc: 'terms').push<void>(context),
          ),
          link(
            Icons.privacy_tip_outlined,
            l10n.legalPrivacy,
            () => const LegalRoute(doc: 'privacy').push<void>(context),
          ),
          const Divider(),
          link(
            Icons.info_outline,
            l10n.settingsAbout,
            () => const AboutRoute().push<void>(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
