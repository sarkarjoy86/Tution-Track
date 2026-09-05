import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../models/session_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../providers/theme_provider.dart';
import '../services/attendance_ledger_service.dart';
import '../utils/theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/session_tile.dart';

/// Screen displaying all classes and session history for a particular calendar month
class ClassHistoryScreen extends StatelessWidget {
  final StudentModel student;
  final DateTime calendarMonth;

  const ClassHistoryScreen({
    super.key,
    required this.student,
    required this.calendarMonth,
  });

  Future<void> _handleDeleteSession(
    BuildContext context,
    SessionModel session,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        title: Text(
          'Delete Class Session?',
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete the class session on ${session.formattedOrdinalDate} (${session.formattedClockTime})?'
          '${session.isMakeup ? '\n\nAny replaced missed gap will revert back to pending.' : ''}',
          style: GoogleFonts.inter(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRose,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final attendanceProvider = context.read<AttendanceProvider>();
      final studentProvider = context.read<StudentProvider>();

      final success =
          await attendanceProvider.deleteSession(session.id, student.id);

      if (context.mounted && success) {
        final newCount = attendanceProvider.getSessionCount(student.id);
        studentProvider.updateSessionCount(student.id, newCount);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class session deleted'),
            backgroundColor: Color(0xFF1E293B),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(calendarMonth);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'All Classes',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$monthName • ${student.name}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Consumer<AttendanceProvider>(
        builder: (context, attendanceProvider, child) {
          final sessions = attendanceProvider.getReconciledSessions(student, calendarMonth);
          final totalTarget = student.monthlyTargetClasses;
          final quota = AttendanceLedgerService.calculateQuota(
            student: student,
            sessions: sessions,
          );
          final ledgerSummary = attendanceProvider.getLedgerSummary(student, calendarMonth);

          final hasBonus = quota.bonusExtraCount > 0;
          final primaryCountText = hasBonus
              ? '$totalTarget of $totalTarget Classes (100% Completed)'
              : '${quota.quotaCompleted} of $totalTarget Classes';

          final subtitleText = hasBonus
              ? '+${quota.bonusExtraCount} Extra Bonus Class${quota.bonusExtraCount > 1 ? 'es' : ''}'
              : (quota.carriedForwardCount > 0
                  ? '${quota.percentage}% completed (${quota.carriedForwardCount} credited from last month)'
                  : '${quota.percentage}% of target quota completed');

          return Column(
            children: [
              // ─── Month Summary Card ───────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: themeProvider.currentGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          monthName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          primaryCountText,
                          style: GoogleFonts.outfit(
                            fontSize: hasBonus ? 17.5 : 21,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleText,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: hasBonus ? FontWeight.w600 : FontWeight.w400,
                            color: Colors.white.withOpacity(hasBonus ? 0.95 : 0.75),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(hasBonus ? 0.28 : 0.2),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                        border: hasBonus
                            ? Border.all(color: Colors.white.withOpacity(0.4), width: 1)
                            : null,
                      ),
                      child: Text(
                        hasBonus
                            ? '+${quota.bonusExtraCount} Extra'
                            : '${sessions.length} Sessions',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Complete Sessions List ───────────────────
              Expanded(
                child: sessions.isEmpty
                    ? const EmptyState(
                        icon: Icons.event_busy_rounded,
                        title: 'No Classes Logged',
                        subtitle:
                            'No attendance records found for this calendar month.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: sessions.length,
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final classNum = sessions.length - index;

                          return SessionTile(
                            session: session,
                            classNumber: classNum,
                            totalTarget: totalTarget,
                            availableMissedDates: ledgerSummary.gapEntries
                                .where((g) =>
                                    !g.isResolved ||
                                    g.date == session.replacesMissedDate)
                                .toList(),
                            onReassign: (s, newType, chosenDate) async {
                              final success = await attendanceProvider
                                  .reassignSessionType(
                                sessionId: s.id,
                                sessionType: newType,
                                replacesMissedDate: chosenDate,
                              );
                              if (context.mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Session status updated to $newType!',
                                    ),
                                    backgroundColor: AppTheme.successGreen,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                              return success;
                            },
                            onDelete: () =>
                                _handleDeleteSession(context, session),
                            onEditNotes: (newNotes) async {
                              final success = await attendanceProvider
                                  .updateSessionNotes(session.id, newNotes);
                              if (context.mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Lesson topic saved to database!'),
                                      ],
                                    ),
                                    backgroundColor: AppTheme.successGreen,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                              return success;
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
