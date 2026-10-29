import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';

/// Shown for any location the router does not know. It deliberately does
/// not show the location: links come from outside and may contain anything.
class NotFoundScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notFoundTitle)),
      body: MessageView(
        icon: Icons.link_off,
        message: l10n.notFoundBody,
        actionLabel: l10n.actionGoHome,
        onAction: () => const HomeRoute().go(context),
      ),
    );
  }
}
