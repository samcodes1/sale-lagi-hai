import 'package:material_ui/material_ui.dart';

/// Pull-to-refresh for every feed.
///
/// Use this instead of [RefreshIndicator]: the Material widget ignores
/// `progressIndicatorTheme` and paints its spinner in `primary`, which is
/// Haldi yellow (1.6:1 on white). This uses Neel on the lowest surface.
class AppRefreshIndicator extends StatelessWidget {
  const new({required this.onRefresh, required this.child, super.key});

  final RefreshCallback onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      color: scheme.secondary,
      backgroundColor: scheme.surfaceContainerLowest,
      child: child,
    );
  }
}
