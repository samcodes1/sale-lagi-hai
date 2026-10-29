import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/formatters.dart';
import 'package:sale_lagi_hai/design_system/theme/accent_primary.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

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
    // Circles grow with the text size (Material's are a fixed 24dp, which
    // clips the digits at 200%). Digits use the UI font at a tight line
    // height, so Urdu's tall Nastaliq line doesn't inflate them.
    final digitSize = MediaQuery.textScalerOf(context).scale(_digitFontSize);
    final circle = (digitSize * 1.25 + 10).clamp(24.0, 80.0);

    return AccentPrimary(
      child: Stepper(
        steps: steps,
        currentStep: currentStep,
        onStepTapped: onStepTapped,
        onStepContinue: onStepContinue,
        onStepCancel: onStepCancel,
        controlsBuilder: controlsBuilder ?? _controls,
        // Horizontal headers can't wrap: above 115% text they would
        // overflow (worse in Urdu), so the stepper goes vertical instead.
        type: MediaQuery.textScalerOf(context).scale(10) > 11.5
            ? StepperType.vertical
            : type,
        stepIconWidth: circle,
        stepIconHeight: circle,
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
              fontFamily: BrandFonts.ui,
              fontSize: _digitFontSize,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          StepState.editing => Icon(
            Icons.edit,
            color: ink(index),
            size: circle * 0.6,
          ),
          StepState.complete => Icon(
            Icons.check,
            color: ink(index),
            size: circle * 0.6,
          ),
          // Material's error triangle already carries its own colours.
          StepState.error => null,
        },
      ),
    );
  }

  static const _digitFontSize = 12.0;

  /// Continue and Cancel, wrapping onto a second line when they don't fit
  /// (Material's row overflows at large text sizes).
  static Widget _controls(BuildContext context, ControlsDetails details) {
    // The vertical stepper builds every step's controls; show the current
    // step's only.
    if (!details.isActive) return const SizedBox.shrink();
    final labels = MaterialLocalizations.of(context);
    // Full width, start-aligned: a narrower body would shrink the step's
    // Stack and pull the connector line off the circles.
    return Container(
      width: double.infinity,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsetsDirectional.only(top: BrandSpacing.s3),
      child: Wrap(
        spacing: BrandSpacing.s2,
        runSpacing: BrandSpacing.s2,
        children: [
          FilledButton(
            onPressed: details.onStepContinue,
            child: Text(labels.continueButtonLabel),
          ),
          TextButton(
            onPressed: details.onStepCancel,
            child: Text(labels.cancelButtonLabel),
          ),
        ],
      ),
    );
  }
}
