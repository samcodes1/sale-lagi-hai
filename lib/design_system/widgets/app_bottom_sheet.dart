import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// Shows a modal bottom sheet with the app's conventions: drag handle,
/// scrollable content that never hides under the keyboard or gesture bar,
/// and a heading screen readers can jump to.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) => Padding(
    // Keep the content above the keyboard.
    padding: EdgeInsetsDirectional.only(
      bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s5,
        0,
        BrandSpacing.s5,
        BrandSpacing.s7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: BrandSpacing.s5),
          builder(sheetContext),
        ],
      ),
    ),
  ),
);
