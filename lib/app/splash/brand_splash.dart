import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/widgets.dart';
import 'package:sale_lagi_hai/app/splash/logo_outlines.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';

/// How wide the logo is drawn.
const _logoWidth = 220.0;

/// The whole reveal, and the shorter still version for reduced motion.
const _revealDuration = Duration(milliseconds: 1600);
const _stillDuration = Duration(milliseconds: 700);

/// The height of one line of the logo, and the step to the next line.
const _lineHeight = 104.0;
const _lineStep = 117.0;

/// The Android launch screen is plain red, so nothing jumps: the logo's
/// lines rise into place one at a time, the "!" lands last, and the whole
/// screen fades into [child], which starts loading underneath.
class BrandSplash extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with SingleTickerProviderStateMixin {
  late final bool _still = WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  late final AnimationController _controller =
      AnimationController(
          vsync: this,
          duration: _still ? _stillDuration : _revealDuration,
        )
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() => _done = true);
          }
        })
        ..forward();

  late final Animation<double> _fadeOut = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.84, 1, curve: Curves.easeIn),
  );

  var _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.topLeft,
    textDirection: TextDirection.ltr,
    fit: StackFit.expand,
    children: [
      widget.child,
      if (!_done)
        ExcludeSemantics(
          child: AbsorbPointer(
            child: FadeTransition(
              opacity: ReverseAnimation(_fadeOut),
              child: ColoredBox(
                color: BrandColors.mirch500,
                child: Center(
                  child: SizedBox(
                    width: _logoWidth,
                    height: _logoWidth * logoBlockHeight / logoBlockWidth,
                    child: CustomPaint(
                      painter: _LogoPainter(_controller, still: _still),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// Turns the generated path data of logo_outlines.dart into a [Path].
Path _path(List<double> data) {
  final path = Path();
  var i = 0;
  while (i < data.length) {
    final op = data[i++].toInt();
    switch (op) {
      case 0:
        path.moveTo(data[i], data[i + 1]);
        i += 2;
      case 1:
        path.lineTo(data[i], data[i + 1]);
        i += 2;
      case 2:
        path.quadraticBezierTo(data[i], data[i + 1], data[i + 2], data[i + 3]);
        i += 4;
      case 3:
        path.cubicTo(
          data[i],
          data[i + 1],
          data[i + 2],
          data[i + 3],
          data[i + 4],
          data[i + 5],
        );
        i += 6;
      default:
        path.close();
    }
  }
  return path;
}

final Path _sale = _path(logoSale);
final Path _lagi = _path(logoLagi);
final Path _hai = _path(logoHai);
final Path _bang = _path(logoBang);

class _LogoPainter extends CustomPainter {
  new(this.time, {required this.still}) : super(repaint: time);

  final Animation<double> time;

  /// Reduced motion: the finished logo, with nothing moving.
  final bool still;

  double _progress(double begin, double end, Curve curve) {
    if (still) return 1;
    return curve.transform(
      clampDouble((time.value - begin) / (end - begin), 0, 1),
    );
  }

  /// One line, rising out of a clip the size of its own row.
  void _line(Canvas canvas, Path path, double top, double progress) {
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(0, top, logoBlockWidth, _lineHeight))
      ..translate(0, lerpDouble(_lineHeight, 0, progress)!)
      ..drawPath(path, _paint)
      ..restore();
  }

  static final _paint = Paint()..color = BrandColors.surma0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / logoBlockWidth;
    canvas
      ..save()
      ..scale(scale);
    _line(canvas, _sale, 0, _progress(0, 0.3, Curves.easeOutCubic));
    _line(canvas, _lagi, _lineStep, _progress(0.1, 0.4, Curves.easeOutCubic));
    _line(
      canvas,
      _hai,
      2 * _lineStep,
      _progress(0.2, 0.5, Curves.easeOutCubic),
    );

    final bang = _progress(0.46, 0.68, Curves.easeOutBack);
    if (bang > 0) {
      final centre = _bang.getBounds().center;
      canvas
        ..translate(centre.dx, centre.dy)
        ..scale(bang)
        ..translate(-centre.dx, -centre.dy)
        ..drawPath(_bang, _paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
