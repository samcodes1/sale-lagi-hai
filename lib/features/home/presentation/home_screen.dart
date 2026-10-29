import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';

/// Home tab. The real feed (Trending, For you, Near me) arrives in 4.3.
class HomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: MessageView(
        icon: Icons.local_offer_outlined,
        message: l10n.emptyNearby,
      ),
    );
  }
}
