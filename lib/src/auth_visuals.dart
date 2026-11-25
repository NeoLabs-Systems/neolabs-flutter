import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'palette.dart';

const Color _qrDarkColor = Color(0xFF0E1511);

/// The QR code on its paper plate: dark modules on a light ground so phone
/// cameras read it in either theme.
class NeoAuthQrPlate extends StatelessWidget {
  const NeoAuthQrPlate({
    super.key,
    required this.size,
    required this.payload,
    required this.preparing,
  });

  static const Color paper = Color(0xFFF4F1E8);

  final double size;
  final String? payload;
  final bool preparing;

  @override
  Widget build(BuildContext context) {
    final data = payload;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.07),
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(size * 0.12),
      ),
      child: data != null
          ? QrImageView(
              data: data,
              version: QrVersions.auto,
              padding: EdgeInsets.zero,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: _qrDarkColor,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: _qrDarkColor,
              ),
            )
          : Center(
              child: preparing
                  ? const SizedBox.square(
                      dimension: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: _qrDarkColor,
                      ),
                    )
                  : Icon(
                      Icons.qr_code_2_rounded,
                      size: size * 0.4,
                      color: _qrDarkColor.withValues(alpha: 0.35),
                    ),
            ),
    );
  }
}

/// The sign-in page ground: the mascot's dot matrix, faint, with a soft glow
/// where the card sits.
class NeoAuthBackdrop extends StatelessWidget {
  const NeoAuthBackdrop({
    super.key,
    required this.child,
    required this.palette,
  });

  final NeoLabsPalette palette;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return DecoratedBox(
      decoration: BoxDecoration(color: palette.bgPrimary),
      child: CustomPaint(
        painter: _NeoAuthBackdropPainter(
          dot: palette.textPrimary.withValues(alpha: isLight ? 0.09 : 0.07),
          glow: palette.accent.withValues(alpha: isLight ? 0.08 : 0.10),
        ),
        child: child,
      ),
    );
  }
}

class _NeoAuthBackdropPainter extends CustomPainter {
  const _NeoAuthBackdropPainter({required this.dot, required this.glow});

  static const double _pitch = 22;
  static const double _glowRadius = 380;

  final Color dot;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * 0.3);
    canvas.drawCircle(
      centre,
      _glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[glow, glow.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: centre, radius: _glowRadius)),
    );
    final points = <Offset>[
      for (var y = _pitch / 2; y < size.height; y += _pitch)
        for (var x = _pitch / 2; x < size.width; x += _pitch) Offset(x, y),
    ];
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = dot
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_NeoAuthBackdropPainter oldDelegate) =>
      oldDelegate.dot != dot || oldDelegate.glow != glow;
}
