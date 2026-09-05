import 'package:flutter/material.dart';

/// Authentic WhatsApp Vector Logo Widget
/// Renders the official WhatsApp speech bubble with the telephone handset inside.
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const WhatsAppIcon({
    super.key,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _WhatsAppPainter(color: color ?? const Color(0xFF25D366)),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  final Color color;

  _WhatsAppPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    // 1. WhatsApp Speech Bubble
    final bubblePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bubblePath = Path()
      ..moveTo(12.0, 2.0)
      ..cubicTo(17.52, 2.0, 22.0, 6.48, 22.0, 12.0)
      ..cubicTo(22.0, 17.52, 17.52, 22.0, 12.0, 22.0)
      ..cubicTo(10.21, 22.0, 8.52, 21.52, 7.07, 20.66)
      ..lineTo(2.0, 22.0)
      ..lineTo(3.38, 17.07)
      ..cubicTo(2.5, 15.58, 2.0, 13.85, 2.0, 12.0)
      ..cubicTo(2.0, 6.48, 6.48, 2.0, 12.0, 2.0)
      ..close();

    canvas.drawPath(bubblePath, bubblePaint);

    // 2. White Phone Handset in the center
    final phonePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final phonePath = Path()
      ..moveTo(17.47, 14.38)
      ..cubicTo(17.18, 14.24, 15.77, 13.54, 15.51, 13.44)
      ..cubicTo(15.25, 13.34, 15.06, 13.3, 14.87, 13.58)
      ..cubicTo(14.68, 13.86, 14.13, 14.52, 13.96, 14.71)
      ..cubicTo(13.79, 14.9, 13.62, 14.92, 13.33, 14.78)
      ..cubicTo(13.04, 14.64, 12.11, 14.33, 11.0, 13.34)
      ..cubicTo(10.14, 12.57, 9.56, 11.62, 9.39, 11.33)
      ..cubicTo(9.22, 11.04, 9.37, 10.88, 9.52, 10.74)
      ..cubicTo(9.65, 10.61, 9.81, 10.4, 9.95, 10.23)
      ..cubicTo(10.09, 10.06, 10.14, 9.94, 10.24, 9.75)
      ..cubicTo(10.34, 9.56, 10.29, 9.39, 10.22, 9.25)
      ..cubicTo(10.15, 9.11, 9.58, 7.71, 9.34, 7.14)
      ..cubicTo(9.11, 6.59, 8.87, 6.66, 8.7, 6.65)
      ..cubicTo(8.53, 6.64, 8.34, 6.64, 8.14, 6.64)
      ..cubicTo(7.95, 6.64, 7.64, 6.71, 7.38, 7.0)
      ..cubicTo(7.12, 7.29, 6.38, 7.98, 6.38, 9.41)
      ..cubicTo(6.38, 10.85, 7.41, 12.24, 7.55, 12.43)
      ..cubicTo(7.69, 12.62, 9.72, 15.8, 12.72, 17.04)
      ..cubicTo(13.43, 17.34, 13.98, 17.52, 14.41, 17.66)
      ..cubicTo(15.12, 17.89, 15.77, 17.86, 16.28, 17.78)
      ..cubicTo(16.85, 17.7, 17.98, 17.08, 18.22, 16.41)
      ..cubicTo(18.46, 15.74, 18.46, 15.16, 18.39, 15.04)
      ..cubicTo(18.32, 14.92, 18.13, 14.85, 17.84, 14.7)
      ..close();

    canvas.drawPath(phonePath, phonePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WhatsAppPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
