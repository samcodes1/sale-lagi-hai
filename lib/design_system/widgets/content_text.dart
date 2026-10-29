import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';

/// Text that comes from deals, brands or users rather than our own copy.
///
/// Brands often write offers in English even when the app is in Urdu, and
/// vice versa. Laid out in the UI's direction, "2 for Rs 999" in an Urdu
/// screen becomes "for Rs 999 2". This lays the text out in **its own**
/// direction (detected from its characters) while keeping it aligned to
/// the UI's start edge, so it reads correctly and lines up with the rest.
class ContentText extends StatelessWidget {
  const new(this.text, {this.style, this.maxLines, this.overflow, super.key});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// The direction of [text] from its characters: right-to-left when it is
  /// mostly Arabic-script, left-to-right otherwise.
  static TextDirection directionOf(String text) =>
      intl.Bidi.detectRtlDirectionality(text)
      ? TextDirection.rtl
      : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    final uiDirection = Directionality.of(context);
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: directionOf(text),
      // Align with the UI's start edge, whatever the content's direction.
      textAlign: uiDirection == TextDirection.rtl
          ? TextAlign.right
          : TextAlign.left,
    );
  }
}
