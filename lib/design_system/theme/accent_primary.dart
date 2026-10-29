import 'package:material_ui/material_ui.dart';

/// Swaps the theme's `primary` (Haldi yellow) for Neel below this widget.
///
/// A few Material widgets paint `colorScheme.primary` as text or thin marks
/// directly, where no component theme can reach: the date-range picker's
/// "today", Stepper's step circles, and the selected and filled variants
/// of toggle `IconButton`s. On light surfaces yellow is unreadable (1.6:1),
/// so wrap those widgets in this. A guard test keeps the raw widgets out of
/// app code.
class AccentPrimary extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  /// The theme with `primary` set to `secondary` (Neel), and the matching
  /// container roles.
  static ThemeData of(ThemeData theme) {
    final scheme = theme.colorScheme;
    return theme.copyWith(
      colorScheme: scheme.copyWith(
        primary: scheme.secondary,
        onPrimary: scheme.onSecondary,
        primaryContainer: scheme.secondaryContainer,
        onPrimaryContainer: scheme.onSecondaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Theme(data: of(Theme.of(context)), child: child);
}

/// [showDateRangePicker] with readable "today" and range colours.
Future<DateTimeRange<DateTime>?> showAppDateRangePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTimeRange<DateTime>? initialDateRange,
  DateTime? currentDate,
}) => showDateRangePicker(
  context: context,
  firstDate: firstDate,
  lastDate: lastDate,
  initialDateRange: initialDateRange,
  currentDate: currentDate,
  builder: (context, child) => AccentPrimary(child: child!),
);
