import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// A category as a rounded icon tile with its name under it (Home row,
/// Explore grid). One button for screen readers, named by the label. The
/// name wraps instead of being cut, so it grows with large text.
class CategoryTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BrandRadii.card,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(BrandSpacing.s1),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BrandRadii.card,
                ),
                child: SizedBox.square(
                  dimension: 56,
                  child: ExcludeSemantics(
                    child: Icon(icon, color: scheme.onSurface),
                  ),
                ),
              ),
              const SizedBox(height: BrandSpacing.s2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
