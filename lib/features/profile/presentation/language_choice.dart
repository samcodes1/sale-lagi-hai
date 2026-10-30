import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';

/// "Language" with English and اردو as radio choices (Profile, Settings).
class LanguageChoice extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
          onChanged: (value) {
            if (value != null) {
              // Fire-and-forget; failures are logged by the controller.
              unawaited(
                ref.read(localeControllerProvider.notifier).select(value),
              );
            }
          },
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
      ],
    );
  }
}
