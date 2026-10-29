import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';

/// Saved tab. Saved deals arrive in 4.8.
class SavedScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSaved)),
      body: MessageView(icon: Icons.bookmark_border, message: l10n.emptySaved),
    );
  }
}
