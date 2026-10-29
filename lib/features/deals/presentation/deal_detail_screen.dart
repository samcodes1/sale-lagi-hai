import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';

/// Placeholder until sub-phase 4.4. [dealId] has already been validated by
/// the route.
class DealDetailScreen extends StatelessWidget {
  const new({required this.dealId, super.key});

  final String dealId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dealTitle)),
      body: MessageView(
        icon: Icons.local_offer_outlined,
        message: l10n.comingSoon,
      ),
    );
  }
}
