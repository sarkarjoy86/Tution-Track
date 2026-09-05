import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../services/attendance_ledger_service.dart';
import '../utils/theme.dart';

/// Compact and expandable "Gap & Attendance Ledger" summary card
/// with tap-to-reveal breakdown sheet
class GapLedgerCard extends StatelessWidget {
  final StudentModel student;
  final DateTime calendarMonth;
  final LedgerSummary summary;
  final VoidCallback? onLogMakeup;

  const GapLedgerCard({
    super.key,
    required this.student,
    required this.calendarMonth,
    required this.summary,
    this.onLogMakeup,
  });

  void _showBreakdownSheet(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(calendarMonth);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXl),
          ),
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkBorder : Colors.transparent,
            ),
            left: BorderSide(
              color: isDark ? AppTheme.darkBorder : Colors.transparent,
            ),
            right: BorderSide(
              color: isDark ? AppTheme.darkBorder : Colors.transparent,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkTextMuted.withOpacity(0.4)
                    : Colors.grey.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fact_check_outlined,
                      size: 20,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gap & Attendance Ledger',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '$monthName • ${student.name}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkTextMuted
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: isDark
                          ? AppTheme.darkTextMuted
                          : AppTheme.textMuted,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),

            // Brief logic explainer
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(isDark ? 0.15 : 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: primaryColor.withOpacity(isDark ? 0.3 : 0.12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Automated FIFO matching connects unscheduled classes to earliest missed days.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFE2E8F0)
                            : AppTheme.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: isDark ? AppTheme.darkBorder : null,
            ),

            // Gap list or empty notice
            Flexible(
              child: summary.gapEntries.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              color: AppTheme.successGreen,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Perfect Attendance! No Gaps',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color:
                                  isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'All scheduled classes have either been attended on time or no scheduled days have passed yet.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shrinkWrap: true,
                      itemCount: summary.gapEntries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final gap = summary.gapEntries[index];
                        final isResolved = gap.isResolved;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isResolved
                                ? (isDark
                                    ? const Color(0xFF064E3B).withOpacity(0.3)
                                    : const Color(0xFFF0FDF4))
                                : (isDark
                                    ? const Color(0xFF78350F).withOpacity(0.3)
                                    : const Color(0xFFFFFBEB)),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: isResolved
                                  ? (isDark
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFBBF7D0))
                                  : (isDark
                                      ? const Color(0xFFD97706)
                                      : const Color(0xFFFDE68A)),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Left icon
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isResolved
                                      ? (isDark
                                          ? const Color(0xFF065F46)
                                          : const Color(0xFFDCFCE7))
                                      : (isDark
                                          ? const Color(0xFF92400E)
                                          : const Color(0xFFFEF3C7)),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isResolved
                                      ? Icons.check_circle_rounded
                                      : Icons.warning_amber_rounded,
                                  size: 18,
                                  color: isResolved
                                      ? (isDark
                                          ? const Color(0xFF34D399)
                                          : const Color(0xFF16A34A))
                                      : (isDark
                                          ? const Color(0xFFFBBF24)
                                          : const Color(0xFFD97706)),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Date details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${gap.formattedDate} — Missed',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isResolved
                                            ? (isDark
                                                ? const Color(0xFF4ADE80)
                                                : const Color(0xFF15803D))
                                            : (isDark
                                                ? const Color(0xFFFBBF24)
                                                : const Color(0xFF92400E)),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      isResolved
                                          ? 'Resolved on ${gap.formattedResolvedOn}'
                                          : 'Pending Makeup Class',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: isResolved
                                            ? (isDark
                                                ? const Color(0xFF86EFAC)
                                                : const Color(0xFF166534))
                                            : (isDark
                                                ? const Color(0xFFFCD34D)
                                                : const Color(0xFFB45309)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Status Chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isResolved
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusFull,
                                  ),
                                ),
                                child: Text(
                                  isResolved ? 'Resolved' : 'Pending',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorder
              : (summary.unresolvedCount > 0
                  ? const Color(0xFFF59E0B).withOpacity(0.35)
                  : AppTheme.borderLight),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: summary.unresolvedCount > 0
                      ? const Color(0xFFF59E0B).withOpacity(0.06)
                      : Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          onTap: () => _showBreakdownSheet(context),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title + Action Link
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.swap_horizontal_circle_outlined,
                        size: 14,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ATTENDANCE & GAP LEDGER',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View Ledger',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: primaryColor,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3 Metric Pills
                Row(
                  children: [
                    // Metric 1: Missed Gaps
                    Expanded(
                      child: _buildMetricTile(
                        isDark: isDark,
                        label: 'Missed',
                        count: summary.missedCount,
                        color: const Color(0xFFEF4444),
                        bgColor: const Color(0xFFFEF2F2),
                        borderColor: const Color(0xFFFCA5A5),
                        icon: Icons.event_busy_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Metric 2: Recovered
                    Expanded(
                      child: _buildMetricTile(
                        isDark: isDark,
                        label: 'Recovered',
                        count: summary.recoveredCount,
                        color: const Color(0xFF10B981),
                        bgColor: const Color(0xFFECFDF5),
                        borderColor: const Color(0xFF6EE7B7),
                        icon: Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Metric 3: Unresolved
                    Expanded(
                      child: _buildMetricTile(
                        isDark: isDark,
                        label: 'Unresolved',
                        count: summary.unresolvedCount,
                        color: const Color(0xFFF59E0B),
                        bgColor: const Color(0xFFFFFBEB),
                        borderColor: const Color(0xFFFCD34D),
                        icon: Icons.hourglass_top_rounded,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required bool isDark,
    required String label,
    required int count,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.16) : bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: isDark ? color.withOpacity(0.35) : borderColor,
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? color : color.withOpacity(0.85),
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
