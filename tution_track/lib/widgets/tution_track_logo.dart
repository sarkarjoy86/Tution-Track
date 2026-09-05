import 'package:flutter/material.dart';

/// TutionTrack branded logo widget - Graduation cap with checkmark
/// Automatically adapts to the app's current accent color or can be
/// used with explicit colors for static contexts (app icon, etc.)
class TutionTrackLogo extends StatelessWidget {
  final double size;
  final Color? capColor;
  final Color? checkColor;
  final bool useAccentColor;
  final bool showText;
  final Color? textColor;

  const TutionTrackLogo({
    super.key,
    this.size = 80,
    this.capColor,
    this.checkColor,
    this.useAccentColor = true,
    this.showText = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = useAccentColor
        ? Theme.of(context).colorScheme.primary
        : (capColor ?? const Color(0xFF2563EB));
    final accentCheck = checkColor ?? const Color(0xFF14B8A6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _TutionTrackLogoPainter(
            capColor: primaryColor,
            checkColor: accentCheck,
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.12),
          Text(
            'TUTION\nTRACKER',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: size * 0.14,
              fontWeight: FontWeight.w800,
              color: textColor ?? primaryColor,
              height: 1.15,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _TutionTrackLogoPainter extends CustomPainter {
  final Color capColor;
  final Color checkColor;

  _TutionTrackLogoPainter({
    required this.capColor,
    required this.checkColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Color variants
    final capDark = HSLColor.fromColor(capColor)
        .withLightness(
          (HSLColor.fromColor(capColor).lightness - 0.15).clamp(0.0, 1.0),
        )
        .toColor();
    final capLight = HSLColor.fromColor(capColor)
        .withLightness(
          (HSLColor.fromColor(capColor).lightness + 0.08).clamp(0.0, 1.0),
        )
        .toColor();

    // ──── 1. Graduation Cap (Mortarboard) ────

    // Cap top (diamond/rhombus shape)
    final capTopPaint = Paint()
      ..shader = LinearGradient(
        colors: [capLight, capColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final capTop = Path()
      ..moveTo(cx, h * 0.08) // top point
      ..lineTo(w * 0.88, h * 0.30) // right point
      ..lineTo(cx, h * 0.45) // bottom point
      ..lineTo(w * 0.12, h * 0.30) // left point
      ..close();

    canvas.drawPath(capTop, capTopPaint);

    // Cap band (trapezoid below the top)
    final capBandPaint = Paint()
      ..shader = LinearGradient(
        colors: [capDark, capColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, h * 0.40, w, h * 0.18))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final capBand = Path()
      ..moveTo(w * 0.22, h * 0.36)
      ..lineTo(w * 0.78, h * 0.36)
      ..lineTo(w * 0.72, h * 0.50)
      ..lineTo(w * 0.28, h * 0.50)
      ..close();

    canvas.drawPath(capBand, capBandPaint);

    // Tassel string (line from center top to the right side)
    final tasselPaint = Paint()
      ..color = capColor
      ..strokeWidth = w * 0.022
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final tasselPath = Path()
      ..moveTo(cx, h * 0.30)
      ..quadraticBezierTo(w * 0.68, h * 0.36, w * 0.74, h * 0.52);

    canvas.drawPath(tasselPath, tasselPaint);

    // Tassel ball (small circle at the end)
    final tasselBallPaint = Paint()
      ..color = capColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(
      Offset(w * 0.74, h * 0.54),
      w * 0.032,
      tasselBallPaint,
    );

    // Button on top center
    final buttonPaint = Paint()
      ..color = capDark
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawCircle(
      Offset(cx, h * 0.30),
      w * 0.035,
      buttonPaint,
    );

    // ──── 2. Checkmark ────

    final checkBgPaint = Paint()
      ..color = checkColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Circle background for checkmark (bottom right)
    final checkCx = w * 0.68;
    final checkCy = h * 0.72;
    final checkRadius = w * 0.17;

    canvas.drawCircle(
      Offset(checkCx, checkCy),
      checkRadius,
      checkBgPaint,
    );

    // White checkmark stroke inside the circle
    final checkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final checkPath = Path()
      ..moveTo(checkCx - checkRadius * 0.40, checkCy + checkRadius * 0.02)
      ..lineTo(checkCx - checkRadius * 0.05, checkCy + checkRadius * 0.35)
      ..lineTo(checkCx + checkRadius * 0.45, checkCy - checkRadius * 0.32);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _TutionTrackLogoPainter oldDelegate) {
    return oldDelegate.capColor != capColor ||
        oldDelegate.checkColor != checkColor;
  }
}

