import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/network_picture.dart';

/// A brand's logo, whole and centred on a white tile, for a deal without a
/// photo of its own. White in both themes: logos are drawn for a light
/// background. Decorative, like the photo it stands in for.
class BrandLogo extends StatelessWidget {
  const new(this.url, {required this.fallback, super.key});

  final String url;

  /// Shown while the logo can't be loaded: the brand plate.
  final Widget fallback;

  @override
  Widget build(BuildContext context) => NetworkPicture(
    url,
    fit: BoxFit.contain,
    fallback: fallback,
    frame: (child) => ColoredBox(
      color: BrandColors.surma0,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
        child: child,
      ),
    ),
  );
}
