import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// A centred icon, one message and at most one action: the shape of every
/// empty, error and placeholder state (flutter-ui-ux skill §8).
///
/// Sub-phase 1.6 adds the illustrated empty, error and offline variants on
/// top of this.
class MessageView extends StatelessWidget {
  const new({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'actionLabel and onAction go together',
       );

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(BrandSpacing.s7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: BrandSpacing.s10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: BrandSpacing.s5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: BrandSpacing.s6),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
