import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';

/// Runs a [launch] from `LinkService` and says "Couldn't open that" when it
/// fails, so a link never fails silently.
Future<void> openLink(BuildContext context, Future<bool> launch) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final message = context.l10n.linkFailed;
  if (!await launch) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
