import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// A Clean grouped list: an optional heading over rows on one rounded,
/// filled block, with hairlines between them (Profile, Settings).
///
/// The rows are ordinary list tiles; the block only groups them, so each
/// keeps its own tap target and screen-reader node.
class GroupedSection extends StatelessWidget {
  const new({required this.children, this.title, super.key});

  /// Read as a heading.
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = this.title;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s4,
        BrandSpacing.s5,
        BrandSpacing.s4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                BrandSpacing.s2,
                0,
                BrandSpacing.s2,
                BrandSpacing.s2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          Material(
            color: scheme.surfaceContainerLow,
            shape: const RoundedRectangleBorder(
              borderRadius: BrandRadii.card,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, child) in children.indexed) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: BrandSpacing.s4,
                      endIndent: BrandSpacing.s4,
                      color: scheme.outlineVariant,
                    ),
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
