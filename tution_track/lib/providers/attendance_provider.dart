import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/session_model.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';
import '../services/attendance_ledger_service.dart';

/// Attendance state provider for session tracking, one-tap attendance, and monthly stats
class AttendanceProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  // Dashboard summary data
  Map<String, int> _sessionCounts = {}; // studentId -> session count
  String _currentMonthYear = '';

  // Today's logged student IDs (for dynamic one-tap button state)
  Set<String> _todayLoggedStudentIds = {};

  // Per-student session history
  List<SessionModel> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Map<String, int> get sessionCounts => _sessionCounts;
  String get currentMonthYear => _currentMonthYear;
  Set<String> get todayLoggedStudentIds => _todayLoggedStudentIds;
  List<SessionModel> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Get the current user's UID
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Check if a student has had a class marked today
  bool isLoggedToday(String studentId) {
    return _todayLoggedStudentIds.contains(studentId);
  }

  /// Get session count for a specific student in current month
  int getSessionCount(String studentId) {
    return _sessionCounts[studentId] ?? 0;
  }

  /// Fetch monthly attendance summary and today's check-in status
  Future<void> fetchSummary({String? monthYear}) async {
    if (_uid == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentMonthYear =
          monthYear ?? DateFormat('yyyy-MM').format(DateTime.now());

      final results = await Future.wait([
        _firestoreService.getMonthlySessionCounts(_uid!, monthYear: monthYear),
        _firestoreService.getTodayLoggedStudentIds(_uid!),
      ]);

      _sessionCounts = results[0] as Map<String, int>;
      _todayLoggedStudentIds = results[1] as Set<String>;
    } catch (e) {
      _errorMessage = 'Failed to load attendance summary';
      debugPrint('Fetch summary error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Quick one-tap check-in with immediate haptic feedback
  Future<bool> quickCheckIn(
    String studentId, {
    List<String>? weeklySchedule,
    String? notes,
    StudentModel? student,
    String? sessionType,
    String? replacesMissedDate,
  }) async {
    if (_uid == null) return false;

    // Immediate haptic feedback
    HapticFeedback.mediumImpact();

    try {
      // Optimistic local update
      _todayLoggedStudentIds.add(studentId);
      final current = _sessionCounts[studentId] ?? 0;
      _sessionCounts[studentId] = current + 1;
      notifyListeners();

      final session = await _firestoreService.checkIn(
        _uid!,
        studentId,
        weeklySchedule: weeklySchedule,
        notes: notes,
        student: student,
        sessionType: sessionType,
        replacesMissedDate: replacesMissedDate,
      );

      // If viewing this student's sessions, update list
      if (_sessions.isNotEmpty && _sessions.first.studentId == studentId) {
        _sessions.insert(0, session);
        _sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifyListeners();
      }

      return true;
    } catch (e) {
      // Revert optimistic update
      _todayLoggedStudentIds.remove(studentId);
      final current = _sessionCounts[studentId] ?? 1;
      if (current > 0) _sessionCounts[studentId] = current - 1;
      _errorMessage = 'Failed to record check-in';
      debugPrint('Check-in error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Undo today's check-in
  Future<bool> undoTodayCheckIn(String studentId) async {
    if (_uid == null) return false;

    HapticFeedback.lightImpact();

    try {
      final success = await _firestoreService.deleteTodaySession(_uid!, studentId);
      if (success) {
        _todayLoggedStudentIds.remove(studentId);
        final current = _sessionCounts[studentId] ?? 0;
        if (current > 0) {
          _sessionCounts[studentId] = current - 1;
        }

        // Also remove from current session list if student detail is open
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        _sessions.removeWhere(
          (s) => s.studentId == studentId && s.dateString == todayStr,
        );

        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Failed to undo check-in';
      debugPrint('Undo check-in error: $e');
    }

    notifyListeners();
    return false;
  }

  /// Manual entry with custom date/time and broad time slot
  Future<bool> manualEntry(
    String studentId,
    DateTime customTimestamp, {
    String? notes,
    String? timeSlot,
    bool? isExtraClass,
    List<String>? weeklySchedule,
    StudentModel? student,
    String? sessionType,
    String? replacesMissedDate,
  }) async {
    if (_uid == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final session = await _firestoreService.manualEntry(
        _uid!,
        studentId,
        customTimestamp,
        notes: notes,
        timeSlot: timeSlot,
        isExtraClass: isExtraClass,
        weeklySchedule: weeklySchedule,
        student: student,
        sessionType: sessionType,
        replacesMissedDate: replacesMissedDate,
      );

      // Check if entry is for today
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (session.dateString == todayStr) {
        _todayLoggedStudentIds.add(studentId);
      }

      // Update local count if it's the current month
      final targetMonth = DateFormat('yyyy-MM').format(customTimestamp);
      if (targetMonth == _currentMonthYear) {
        final current = _sessionCounts[studentId] ?? 0;
        _sessionCounts[studentId] = current + 1;
      }

      // Prepend to local session list
      _sessions.insert(0, session);
      _sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to record manual entry';
      debugPrint('Manual entry error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Fetch sessions for a specific student and month
  Future<void> fetchStudentSessions(
    String studentId, {
    String? monthYear,
    StudentModel? student,
  }) async {
    if (_uid == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final rawSessions = await _firestoreService.getStudentSessions(
        _uid!,
        studentId,
        monthYear: monthYear,
      );

      if (student != null) {
        DateTime calendarMonth = DateTime.now();
        if (monthYear != null && monthYear.contains('-')) {
          final parts = monthYear.split('-');
          calendarMonth = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        }
        _sessions = AttendanceLedgerService.reconcileSessions(
          student: student,
          calendarMonth: calendarMonth,
          sessions: rawSessions,
        );

        // Sync any repaired sessions to Firestore in background
        for (final r in _sessions) {
          final orig = rawSessions.firstWhere((s) => s.id == r.id, orElse: () => r);
          if (orig.sessionType != r.sessionType ||
              orig.replacesMissedDate != r.replacesMissedDate) {
            _firestoreService.updateSessionType(
              _uid!,
              r.id,
              sessionType: r.sessionType,
              replacesMissedDate: r.replacesMissedDate,
            ).catchError((e) => debugPrint('Error syncing reconciled session: $e'));
          }
        }
      } else {
        _sessions = rawSessions;
      }
    } catch (e) {
      _errorMessage = 'Failed to load sessions: $e';
      debugPrint('Fetch sessions error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Delete a session
  Future<bool> deleteSession(String sessionId, String studentId) async {
    if (_uid == null) return false;

    try {
      final sessionIndex = _sessions.indexWhere((s) => s.id == sessionId);
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (sessionIndex != -1) {
        if (_sessions[sessionIndex].dateString == todayStr) {
          _todayLoggedStudentIds.remove(studentId);
        }
        _sessions.removeAt(sessionIndex);
      }

      await _firestoreService.deleteSession(_uid!, sessionId);

      // Decrement local count
      final current = _sessionCounts[studentId] ?? 0;
      if (current > 0) {
        _sessionCounts[studentId] = current - 1;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete session';
      notifyListeners();
    }
    return false;
  }

  /// Update notes / topic for a specific session (optimistic)
  Future<bool> updateSessionNotes(String sessionId, String notes) async {
    if (_uid == null) return false;

    // 1. Optimistic update in memory
    final index = _sessions.indexWhere((s) => s.id == sessionId);
    final previousNotes = index != -1 ? _sessions[index].notes : '';

    if (index != -1) {
      _sessions[index] = _sessions[index].copyWith(notes: notes);
      notifyListeners();
    }

    try {
      await _firestoreService.updateSessionNotes(_uid!, sessionId, notes);
      return true;
    } catch (e) {
      // Revert optimistic update on failure
      if (index != -1 && index < _sessions.length) {
        _sessions[index] = _sessions[index].copyWith(notes: previousNotes);
        notifyListeners();
      }
      _errorMessage = 'Failed to update session notes';
      debugPrint('Update notes error: $e');
      return false;
    }
  }

  /// Get unique dates from sessions (for calendar marking)
  Set<DateTime> getSessionDates() {
    final dates = <DateTime>{};
    for (final session in _sessions) {
      final parts = session.dateString.split('-');
      if (parts.length == 3) {
        dates.add(DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ));
      }
    }
    return dates;
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Reassign session type or target replaced missed date
  Future<bool> reassignSessionType({
    required String sessionId,
    required String sessionType,
    String replacesMissedDate = '',
  }) async {
    if (_uid == null) return false;

    try {
      await _firestoreService.updateSessionType(
        _uid!,
        sessionId,
        sessionType: sessionType,
        replacesMissedDate: replacesMissedDate,
      );

      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        _sessions[index] = _sessions[index].copyWith(
          sessionType: sessionType,
          replacesMissedDate: replacesMissedDate,
          isExtraClass: sessionType != 'SCHEDULED',
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to reassign session: $e';
      debugPrint('Reassign session error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get deterministically reconciled sessions for a student and month
  List<SessionModel> getReconciledSessions(StudentModel student, DateTime calendarMonth) {
    final reconciled = AttendanceLedgerService.reconcileSessions(
      student: student,
      calendarMonth: calendarMonth,
      sessions: _sessions,
    );

    // Sync any repaired sessions to Firestore in background
    for (final r in reconciled) {
      final idx = _sessions.indexWhere((s) => s.id == r.id);
      if (idx != -1) {
        final current = _sessions[idx];
        if (current.sessionType != r.sessionType ||
            current.replacesMissedDate != r.replacesMissedDate) {
          _sessions[idx] = r;
          if (_uid != null) {
            _firestoreService.updateSessionType(
              _uid!,
              r.id,
              sessionType: r.sessionType,
              replacesMissedDate: r.replacesMissedDate,
            ).catchError((e) => debugPrint('Error auto-syncing reconciled session: $e'));
          }
        }
      }
    }

    return reconciled;
  }

  /// Get intelligent attendance ledger summary for a student and month
  LedgerSummary getLedgerSummary(StudentModel student, DateTime calendarMonth) {
    return AttendanceLedgerService.reconcileMonth(
      student: student,
      calendarMonth: calendarMonth,
      sessions: _sessions,
    );
  }

  /// Clear sessions (when navigating away)
  void clearSessions() {
    _sessions = [];
    notifyListeners();
  }
}
