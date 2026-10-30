import 'package:material_ui/material_ui.dart';

/// A picture from the network, decoded at the size it is shown rather than
/// the size it was uploaded: a 2 MB photo in a card would otherwise take
/// tens of MB of memory (QA P4-P1).
class NetworkPicture extends StatelessWidget {
  const new(this.url, {required this.fallback, super.key});

  final String url;

  /// Shown while it can't be loaded.
  final Widget fallback;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final ratio = MediaQuery.devicePixelRatioOf(context);
      final width = constraints.maxWidth.isFinite
          ? (constraints.maxWidth * ratio).round()
          : null;
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: width,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => fallback,
      );
    },
  );
}
