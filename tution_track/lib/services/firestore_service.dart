import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/session_model.dart';
import '../models/payment_model.dart';
import '../utils/formatters.dart';
import 'attendance_ledger_service.dart';
import 'connectivity_service.dart';

/// Cloud Firestore service — all CRUD operations scoped strictly under users/{uid}/
///
/// Uses cache-first reads when offline for instant data access.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────
  // Offline-aware helpers
  // ─────────────────────────────────────────────────────

  /// Returns true if the device is currently offline.
  bool get _isOffline =>
      ConnectivityService.instance?.isOffline ?? false;

  /// Resilient timestamp for writes — uses server timestamp when online,
  /// falls back to local [Timestamp.now()] when offline so documents
  /// are immediately readable from the cache.
  dynamic get _resilientTimestamp => _isOffline
      ? Timestamp.fromDate(DateTime.now())
      : FieldValue.serverTimestamp();

  /// Safely get a query snapshot — uses cache when offline or on network failure/timeout
  Future<QuerySnapshot<Map<String, dynamic>>> _getDocs(
    Query<Map<String, dynamic>> query, {
    bool useCache = false,
  }) async {
    if (useCache || _isOffline) {
      return query.get(const GetOptions(source: Source.cache));
    }
    try {
      return await query.get().timeout(
        const Duration(seconds: 4),
        onTimeout: () => query.get(const GetOptions(source: Source.cache)),
      );
    } catch (e) {
      try {
        return await query.get(const GetOptions(source: Source.cache));
      } catch (_) {
        rethrow;
      }
    }
  }

  /// Safely get a document snapshot — uses cache when offline or on network failure/timeout
  Future<DocumentSnapshot<Map<String, dynamic>>> _getDoc(
    DocumentReference<Map<String, dynamic>> docRef, {
    bool useCache = false,
  }) async {
    if (useCache || _isOffline) {
      return docRef.get(const GetOptions(source: Source.cache));
    }
    try {
      return await docRef.get().timeout(
        const Duration(seconds: 4),
        onTimeout: () => docRef.get(const GetOptions(source: Source.cache)),
      );
    } catch (e) {
      try {
        return await docRef.get(const GetOptions(source: Source.cache));
      } catch (_) {
        rethrow;
      }
    }
  }

  // ─────────────────────────────────────────────────────
  // Helper: collection references
  // ─────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _studentsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('students');

  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) =>
      _firestore.collection('users').doc(uid).collection('sessions');

  CollectionReference<Map<String, dynamic>> _paymentsRef(
    String uid,
    String studentId,
  ) =>
      _studentsRef(uid).doc(studentId).collection('payments');

  // ─────────────────────────────────────────────────────
  // STUDENTS
  // ─────────────────────────────────────────────────────

  /// Fetch all students for a user
  Future<List<StudentModel>> getStudents(String uid) async {
    final snapshot = await _getDocs(_studentsRef(uid));

    final students = snapshot.docs
        .map((doc) => StudentModel.fromFirestore(doc))
        .toList();
    students.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return students;
  }

  /// Add a new student
  Future<StudentModel> addStudent(String uid, Map<String, dynamic> data) async {
    data['tutorId'] = uid;
    data['createdAt'] = _resilientTimestamp;
    data['isActive'] = data['isActive'] ?? true;
    data['isFeePaidThisMonth'] = data['isFeePaidThisMonth'] ?? false;
    data['feePaidMonthYear'] = data['feePaidMonthYear'] ?? '';

    final docRef = await _studentsRef(uid).add(data);
    final doc = await _getDoc(docRef);
    return StudentModel.fromFirestore(doc);
  }

  /// Update an existing student
  Future<StudentModel> updateStudent(
    String uid,
    String studentId,
    Map<String, dynamic> data,
  ) async {
    await _studentsRef(uid).doc(studentId).update(data);
    final doc = await _getDoc(_studentsRef(uid).doc(studentId));
    return StudentModel.fromFirestore(doc);
  }

  /// Mark tution as discontinued / completed with optional leaving date and note
  Future<StudentModel> discontinueStudent(
    String uid,
    String studentId, {
    DateTime? leavingDate,
    String? leavingNote,
  }) async {
    final updateData = <String, dynamic>{
      'isActive': false,
      'leavingDate': Timestamp.fromDate(leavingDate ?? DateTime.now()),
      'leavingNote': leavingNote ?? '',
    };
    await _studentsRef(uid).doc(studentId).update(updateData);
    final doc = await _getDoc(_studentsRef(uid).doc(studentId));
    return StudentModel.fromFirestore(doc);
  }

  /// Reactivate an archived student
  Future<StudentModel> reactivateStudent(String uid, String studentId) async {
    final updateData = <String, dynamic>{
      'isActive': true,
      'leavingDate': null,
      'leavingNote': '',
    };
    await _studentsRef(uid).doc(studentId).update(updateData);
    final doc = await _getDoc(_studentsRef(uid).doc(studentId));
    return StudentModel.fromFirestore(doc);
  }

  /// Delete a student permanently
  Future<void> deleteStudent(String uid, String studentId) async {
    // 1. Cleanup payments subcollection
    final payments = await _getDocs(_paymentsRef(uid, studentId));
    for (final p in payments.docs) {
      await p.reference.delete();
    }
    // 2. Cleanup session records for this student
    final sessions = await _getDocs(
      _sessionsRef(uid).where('studentId', isEqualTo: studentId),
    );
    for (final s in sessions.docs) {
      await s.reference.delete();
    }
    // 3. Delete student doc
    await _studentsRef(uid).doc(studentId).delete();
  }

  // ─────────────────────────────────────────────────────
  // ATTENDANCE / SESSIONS
  // ─────────────────────────────────────────────────────

  /// Quick check-in (uses current timestamp or provided timestamp)
  Future<SessionModel> checkIn(
    String uid,
    String studentId, {
    DateTime? timestamp,
    String? notes,
    List<String>? weeklySchedule,
    String? sessionType,
    String? replacesMissedDate,
    StudentModel? student,
  }) async {
    final now = timestamp ?? DateTime.now();
    final dayAbbr = DateFormat('EEE').format(now); // e.g. "Sat", "Sun"
    final isScheduled = (weeklySchedule != null && weeklySchedule.isNotEmpty)
        ? weeklySchedule.contains(dayAbbr)
        : true;

    String resolvedType = sessionType ?? (isScheduled ? 'SCHEDULED' : 'EXTRA');
    String resolvedReplaced = replacesMissedDate ?? '';

    // If unscheduled and not explicitly passed, attempt automated FIFO classification
    if (sessionType == null && !isScheduled && student != null) {
      final monthStr = DateFormat('yyyy-MM').format(now);
      final existingSessions = await getStudentSessions(uid, studentId, monthYear: monthStr, useCache: true);
      final classification = AttendanceLedgerService.classifySession(
        student: student,
        sessionTimestamp: now,
        existingSessions: existingSessions,
      );
      resolvedType = classification.sessionType;
      resolvedReplaced = classification.replacesMissedDate;
    }

    final timeSlot = AppFormatters.getTimeSlot(now);

    final data = _buildSessionData(
      uid,
      studentId,
      now,
      notes: notes,
      timeSlot: timeSlot,
      isExtraClass: resolvedType != 'SCHEDULED',
      sessionType: resolvedType,
      replacesMissedDate: resolvedReplaced,
    );

    final docRef = await _sessionsRef(uid).add(data);
    final doc = await _getDoc(docRef);
    return SessionModel.fromFirestore(doc);
  }

  /// Manual entry with custom timestamp
  Future<SessionModel> manualEntry(
    String uid,
    String studentId,
    DateTime customTimestamp, {
    String? notes,
    String? timeSlot,
    bool? isExtraClass,
    List<String>? weeklySchedule,
    String? sessionType,
    String? replacesMissedDate,
    StudentModel? student,
  }) async {
    final slot = timeSlot ?? AppFormatters.getTimeSlot(customTimestamp);
    final dayAbbr = DateFormat('EEE').format(customTimestamp);
    final isScheduled = (weeklySchedule != null && weeklySchedule.isNotEmpty)
        ? weeklySchedule.contains(dayAbbr)
        : true;

    String resolvedType = sessionType ??
        (isExtraClass == true
            ? 'EXTRA'
            : (isScheduled ? 'SCHEDULED' : 'EXTRA'));
    String resolvedReplaced = replacesMissedDate ?? '';

    // If unscheduled and not explicitly provided, attempt automated FIFO classification
    if (sessionType == null && !isScheduled && student != null) {
      final monthStr = DateFormat('yyyy-MM').format(customTimestamp);
      final existingSessions = await getStudentSessions(uid, studentId, monthYear: monthStr, useCache: true);
      final classification = AttendanceLedgerService.classifySession(
        student: student,
        sessionTimestamp: customTimestamp,
        existingSessions: existingSessions,
      );
      resolvedType = classification.sessionType;
      resolvedReplaced = classification.replacesMissedDate;
    }

    final data = _buildSessionData(
      uid,
      studentId,
      customTimestamp,
      notes: notes,
      timeSlot: slot,
      isExtraClass: resolvedType != 'SCHEDULED',
      sessionType: resolvedType,
      replacesMissedDate: resolvedReplaced,
    );

    final docRef = await _sessionsRef(uid).add(data);
    final doc = await _getDoc(docRef);
    return SessionModel.fromFirestore(doc);
  }

  /// Build session document data from a timestamp
  Map<String, dynamic> _buildSessionData(
    String uid,
    String studentId,
    DateTime timestamp, {
    String? notes,
    String? timeSlot,
    bool isExtraClass = false,
    String sessionType = 'SCHEDULED',
    String replacesMissedDate = '',
  }) {
    final dateString = DateFormat('yyyy-MM-dd').format(timestamp);
    final dayOfWeek = DateFormat('EEEE').format(timestamp);
    final monthYear = DateFormat('yyyy-MM').format(timestamp);

    return {
      'tutorId': uid,
      'studentId': studentId,
      'timestamp': Timestamp.fromDate(timestamp),
      'dateString': dateString,
      'dayOfWeek': dayOfWeek,
      'monthYear': monthYear,
      'timeSlot': timeSlot ?? AppFormatters.getTimeSlot(timestamp),
      'isExtraClass': isExtraClass || sessionType != 'SCHEDULED',
      'sessionType': sessionType,
      'replacesMissedDate': replacesMissedDate,
      'notes': notes ?? '',
      'createdAt': _resilientTimestamp,
    };
  }

  /// Update session type classification and replaced missed date
  Future<void> updateSessionType(
    String uid,
    String sessionId, {
    required String sessionType,
    String replacesMissedDate = '',
  }) async {
    await _sessionsRef(uid).doc(sessionId).set(
      {
        'sessionType': sessionType,
        'replacesMissedDate': replacesMissedDate,
        'isExtraClass': sessionType != 'SCHEDULED',
      },
      SetOptions(merge: true),
    );
  }

  /// Fetch set of student IDs who have a session logged today
  Future<Set<String>> getTodayLoggedStudentIds(String uid) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = await _getDocs(
      _sessionsRef(uid).where('dateString', isEqualTo: todayStr),
    );

    final set = <String>{};
    for (final doc in snapshot.docs) {
      final sId = doc.data()['studentId'] as String?;
      if (sId != null && sId.isNotEmpty) {
        set.add(sId);
      }
    }
    return set;
  }

  /// Undo / remove today's session for a student
  Future<bool> deleteTodaySession(String uid, String studentId) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final snapshot = await _getDocs(
      _sessionsRef(uid)
          .where('studentId', isEqualTo: studentId)
          .where('dateString', isEqualTo: todayStr),
    );

    if (snapshot.docs.isEmpty) return false;

    // Delete the most recent session of today
    final docs = snapshot.docs;
    await docs.first.reference.delete();
    return true;
  }

  /// Get sessions for a specific student in a specific month
  Future<List<SessionModel>> getStudentSessions(
    String uid,
    String studentId, {
    String? monthYear,
    bool useCache = false,
  }) async {
    Query<Map<String, dynamic>> query =
        _sessionsRef(uid).where('studentId', isEqualTo: studentId);

    if (monthYear != null && monthYear.isNotEmpty) {
      query = query.where('monthYear', isEqualTo: monthYear);
    }

    final snapshot = await _getDocs(query, useCache: useCache);
    final sessions =
        snapshot.docs.map((doc) => SessionModel.fromFirestore(doc)).toList();

    // Sort descending by timestamp in memory
    sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sessions;
  }

  /// Get monthly session counts for all students (for dashboard summary)
  Future<Map<String, int>> getMonthlySessionCounts(
    String uid, {
    String? monthYear,
  }) async {
    final targetMonth =
        monthYear ?? DateFormat('yyyy-MM').format(DateTime.now());

    final snapshot = await _getDocs(
      _sessionsRef(uid).where('monthYear', isEqualTo: targetMonth),
    );

    final counts = <String, int>{};
    for (final doc in snapshot.docs) {
      final studentId = doc.data()['studentId'] as String? ?? '';
      if (studentId.isNotEmpty) {
        counts[studentId] = (counts[studentId] ?? 0) + 1;
      }
    }

    return counts;
  }

  /// Delete a session by its document ID
  Future<void> deleteSession(String uid, String sessionId) async {
    await _sessionsRef(uid).doc(sessionId).delete();
  }

  /// Update notes / topic for a specific session directly in Firestore
  Future<void> updateSessionNotes(
    String uid,
    String sessionId,
    String notes,
  ) async {
    await _sessionsRef(uid).doc(sessionId).set(
      {'notes': notes},
      SetOptions(merge: true),
    );
  }

  /// Get session count for a specific student in a month
  Future<int> getStudentSessionCount(
    String uid,
    String studentId, {
    String? monthYear,
  }) async {
    final targetMonth =
        monthYear ?? DateFormat('yyyy-MM').format(DateTime.now());

    final snapshot = await _getDocs(
      _sessionsRef(uid)
          .where('studentId', isEqualTo: studentId)
          .where('monthYear', isEqualTo: targetMonth),
    );

    return snapshot.docs.length;
  }

  /// Get all-time total session count for a student
  Future<int> getStudentTotalSessions(String uid, String studentId) async {
    final snapshot = await _getDocs(
      _sessionsRef(uid).where('studentId', isEqualTo: studentId),
    );
    return snapshot.docs.length;
  }

  // ─────────────────────────────────────────────────────
  // POSTPAID PAYMENTS SUBCOLLECTION
  // users/{uid}/students/{studentId}/payments
  // ─────────────────────────────────────────────────────

  /// Add a payment to a student's payment history
  Future<PaymentModel> addPayment(
    String uid,
    String studentId,
    Map<String, dynamic> data,
  ) async {
    data['studentId'] = studentId;
    data['tutorId'] = uid;
    data['createdAt'] = _resilientTimestamp;

    final docRef = await _paymentsRef(uid, studentId).add(data);
    final doc = await _getDoc(docRef);
    return PaymentModel.fromFirestore(doc);
  }

  /// Fetch all payments for a student
  Future<List<PaymentModel>> getPayments(String uid, String studentId) async {
    final snapshot = await _getDocs(_paymentsRef(uid, studentId));
    final payments =
        snapshot.docs.map((doc) => PaymentModel.fromFirestore(doc)).toList();
    payments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
    return payments;
  }

  /// Delete a payment record
  Future<void> deletePayment(
    String uid,
    String studentId,
    String paymentId,
  ) async {
    await _paymentsRef(uid, studentId).doc(paymentId).delete();
  }

  /// Calculate total fees collected for a student
  Future<double> getTotalFeesCollected(String uid, String studentId) async {
    final payments = await getPayments(uid, studentId);
    return payments.fold<double>(0.0, (total, p) => total + p.amount);
  }
}

