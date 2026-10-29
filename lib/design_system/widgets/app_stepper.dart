import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/design_system/theme/accent_primary.dart';

/// Use this instead of [Stepper].
///
/// Material's Stepper paints active step circles in `primary` (yellow, so
/// thin connector marks vanish on light surfaces), and inactive steps as
/// white digits on a 38% grey circle (2.5:1), which no theme reaches. This
/// draws the circles from scheme roles: Neel with `onSecondary` for
/// active steps, `surfaceContainerHighest` with `onSurface` for the
/// rest, and digits in the app's number format.
class AppStepper extends StatelessWidget {
  const new({
    required this.steps,
    this.currentStep = 0,
    this.onStepTapped,
    this.onStepContinue,
    this.onStepCancel,
    this.controlsBuilder,
    this.type = StepperType.vertical,
    super.key,
  });

  final List<Step> steps;
  final int currentStep;
  final ValueChanged<int>? onStepTapped;
  final VoidCallback? onStepContinue;
  final VoidCallback? onStepCancel;
  final ControlsWidgetBuilder? controlsBuilder;
  final StepperType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final format = AppFormatters.of(context);
    Color ink(int index) =>
        steps[index].isActive ? scheme.onSecondary : scheme.onSurface;

    return AccentPrimary(
      child: Stepper(
        steps: steps,
        currentStep: currentStep,
        onStepTapped: onStepTapped,
        onStepContinue: onStepContinue,
        onStepCancel: onStepCancel,
        controlsBuilder: controlsBuilder,
        type: type,
        // Colours both the circles and the connectors.
        connectorColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.surfaceContainerHighest,
        ),
        stepIconBuilder: (index, state) => switch (state) {
          StepState.indexed || StepState.disabled => Text(
            format.number(index + 1),
            style: TextStyle(
              color: ink(index),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          StepState.editing => Icon(Icons.edit, color: ink(index), size: 18),
          StepState.complete => Icon(Icons.check, color: ink(index), size: 18),
          // Material's error triangle already carries its own colours.
          StepState.error => null,
        },
      ),
    );
  }
}
