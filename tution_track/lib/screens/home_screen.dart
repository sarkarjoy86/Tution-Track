import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../providers/auth_provider.dart';
import '../providers/student_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../widgets/student_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/next_tution_banner.dart';
import '../services/connectivity_service.dart';

/// Main dashboard showing active tutions and archived past students with one-tap attendance
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime? _lastBackPressTime;
  int _selectedTabIndex = 0; // 0: Active Tutions, 1: Archived / Past
  bool _isRevenueVisible = false;
  Timer? _midnightTimer;
  Timer? _periodicTicker;
  DateTime _lastCheckedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _scheduleMidnightTimer();
    _startPeriodicTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    _periodicTicker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (now.day != _lastCheckedDate.day ||
          now.month != _lastCheckedDate.month ||
          now.year != _lastCheckedDate.year) {
        _lastCheckedDate = now;
        _refreshData();
        _scheduleMidnightTimer();
      }
    }
  }

  void _scheduleMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 2);
    final duration = nextMidnight.difference(now);
    _midnightTimer = Timer(duration, () {
      if (mounted) {
        _lastCheckedDate = DateTime.now();
        _refreshData();
        _scheduleMidnightTimer();
      }
    });
  }

  void _startPeriodicTicker() {
    _periodicTicker?.cancel();
    _periodicTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadData() async {
    final studentProvider = context.read<StudentProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    await Future.wait([
      studentProvider.fetchStudents(),
      attendanceProvider.fetchSummary(),
    ]);

    if (mounted) {
      final counts = attendanceProvider.sessionCounts;
      for (final entry in counts.entries) {
        studentProvider.updateSessionCount(entry.key, entry.value);
      }
    }
  }

  Future<void> _refreshData() async {
    await _loadData();
  }

  /// Handle One-Tap Check-In
  Future<void> _handleCheckIn(StudentModel student) async {
    final attendanceProvider = context.read<AttendanceProvider>();
    final studentProvider = context.read<StudentProvider>();

    final success = await attendanceProvider.quickCheckIn(
      student.id,
      weeklySchedule: student.weeklySchedule,
      student: student,
    );

    if (mounted) {
      if (success) {
        final newCount = attendanceProvider.getSessionCount(student.id);
        studentProvider.updateSessionCount(student.id, newCount);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Class recorded for ${student.name}'),
                ),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () => _handleUndo(student),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (attendanceProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(attendanceProvider.errorMessage!),
            backgroundColor: AppTheme.errorRose,
          ),
        );
      }
    }
  }

  /// Handle Undo Check-In
  Future<void> _handleUndo(StudentModel student) async {
    final shouldUndo = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            side: BorderSide(
              color: isDark ? AppTheme.darkBorder : Colors.transparent,
            ),
          ),
          title: Text(
            'Undo Today\'s Class?',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to remove today\'s attendance entry for ${student.name}?',
            style: GoogleFonts.inter(
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Keep',
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorRose),
              child: const Text('Undo Class'),
            ),
          ],
        );
      },
    );

    if (shouldUndo != true || !mounted) return;

    final attendanceProvider = context.read<AttendanceProvider>();
    final studentProvider = context.read<StudentProvider>();

    final success = await attendanceProvider.undoTodayCheckIn(student.id);

    if (mounted && success) {
      final newCount = attendanceProvider.getSessionCount(student.id);
      studentProvider.updateSessionCount(student.id, newCount);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance undone for ${student.name}'),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Reactivate an archived student
  Future<void> _handleReactivate(StudentModel student) async {
    final studentProvider = context.read<StudentProvider>();
    final success = await studentProvider.reactivateStudent(student.id);

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${student.name} restored to Active Tutions'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      _refreshData();
    }
  }

  /// Permanently delete an archived student
  void _handleDeleteArchivedStudent(StudentModel student) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.errorRose, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Permanently?',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete ${student.name} and all associated sessions and payment records from the database. This action cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color:
                isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final studentProvider = context.read<StudentProvider>();
              final success = await studentProvider.deleteStudent(student.id);
              if (!mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${student.name} permanently deleted'),
                    backgroundColor: AppTheme.errorRose,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _refreshData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(studentProvider.errorMessage ??
                        'Failed to delete student'),
                    backgroundColor: AppTheme.errorRose,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRose,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Dynamic schedule-aware sorting:
  /// Bucket A: Pending Today (Scheduled today first sorted by probableTime ascending, then other active)
  /// Bucket B: Completed Today (cards marked today, moved to bottom)
  List<StudentModel> _getSortedActiveStudents({
    required List<StudentModel> students,
    required AttendanceProvider attendanceProvider,
    required DateTime now,
  }) {
    final todayAbbr = DateFormat('E').format(now);

    final bucketA = <StudentModel>[]; // Pending Today
    final bucketB = <StudentModel>[]; // Completed Today

    for (final student in students) {
      if (attendanceProvider.isLoggedToday(student.id)) {
        bucketB.add(student);
      } else {
        bucketA.add(student);
      }
    }

    // Sort Bucket A (Pending Today):
    // 1. Scheduled for today at the top
    // 2. Chronologically by probableTime ascending
    // 3. Alphabetically by name
    bucketA.sort((a, b) {
      final aScheduled = a.weeklySchedule.contains(todayAbbr);
      final bScheduled = b.weeklySchedule.contains(todayAbbr);

      if (aScheduled && !bScheduled) return -1;
      if (!aScheduled && bScheduled) return 1;

      final aTime = a.probableTimeMinutes;
      final bTime = b.probableTimeMinutes;

      if (aTime != null && bTime != null) {
        final cmp = aTime.compareTo(bTime);
        if (cmp != 0) return cmp;
      } else if (aTime != null) {
        return -1;
      } else if (bTime != null) {
        return 1;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    // Sort Bucket B (Completed Today):
    // Chronologically by probableTime ascending, then name
    bucketB.sort((a, b) {
      final aTime = a.probableTimeMinutes;
      final bTime = b.probableTimeMinutes;

      if (aTime != null && bTime != null) {
        final cmp = aTime.compareTo(bTime);
        if (cmp != 0) return cmp;
      } else if (aTime != null) {
        return -1;
      } else if (bTime != null) {
        return 1;
      }

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return [...bucketA, ...bucketB];
  }

  StudentModel? _getNextPendingStudentToday({
    required List<StudentModel> activeStudents,
    required AttendanceProvider attendanceProvider,
    required DateTime now,
  }) {
    final todayAbbr = DateFormat('E').format(now);
    final pendingToday = activeStudents
        .where((s) =>
            s.weeklySchedule.contains(todayAbbr) &&
            !attendanceProvider.isLoggedToday(s.id))
        .toList();

    if (pendingToday.isEmpty) return null;

    final currentMinutes = now.hour * 60 + now.minute;

    // Upcoming sessions today (scheduled at or after current time)
    final upcoming = pendingToday
        .where((s) => (s.probableTimeMinutes ?? -1) >= currentMinutes)
        .toList()
      ..sort((a, b) => a.probableTimeMinutes!.compareTo(b.probableTimeMinutes!));

    if (upcoming.isNotEmpty) {
      return upcoming.first;
    }

    // If all pending scheduled sessions for today are earlier than current time,
    // pick earliest scheduled pending session today
    pendingToday.sort((a, b) {
      final aTime = a.probableTimeMinutes ?? 9999;
      final bTime = b.probableTimeMinutes ?? 9999;
      if (aTime != bTime) return aTime.compareTo(bTime);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return pendingToday.first;
  }

  StudentModel? _getEarliestTomorrowStudent({
    required List<StudentModel> activeStudents,
    required DateTime now,
  }) {
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowAbbr = DateFormat('E').format(tomorrow);
    final tomorrowStudents = activeStudents
        .where((s) => s.weeklySchedule.contains(tomorrowAbbr))
        .toList();

    if (tomorrowStudents.isEmpty) return null;

    tomorrowStudents.sort((a, b) {
      final aTime = a.probableTimeMinutes ?? 9999;
      final bTime = b.probableTimeMinutes ?? 9999;
      if (aTime != bTime) return aTime.compareTo(bTime);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return tomorrowStudents.first;
  }

  String _getTomorrowSummary({
    required List<StudentModel> activeStudents,
    required DateTime now,
  }) {
    final first = _getEarliestTomorrowStudent(
      activeStudents: activeStudents,
      now: now,
    );

    if (first == null) {
      return 'No classes scheduled for tomorrow';
    }

    final timeStr = first.formattedProbableTime.isNotEmpty
        ? ' • Tomorrow, ${first.formattedProbableTime}'
        : ' • Tomorrow';
    return "Next: ${first.name}$timeStr";
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final studentProvider = context.watch<StudentProvider>();
    final attendanceProvider = context.watch<AttendanceProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final connectivityService = context.watch<ConnectivityService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);
    final greeting = _getGreeting();
    final rawName = authProvider.user?.name.trim() ?? '';
    final userName = rawName.isNotEmpty ? rawName.split(' ').first : 'Tutor';

    final activeStudents = studentProvider.activeStudents;
    final archivedStudents = studentProvider.archivedStudents;

    // Smart Schedule-Aware Sorting
    final sortedActiveStudents = _getSortedActiveStudents(
      students: activeStudents,
      attendanceProvider: attendanceProvider,
      now: now,
    );

    // Schedule metrics for Next Tution Alert Banner
    final todayAbbr = DateFormat('E').format(now);
    final scheduledToday = activeStudents
        .where((s) => s.weeklySchedule.contains(todayAbbr))
        .toList();
    final hasScheduledToday = scheduledToday.isNotEmpty;
    final allCompletedToday = hasScheduledToday &&
        scheduledToday.every((s) => attendanceProvider.isLoggedToday(s.id));
    final nextStudentToday = hasScheduledToday && !allCompletedToday
        ? _getNextPendingStudentToday(
            activeStudents: activeStudents,
            attendanceProvider: attendanceProvider,
            now: now,
          )
        : null;
    final tomorrowStudent = _getEarliestTomorrowStudent(
      activeStudents: activeStudents,
      now: now,
    );
    final isNextTomorrow = nextStudentToday == null && tomorrowStudent != null;
    final bannerStudent = nextStudentToday ?? (allCompletedToday ? null : tomorrowStudent);
    final tomorrowSummary = _getTomorrowSummary(
      activeStudents: activeStudents,
      now: now,
    );

    // Total monthly projected fees in BDT
    final totalProjectedFee = activeStudents.fold<double>(
      0.0,
      (sum, s) => sum + s.monthlyFee,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final currentTime = DateTime.now();
        if (_lastBackPressTime == null ||
            currentTime.difference(_lastBackPressTime!) >
                const Duration(seconds: 2)) {
          _lastBackPressTime = currentTime;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Press back again to exit'),
                ],
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              backgroundColor: const Color(0xFF1E293B),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.surfaceLight,
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshData,
            color: primaryColor,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ─── Header & Greeting ──────────────────
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      border: isDark
                          ? const Border(
                              bottom: BorderSide(
                                color: AppTheme.darkBorder,
                                width: 1,
                              ),
                            )
                          : null,
                      boxShadow: isDark ? null : AppTheme.shadowSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$greeting 👋',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: isDark
                                          ? AppTheme.darkTextMuted
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    userName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Settings Button
                            IconButton(
                              onPressed: () {
                                Navigator.pushNamed(context, Routes.settings);
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppTheme.darkSurface
                                      : AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                  border: isDark
                                      ? Border.all(color: AppTheme.darkBorder)
                                      : null,
                                ),
                                child: Icon(
                                  Icons.settings_outlined,
                                  size: 20,
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Monthly Summary Stats Card (BDT)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: themeProvider.currentGradient,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg,
                            ),
                            boxShadow: AppTheme.shadowMd,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    monthName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusFull,
                                      ),
                                    ),
                                    child: Text(
                                      'Dashboard',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  // Active Students
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '${studentProvider.activeCount}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Active Tutions',
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color:
                                                  Colors.white.withOpacity(0.85),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 38,
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  // Total Sessions
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '${attendanceProvider.sessionCounts.values.fold<int>(0, (a, b) => a + b)}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Classes Taken',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color:
                                                    Colors.white.withOpacity(0.85),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 1,
                                    height: 38,
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  // Monthly Revenue (Tap to hide/show)
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isRevenueVisible = !_isRevenueVisible;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    alignment: Alignment.centerLeft,
                                                    child: Text(
                                                      _isRevenueVisible
                                                          ? AppFormatters.formatTaka(
                                                              totalProjectedFee,
                                                            )
                                                          : '৳ *****',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 17,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                        letterSpacing: _isRevenueVisible ? 0 : 1.5,
                                                      ),
                                                      maxLines: 1,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                Icon(
                                                  _isRevenueVisible
                                                      ? Icons.visibility_rounded
                                                      : Icons.visibility_off_rounded,
                                                  size: 13,
                                                  color: Colors.white.withOpacity(0.8),
                                                ),
                                              ],
                                            ),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                'Target Revenue',
                                                style: GoogleFonts.inter(
                                                  fontSize: 11,
                                                  color:
                                                      Colors.white.withOpacity(0.85),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Offline / Back-Online Status Banner ──
                SliverToBoxAdapter(
                  child: _OfflineBanner(
                    isOffline: connectivityService.isOffline,
                    connectivityService: connectivityService,
                  ),
                ),

                // ─── Dynamic "Next Tution" Alert Banner ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: NextTutionBanner(
                      nextStudent: bannerStudent,
                      hasScheduledToday: hasScheduledToday,
                      allCompletedToday: allCompletedToday,
                      tomorrowSummary: tomorrowSummary,
                      isTomorrow: isNextTomorrow,
                      onTap: () {
                        if (bannerStudent != null) {
                          Navigator.pushNamed(
                            context,
                            Routes.studentDetail,
                            arguments: bannerStudent,
                          ).then((_) => _refreshData());
                        }
                      },
                    ),
                  ),
                ),

                // ─── Sleek Status Filter Tab Toggle ──────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.borderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Tab 1: Active Tutions
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTabIndex = 0),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedTabIndex == 0
                                      ? primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.school_rounded,
                                      size: 16,
                                      color: _selectedTabIndex == 0
                                          ? Colors.white
                                          : (isDark
                                              ? AppTheme.darkTextSecondary
                                              : AppTheme.textSecondary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Active (${studentProvider.activeCount})',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedTabIndex == 0
                                            ? Colors.white
                                            : (isDark
                                                ? AppTheme.darkTextSecondary
                                                : AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Tab 2: Archived / Past
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTabIndex = 1),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _selectedTabIndex == 1
                                      ? primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.archive_outlined,
                                      size: 16,
                                      color: _selectedTabIndex == 1
                                          ? Colors.white
                                          : (isDark
                                              ? AppTheme.darkTextSecondary
                                              : AppTheme.textSecondary),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Past (${studentProvider.archivedCount})',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedTabIndex == 1
                                            ? Colors.white
                                            : (isDark
                                                ? AppTheme.darkTextSecondary
                                                : AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── Content for Active Tab ───────────────
                if (_selectedTabIndex == 0) ...[
                  if (studentProvider.isLoading && sortedActiveStudents.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                        ),
                      ),
                    )
                  else if (sortedActiveStudents.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.school_outlined,
                        title: 'No Active Tutions',
                        subtitle:
                            'Add your first student to start tracking attendance and managing fees.',
                        actionLabel: 'Add Student',
                        onAction: () {
                          Navigator.pushNamed(context, Routes.addStudent)
                              .then((_) => _refreshData());
                        },
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final student = sortedActiveStudents[index];
                            return StudentCard(
                              key: ValueKey(student.id),
                              student: student,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  Routes.studentDetail,
                                  arguments: student,
                                ).then((_) => _refreshData());
                              },
                              onCheckIn: () => _handleCheckIn(student),
                              onUndo: () => _handleUndo(student),
                            );
                          },
                          childCount: sortedActiveStudents.length,
                        ),
                      ),
                    ),
                ],

                // ─── Content for Archived Tab ─────────────
                if (_selectedTabIndex == 1) ...[
                  if (archivedStudents.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.history_edu_rounded,
                        title: 'No Past Students',
                        subtitle:
                            'Completed or discontinued tutions will appear here with lifetime history & metrics.',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final student = archivedStudents[index];
                            final metrics =
                                studentProvider.getStudentMetrics(student.id);

                            return _ArchivedStudentCard(
                              student: student,
                              metrics: metrics,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  Routes.studentDetail,
                                  arguments: student,
                                ).then((_) => _refreshData());
                              },
                              onReactivate: () => _handleReactivate(student),
                              onDelete: () => _handleDeleteArchivedStudent(student),
                            );
                          },
                          childCount: archivedStudents.length,
                        ),
                      ),
                    ),
                ],

                // Bottom spacing
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
              ],
            ),
          ),
        ),
        // FAB: Add student
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, Routes.addStudent)
                .then((_) => _refreshData());
          },
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'Add Student',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

/// Animated offline / back-online status banner
class _OfflineBanner extends StatefulWidget {
  final bool isOffline;
  final ConnectivityService connectivityService;

  const _OfflineBanner({
    required this.isOffline,
    required this.connectivityService,
  });

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner>
    with SingleTickerProviderStateMixin {
  bool _showBackOnline = false;
  Timer? _backOnlineTimer;

  @override
  void didUpdateWidget(covariant _OfflineBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detect transition from offline → online
    if (oldWidget.isOffline && !widget.isOffline) {
      setState(() => _showBackOnline = true);
      _backOnlineTimer?.cancel();
      _backOnlineTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showBackOnline = false);
      });
    }
  }

  @override
  void dispose() {
    _backOnlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showBanner = widget.isOffline || _showBackOnline;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: showBanner
          ? Padding(
              key: ValueKey(widget.isOffline ? 'offline' : 'back_online'),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: widget.isOffline
                      ? (isDark
                          ? const Color(0xFF3D2E10)
                          : const Color(0xFFFFF8E7))
                      : (isDark
                          ? const Color(0xFF0D3320)
                          : const Color(0xFFECFDF5)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isOffline
                        ? (isDark
                            ? const Color(0xFF6B5B22)
                            : const Color(0xFFE8D48B))
                        : (isDark
                            ? const Color(0xFF166534)
                            : const Color(0xFFA7F3D0)),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isOffline
                          ? Icons.cloud_off_rounded
                          : Icons.cloud_done_rounded,
                      size: 18,
                      color: widget.isOffline
                          ? (isDark
                              ? const Color(0xFFEAB308)
                              : const Color(0xFFB45309))
                          : (isDark
                              ? const Color(0xFF22C55E)
                              : const Color(0xFF15803D)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.isOffline
                            ? 'Offline Mode  •  Changes sync when reconnected'
                            : 'Back Online ✓',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: widget.isOffline
                              ? (isDark
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFF92400E))
                              : (isDark
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFF166534)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

/// Card representation for Archived / Past Students with lifetime history metrics
class _ArchivedStudentCard extends StatelessWidget {
  final StudentModel student;
  final Map<String, num>? metrics;
  final VoidCallback onTap;
  final VoidCallback onReactivate;
  final VoidCallback onDelete;

  const _ArchivedStudentCard({
    required this.student,
    required this.metrics,
    required this.onTap,
    required this.onReactivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final totalClasses = metrics?['totalSessions'] ?? student.completedSessions;
    final totalFee = metrics?['totalFees'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderLight,
        ),
        boxShadow: isDark ? null : AppTheme.shadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Name + Badge + Reactivate & Delete actions
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            student.grade.isNotEmpty
                                ? '${student.grade} • ${student.displaySubject}'
                                : student.displaySubject,
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: onReactivate,
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          label: const Text('Restore'),
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            textStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: AppTheme.errorRose,
                          ),
                          tooltip: 'Delete Permanently',
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ],
                ),
                Divider(
                  height: 20,
                  color: isDark ? AppTheme.darkBorder : null,
                ),

                // Lifetime History Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _LifetimeMetric(
                      icon: Icons.date_range_rounded,
                      label: 'Duration',
                      value: '${student.activeMonthsCount} mo',
                    ),
                    _LifetimeMetric(
                      icon: Icons.event_available_rounded,
                      label: 'Classes Taken',
                      value: '$totalClasses',
                    ),
                    _LifetimeMetric(
                      icon: Icons.payments_outlined,
                      label: 'Total Collected',
                      value: AppFormatters.formatTaka(totalFee),
                    ),
                  ],
                ),

                if (student.leavingNote.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppTheme.darkSurface
                          : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      'Note: ${student.leavingNote}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small lifetime metric item
class _LifetimeMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LifetimeMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: primaryColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            color: isDark ? AppTheme.darkTextMuted : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

