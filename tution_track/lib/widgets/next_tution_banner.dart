import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/student_model.dart';
import '../utils/theme.dart';

/// Dynamic "Next Tution" Alert Widget displayed prominently on the Home Screen.
/// Supports 3 states:
/// 1. Upcoming Today: Displays next pending student, time, location with pulsing clock icon.
/// 2. All Completed Today: Green celebration badge with preview of tomorrow's earliest tution.
/// 3. No Classes Scheduled: Relaxation banner informing the tutor to take rest.
class NextTutionBanner extends StatefulWidget {
  final StudentModel? nextStudent;
  final bool hasScheduledToday;
  final bool allCompletedToday;
  final String? tomorrowSummary;
  final bool isTomorrow;
  final VoidCallback? onTap;

  const NextTutionBanner({
    super.key,
    this.nextStudent,
    required this.hasScheduledToday,
    required this.allCompletedToday,
    this.tomorrowSummary,
    this.isTomorrow = false,
    this.onTap,
  });

  @override
  State<NextTutionBanner> createState() => _NextTutionBannerState();
}

class _NextTutionBannerState extends State<NextTutionBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Determine state
    if (widget.hasScheduledToday &&
        !widget.allCompletedToday &&
        widget.nextStudent != null) {
      return _buildUpcomingState(context, widget.nextStudent!, isDark, isTomorrow: false);
    } else if (widget.hasScheduledToday && widget.allCompletedToday) {
      return _buildAllDoneState(context, isDark);
    } else if (widget.nextStudent != null && widget.isTomorrow) {
      return _buildUpcomingState(context, widget.nextStudent!, isDark, isTomorrow: true);
    } else {
      return _buildNoClassesState(context, isDark);
    }
  }

  /// State 1: Upcoming Today or Tomorrow
  Widget _buildUpcomingState(
    BuildContext context,
    StudentModel student,
    bool isDark, {
    bool isTomorrow = false,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final dayLabel = isTomorrow ? 'Tomorrow' : 'Today';
    final timeStr = student.formattedProbableTime.isNotEmpty
        ? '$dayLabel, ${student.formattedProbableTime}'
        : '$dayLabel • Scheduled';

    final locationStr = student.address.trim().isNotEmpty
        ? student.address.trim()
        : 'Location not specified';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E2433)
                  : primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: primaryColor.withOpacity(0.3),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Pulsing Clock / Accent Icon
                ScaleTransition(
                  scale: _pulseScaleAnimation,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.access_time_filled_rounded,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Location
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Next: ${student.name}',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              ' • $timeStr',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              locationStr,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: isDark
                                    ? Colors.white70
                                    : AppTheme.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Chevron indicating tapability
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: primaryColor.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// State 2: All Classes Completed for Today
  Widget _buildAllDoneState(BuildContext context, bool isDark) {
    const successColor = Color(0xFF10B981);
    final subtitleText = widget.tomorrowSummary?.isNotEmpty == true
        ? widget.tomorrowSummary!
        : 'All scheduled sessions for today are completed!';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF132A22)
                  : successColor.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: successColor.withOpacity(0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: successColor.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Celebration / Checkmark Badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: successColor.withOpacity(0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: successColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: successColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'All done for today! 🎉',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isDark
                              ? Colors.white70
                              : AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// State 3: No Classes Scheduled
  Widget _buildNoClassesState(BuildContext context, bool isDark) {
    final subtitleText = widget.tomorrowSummary?.isNotEmpty == true
        ? widget.tomorrowSummary!
        : 'No scheduled classes today. Enjoy your day!';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2433) : AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white12
                    : AppTheme.borderLight,
                width: 1.2,
              ),
              boxShadow: AppTheme.shadowSm,
            ),
            child: Row(
              children: [
                // Cozy Coffee / Sun Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : AppTheme.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wb_sunny_outlined,
                    color: AppTheme.warningAmber,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No classes scheduled for today. Take rest!',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitleText,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

