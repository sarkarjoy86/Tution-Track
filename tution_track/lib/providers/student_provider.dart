import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';

/// Student list state provider
class StudentProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<StudentModel> _students = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Cached lifetime metrics: studentId -> {totalSessions, totalFees}
  final Map<String, Map<String, num>> _studentMetrics = {};

  // Getters
  List<StudentModel> get students => _students;
  List<StudentModel> get activeStudents =>
      _students.where((s) => s.isActive).toList();
  List<StudentModel> get archivedStudents =>
      _students.where((s) => !s.isActive).toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get activeCount => activeStudents.length;
  int get archivedCount => archivedStudents.length;

  /// Get the current user's UID
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Fetch all students from Firestore
  Future<void> fetchStudents() async {
    if (_uid == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _students = await _firestoreService.getStudents(_uid!);
      // Asynchronously pre-fetch lifetime metrics for archived students
      _fetchArchivedMetrics();
    } catch (e) {
      _errorMessage = 'Failed to load students';
      debugPrint('Fetch students error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Helper to fetch lifetime metrics for archived students
  Future<void> _fetchArchivedMetrics() async {
    if (_uid == null) return;
    for (final student in archivedStudents) {
      if (!_studentMetrics.containsKey(student.id)) {
        try {
          final totalSessions =
              await _firestoreService.getStudentTotalSessions(_uid!, student.id);
          final totalFees =
              await _firestoreService.getTotalFeesCollected(_uid!, student.id);
          _studentMetrics[student.id] = {
            'totalSessions': totalSessions,
            'totalFees': totalFees,
          };
          notifyListeners();
        } catch (_) {}
      }
    }
  }

  /// Get cached lifetime metrics for a student
  Map<String, num>? getStudentMetrics(String studentId) {
    return _studentMetrics[studentId];
  }

  /// Add a new student
  Future<bool> addStudent(Map<String, dynamic> data) async {
    if (_uid == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final student = await _firestoreService.addStudent(_uid!, data);
      _students.insert(0, student);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage =
          'Failed to add student: ${e.toString().replaceAll('Exception: ', '')}';
      debugPrint('Add student error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Update an existing student
  Future<bool> updateStudent(String id, Map<String, dynamic> data) async {
    if (_uid == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _firestoreService.updateStudent(_uid!, id, data);
      final index = _students.indexWhere((s) => s.id == id);
      if (index != -1) {
        updated.completedSessions = _students[index].completedSessions;
        _students[index] = updated;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update student';
      debugPrint('Update student error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Discontinue a student (mark as completed / left with date and note)
  Future<bool> discontinueStudent(
    String id, {
    DateTime? leavingDate,
    String? note,
  }) async {
    if (_uid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final updated = await _firestoreService.discontinueStudent(
        _uid!,
        id,
        leavingDate: leavingDate,
        leavingNote: note,
      );
      final index = _students.indexWhere((s) => s.id == id);
      if (index != -1) {
        updated.completedSessions = _students[index].completedSessions;
        _students[index] = updated;
      }
      _fetchArchivedMetrics();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to discontinue tution';
      debugPrint('Discontinue error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Restore / reactivate an archived student
  Future<bool> reactivateStudent(String id) async {
    if (_uid == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final updated = await _firestoreService.reactivateStudent(_uid!, id);
      final index = _students.indexWhere((s) => s.id == id);
      if (index != -1) {
        updated.completedSessions = _students[index].completedSessions;
        _students[index] = updated;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to restore student';
      debugPrint('Restore error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Alias for reactivateStudent (for settings_screen compatibility)
  Future<bool> restoreStudent(String id) => reactivateStudent(id);

  /// Permanently delete a student
  Future<bool> deleteStudent(String id) async {
    if (_uid == null) return false;

    try {
      await _firestoreService.deleteStudent(_uid!, id);
      _students.removeWhere((s) => s.id == id);
      _studentMetrics.remove(id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete student';
      notifyListeners();
    }
    return false;
  }

  /// Toggle fee paid status
  Future<bool> toggleFeePaid(String id, bool isPaid, String monthYear) async {
    if (_uid == null) return false;

    try {
      final updated = await _firestoreService.updateStudent(_uid!, id, {
        'isFeePaidThisMonth': isPaid,
        'feePaidMonthYear': monthYear,
      });
      final index = _students.indexWhere((s) => s.id == id);
      if (index != -1) {
        updated.completedSessions = _students[index].completedSessions;
        _students[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update fee status';
      notifyListeners();
    }
    return false;
  }

  /// Update completed sessions count for a student
  void updateSessionCount(String studentId, int count) {
    final index = _students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      _students[index].completedSessions = count;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

