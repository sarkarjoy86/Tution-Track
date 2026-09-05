import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/session_model.dart';
import '../models/payment_model.dart';
import '../providers/attendance_provider.dart';
import '../providers/student_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../widgets/session_tile.dart';
import '../widgets/empty_state.dart';
import '../widgets/gap_ledger_card.dart';
import '../widgets/whatsapp_icon.dart';
import 'payment_history_screen.dart';
import 'class_history_screen.dart';

/// Student detail screen with two-tone calendar, postpaid payment ledger, and tution status management
class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  StudentModel? _student;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _selectedMonthYear = '';
  DateTime? _lastTappedDay;
  DateTime? _lastTapTime;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_student == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is StudentModel) {
        _student = args;
        _selectedMonthYear =
            '${_focusedDay.year}-${_focusedDay.month.toString().padLeft(2, '0')}';
        // Fetch sessions and payments for this student
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<AttendanceProvider>().fetchStudentSessions(
                _student!.id,
                monthYear: _selectedMonthYear,
                student: _student,
              );
          context.read<PaymentProvider>().fetchPayments(_student!.id);
        });
      }
    }
  }

  IconData _getGroupIcon(String group) {
    switch (group.toLowerCase()) {
      case 'science':
        return Icons.science_outlined;
      case 'commerce':
        return Icons.bar_chart_rounded;
      case 'arts / humanities':
      case 'arts':
      case 'humanities':
        return Icons.palette_outlined;
      default:
        return Icons.auto_stories_outlined;
    }
  }

  void _onMonthChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _selectedMonthYear =
          '${focusedDay.year}-${focusedDay.month.toString().padLeft(2, '0')}';
    });
    context.read<AttendanceProvider>().fetchStudentSessions(
          _student!.id,
          monthYear: _selectedMonthYear,
          student: _student,
        );
  }

  /// Manual Attendance Entry with Broad Time Slot (supports double-tap preselected date)
  Future<void> _handleManualEntry({DateTime? preselectedDate}) async {
    if (_student == null) return;

    final now = DateTime.now();
    DateTime pickedDate;

    if (preselectedDate != null) {
      pickedDate = preselectedDate;
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(2020),
        lastDate: now,
      );
      if (picked == null || !mounted) return;
      pickedDate = picked;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null || !mounted) return;

    final customTimestamp = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    // Prompt for humanized time slot and notes
    String selectedSlot = AppFormatters.getTimeSlot(customTimestamp);
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = Theme.of(context).colorScheme.primary;

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
              title: Text(
                'Add Class Entry',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppFormatters.formatDateOrdinal(customTimestamp),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedSlot,
                    dropdownColor:
                        isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                    decoration: const InputDecoration(
                      labelText: 'Time Slot',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      'Morning',
                      'Noon',
                      'Afternoon',
                      'Evening',
                      'Night',
                    ]
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s,
                              style: GoogleFonts.inter(
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedSlot = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      hintText: 'e.g., Chapter 4 revision, extra class',
                    ),
                    maxLines: 2,
                  ),
                ],
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
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Entry'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final attendanceProvider = context.read<AttendanceProvider>();
    final studentProvider = context.read<StudentProvider>();

    final success = await attendanceProvider.manualEntry(
      _student!.id,
      customTimestamp,
      notes: notesController.text.trim(),
      timeSlot: selectedSlot,
      weeklySchedule: _student!.weeklySchedule,
      student: _student!,
    );

    if (mounted && success) {
      final newCount = attendanceProvider.getSessionCount(_student!.id);
      studentProvider.updateSessionCount(_student!.id, newCount);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance entry saved'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  /// Delete a Session
  Future<void> _handleDeleteSession(SessionModel session) async {
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

    if (confirmed != true || !mounted) return;

    final attendanceProvider = context.read<AttendanceProvider>();
    final studentProvider = context.read<StudentProvider>();

    final success =
        await attendanceProvider.deleteSession(session.id, _student!.id);

    if (mounted && success) {
      final newCount = attendanceProvider.getSessionCount(_student!.id);
      studentProvider.updateSessionCount(_student!.id, newCount);
    }
  }

  /// Postpaid Payment Dialog
  Future<void> _showPaymentDialog() async {
    if (_student == null) return;

    DateTime paymentDate = DateTime.now();
    final amountController = TextEditingController(
      text: _student!.monthlyFee > 0
          ? _student!.monthlyFee.toStringAsFixed(0)
          : '',
    );
    final periodController = TextEditingController(
      text: DateFormat('MMMM yyyy').format(DateTime.now()),
    );
    final notesController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = Theme.of(context).colorScheme.primary;

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                side: BorderSide(
                  color: isDark ? AppTheme.darkBorder : Colors.transparent,
                ),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    color: primaryColor,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Record Fee Payment',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Date Picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.calendar_today_rounded,
                        size: 20,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                      ),
                      title: Text(
                        'Payment Date',
                        style: GoogleFonts.inter(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        AppFormatters.formatDateOrdinal(paymentDate),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      trailing: Icon(
                        Icons.edit_calendar_rounded,
                        size: 20,
                        color: primaryColor,
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: paymentDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setDialogState(() => paymentDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // Amount Paid
                    TextField(
                      controller: amountController,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Amount Paid (${AppFormatters.currencySymbol}) *',
                        prefixText: '${AppFormatters.currencySymbol} ',
                        hintText: '5000',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),

                    // Period / Month Paid For
                    TextField(
                      controller: periodController,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'For Month / Period *',
                        hintText: 'e.g., August 2026',
                        prefixIcon: Icon(Icons.event_note_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Notes
                    TextField(
                      controller: notesController,
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Payment Note / Method (Optional)',
                        hintText: 'e.g., Paid via bKash, Cash, Partial',
                        prefixIcon: Icon(Icons.notes_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final amt = double.tryParse(amountController.text.trim());
                    if (amt == null || amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid amount'),
                          backgroundColor: AppTheme.errorRose,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Payment'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || !mounted) return;

    final payProvider = context.read<PaymentProvider>();
    final studentProvider = context.read<StudentProvider>();

    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final period = periodController.text.trim();
    final notes = notesController.text.trim();

    final paymentData = {
      'amount': amount,
      'paymentDate': paymentDate,
      'period': period,
      'notes': notes,
    };

    final saved = await payProvider.addPayment(_student!.id, paymentData);

    if (mounted && saved != null) {
      // If payment is for current month, update student status
      final currentMonthStr = DateFormat('MMMM yyyy').format(DateTime.now());
      if (period.toLowerCase().contains(currentMonthStr.toLowerCase()) ||
          period.toLowerCase().contains(DateFormat('yyyy-MM').format(DateTime.now()))) {
        await studentProvider.toggleFeePaid(
          _student!.id,
          true,
          DateFormat('yyyy-MM').format(paymentDate),
        );
      }

      // Refresh student model in local state
      final updated = studentProvider.students.firstWhere(
        (s) => s.id == _student!.id,
        orElse: () => _student!,
      );
      setState(() => _student = updated);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment of ${AppFormatters.formatTaka(amount)} recorded!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  /// Discontinue Tution Dialog
  Future<void> _handleDiscontinue() async {
    if (_student == null) return;

    DateTime leavingDate = DateTime.now();
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = Theme.of(context).colorScheme.primary;

            return AlertDialog(
              backgroundColor: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                side: BorderSide(
                  color: isDark ? AppTheme.darkBorder : Colors.transparent,
                ),
              ),
              title: Text(
                'Discontinue Tution?',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mark this tution as completed or discontinued. Student will move to Archived / Past Students.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.event_busy_rounded,
                      size: 20,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.textMuted,
                    ),
                    title: Text(
                      'Leaving Date',
                      style: GoogleFonts.inter(
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      AppFormatters.formatDateOrdinal(leavingDate),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    trailing: Icon(
                      Icons.edit_calendar_rounded,
                      size: 20,
                      color: primaryColor,
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: leavingDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => leavingDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    style: GoogleFonts.inter(
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Leaving Reason / Note (Optional)',
                      hintText: 'e.g., Course completed, relocated, exams over',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorRose,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Discontinue'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final studentProvider = context.read<StudentProvider>();
    final success = await studentProvider.discontinueStudent(
      _student!.id,
      leavingDate: leavingDate,
      note: noteController.text.trim(),
    );

    if (mounted && success) {
      final updated = studentProvider.students.firstWhere(
        (s) => s.id == _student!.id,
        orElse: () => _student!,
      );
      setState(() => _student = updated);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tution marked as discontinued'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
    }
  }

  /// Reactivate Tution
  Future<void> _handleReactivate() async {
    if (_student == null) return;
    final studentProvider = context.read<StudentProvider>();
    final success = await studentProvider.reactivateStudent(_student!.id);

    if (mounted && success) {
      final updated = studentProvider.students.firstWhere(
        (s) => s.id == _student!.id,
        orElse: () => _student!,
      );
      setState(() => _student = updated);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tution reactivated successfully!'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_student == null) {
      return const Scaffold(body: Center(child: Text('Student not found')));
    }

    final attendanceProvider = context.watch<AttendanceProvider>();
    final paymentProvider = context.watch<PaymentProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final sessionCount = attendanceProvider.getSessionCount(_student!.id);
    final sessionDates = attendanceProvider.getSessionDates();
    final ledgerSummary = attendanceProvider.getLedgerSummary(_student!, _focusedDay);

    final scheduledDays = _student!.weeklySchedule; // e.g. ['Sat', 'Mon', 'Wed']

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.surfaceWhite,
      appBar: AppBar(
        title: Text(_student!.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.pushNamed(
                context,
                Routes.editStudent,
                arguments: _student,
              ).then((result) {
                if (result == true) {
                  final sp = context.read<StudentProvider>();
                  final updated = sp.students.firstWhere(
                    (s) => s.id == _student!.id,
                    orElse: () => _student!,
                  );
                  setState(() => _student = updated);
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'discontinue') {
                _handleDiscontinue();
              } else if (val == 'reactivate') {
                _handleReactivate();
              } else if (val == 'manual_entry') {
                _handleManualEntry();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'manual_entry',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Manual Class Entry'),
                  ],
                ),
              ),
              if (_student!.isActive)
                const PopupMenuItem(
                  value: 'discontinue',
                  child: Row(
                    children: [
                      Icon(Icons.person_off_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Mark Discontinued'),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'reactivate',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Reactivate Tution'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Gorgeous Student Header Card ────────────────
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: themeProvider.currentGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top: Student Name + Grade & Stream Badges
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _student!.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              // Academic Badges Row: Grade & Group Cleanly Separated
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (_student!.grade.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusFull,
                                        ),
                                      ),
                                      child: Text(
                                        _student!.grade,
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  if (_student!.subjectGroup.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentTeal.withOpacity(0.35),
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusFull,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.25),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getGroupIcon(_student!.subjectGroup),
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${_student!.subjectGroup} Group',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Specific Subjects Row (Separated from Group)
                    if (_student!.cleanSubjects.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Subjects: ',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.75),
                            ),
                          ),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: _student!.cleanSubjects.map((sub) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm,
                                    ),
                                  ),
                                  child: Text(
                                    sub,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    const SizedBox(height: 14),

                    // Progress Section (Ring + Stats + Progress Bar)
                    Row(
                      children: [
                        // Circular Progress Ring (Enlarged with ample breathing room)
                        Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.16),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background track
                              SizedBox(
                                width: 68,
                                height: 68,
                                child: CircularProgressIndicator(
                                  value: 1.0,
                                  strokeWidth: 4.5,
                                  color: Colors.white.withOpacity(0.2),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              // Active animated arc
                              SizedBox(
                                width: 68,
                                height: 68,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(
                                    begin: 0,
                                    end: _student!.monthlyTargetClasses > 0
                                        ? (sessionCount /
                                                _student!.monthlyTargetClasses)
                                            .clamp(0.0, 1.0)
                                        : 0.0,
                                  ),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutCubic,
                                  builder: (_, value, __) {
                                    return CircularProgressIndicator(
                                      value: value,
                                      strokeWidth: 4.5,
                                      color: sessionCount >=
                                              _student!.monthlyTargetClasses
                                          ? AppTheme.accentTeal
                                          : Colors.white,
                                      strokeCap: StrokeCap.round,
                                    );
                                  },
                                ),
                              ),
                              // Center numbers with clear spacing & high contrast
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$sessionCount',
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '/${_student!.monthlyTargetClasses}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Progress Metrics & Track
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _student!.monthlyTargetClasses > 0
                                        ? '${((sessionCount / _student!.monthlyTargetClasses) * 100).toInt()}% Completed'
                                        : '0% Completed',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (sessionCount > _student!.monthlyTargetClasses)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentTeal,
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusFull,
                                        ),
                                      ),
                                      child: Text(
                                        '+${sessionCount - _student!.monthlyTargetClasses} Extra',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      '${(_student!.monthlyTargetClasses - sessionCount).clamp(0, 99)} left',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.75),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Linear Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: _student!.monthlyTargetClasses > 0
                                      ? (sessionCount /
                                              _student!.monthlyTargetClasses)
                                          .clamp(0.0, 1.0)
                                      : 0.0,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$sessionCount of ${_student!.monthlyTargetClasses} monthly target sessions taken',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Discontinued Banner (if inactive)
              if (!_student!.isActive)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.warningAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: AppTheme.warningAmber.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.warningAmber,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _student!.leavingDate != null
                              ? 'Discontinued on ${AppFormatters.formatDateOrdinal(_student!.leavingDate!)}'
                              : 'Discontinued Tution',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _handleReactivate,
                        child: const Text('Reactivate'),
                      ),
                    ],
                  ),
                ),

              // ─── Two-Tone Smart Calendar ──────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Text(
                      'Smart Calendar',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (scheduledDays.isNotEmpty)
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Target: ${scheduledDays.join(', ')}',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          _selectedDay != null && isSameDay(_selectedDay, day),
                      onDaySelected: (selected, focused) {
                        final now = DateTime.now();
                        final isDoubleTap = _lastTappedDay != null &&
                            isSameDay(_lastTappedDay, selected) &&
                            _lastTapTime != null &&
                            now.difference(_lastTapTime!) <
                                const Duration(milliseconds: 500);

                        _lastTapTime = now;
                        _lastTappedDay = selected;

                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });

                        if (isDoubleTap) {
                          _handleManualEntry(preselectedDate: selected);
                        }
                      },
                      onDayLongPressed: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                        _handleManualEntry(preselectedDate: selected);
                      },
                      onPageChanged: _onMonthChanged,
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        outsideDaysVisible: false,
                        defaultTextStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                        weekendTextStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left_rounded,
                          color: primaryColor,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right_rounded,
                          color: primaryColor,
                        ),
                      ),
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppTheme.darkTextMuted
                              : AppTheme.textSecondary,
                        ),
                        weekendStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppTheme.darkTextMuted
                              : AppTheme.textSecondary,
                        ),
                      ),
                      // Two-Tone Calendar Custom Builders
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, date, events) {
                          final norm = DateTime(date.year, date.month, date.day);
                          final isCompleted = sessionDates.contains(norm);
                          final dayAbbr = DateFormat('EEE').format(date);
                          final isScheduled = scheduledDays.contains(dayAbbr);

                          if (isCompleted) {
                            // Solid badge (Green for scheduled, Teal for Extra Class)
                            final isExtra = !isScheduled && scheduledDays.isNotEmpty;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isExtra
                                    ? AppTheme.accentTeal
                                    : AppTheme.successGreen,
                              ),
                            );
                          } else if (isScheduled &&
                              date.isBefore(
                                DateTime.now().add(const Duration(days: 1)),
                              )) {
                            // Subtle indicator/dot for scheduled target days
                            return Container(
                              margin: const EdgeInsets.only(bottom: 2),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withOpacity(0.4),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                      calendarFormat: CalendarFormat.month,
                    ),

                    Divider(
                      height: 16,
                      color: isDark ? AppTheme.darkBorder : null,
                    ),
                    // Two-Tone Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _LegendItem(
                          color: primaryColor.withOpacity(0.5),
                          label: 'Scheduled Day',
                        ),
                        const SizedBox(width: 14),
                        const _LegendItem(
                          color: AppTheme.successGreen,
                          label: 'Completed Class',
                        ),
                        const SizedBox(width: 14),
                        const _LegendItem(
                          color: AppTheme.accentTeal,
                          label: 'Extra Class',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tip: Double-tap or long-press any date to log a class',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextMuted
                            : AppTheme.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Session History ──────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(
                  'Class History',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),

              if (attendanceProvider.isLoading)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                    ),
                  ),
                )
              else if (attendanceProvider.sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: EmptyState(
                    icon: Icons.event_available_rounded,
                    title: 'No Sessions in this Month',
                    subtitle:
                        'Tap the one-tap attendance button on the dashboard or add a manual entry.',
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Display only the last 5 sessions
                      ...List.generate(
                        attendanceProvider.sessions.take(5).length,
                        (index) {
                          final session = attendanceProvider.sessions[index];
                          final classNum =
                              attendanceProvider.sessions.length - index;
                          return SessionTile(
                            session: session,
                            classNumber: classNum,
                            totalTarget: _student!.monthlyTargetClasses,
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
                              if (mounted && success) {
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
                            onDelete: () => _handleDeleteSession(session),
                            onEditNotes: (newNotes) async {
                              final success =
                                  await attendanceProvider.updateSessionNotes(
                                session.id,
                                newNotes,
                              );
                              if (mounted && success) {
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
                      // If there are more than 5 classes, provide an eye-catchy button
                      if (attendanceProvider.sessions.length > 5)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 4, bottom: 8),
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ClassHistoryScreen(
                                    student: _student!,
                                    calendarMonth: _focusedDay,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.history_rounded, size: 16),
                            label: Text(
                              'View All ${attendanceProvider.sessions.length} Classes for ${DateFormat('MMMM yyyy').format(_focusedDay)} →',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryColor,
                              side: BorderSide(
                                color: primaryColor.withOpacity(0.35),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

              // ─── Gap & Attendance Ledger Summary Widget ───
              GapLedgerCard(
                student: _student!,
                calendarMonth: _focusedDay,
                summary: ledgerSummary,
              ),

              // ─── Postpaid Fee & Payment Ledger Card ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                    ),
                    boxShadow: isDark ? null : AppTheme.shadowSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _student!.isFeePaidThisMonth
                                ? Icons.check_circle_rounded
                                : Icons.pending_actions_rounded,
                            color: _student!.isFeePaidThisMonth
                                ? AppTheme.successGreen
                                : AppTheme.warningAmber,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _student!.isFeePaidThisMonth
                                      ? 'Fee Paid (Current Month)'
                                      : 'Fee Pending',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _student!.isFeePaidThisMonth
                                        ? AppTheme.successGreen
                                        : AppTheme.warningAmber,
                                  ),
                                ),
                                Text(
                                  'Monthly Fee: ${AppFormatters.formatTaka(_student!.monthlyFee)}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showPaymentDialog,
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Record Pay'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              textStyle: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Ledger Summary
                      if (paymentProvider.payments.isNotEmpty) ...[
                        Divider(
                          height: 24,
                          color: isDark ? AppTheme.darkBorder : null,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Payment Ledger (${paymentProvider.payments.length})',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PaymentHistoryScreen(
                                      student: _student!,
                                    ),
                                  ),
                                );
                              },
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'All History',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 10,
                                      color: primaryColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // List only the latest / current payment record
                        ...paymentProvider.payments.take(1).map((p) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurface
                                  : AppTheme.surfaceLight,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.receipt_rounded,
                                  size: 16,
                                  color: AppTheme.accentTeal,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.period.isNotEmpty
                                            ? p.period
                                            : p.formattedPaymentDate,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        p.formattedPaymentDate +
                                            (p.notes.isNotEmpty
                                                ? ' • ${p.notes}'
                                                : ''),
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          color: isDark
                                              ? AppTheme.darkTextMuted
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  p.formattedAmount,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.successGreen,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16,
                                    color: isDark
                                        ? AppTheme.darkTextMuted
                                        : AppTheme.textMuted,
                                  ),
                                  splashRadius: 16,
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                          side: BorderSide(
                                            color: isDark ? AppTheme.darkBorder : Colors.transparent,
                                          ),
                                        ),
                                        title: Text(
                                          'Delete Payment?',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AppTheme.textPrimary,
                                          ),
                                        ),
                                        content: Text(
                                          'Delete payment entry of ${p.formattedAmount}?',
                                          style: GoogleFonts.inter(
                                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  AppTheme.errorRose,
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true && mounted) {
                                      paymentProvider.deletePayment(
                                        _student!.id,
                                        p.id,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                        if (paymentProvider.payments.length > 1)
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentHistoryScreen(
                                    student: _student!,
                                  ),
                                ),
                              );
                            },
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'View all ${paymentProvider.payments.length} payment records',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              // ─── Contact Info with Call & WhatsApp Launchers
              if (_student!.contactNumber.isNotEmpty ||
                  _student!.studentContactNumber.isNotEmpty ||
                  _student!.address.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Contact',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Guardian Contact
                      if (_student!.contactNumber.isNotEmpty) ...[
                        _ContactActionRow(
                          title: 'Guardian Phone',
                          phone: _student!.contactNumber,
                        ),
                        if (_student!.studentContactNumber.isNotEmpty ||
                            _student!.address.isNotEmpty)
                          Divider(
                            height: 20,
                            color: isDark ? AppTheme.darkBorder : null,
                          ),
                      ],
                      // Student Contact
                      if (_student!.studentContactNumber.isNotEmpty) ...[
                        _ContactActionRow(
                          title: 'Student Phone',
                          phone: _student!.studentContactNumber,
                        ),
                        if (_student!.address.isNotEmpty)
                          Divider(
                            height: 20,
                            color: isDark ? AppTheme.darkBorder : null,
                          ),
                      ],
                      // Address
                      if (_student!.address.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: isDark
                                  ? AppTheme.darkTextMuted
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tution Address',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextMuted
                                          : AppTheme.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _student!.address,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Tution Schedule & Probable Time
                      if (_student!.weeklySchedule.isNotEmpty ||
                          _student!.probableTime.isNotEmpty) ...[
                        if (_student!.contactNumber.isNotEmpty ||
                            _student!.studentContactNumber.isNotEmpty ||
                            _student!.address.isNotEmpty)
                          Divider(
                            height: 20,
                            color: isDark ? AppTheme.darkBorder : null,
                          ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 18,
                              color: isDark
                                  ? AppTheme.darkTextMuted
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tution Schedule & Time',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppTheme.darkTextMuted
                                          : AppTheme.textMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (_student!.weeklySchedule.isNotEmpty)
                                        _student!.weeklySchedule.join(' • '),
                                      if (_student!.probableTime.isNotEmpty)
                                        _student!.formattedProbableTime,
                                    ].join('  |  '),
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contact row with direct Call and WhatsApp action buttons
class _ContactActionRow extends StatelessWidget {
  final String title;
  final String phone;

  const _ContactActionRow({
    required this.title,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Icon(
          Icons.phone_outlined,
          size: 18,
          color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            onTap: () => AppFormatters.launchDialer(phone),
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: phone));
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Copied $phone to clipboard',
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              );
            },
            child: Tooltip(
              message: 'Tap to call, press & hold to copy',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      phone,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 1. Call Button
        IconButton(
          tooltip: 'Call $phone',
          onPressed: () => AppFormatters.launchDialer(phone),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              Icons.phone_rounded,
              size: 16,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // 2. Direct Message (SMS) Button
        IconButton(
          tooltip: 'Message $phone',
          onPressed: () => AppFormatters.launchSms(phone),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF06B6D4).withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              Icons.chat_outlined,
              size: 16,
              color: Color(0xFF06B6D4),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // 3. WhatsApp Button with Authentic Logo
        IconButton(
          tooltip: 'WhatsApp $phone',
          onPressed: () => AppFormatters.launchWhatsApp(phone),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.14),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const WhatsAppIcon(
              size: 16,
              color: Color(0xFF25D366),
            ),
          ),
        ),
      ],
    );
  }
}

/// Legend item for calendar
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

