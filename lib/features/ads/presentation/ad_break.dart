import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/features/ads/application/ads_providers.dart';

/// Marks leaving [child] as a natural break for a full-screen ad. Whether
/// one shows is up to the pacing rules.
class AdBreak extends ConsumerWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) ref.read(interstitialsProvider).onBreak();
    },
    child: child,
  );
}
