import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/widgets/brand_logo.dart';

/// A brand's logo in a small rounded tile with a hairline, or its first
/// letter while there is no logo (or it can't load). Decorative: the
/// brand's name is always next to it.
class BrandAvatar extends StatelessWidget {
  const new({
    required this.name,
    required this.logoUrl,
    this.size = 40,
    super.key,
  });

  final String name;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.all(Radius.circular(size * 0.3));
    final initial = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          name.isEmpty ? '' : name.characters.first.toUpperCase(),
          style:
              (size >= 56
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.titleMedium)
                  ?.copyWith(color: scheme.onSurface),
        ),
      ),
    );
    final url = logoUrl;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: url == null ? initial : BrandLogo(url, fallback: initial),
          ),
        ),
      ),
    );
  }
}
