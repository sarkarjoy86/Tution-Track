import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';

/// Circular progress ring widget showing monthly quota progress
class ProgressRing extends StatelessWidget {
  final int completed;
  final int target;
  final double size;
  final double strokeWidth;
  final bool showLabel;

  const ProgressRing({
    super.key,
    required this.completed,
    required this.target,
    this.size = 56,
    this.strokeWidth = 5,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = target > 0 ? completed / target : 0.0;
    final isOver = completed > target;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    // Color based on progress
    Color progressColor;
    if (isOver) {
      progressColor = AppTheme.accentTeal;
    } else if (ratio >= 0.75) {
      progressColor = AppTheme.successGreen;
    } else if (ratio >= 0.5) {
      progressColor = AppTheme.warningAmber;
    } else {
      progressColor = primary;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: strokeWidth,
              color: progressColor.withOpacity(0.15),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Progress ring
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: strokeWidth,
                  color: progressColor,
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          // Center text
          if (showLabel)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$completed',
                  style: GoogleFonts.inter(
                    fontSize: size * 0.26,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.darkTextPrimary
                        : AppTheme.textPrimary,
                    height: 1,
                  ),
                ),
                Text(
                  '/$target',
                  style: GoogleFonts.inter(
                    fontSize: size * 0.17,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textMuted,
                    height: 1.2,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
