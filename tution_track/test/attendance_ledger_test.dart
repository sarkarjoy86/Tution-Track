import 'package:flutter_test/flutter_test.dart';
import 'package:tution_track/models/student_model.dart';
import 'package:tution_track/models/session_model.dart';
import 'package:tution_track/services/attendance_ledger_service.dart';

void main() {
  group('SessionModel Classification Tests', () {
    test('SessionModel defaults to SCHEDULED and supports MAKEUP and EXTRA', () {
      final scheduled = SessionModel(
        id: 's1',
        studentId: 'st1',
        timestamp: DateTime(2026, 9, 1, 16, 0),
        dateString: '2026-09-01',
        dayOfWeek: 'Tuesday',
        monthYear: '2026-09',
      );

      expect(scheduled.isScheduled, true);
      expect(scheduled.isMakeup, false);
      expect(scheduled.isPureExtra, false);
      expect(scheduled.formattedReplacedDate, '');

      final makeup = SessionModel(
        id: 's2',
        studentId: 'st1',
        timestamp: DateTime(2026, 9, 3, 16, 0),
        dateString: '2026-09-03',
        dayOfWeek: 'Thursday',
        monthYear: '2026-09',
        sessionType: 'MAKEUP',
        replacesMissedDate: '2026-09-01',
      );

      expect(makeup.isScheduled, false);
      expect(makeup.isMakeup, true);
      expect(makeup.isPureExtra, false);
      expect(makeup.formattedReplacedDate, 'Tue, 1st Sep');

      final pureExtra = SessionModel(
        id: 's3',
        studentId: 'st1',
        timestamp: DateTime(2026, 9, 4, 16, 0),
        dateString: '2026-09-04',
        dayOfWeek: 'Friday',
        monthYear: '2026-09',
        sessionType: 'EXTRA',
      );

      expect(pureExtra.isScheduled, false);
      expect(pureExtra.isMakeup, false);
      expect(pureExtra.isPureExtra, true);
    });

    test('SessionModel serialization preserves sessionType and replacesMissedDate', () {
      final session = SessionModel(
        id: 's1',
        studentId: 'st1',
        timestamp: DateTime(2026, 9, 3, 17, 30),
        dateString: '2026-09-03',
        dayOfWeek: 'Thursday',
        monthYear: '2026-09',
        sessionType: 'MAKEUP',
        replacesMissedDate: '2026-09-01',
      );

      final map = session.toMap();
      expect(map['sessionType'], 'MAKEUP');
      expect(map['replacesMissedDate'], '2026-09-01');

      final deserialized = SessionModel.fromJson(map);
      expect(deserialized.sessionType, 'MAKEUP');
      expect(deserialized.replacesMissedDate, '2026-09-01');
      expect(deserialized.isMakeup, true);
    });
  });

  group('AttendanceLedgerService Tests', () {
    final student = StudentModel(
      id: 'student_1',
      name: 'Rahim Ahmed',
      weeklySchedule: ['Tue', 'Thu'], // Scheduled on Tuesday and Thursday
      monthlyTargetClasses: 8,
      createdAt: DateTime(2026, 8, 15),
    );

    test('detectMissedDates detects scheduled days with no sessions up to yesterday', () {
      // Current date is 2026-09-05 (Saturday).
      // In September 2026 up to 2026-09-04 (Friday):
      // Sep 1 is Tuesday (Scheduled)
      // Sep 2 is Wednesday (Unscheduled)
      // Sep 3 is Thursday (Scheduled)
      // Sep 4 is Friday (Unscheduled)
      // No sessions logged yet. Both Sep 1 and Sep 3 should be detected as missed.

      final missed = AttendanceLedgerService.detectMissedDates(
        student: student,
        calendarMonth: DateTime(2026, 9, 1),
        sessions: [],
        nowOverride: DateTime(2026, 9, 5, 12, 0),
      );

      expect(missed.length, 2);
      expect(missed[0].date, '2026-09-01');
      expect(missed[0].dayAbbr, 'Tue');
      expect(missed[1].date, '2026-09-03');
      expect(missed[1].dayAbbr, 'Thu');
    });

    test('detectMissedDates excludes scheduled days where a session was completed', () {
      final completedSession = SessionModel(
        id: 's1',
        studentId: student.id,
        timestamp: DateTime(2026, 9, 1, 16, 0),
        dateString: '2026-09-01',
        dayOfWeek: 'Tuesday',
        monthYear: '2026-09',
        sessionType: 'SCHEDULED',
      );

      final missed = AttendanceLedgerService.detectMissedDates(
        student: student,
        calendarMonth: DateTime(2026, 9, 1),
        sessions: [completedSession],
        nowOverride: DateTime(2026, 9, 5, 12, 0),
      );

      // Sep 1 was attended, so only Sep 3 is missed
      expect(missed.length, 1);
      expect(missed[0].date, '2026-09-03');
    });

    test('classifySession performs FIFO mapping to earliest unfulfilled missed date', () {
      // Situation: Sep 1 (Tue) and Sep 3 (Thu) were missed.
      // On Sep 4 (Fri - unscheduled), tutor logs a class.
      // FIFO must match it to Sep 1 (the earliest unfulfilled gap).

      final classification1 = AttendanceLedgerService.classifySession(
        student: student,
        sessionTimestamp: DateTime(2026, 9, 4, 16, 0),
        existingSessions: [],
        nowOverride: DateTime(2026, 9, 5, 12, 0),
      );

      expect(classification1.sessionType, 'MAKEUP');
      expect(classification1.replacesMissedDate, '2026-09-01');

      // Now create the session for Sep 4
      final session4 = SessionModel(
        id: 's_sep4',
        studentId: student.id,
        timestamp: DateTime(2026, 9, 4, 16, 0),
        dateString: '2026-09-04',
        dayOfWeek: 'Friday',
        monthYear: '2026-09',
        sessionType: classification1.sessionType,
        replacesMissedDate: classification1.replacesMissedDate,
      );

      // On Sep 5 (Sat - unscheduled), tutor logs another class.
      // Next earliest unfulfilled gap is Sep 3.
      final classification2 = AttendanceLedgerService.classifySession(
        student: student,
        sessionTimestamp: DateTime(2026, 9, 5, 10, 0),
        existingSessions: [session4],
        nowOverride: DateTime(2026, 9, 5, 12, 0),
      );

      expect(classification2.sessionType, 'MAKEUP');
      expect(classification2.replacesMissedDate, '2026-09-03');

      // Create session for Sep 5
      final session5 = SessionModel(
        id: 's_sep5',
        studentId: student.id,
        timestamp: DateTime(2026, 9, 5, 10, 0),
        dateString: '2026-09-05',
        dayOfWeek: 'Saturday',
        monthYear: '2026-09',
        sessionType: classification2.sessionType,
        replacesMissedDate: classification2.replacesMissedDate,
      );

      // On Sep 5 evening (unscheduled), tutor logs a third unscheduled class.
      // All previous gaps (Sep 1 and Sep 3) are already resolved!
      // Must classify as pure EXTRA!
      final classification3 = AttendanceLedgerService.classifySession(
        student: student,
        sessionTimestamp: DateTime(2026, 9, 5, 18, 0),
        existingSessions: [session4, session5],
        nowOverride: DateTime(2026, 9, 5, 19, 0),
      );

      expect(classification3.sessionType, 'EXTRA');
      expect(classification3.replacesMissedDate, '');
    });

    test('reconcileMonth correctly aggregates Missed, Recovered, Unresolved and Extra counts', () {
      final session4 = SessionModel(
        id: 's_sep4',
        studentId: student.id,
        timestamp: DateTime(2026, 9, 4, 16, 0),
        dateString: '2026-09-04',
        dayOfWeek: 'Friday',
        monthYear: '2026-09',
        sessionType: 'MAKEUP',
        replacesMissedDate: '2026-09-01',
      );

      final summary = AttendanceLedgerService.reconcileMonth(
        student: student,
        calendarMonth: DateTime(2026, 9, 1),
        sessions: [session4],
        nowOverride: DateTime(2026, 9, 5, 12, 0),
      );

      expect(summary.missedCount, 2); // Sep 1 and Sep 3
      expect(summary.recoveredCount, 1); // Sep 1 is recovered by Sep 4
      expect(summary.unresolvedCount, 1); // Sep 3 is still pending
      expect(summary.makeupCount, 1);
      expect(summary.pureExtraCount, 0);

      // Check gap details
      final gap1 = summary.gapEntries.firstWhere((g) => g.date == '2026-09-01');
      expect(gap1.isResolved, true);
      expect(gap1.resolvedOn, '2026-09-04');

      final gap2 = summary.gapEntries.firstWhere((g) => g.date == '2026-09-03');
      expect(gap2.isResolved, false);
    });

    test('Deleting a makeup session reverts the gap back to unresolved pending status', () {
      // Simulating session deletion: removing session4 from sessions list
      final summaryAfterDeletion = AttendanceLedgerService.reconcileMonth(
        student: student,
        calendarMonth: DateTime(2026, 9, 1),
        sessions: [], // session deleted
        nowOverride: DateTime(2026, 9, 5, 12, 0),
      );

      expect(summaryAfterDeletion.missedCount, 2);
      expect(summaryAfterDeletion.recoveredCount, 0);
      expect(summaryAfterDeletion.unresolvedCount, 2);

      for (final gap in summaryAfterDeletion.gapEntries) {
        expect(gap.isResolved, false);
      }
    });

    test('reconcileSessions fixes Class #02 on Sep 3 from EXTRA to MAKEUP for Sep 2 missed class', () {
      final taiba = StudentModel(
        id: 'taiba_1',
        name: 'Taiba Rehman',
        weeklySchedule: ['Tue', 'Wed', 'Fri', 'Sat'],
        monthlyTargetClasses: 16,
        createdAt: DateTime(2026, 9, 3), // Created on Sep 3
      );

      // Class #01: Tuesday, Sep 1 (Scheduled)
      final class1 = SessionModel(
        id: 'c1',
        studentId: taiba.id,
        timestamp: DateTime(2026, 9, 1, 20, 22),
        dateString: '2026-09-01',
        dayOfWeek: 'Tuesday',
        monthYear: '2026-09',
        sessionType: 'SCHEDULED',
      );

      // Class #02: Thursday, Sep 3 (Off-schedule day, initially saved as EXTRA)
      final class2 = SessionModel(
        id: 'c2',
        studentId: taiba.id,
        timestamp: DateTime(2026, 9, 3, 20, 10),
        dateString: '2026-09-03',
        dayOfWeek: 'Thursday',
        monthYear: '2026-09',
        sessionType: 'EXTRA',
      );

      // Deterministic reconciliation pass (evaluating on Sep 5)
      final reconciled = AttendanceLedgerService.reconcileSessions(
        student: taiba,
        calendarMonth: DateTime(2026, 9, 1),
        sessions: [class1, class2],
        nowOverride: DateTime(2026, 9, 5, 12, 0),
      );

      expect(reconciled.length, 2);

      final reconciledClass2 = reconciled.firstWhere((s) => s.id == 'c2');
      expect(reconciledClass2.isMakeup, true);
      expect(reconciledClass2.type, SessionType.makeup);
      expect(reconciledClass2.sessionType, 'MAKEUP');
      expect(reconciledClass2.replacesMissedDate, '2026-09-02');
      expect(reconciledClass2.formattedReplacedDate, 'Wed, 2nd Sep');
    });

    test('calculateQuota correctly handles under quota, capped quota with bonus, and carry-forward', () {
      final student = StudentModel(
        id: 's_quota',
        name: 'Test Student',
        monthlyTargetClasses: 16,
        carriedForwardClasses: 2,
        carryForwardExtraClasses: true,
        createdAt: DateTime(2026, 9, 1),
      );

      // Case A: 11 sessions with 2 carried forward = 13 of 16
      final sessions11 = List.generate(
        11,
        (i) => SessionModel(
          id: 's_$i',
          studentId: student.id,
          timestamp: DateTime(2026, 9, i + 1),
          dateString: '2026-09-${(i + 1).toString().padLeft(2, '0')}',
          dayOfWeek: 'Monday',
          monthYear: '2026-09',
        ),
      );

      final quotaA = AttendanceLedgerService.calculateQuota(
        student: student,
        sessions: sessions11,
      );
      expect(quotaA.quotaCompleted, 13);
      expect(quotaA.totalTarget, 16);
      expect(quotaA.bonusExtraCount, 0);
      expect(quotaA.carriedForwardCount, 2);
      expect(quotaA.isQuotaCompleted, false);

      // Case B: 18 sessions (exceeds 16 target by 2 bonus classes)
      final studentNoCarry = student.copyWith(carriedForwardClasses: 0);
      final sessions18 = List.generate(
        18,
        (i) => SessionModel(
          id: 's_$i',
          studentId: student.id,
          timestamp: DateTime(2026, 9, i + 1),
          dateString: '2026-09-${(i + 1).toString().padLeft(2, '0')}',
          dayOfWeek: 'Monday',
          monthYear: '2026-09',
        ),
      );

      final quotaB = AttendanceLedgerService.calculateQuota(
        student: studentNoCarry,
        sessions: sessions18,
      );
      expect(quotaB.quotaCompleted, 16); // Capped at target
      expect(quotaB.totalTarget, 16);
      expect(quotaB.percentage, 100);
      expect(quotaB.bonusExtraCount, 2); // +2 Extra bonus classes
      expect(quotaB.isQuotaCompleted, true);
    });
  });
}

