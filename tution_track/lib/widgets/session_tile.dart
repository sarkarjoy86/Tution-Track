import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/session_model.dart';
import '../providers/theme_provider.dart';
import '../services/attendance_ledger_service.dart';
import '../utils/theme.dart';

/// Redesigned eye-catchy SessionTile supporting Scheduled, Makeup, and Pure Extra class classification
class SessionTile extends StatelessWidget {
  final SessionModel session;
  final int? classNumber;
  final int? totalTarget;
  final VoidCallback? onDelete;
  final Future<bool> Function(String newNotes)? onEditNotes;
  final Future<bool> Function(
    SessionModel session,
    String newType,
    String replacesMissedDate,
  )? onReassign;
  final List<MissedDateEntry>? availableMissedDates;

  const SessionTile({
    super.key,
    required this.session,
    this.classNumber,
    this.totalTarget,
    this.onDelete,
    this.onEditNotes,
    this.onReassign,
    this.availableMissedDates,
  });

  void _showReassignSheet(BuildContext context) {
    if (onReassign == null) return;

    String selectedType = session.sessionType;
    String selectedMissedDate = session.replacesMissedDate;
    bool isSaving = false;

    // Filter available missed dates (include currently replaced date if already makeup)
    final gaps = availableMissedDates ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkTextMuted.withOpacity(0.4)
                        : Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.published_with_changes_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reassign Session Status',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${session.formattedOrdinalDate} • ${session.formattedClockTime}',
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
              const SizedBox(height: 18),

              // Option 1: Scheduled Session
              _buildTypeOption(
                title: 'Regular Scheduled Class',
                subtitle: 'Counts towards standard monthly quota',
                icon: Icons.check_circle_outline_rounded,
                color: primaryColor,
                isSelected: selectedType == 'SCHEDULED',
                isDark: isDark,
                onTap: () {
                  setSheetState(() {
                    selectedType = 'SCHEDULED';
                    selectedMissedDate = '';
                  });
                },
              ),
              const SizedBox(height: 10),

              // Option 2: Makeup Class
              _buildTypeOption(
                title: 'Makeup Class',
                subtitle: 'Replaces a missed scheduled class to fill quota',
                icon: Icons.replay_rounded,
                color: const Color(0xFFF59E0B),
                isSelected: selectedType == 'MAKEUP',
                isDark: isDark,
                onTap: () {
                  setSheetState(() {
                    selectedType = 'MAKEUP';
                    if (selectedMissedDate.isEmpty && gaps.isNotEmpty) {
                      selectedMissedDate = gaps.first.date;
                    }
                  });
                },
              ),

              // If Makeup selected: Missed Date Selector
              if (selectedType == 'MAKEUP') ...[
                const SizedBox(height: 10),
                Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2D1F03)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFB45309)
                          : const Color(0xFFFDE68A),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Missed Date To Resolve:',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (gaps.isEmpty)
                        Text(
                          'No unfulfilled missed dates recorded this month. You can still assign it as a makeup class or switch to Pure Extra Class.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: isDark
                                ? const Color(0xFFFCD34D)
                                : const Color(0xFFB45309),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: gaps.map((gap) {
                            final isPicked = selectedMissedDate == gap.date;
                            return ChoiceChip(
                              label: Text(gap.formattedDate),
                              selected: isPicked,
                              selectedColor: const Color(0xFFF59E0B),
                              labelStyle: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isPicked
                                    ? Colors.white
                                    : (isDark
                                        ? const Color(0xFFFDE68A)
                                        : const Color(0xFF78350F)),
                              ),
                              backgroundColor:
                                  isDark ? AppTheme.darkCard : Colors.white,
                              side: BorderSide(
                                color: isPicked
                                    ? const Color(0xFFF59E0B)
                                    : (isDark
                                        ? AppTheme.darkBorder
                                        : const Color(0xFFFDE68A)),
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setSheetState(() {
                                    selectedMissedDate = gap.date;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Option 3: Pure Extra Class
              _buildTypeOption(
                title: 'Pure Extra Class (Bonus)',
                subtitle: 'Bonus session beyond monthly quota target',
                icon: Icons.stars_rounded,
                color: const Color(0xFF10B981),
                isSelected: selectedType == 'EXTRA',
                isDark: isDark,
                onTap: () {
                  setSheetState(() {
                    selectedType = 'EXTRA';
                    selectedMissedDate = '';
                  });
                },
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.white : AppTheme.textPrimary,
                        side: BorderSide(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.borderLight,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setSheetState(() => isSaving = true);
                              await onReassign!(
                                session,
                                selectedType,
                                selectedType == 'MAKEUP'
                                    ? selectedMissedDate
                                    : '',
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.18 : 0.08)
              : (isDark ? AppTheme.darkSurface : Colors.transparent),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? AppTheme.darkBorder : AppTheme.borderLight),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? color
                  : (isDark ? AppTheme.darkTextMuted : AppTheme.textMuted),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? color
                              : (isDark ? Colors.white : AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNotesDialog(BuildContext context) {
    final controller = TextEditingController(text: session.notes);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: primaryColor),
            const SizedBox(width: 8),
            Text(
              classNumber != null
                  ? 'Class #$classNumber Topic'
                  : 'Lesson Topic',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session.formattedOrdinalDate} • ${session.formattedClockTime}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: GoogleFonts.inter(
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'e.g., Chapter 4: Calculus, Homework review',
                labelText: 'Topic / Lesson Notes',
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppTheme.darkTextSecondary
                  : AppTheme.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newNotes = controller.text.trim();
              Navigator.pop(ctx);
              if (onEditNotes != null) {
                onEditNotes!(newNotes);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ThemeProvider? themeProvider;
    try {
      themeProvider = Provider.of<ThemeProvider?>(context);
    } catch (_) {
      themeProvider = null;
    }
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isMakeup = session.isMakeup;
    final isPureExtra = session.isPureExtra;

    // Day initials (e.g. "SAT", "THU", "TUE")
    final String dayInitial;
    if (session.dayOfWeek.trim().isNotEmpty) {
      final clean = session.dayOfWeek.trim();
      dayInitial = clean.substring(0, clean.length >= 3 ? 3 : clean.length).toUpperCase();
    } else {
      dayInitial = DateFormat('EEE').format(session.timestamp).toUpperCase();
    }

    // Determine visual stripe gradient
    final LinearGradient stripeGradient = isMakeup
        ? const LinearGradient(
            colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : (isPureExtra
            ? const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF10B981)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : (themeProvider?.currentGradient ??
                LinearGradient(
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )));

    // Border color based on class type
    final Color borderColor = isDark
        ? AppTheme.darkBorder
        : (isMakeup
            ? const Color(0xFFF59E0B).withOpacity(0.35)
            : (isPureExtra
                ? AppTheme.accentTeal.withOpacity(0.4)
                : AppTheme.borderLight));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: isMakeup
                      ? const Color(0xFFF59E0B).withOpacity(0.06)
                      : (isPureExtra
                          ? AppTheme.accentTeal.withOpacity(0.06)
                          : Colors.black.withOpacity(0.03)),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Left Visual Accent & Class Number Badge ───
              Container(
                width: 58,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  gradient: stripeGradient,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'CLASS',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.75),
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      classNumber != null
                          ? '#${classNumber.toString().padLeft(2, '0')}'
                          : '✓',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dayInitial,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Center Information ─────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Date & Class Type Badge
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                session.formattedOrdinalDate,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Class Type Badge (Clickable if onReassign provided)
                          GestureDetector(
                            onTap: onReassign != null
                                ? () => _showReassignSheet(context)
                                : null,
                            child: _buildBadge(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Day and Clock Time
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${session.dayOfWeek} • ${session.formattedClockTime} (${session.timeSlot})',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Inline Subtitle for Makeup Class
                      if (isMakeup && session.replacesMissedDate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 13,
                              color: Color(0xFFD97706),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '↩ Replaces Missed: ${session.formattedReplacedDate}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 8),

                      // ─── Useful Lesson Topic / Note Section ────
                      if (session.notes.isNotEmpty)
                        GestureDetector(
                          onTap: () => _showEditNotesDialog(context),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurface : AppTheme.surfaceLight,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                              border: Border.all(
                                color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 13,
                                  color: primaryColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    session.notes,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 13,
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => _showEditNotesDialog(context),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 13,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+ Add lesson topic / notes',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ─── Delete Button ──────────────────────────────
              if (onDelete != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                      ),
                      splashRadius: 18,
                      onPressed: onDelete,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (session.isMakeup) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D1F03) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isDark ? const Color(0xFFB45309) : const Color(0xFFFCD34D),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.replay_rounded,
              size: 11,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
            ),
            const SizedBox(width: 3),
            Text(
              'Makeup Class',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
              ),
            ),
            if (onReassign != null) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 13,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
              ),
            ],
          ],
        ),
      );
    }

    if (session.isPureExtra) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF062A1F) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isDark ? const Color(0xFF047857) : const Color(0xFF6EE7B7),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.stars_rounded,
              size: 11,
              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
            ),
            const SizedBox(width: 3),
            Text(
              'Bonus Extra Class',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
              ),
            ),
            if (onReassign != null) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.arrow_drop_down_rounded,
                size: 13,
                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: isDark
            ? primaryColor.withOpacity(0.18)
            : primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: isDark
              ? primaryColor.withOpacity(0.4)
              : primaryColor.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 11,
            color: primaryColor,
          ),
          const SizedBox(width: 3),
          Text(
            'Scheduled',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          if (onReassign != null) ...[
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 13,
              color: primaryColor,
            ),
          ],
        ],
      ),
    );
  }
}
