import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';

/// The legal documents bundled with the app, by name.
enum LegalDoc { terms, privacy }

/// The bundled text of a legal document in a language.
final FutureProviderFamily<String, (LegalDoc, String)> legalTextProvider =
    FutureProvider.autoDispose.family<String, (LegalDoc, String)>(
      (ref, key) =>
          rootBundle.loadString('assets/legal/${key.$1.name}_${key.$2}.txt'),
    );

/// A legal page in the app's language: bundled text (no network needed),
/// where `# ` lines are headings and `- ` lines are list items.
class LegalScreen extends ConsumerWidget {
  const new({required this.doc, super.key});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lang = ref.watch(localeControllerProvider).languageCode;
    final title = doc == LegalDoc.terms ? l10n.legalTerms : l10n.legalPrivacy;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: switch (ref.watch(legalTextProvider((doc, lang)))) {
        AsyncData(:final value) => _LegalText(value),
        AsyncError() => ErrorView(
          failure: const UnexpectedFailure(),
          onRetry: () => ref.invalidate(legalTextProvider((doc, lang))),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _LegalText extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = [
      for (final line in text.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ];
    return ListView(
      padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
      children: [
        for (final (i, line) in lines.indexed)
          if (line.startsWith('# '))
            Padding(
              padding: EdgeInsetsDirectional.only(
                top: i == 0 ? 0 : BrandSpacing.s6,
                bottom: BrandSpacing.s2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  line.substring(2),
                  style: i == 0
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.titleMedium,
                ),
              ),
            )
          else if (line.startsWith('- '))
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: BrandSpacing.s3,
                bottom: BrandSpacing.s2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(child: Text('•  ')),
                  Expanded(
                    child: Text(
                      line.substring(2),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsetsDirectional.only(
                bottom: BrandSpacing.s3,
              ),
              child: Text(line, style: theme.textTheme.bodyMedium),
            ),
      ],
    );
  }
}
