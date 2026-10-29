import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A [TabBar] whose tabs grow with the text size.
///
/// Material's `Tab` has a fixed 46dp height, which clips Urdu labels (and
/// large Latin text) at bigger text sizes. Use this for every tab row.
///
/// Place it in the body (e.g. above a `TabBarView`), not as `AppBar.bottom`:
/// the app bar would size it from a fixed preferred height and clip it.
class AppTabBar extends StatelessWidget {
  const new({required this.labels, this.controller, super.key});

  final List<String> labels;
  final TabController? controller;

  static const _minHeight = 48.0;
  static const _verticalPadding = 12.0;

  /// The height the tabs need for one line of label text at the current
  /// text scale.
  static double tabHeight(BuildContext context) {
    final style =
        TabBarTheme.of(context).labelStyle ??
        Theme.of(context).textTheme.labelLarge!;
    final fontSize = MediaQuery.textScalerOf(context)
        .scale(style.fontSize ?? 14);
    final lineHeight = fontSize * (style.height ?? 1.2);
    return math.max(_minHeight, lineHeight + 2 * _verticalPadding);
  }

  /// True when the labels don't fit side by side in [maxWidth] at the
  /// current text size; the tabs then scroll instead of truncating.
  static bool needsScrolling(
    BuildContext context,
    List<String> labels,
    double maxWidth,
  ) {
    final style =
        TabBarTheme.of(context).labelStyle ??
        Theme.of(context).textTheme.labelLarge!;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final share = maxWidth / labels.length;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      // Material's default label padding is 16dp on each side.
      if (width + 32 > share) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final height = tabHeight(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scroll = needsScrolling(context, labels, constraints.maxWidth);
        return TabBar(
          controller: controller,
          isScrollable: scroll,
          tabAlignment: scroll ? TabAlignment.start : null,
          tabs: [
            for (final label in labels)
              Tab(
                height: height,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );
      },
    );
  }
}
