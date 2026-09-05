import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../providers/attendance_provider.dart';
import '../utils/theme.dart';
import 'progress_ring.dart';

/// Dashboard student card with progress indicator, dynamic quick-log button, and schedule badges
class StudentCard extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onTap;
  final VoidCallback onCheckIn;
  final VoidCallback onUndo;
  final bool isArchivedView;

  const StudentCard({
    super.key,
    required this.student,
    required this.onTap,
    required this.onCheckIn,
    required this.onUndo,
    this.isArchivedView = false,
  });

  @override
  Widget build(BuildContext context) {
    final attendanceProvider = context.watch<AttendanceProvider>();
    final sessionCount = attendanceProvider.getSessionCount(student.id);
    final isMarkedToday = attendanceProvider.isLoggedToday(student.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isArchivedView
                ? (isDark ? AppTheme.darkBorder : AppTheme.borderLight)
                : (isMarkedToday
                    ? AppTheme.successGreen.withOpacity(0.35)
                    : (isDark ? AppTheme.darkBorder : AppTheme.borderLight)),
          ),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Progress ring
              ProgressRing(
                completed: sessionCount,
                target: student.monthlyTargetClasses,
                size: 60,
                strokeWidth: 5,
              ),
              const SizedBox(width: 14),
              // Student info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.darkTextPrimary
                                  : AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!student.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.08)
                                  : AppTheme.textMuted.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              'Discontinued',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Academic: Grade & Subject Group / Specific Subjects
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (student.grade.isNotEmpty)
                          Text(
                            student.grade,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textMuted,
                            ),
                          ),
                        if (student.subjectGroup.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentTeal.withOpacity(0.15),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              student.subjectGroup,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.accentTealLight
                                    : AppTheme.accentTealDark,
                              ),
                            ),
                          ),
                        if (student.displaySubject.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(isDark ? 0.2 : 0.08),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              student.displaySubject,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Progress info & Fee status
                    Row(
                      children: [
                        Text(
                          '$sessionCount of ${student.monthlyTargetClasses} classes',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        // Probable Time Badge (Replaced payment fee details)
                        if (student.probableTime.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: primary,
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                student.formattedProbableTime,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // Weekly Schedule (if configured)
                    if (student.weeklySchedule.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 11,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              student.weeklySchedule.join(' • '),
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Interactive One-Tap Attendance Button
              if (!isArchivedView)
                _QuickLogButton(
                  isMarkedToday: isMarkedToday,
                  onCheckIn: onCheckIn,
                  onUndo: onUndo,
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: onTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dynamic Quick Log button with State 1 (+) and State 2 (green checkmark), haptics, and undo
class _QuickLogButton extends StatefulWidget {
  final bool isMarkedToday;
  final VoidCallback onCheckIn;
  final VoidCallback onUndo;

  const _QuickLogButton({
    required this.isMarkedToday,
    required this.onCheckIn,
    required this.onUndo,
  });

  @override
  State<_QuickLogButton> createState() => _QuickLogButtonState();
}

class _QuickLogButtonState extends State<_QuickLogButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isMarkedToday) {
      widget.onUndo();
    } else {
      widget.onCheckIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTapDown: (_) => _animController.forward(),
      onTapUp: (_) {
        _animController.reverse();
        _handleTap();
      },
      onTapCancel: () => _animController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isMarkedToday
                ? AppTheme.successGreen
                : (isDark ? const Color(0xFF0F172A) : AppTheme.cardWhite),
            border: Border.all(
              color: widget.isMarkedToday
                  ? AppTheme.successGreen
                  : (isDark ? AppTheme.darkBorder : AppTheme.borderLight),
              width: 2,
            ),
            boxShadow: widget.isMarkedToday
                ? [
                    BoxShadow(
                      color: AppTheme.successGreen.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: widget.isMarkedToday
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey('checked'),
                      color: Colors.white,
                      size: 26,
                    )
                  : Icon(
                      Icons.add_rounded,
                      key: const ValueKey('plus'),
                      color: primaryColor,
                      size: 26,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
