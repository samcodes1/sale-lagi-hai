import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// The legal documents bundled with the app, by name.
enum LegalDoc { terms, privacy }

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
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/legal/${doc.name}_$lang.txt'),
        builder: (context, snapshot) {
          final text = snapshot.data;
          if (text == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _LegalText(text);
        },
      ),
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
