import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';

/// Placeholder until sub-phase 4.5. [slug] has already been validated by
/// the route.
class BrandScreen extends StatelessWidget {
  const new({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.brandTitle)),
      body: MessageView(
        icon: Icons.storefront_outlined,
        message: l10n.comingSoon,
      ),
    );
  }
}
