import 'package:intl/intl.dart';
import '../models/session_model.dart';
import '../models/student_model.dart';
import '../utils/formatters.dart';

/// Represents an individual missed class gap and its resolution state
class MissedDateEntry {
  final String date; // "YYYY-MM-DD"
  final String dayOfWeek; // "Tuesday"
  final String dayAbbr; // "Tue"
  final bool isResolved;
  final String resolvedOn; // "YYYY-MM-DD" (date of makeup class)
  final String resolvedBySessionId;

  const MissedDateEntry({
    required this.date,
    required this.dayOfWeek,
    required this.dayAbbr,
    this.isResolved = false,
    this.resolvedOn = '',
    this.resolvedBySessionId = '',
  });

  /// Readable formatted string: e.g., "Tue, 1st Sep"
  String get formattedDate {
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        final d = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final ordinal = AppFormatters.formatDateOrdinal(d);
        final monthDay = ordinal.split(',').first.trim();
        return '$dayAbbr, $monthDay';
      }
    } catch (_) {}
    return date;
  }

  /// Readable resolved string: e.g., "Thu, 3rd Sep"
  String get formattedResolvedOn {
    if (resolvedOn.isEmpty) return '';
    try {
      final parts = resolvedOn.split('-');
      if (parts.length == 3) {
        final d = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final dAbbr = DateFormat('EEE').format(d);
        final ordinal = AppFormatters.formatDateOrdinal(d);
        final monthDay = ordinal.split(',').first.trim();
        return '$dAbbr, $monthDay';
      }
    } catch (_) {}
    return resolvedOn;
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'dayOfWeek': dayOfWeek,
      'dayAbbr': dayAbbr,
      'isResolved': isResolved,
      'resolvedOn': resolvedOn,
      'resolvedBySessionId': resolvedBySessionId,
    };
  }

  factory MissedDateEntry.fromMap(Map<String, dynamic> map) {
    return MissedDateEntry(
      date: map['date']?.toString() ?? '',
      dayOfWeek: map['dayOfWeek']?.toString() ?? '',
      dayAbbr: map['dayAbbr']?.toString() ?? '',
      isResolved: map['isResolved'] == true,
      resolvedOn: map['resolvedOn']?.toString() ?? '',
      resolvedBySessionId: map['resolvedBySessionId']?.toString() ?? '',
    );
  }

  MissedDateEntry copyWith({
    String? date,
    String? dayOfWeek,
    String? dayAbbr,
    bool? isResolved,
    String? resolvedOn,
    String? resolvedBySessionId,
  }) {
    return MissedDateEntry(
      date: date ?? this.date,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dayAbbr: dayAbbr ?? this.dayAbbr,
      isResolved: isResolved ?? this.isResolved,
      resolvedOn: resolvedOn ?? this.resolvedOn,
      resolvedBySessionId: resolvedBySessionId ?? this.resolvedBySessionId,
    );
  }
}

/// Aggregated Ledger Summary for a specific month
class LedgerSummary {
  final int missedCount;
  final int recoveredCount;
  final int unresolvedCount;
  final int scheduledCount;
  final int makeupCount;
  final int pureExtraCount;
  final List<MissedDateEntry> gapEntries;

  const LedgerSummary({
    required this.missedCount,
    required this.recoveredCount,
    required this.unresolvedCount,
    required this.scheduledCount,
    required this.makeupCount,
    required this.pureExtraCount,
    required this.gapEntries,
  });

  /// Factory for empty summary
  factory LedgerSummary.empty() {
    return const LedgerSummary(
      missedCount: 0,
      recoveredCount: 0,
      unresolvedCount: 0,
      scheduledCount: 0,
      makeupCount: 0,
      pureExtraCount: 0,
      gapEntries: [],
    );
  }
}

/// Service that detects missed sessions and automatically reconciles makeup classes via FIFO
class AttendanceLedgerService {
  /// Detect all missed scheduled days for a given calendar month
  static List<MissedDateEntry> detectMissedDates({
    required StudentModel student,
    required DateTime calendarMonth,
    required List<SessionModel> sessions,
    DateTime? nowOverride,
  }) {
    if (student.weeklySchedule.isEmpty) return [];

    final now = nowOverride ?? DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // Month boundary
    final firstDayOfMonth = DateTime(calendarMonth.year, calendarMonth.month, 1);
    final lastDayOfMonth = DateTime(calendarMonth.year, calendarMonth.month + 1, 0);

    // Start from the first day of the calendar month (billing cycle start)
    DateTime startDate = firstDayOfMonth;

    // Effective end date: cannot miss dates that have not yet passed 11:59 PM
    DateTime endDate = lastDayOfMonth;
    final yesterdayMidnight = todayMidnight.subtract(const Duration(days: 1));
    if (endDate.isAfter(yesterdayMidnight)) {
      endDate = yesterdayMidnight;
    }

    if (startDate.isAfter(endDate)) {
      return [];
    }

    // Set of date strings where sessions were completed
    final completedDateStrings = sessions.map((s) => s.dateString).toSet();

    final missedList = <MissedDateEntry>[];

    DateTime cursor = startDate;
    while (!cursor.isAfter(endDate)) {
      final dayAbbr = DateFormat('EEE').format(cursor); // e.g. "Sat", "Mon"
      if (student.weeklySchedule.contains(dayAbbr)) {
        final dateStr = DateFormat('yyyy-MM-dd').format(cursor);
        if (!completedDateStrings.contains(dateStr)) {
          missedList.add(MissedDateEntry(
            date: dateStr,
            dayOfWeek: DateFormat('EEEE').format(cursor),
            dayAbbr: dayAbbr,
            isResolved: false,
          ));
        }
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    // Sort ascending (chronological order)
    missedList.sort((a, b) => a.date.compareTo(b.date));
    return missedList;
  }

  /// Deterministic FIFO reconciliation of a session list against missed gaps.
  /// Automatically re-evaluates off-schedule sessions:
  /// If an unfulfilled gap precedes or matches the session, maps it as MAKEUP for that gap.
  /// Only sessions with NO preceding unfulfilled gaps are left as EXTRA.
  static List<SessionModel> reconcileSessions({
    required StudentModel student,
    required DateTime calendarMonth,
    required List<SessionModel> sessions,
    DateTime? nowOverride,
  }) {
    if (sessions.isEmpty) return [];

    // Sort chronologically ascending for deterministic FIFO matching
    final sorted = List<SessionModel>.from(sessions)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final missedEntries = detectMissedDates(
      student: student,
      calendarMonth: calendarMonth,
      sessions: sorted,
      nowOverride: nowOverride,
    );

    // Track resolution of gaps
    final Set<String> resolvedGapDates = {};

    // 1. Honor explicit manual mappings if the gap is valid
    for (final s in sorted) {
      if (s.sessionType == 'MAKEUP' && s.replacesMissedDate.isNotEmpty) {
        resolvedGapDates.add(s.replacesMissedDate);
      }
    }

    // 2. Process all sessions in chronological order
    final reconciledList = <SessionModel>[];
    for (final session in sorted) {
      final dayAbbr = DateFormat('EEE').format(session.timestamp);
      final isScheduledDay = student.weeklySchedule.contains(dayAbbr);

      if (isScheduledDay) {
        // Scheduled day class: keep as SCHEDULED unless manually reassigned
        reconciledList.add(session);
      } else {
        // Off-schedule class:
        if (session.sessionType == 'MAKEUP' && session.replacesMissedDate.isNotEmpty) {
          // Already explicitly mapped
          reconciledList.add(session);
        } else {
          // Check for earliest unresolved missed date on or before this session date (FIFO)
          final availableGaps = missedEntries
              .where((g) =>
                  !resolvedGapDates.contains(g.date) &&
                  g.date.compareTo(session.dateString) <= 0)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          if (availableGaps.isNotEmpty) {
            final targetGap = availableGaps.first;
            resolvedGapDates.add(targetGap.date);

            final updatedSession = session.copyWith(
              sessionType: 'MAKEUP',
              type: SessionType.makeup,
              replacesMissedDate: targetGap.date,
              isExtraClass: true,
            );
            reconciledList.add(updatedSession);
          } else {
            // No unfulfilled gaps prior to this session -> pure EXTRA class
            final updatedSession = session.copyWith(
              sessionType: 'EXTRA',
              type: SessionType.extra,
              replacesMissedDate: '',
              isExtraClass: true,
            );
            reconciledList.add(updatedSession);
          }
        }
      }
    }

    // Order descending by timestamp (newest first) for standard list display
    reconciledList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return reconciledList;
  }

  /// Reconcile sessions and missed dates for a month with FIFO logic
  static LedgerSummary reconcileMonth({
    required StudentModel student,
    required DateTime calendarMonth,
    required List<SessionModel> sessions,
    DateTime? nowOverride,
  }) {
    final reconciledSessions = reconcileSessions(
      student: student,
      calendarMonth: calendarMonth,
      sessions: sessions,
      nowOverride: nowOverride,
    );

    final missedEntries = detectMissedDates(
      student: student,
      calendarMonth: calendarMonth,
      sessions: reconciledSessions,
      nowOverride: nowOverride,
    );

    final missedMap = <String, MissedDateEntry>{
      for (final m in missedEntries) m.date: m,
    };

    for (final s in reconciledSessions) {
      if (s.sessionType == 'MAKEUP' &&
          s.replacesMissedDate.isNotEmpty &&
          missedMap.containsKey(s.replacesMissedDate)) {
        final m = missedMap[s.replacesMissedDate]!;
        missedMap[s.replacesMissedDate] = m.copyWith(
          isResolved: true,
          resolvedOn: s.dateString,
          resolvedBySessionId: s.id,
        );
      }
    }

    final updatedGaps = missedMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final missedCount = updatedGaps.length;
    final recoveredCount = updatedGaps.where((g) => g.isResolved).length;
    final unresolvedCount = missedCount - recoveredCount;

    int scheduledCount = 0;
    int makeupCount = 0;
    int pureExtraCount = 0;

    for (final s in reconciledSessions) {
      if (s.sessionType == 'MAKEUP') {
        makeupCount++;
      } else if (s.sessionType == 'EXTRA') {
        pureExtraCount++;
      } else {
        scheduledCount++;
      }
    }

    return LedgerSummary(
      missedCount: missedCount,
      recoveredCount: recoveredCount,
      unresolvedCount: unresolvedCount,
      scheduledCount: scheduledCount,
      makeupCount: makeupCount,
      pureExtraCount: pureExtraCount,
      gapEntries: updatedGaps,
    );
  }

  /// Calculate monthly quota progress with carry-forward support and bonus extra count
  static ({
    int quotaCompleted,
    int totalTarget,
    int percentage,
    int bonusExtraCount,
    int carriedForwardCount,
    bool isQuotaCompleted,
  }) calculateQuota({
    required StudentModel student,
    required List<SessionModel> sessions,
  }) {
    final target = student.monthlyTargetClasses;
    final carried = (student.carryForwardExtraClasses == true) ? student.carriedForwardClasses : 0;
    final totalSessions = sessions.length;
    final effectiveTotal = totalSessions + carried;

    if (effectiveTotal <= target) {
      final pct = target > 0 ? ((effectiveTotal / target) * 100).toInt() : 0;
      return (
        quotaCompleted: effectiveTotal,
        totalTarget: target,
        percentage: pct,
        bonusExtraCount: 0,
        carriedForwardCount: carried,
        isQuotaCompleted: target > 0 && effectiveTotal >= target,
      );
    } else {
      final bonus = effectiveTotal - target;
      return (
        quotaCompleted: target,
        totalTarget: target,
        percentage: 100,
        bonusExtraCount: bonus,
        carriedForwardCount: carried,
        isQuotaCompleted: true,
      );
    }
  }

  /// Automatically classify a new session being logged:
  /// Returns a record with `(sessionType, replacesMissedDate)`
  static ({String sessionType, String replacesMissedDate}) classifySession({
    required StudentModel student,
    required DateTime sessionTimestamp,
    required List<SessionModel> existingSessions,
    DateTime? nowOverride,
  }) {
    final dayAbbr = DateFormat('EEE').format(sessionTimestamp);
    final isScheduled = student.weeklySchedule.isNotEmpty &&
        student.weeklySchedule.contains(dayAbbr);

    if (isScheduled) {
      return (sessionType: 'SCHEDULED', replacesMissedDate: '');
    }

    // Unscheduled session: Check for any pending unfulfilled missed dates in the month
    final calendarMonth = DateTime(sessionTimestamp.year, sessionTimestamp.month, 1);
    final missedEntries = detectMissedDates(
      student: student,
      calendarMonth: calendarMonth,
      sessions: existingSessions,
      nowOverride: nowOverride,
    );

    // Identify which missed dates are already resolved by existing sessions
    final resolvedDates = <String>{};
    for (final s in existingSessions) {
      if (s.sessionType == 'MAKEUP' && s.replacesMissedDate.isNotEmpty) {
        resolvedDates.add(s.replacesMissedDate);
      }
    }

    // Find earliest unfulfilled missed date strictly prior or equal to this session (FIFO)
    final sessionDateStr = DateFormat('yyyy-MM-dd').format(sessionTimestamp);
    final pendingGaps = missedEntries
        .where((m) =>
            !resolvedDates.contains(m.date) &&
            m.date.compareTo(sessionDateStr) <= 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (pendingGaps.isNotEmpty) {
      // Case A: Pending gap exists -> Makeup Class replacing earliest missed date
      return (
        sessionType: 'MAKEUP',
        replacesMissedDate: pendingGaps.first.date,
      );
    }

    // Case B: No pending gaps -> Pure Extra Class (Bonus)
    return (sessionType: 'EXTRA', replacesMissedDate: '');
  }
}
