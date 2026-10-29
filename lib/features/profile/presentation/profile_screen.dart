import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';

/// Profile tab. For now: the language choice (and, outside production, a
/// link to the theme preview). Account, cards and notification settings
/// arrive in Phase 4.
class ProfileScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeControllerProvider);
    final isProduction = ref.watch(appConfigProvider).flavor.isProduction;

    void select(Locale? value) {
      if (value != null) {
        // Saving is fire-and-forget; failures are logged by the controller.
        unawaited(ref.read(localeControllerProvider.notifier).select(value));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
      body: ListView(
        children: [
          ListTile(
            title: Semantics(
              header: true,
              child: Text(
                l10n.settingsLanguage,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          RadioGroup<Locale>(
            groupValue: locale,
            onChanged: select,
            child: Column(
              children: [
                for (final (option, label) in [
                  (AppLocales.english, l10n.languageEnglish),
                  (AppLocales.urdu, l10n.languageUrdu),
                ])
                  RadioListTile<Locale>(value: option, title: Text(label)),
              ],
            ),
          ),
          if (!isProduction) ...[
            const Divider(),
            // Developer tool: its label is not localized on purpose.
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Theme preview (dev)'),
              onTap: () => const ThemePreviewRoute().go(context),
            ),
          ],
        ],
      ),
    );
  }
}
