import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';

/// Explore tab. Categories, brands and search arrive in 4.5 and 4.6.
class ExploreScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navExplore)),
      body: MessageView(icon: Icons.search, message: l10n.exploreHint),
    );
  }
}
